"""
Cross-Database Analytics & Visualization Pipeline for ThuVien2 (Phase 8).

Joins relational data from SQL Server (ThuVien2) with high-frequency event logs
from MongoDB (ThuVien2Logs.library_event_logs) on Barcode and StudentCode,
then exports 4 business insight charts to analytics/charts/.
"""

from __future__ import annotations

import os
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
import pyodbc
import seaborn as sns
from pymongo import MongoClient

SQL_SERVER = os.getenv("THUVIEN2_SQL_SERVER", "localhost")
SQL_DB = os.getenv("THUVIEN2_SQL_DB", "ThuVien2")
MONGO_URI = os.getenv("THUVIEN2_MONGO_URI", "mongodb://localhost:27017/")
MONGO_DB = os.getenv("THUVIEN2_MONGO_DB", "ThuVien2Logs")
MONGO_COLLECTION = "library_event_logs"

CHARTS_DIR = Path(__file__).resolve().parent / "charts"


def get_sql_connection() -> pyodbc.Connection:
    """Connect to SQL Server ThuVien2 using an available SQL Server ODBC driver."""
    preferred_drivers = [
        "ODBC Driver 18 for SQL Server",
        "ODBC Driver 17 for SQL Server",
        "SQL Server",
    ]
    installed = set(pyodbc.drivers())
    driver = next((d for d in preferred_drivers if d in installed), None)
    if not driver:
        raise RuntimeError(f"No SQL Server ODBC driver found. Installed: {sorted(installed)}")

    conn_str = (
        f"DRIVER={{{driver}}};"
        f"SERVER={SQL_SERVER};"
        f"DATABASE={SQL_DB};"
        "Trusted_Connection=yes;"
        "TrustServerCertificate=yes;"
    )
    return pyodbc.connect(conn_str)


def load_sql_data(conn: pyodbc.Connection) -> dict[str, pd.DataFrame]:
    """Load relational tables and reporting views from SQL Server into DataFrames."""
    books_sql = """
        SELECT bi.BookItemID,
               bi.Barcode,
               bi.TitleID,
               bt.BookTitle,
               bi.StatusID,
               CAST(bi.Price AS FLOAT) AS Price
        FROM dbo.BookItem bi
        INNER JOIN dbo.BookTitle bt ON bi.TitleID = bt.TitleID;
    """
    students_sql = """
        SELECT StudentID,
               StudentCode,
               FullName,
               ClassName,
               AccountStatus,
               TotalBorrows,
               ActiveLoans,
               LateReturns,
               CAST(TotalFinesAssessed AS FLOAT) AS TotalFinesAssessed,
               CAST(TotalPaid AS FLOAT)          AS TotalPaid,
               CAST(TotalWaived AS FLOAT)        AS TotalWaived,
               CAST(OutstandingBalance AS FLOAT) AS OutstandingBalance
        FROM dbo.vw_Report_StudentActivityKPI;
    """
    fines_sql = """
        SELECT RuleCode,
               RuleName,
               FineCount,
               CAST(TotalAssessed AS FLOAT)    AS TotalAssessed,
               CAST(TotalCollected AS FLOAT)   AS TotalCollected,
               CAST(TotalWaived AS FLOAT)      AS TotalWaived,
               CAST(TotalOutstanding AS FLOAT) AS TotalOutstanding
        FROM dbo.vw_Report_FineSummaryByRule;
    """

    cursor = conn.cursor()

    def query_df(sql: str) -> pd.DataFrame:
        cursor.execute(sql)
        cols = [col[0] for col in cursor.description]
        rows = [tuple(row) for row in cursor.fetchall()]
        return pd.DataFrame(rows, columns=cols)

    return {
        "books": query_df(books_sql),
        "students": query_df(students_sql),
        "fines": query_df(fines_sql),
    }


def load_mongo_logs() -> pd.DataFrame:
    """Load library event logs from MongoDB into a pandas DataFrame."""
    client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
    col = client[MONGO_DB][MONGO_COLLECTION]
    docs = list(
        col.find(
            {},
            {
                "_id": 0,
                "event_id": 1,
                "event_type": 1,
                "timestamp": 1,
                "StudentCode": 1,
                "Barcode": 1,
                "station_id": 1,
                "action": 1,
                "result": 1,
                "response_time_ms": 1,
            },
        )
    )
    if not docs:
        raise RuntimeError("No documents found in MongoDB. Run nosql/generate_logs.py first.")

    df = pd.DataFrame(docs)
    df["timestamp"] = pd.to_datetime(df["timestamp"], utc=True)
    df["hour"] = df["timestamp"].dt.hour
    return df


