"""
Bulk MongoDB Event Log Generator for ThuVien2 (Phase 7).

Queries live StudentCode and Barcode keys from SQL Server (ThuVien2)
and inserts 5,500+ realistic library event log documents into MongoDB
(ThuVien2Logs.library_event_logs) for cross-database analytics.
"""

from __future__ import annotations

import os
import random
import uuid
from datetime import datetime, timedelta, timezone

import pyodbc
from pymongo import ASCENDING, MongoClient

SQL_SERVER = os.getenv("THUVIEN2_SQL_SERVER", "localhost")
SQL_DB = os.getenv("THUVIEN2_SQL_DB", "ThuVien2")
MONGO_URI = os.getenv("THUVIEN2_MONGO_URI", "mongodb://localhost:27017/")
MONGO_DB = os.getenv("THUVIEN2_MONGO_DB", "ThuVien2Logs")
MONGO_COLLECTION = "library_event_logs"
TARGET_DOC_COUNT = 5500


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


def fetch_sql_keys(conn: pyodbc.Connection) -> tuple[list[dict], list[dict]]:
    """Fetch live StudentCode and Barcode records from ThuVien2."""
    cursor = conn.cursor()

    cursor.execute("SELECT StudentCode, Status FROM dbo.Student;")
    students = [{"StudentCode": row[0], "Status": row[1]} for row in cursor.fetchall()]

    cursor.execute(
        """
        SELECT bi.Barcode, bi.StatusID, bt.BookTitle
        FROM dbo.BookItem bi
        INNER JOIN dbo.BookTitle bt ON bi.TitleID = bt.TitleID;
        """
    )
    books = [
        {"Barcode": row[0], "StatusID": row[1], "BookTitle": row[2]}
        for row in cursor.fetchall()
    ]

    if not students or not books:
        raise RuntimeError("SQL Server ThuVien2 has no Student or BookItem rows. Run seeds first.")

    return students, books


def weighted_timestamp(now_utc: datetime) -> datetime:
    """Generate a realistic timestamp over the past 60 days weighted toward daytime campus hours."""
    days_ago = random.randint(0, 59)
    # Campus hours 07:00 - 21:00 weighted higher
    hours = list(range(7, 22))
    weights = [2, 5, 8, 10, 9, 7, 8, 10, 9, 8, 6, 4, 3, 2, 1]
    hour = random.choices(hours, weights=weights, k=1)[0]
    minute = random.randint(0, 59)
    second = random.randint(0, 59)
    dt = (now_utc - timedelta(days=days_ago)).replace(
        hour=hour, minute=minute, second=second, microsecond=0
    )
    return dt


def build_event_document(
    students: list[dict], books: list[dict], now_utc: datetime
) -> dict:
    """Construct a single realistic event log document referencing live SQL keys."""
    student = random.choice(students)
    book = random.choice(books)
    event_type = random.choices(
        ["KIOSK_SCAN", "CATALOG_SEARCH", "RFID_GATE_PING"],
        weights=[45, 35, 20],
        k=1,
    )[0]

    ts = weighted_timestamp(now_utc)
    ts_iso = ts.strftime("%Y-%m-%dT%H:%M:%SZ")

    if event_type == "KIOSK_SCAN":
        action = random.choices(
            ["SELF_CHECKOUT_ATTEMPT", "SELF_RETURN_SCAN", "BARCODE_LOOKUP"],
            weights=[55, 25, 20],
            k=1,
        )[0]
        if action == "SELF_CHECKOUT_ATTEMPT":
            if student["Status"] != "ACTIVE":
                result = "DENIED_FINES"
            elif book["StatusID"] != "AVAILABLE":
                result = "UNAVAILABLE"
            else:
                result = random.choices(
                    ["SUCCESS", "DENIED_FINES", "DENIED_LIMIT"],
                    weights=[78, 12, 10],
                    k=1,
                )[0]
        else:
            result = "SUCCESS"

        return {
            "event_id": str(uuid.uuid4()),
            "event_type": event_type,
            "timestamp": ts_iso,
            "StudentCode": student["StudentCode"],
            "Barcode": book["Barcode"],
            "station_id": random.choice(["KIOSK-01", "KIOSK-02", "KIOSK-03"]),
            "action": action,
            "result": result,
            "search_query": None,
            "response_time_ms": random.randint(65, 320),
            "metadata": {
                "client_os": "Windows-Kiosk",
                "session_duration_sec": random.randint(8, 60),
            },
        }

    if event_type == "CATALOG_SEARCH":
        result = "SUCCESS" if book["StatusID"] == "AVAILABLE" else "UNAVAILABLE"
        return {
            "event_id": str(uuid.uuid4()),
            "event_type": event_type,
            "timestamp": ts_iso,
            "StudentCode": student["StudentCode"],
            "Barcode": book["Barcode"],
            "station_id": random.choice(["OPAC-WEB-01", "OPAC-WEB-02", "MOBILE-APP"]),
            "action": "OPAC_KEYWORD_SEARCH",
            "result": result,
            "search_query": book["BookTitle"],
            "response_time_ms": random.randint(25, 190),
            "metadata": {
                "client_os": "Web-Browser",
                "session_duration_sec": random.randint(15, 180),
            },
        }

    # RFID_GATE_PING
    result = "UNRETURNED_ALERT" if book["StatusID"] == "LOST" else "CLEARED"
    return {
        "event_id": str(uuid.uuid4()),
        "event_type": event_type,
        "timestamp": ts_iso,
        "StudentCode": student["StudentCode"],
        "Barcode": book["Barcode"],
        "station_id": random.choice(["GATE-MAIN-01", "GATE-EXIT-02"]),
        "action": "EXIT_GATE_CHECK",
        "result": result,
        "search_query": None,
        "response_time_ms": random.randint(10, 45),
        "metadata": {
            "client_os": "RFID-Firmware-v2",
            "session_duration_sec": 1,
        },
    }


def main() -> None:
    random.seed(42)
    now_utc = datetime.now(timezone.utc)

    with get_sql_connection() as sql_conn:
        students, books = fetch_sql_keys(sql_conn)

    print(
        f"Loaded {len(students)} StudentCode(s) and {len(books)} Barcode(s) from SQL Server ({SQL_DB})."
    )

    docs = [build_event_document(students, books, now_utc) for _ in range(TARGET_DOC_COUNT)]

    client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
    db = client[MONGO_DB]
    col = db[MONGO_COLLECTION]

    # Idempotent reload
    col.drop()

    batch_size = 1000
    for start in range(0, len(docs), batch_size):
        col.insert_many(docs[start : start + batch_size])

    col.create_index([("StudentCode", ASCENDING)])
    col.create_index([("Barcode", ASCENDING)])
    col.create_index([("event_type", ASCENDING)])
    col.create_index([("timestamp", ASCENDING)])

    total_inserted = col.count_documents({})
    print(f"Inserted {total_inserted} documents into {MONGO_DB}.{MONGO_COLLECTION}.")


if __name__ == "__main__":
    main()