def plot_search_demand_vs_availability(
    df_logs_books: pd.DataFrame, df_books: pd.DataFrame
) -> Path:
    """Chart 1: Digital catalog/kiosk demand (MongoDB) vs. physical AVAILABLE copies (SQL)."""
    demand = (
        df_logs_books[df_logs_books["event_type"].isin(["CATALOG_SEARCH", "KIOSK_SCAN"])]
        .groupby("BookTitle", as_index=False)
        .agg(
            DigitalDemand=("event_id", "count"),
            UnavailableHits=("result", lambda s: int((s == "UNAVAILABLE").sum())),
        )
    )
    stock = (
        df_books.groupby("BookTitle", as_index=False)
        .agg(
            TotalCopies=("BookItemID", "count"),
            AvailableCopies=("StatusID", lambda s: int((s == "AVAILABLE").sum())),
        )
    )
    merged = demand.merge(stock, on="BookTitle", how="inner").sort_values(
        "DigitalDemand", ascending=True
    )

    fig, ax1 = plt.subplots(figsize=(11, 5.5))
    y = range(len(merged))

    ax1.barh(y, merged["DigitalDemand"], height=0.45, color="#2b6cb0", label="Digital Demand (Searches + Scans)")
    ax1.barh(
        [i - 0.25 for i in y],
        merged["UnavailableHits"],
        height=0.25,
        color="#e53e3e",
        alpha=0.85,
        label="Unavailable Hits",
    )
    ax1.set_yticks(list(y))
    ax1.set_yticklabels(merged["BookTitle"], fontsize=9)
    ax1.set_xlabel("MongoDB Event Count (60 Days)")
    ax1.set_title("Digital Demand vs. Physical Copy Availability by Book Title", fontweight="bold")

    for i, (_, row) in enumerate(merged.iterrows()):
        ax1.text(
            row["DigitalDemand"] + 15,
            i,
            f"Avail: {int(row['AvailableCopies'])}/{int(row['TotalCopies'])}",
            va="center",
            fontsize=8.5,
            color="#2d3748",
            fontweight="bold",
        )

    ax1.set_xlim(0, merged["DigitalDemand"].max() * 1.22)
    ax1.legend(loc="lower right")
    fig.tight_layout()

    out = CHARTS_DIR / "01_search_demand_vs_availability.png"
    fig.savefig(out, dpi=150)
    plt.close(fig)
    return out


def plot_kiosk_hourly_traffic(df_logs: pd.DataFrame) -> Path:
    """Chart 2: Hourly kiosk scan traffic segmented by outcome result."""
    kiosk = df_logs[df_logs["event_type"] == "KIOSK_SCAN"]
    hourly = (
        kiosk.groupby(["hour", "result"])
        .size()
        .unstack(fill_value=0)
        .sort_index()
    )

    palette = {
        "SUCCESS": "#38a169",
        "UNAVAILABLE": "#dd6b20",
        "DENIED_FINES": "#e53e3e",
        "DENIED_LIMIT": "#805ad5",
    }
    cols = [c for c in ["SUCCESS", "UNAVAILABLE", "DENIED_FINES", "DENIED_LIMIT"] if c in hourly.columns]
    colors = [palette[c] for c in cols]

    fig, ax = plt.subplots(figsize=(11, 5))
    hourly[cols].plot(kind="bar", stacked=True, color=colors, ax=ax, width=0.75)
    ax.set_title("Hourly Kiosk Scan Volume & Checkout Outcomes", fontweight="bold")
    ax.set_xlabel("Hour of Day (UTC)")
    ax.set_ylabel("Kiosk Scan Events")
    ax.tick_params(axis="x", rotation=0)
    ax.legend(title="Outcome")
    fig.tight_layout()

    out = CHARTS_DIR / "02_kiosk_hourly_traffic_vs_checkouts.png"
    fig.savefig(out, dpi=150)
    plt.close(fig)
    return out


def plot_student_engagement_vs_delinquency(df_logs_students: pd.DataFrame) -> Path:
    """Chart 3: Student digital activity (MongoDB) vs. outstanding fine balance (SQL)."""
    stu_summary = (
        df_logs_students.groupby(
            ["StudentCode", "FullName", "AccountStatus", "OutstandingBalance"],
            as_index=False,
        )
        .agg(
            TotalEvents=("event_id", "count"),
            DeniedFines=("result", lambda s: int((s == "DENIED_FINES").sum())),
        )
        .sort_values("TotalEvents", ascending=False)
    )

    fig, ax1 = plt.subplots(figsize=(11, 5.5))
    x = range(len(stu_summary))
    labels = [
        f"{r['FullName']}\n({r['StudentCode']}, {r['AccountStatus']})"
        for _, r in stu_summary.iterrows()
    ]

    status_colors = {
        "ACTIVE": "#3182ce",
        "SUSPENDED": "#e53e3e",
        "EXPIRED": "#718096",
    }
    bar_colors = [status_colors.get(s, "#3182ce") for s in stu_summary["AccountStatus"]]

    bars = ax1.bar(x, stu_summary["TotalEvents"], width=0.45, color=bar_colors, alpha=0.85, label="Total Log Events")
    ax1.set_xticks(list(x))
    ax1.set_xticklabels(labels, fontsize=8.5)
    ax1.set_ylabel("MongoDB Log Events (Scans + Searches)")
    ax1.set_title("Student Library Engagement vs. Fine Delinquency", fontweight="bold")

    ax2 = ax1.twinx()
    ax2.plot(
        list(x),
        stu_summary["OutstandingBalance"] / 1000.0,
        color="#c53030",
        marker="o",
        linewidth=2.2,
        label="Outstanding Fines (k VND)",
    )
    ax2.set_ylabel("Outstanding Fine Balance (Thousand VND)", color="#c53030")
    ax2.tick_params(axis="y", labelcolor="#c53030")

    for bar, (_, row) in zip(bars, stu_summary.iterrows()):
        ax1.text(
            bar.get_x() + bar.get_width() / 2,
            bar.get_height() + 15,
            f"Denied: {int(row['DeniedFines'])}",
            ha="center",
            fontsize=8,
            color="#2d3748",
        )

    fig.tight_layout()
    out = CHARTS_DIR / "03_student_engagement_vs_delinquency.png"
    fig.savefig(out, dpi=150)
    plt.close(fig)
    return out


def plot_fine_revenue_and_recovery(
    df_fines: pd.DataFrame, df_logs: pd.DataFrame
) -> Path:
    """Chart 4: Fine assessment & recovery breakdown by FineRule + RFID gate alerts."""
    fines = df_fines.set_index("RuleCode")[
        ["TotalCollected", "TotalWaived", "TotalOutstanding"]
    ] / 1000.0

    rfid_alerts = int(
        ((df_logs["event_type"] == "RFID_GATE_PING") & (df_logs["result"] == "UNRETURNED_ALERT")).sum()
    )

    fig, ax = plt.subplots(figsize=(10, 5))
    fines.plot(
        kind="bar",
        stacked=True,
        color=["#38a169", "#4299e1", "#e53e3e"],
        ax=ax,
        width=0.55,
    )
    ax.set_title(
        f"Fine Recovery Breakdown by Rule (RFID Gate Unreturned Alerts: {rfid_alerts})",
        fontweight="bold",
    )
    ax.set_xlabel("Fine Rule Code")
    ax.set_ylabel("Amount (Thousand VND)")
    ax.tick_params(axis="x", rotation=0)
    ax.legend(["Collected (PAYMENT)", "Waived (WAIVER)", "Outstanding (UNPAID/PARTIAL)"])

    for i, rule in enumerate(fines.index):
        total = fines.loc[rule].sum()
        ax.text(i, total + 8, f"{total:,.0f}k", ha="center", fontsize=9, fontweight="bold")

    fig.tight_layout()
    out = CHARTS_DIR / "04_fine_revenue_and_recovery_breakdown.png"
    fig.savefig(out, dpi=150)
    plt.close(fig)
    return out


def main() -> None:
    sns.set_theme(style="whitegrid")
    CHARTS_DIR.mkdir(parents=True, exist_ok=True)

    with get_sql_connection() as conn:
        sql_data = load_sql_data(conn)

    df_logs = load_mongo_logs()

    # Cross-DB joins on Barcode and StudentCode
    df_logs_books = df_logs.merge(sql_data["books"], on="Barcode", how="inner")
    df_logs_students = df_logs.merge(sql_data["students"], on="StudentCode", how="inner")

    print(
        f"Loaded {len(df_logs)} MongoDB logs | "
        f"Joined {len(df_logs_books)} rows on Barcode | "
        f"Joined {len(df_logs_students)} rows on StudentCode."
    )

    charts = [
        plot_search_demand_vs_availability(df_logs_books, sql_data["books"]),
        plot_kiosk_hourly_traffic(df_logs),
        plot_student_engagement_vs_delinquency(df_logs_students),
        plot_fine_revenue_and_recovery(sql_data["fines"], df_logs),
    ]

    for chart_path in charts:
        print(f"Exported chart: {chart_path}")


if __name__ == "__main__":
    main()
