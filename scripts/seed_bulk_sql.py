"""
Bulk SQL Server Data Seeder for ThuVien2 (Phase 9).

Preserves all existing 002_seed/ records and appends:
  - ~40 Students (ACTIVE, SUSPENDED, EXPIRED)
  - ~20 BookTitles + Authors + Author_BookTitle links
  - ~75 BookItems (Barcode BI101..BI175)
  - ~300 historical LoanSlip / LoanItem / ReturnSlip / ReturnItem / FineItem / PaymentReceipt
    transactions over the past 6 months (180 days), respecting CK_FineItem_Link XOR.
"""

from __future__ import annotations

import os
import random
from datetime import date, timedelta

import pyodbc

SQL_SERVER = os.getenv("THUVIEN2_SQL_SERVER", "localhost")
SQL_DB = os.getenv("THUVIEN2_SQL_DB", "ThuVien2")


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
    return pyodbc.connect(conn_str, autocommit=False)


def _fetch_scalar_id(cur: pyodbc.Cursor) -> int:
    """Fetch a single integer ID from an OUTPUT inserted.<ID> query."""
    row = cur.fetchone()
    if row is None:
        raise RuntimeError("Expected an inserted ID row from SQL Server, got None.")
    return int(row[0])


def main() -> None:
    random.seed(42)
    today = date.today()

    with get_sql_connection() as conn:
        cur = conn.cursor()

        # Fetch lookup IDs from existing seeds
        cur.execute("SELECT StaffID, RoleID FROM dbo.Staff ORDER BY StaffID;")
        staff_rows = cur.fetchall()
        librarian_ids = [r[0] for r in staff_rows if r[1] == "LIBRARIAN"] or [staff_rows[0][0]]
        admin_ids = [r[0] for r in staff_rows if r[1] == "ADMIN"] or [staff_rows[0][0]]

        cur.execute("SELECT RuleCode, RuleID, RatePerDay, PercentOfBookValue, FixedProcessingFee FROM dbo.FineRule;")
        rules = {
            r[0]: {
                "id": r[1],
                "rate": float(r[2] or 0),
                "pct": float(r[3] or 0),
                "fee": float(r[4] or 0),
            }
            for r in cur.fetchall()
        }

        # ---------------------------------------------------------------------
        # 1. Insert 40 Students
        # ---------------------------------------------------------------------
        first_names = ["Nguyen", "Tran", "Le", "Pham", "Hoang", "Huynh", "Phan", "Vu", "Vo", "Dang"]
        mid_names = ["Minh", "Hoang", "Anh", "Thu", "Quoc", "Gia", "Thanh", "Ngoc", "Duc", "Khanh"]
        last_names = ["An", "Binh", "Chi", "Dung", "Giang", "Hai", "Huy", "Khoa", "Linh", "Nam", "Phuc", "Trang"]
        classes = ["29K12.1", "29K12.2", "29K12.3", "28K10.1", "28K10.2", "30K14.1"]

        new_student_ids: list[int] = []
        for i in range(1, 41):
            code = f"29210253{i:03d}"
            full_name = f"{random.choice(first_names)} {random.choice(mid_names)} {random.choice(last_names)}"
            cls = random.choice(classes)
            email = f"stu{i:03d}@uni.edu.vn"
            status = random.choices(["ACTIVE", "SUSPENDED", "EXPIRED"], weights=[85, 8, 7], k=1)[0]
            cur.execute(
                """
                INSERT INTO dbo.Student (StudentCode, FullName, ClassName, Email, Status)
                OUTPUT inserted.StudentID
                VALUES (?, ?, ?, ?, ?);
                """,
                code,
                full_name,
                cls,
                email,
                status,
            )
            new_student_ids.append(_fetch_scalar_id(cur))

        # ---------------------------------------------------------------------
        # 2. Insert 10 Authors & 20 BookTitles + Author_BookTitle
        # ---------------------------------------------------------------------
        author_names = [
            "Eric Evans",
            "Joshua Bloch",
            "Thomas H. Cormen",
            "Donald Knuth",
            "Bjarne Stroustrup",
            "Herbert Schildt",
            "Wes McKinney",
            "Jake VanderPlas",
            "Ian Goodfellow",
            "Andriy Burkov",
        ]
        author_ids: list[int] = []
        for name in author_names:
            cur.execute("INSERT INTO dbo.Author (AuthorName) OUTPUT inserted.AuthorID VALUES (?);", name)
            author_ids.append(_fetch_scalar_id(cur))

        book_titles = [
            ("Domain-Driven Design", 0),
            ("Effective Java", 1),
            ("Introduction to Algorithms", 2),
            ("The Art of Computer Programming Vol 1", 3),
            ("The C++ Programming Language", 4),
            ("Java: The Complete Reference", 5),
            ("Python for Data Analysis", 6),
            ("Python Data Science Handbook", 7),
            ("Deep Learning", 8),
            ("The Hundred-Page Machine Learning Book", 9),
            ("SQL Performance Explained", 0),
            ("Database Internals", 2),
            ("High Performance MySQL", 1),
            ("Designing Distributed Systems", 3),
            ("Fundamentals of Software Architecture", 4),
            ("Head First Design Patterns", 5),
            ("Hands-On Machine Learning", 6),
            ("Fluent Python", 7),
            ("Pattern Recognition and Machine Learning", 8),
            ("Reliable Machine Learning", 9),
        ]
        title_ids: list[int] = []
        for title, auth_idx in book_titles:
            cur.execute("INSERT INTO dbo.BookTitle (BookTitle) OUTPUT inserted.TitleID VALUES (?);", title)
            tid = _fetch_scalar_id(cur)
            title_ids.append(tid)
            cur.execute(
                "INSERT INTO dbo.Author_BookTitle (AuthorID, TitleID) VALUES (?, ?);",
                author_ids[auth_idx],
                tid,
            )

        # ---------------------------------------------------------------------
        # 3. Insert 75 BookItems (BI101..BI175)
        # ---------------------------------------------------------------------
        book_items: list[dict] = []
        for idx in range(1, 76):
            barcode = f"BI{100 + idx:03d}"
            # Skew copies slightly toward earlier popular titles
            tid = title_ids[(idx - 1) % len(title_ids)]
            price = float(random.choice([120000, 150000, 220000, 280000, 350000, 420000, 500000]))
            cur.execute(
                """
                INSERT INTO dbo.BookItem (Barcode, TitleID, StatusID, Price)
                OUTPUT inserted.BookItemID
                VALUES (?, ?, 'AVAILABLE', ?);
                """,
                barcode,
                tid,
                price,
            )
            bid = _fetch_scalar_id(cur)
            book_items.append({"id": bid, "price": price, "available_from": today - timedelta(days=180), "final_status": "AVAILABLE"})

        # ---------------------------------------------------------------------
        # 4. Simulate ~300 historical transactions over the past 180 days
        # ---------------------------------------------------------------------
        # Sort simulation chronologically so each BookItem is only loaned when free
        loan_dates = sorted(today - timedelta(days=random.randint(1, 179)) for _ in range(300))
        created_loans = 0
        created_returns = 0
        created_fines = 0

        for loan_date in loan_dates:
            free_items = [b for b in book_items if b["final_status"] == "AVAILABLE" and b["available_from"] <= loan_date]
            if not free_items:
                continue

            item = random.choice(free_items)
            stu_id = random.choice(new_student_ids)
            staff_id = random.choice(librarian_ids)
            due_date = loan_date + timedelta(days=14)

            cur.execute(
                """
                INSERT INTO dbo.LoanSlip (StudentID, StaffID, LoanDate)
                OUTPUT inserted.LoanSlipID
                VALUES (?, ?, ?);
                """,
                stu_id,
                staff_id,
                loan_date,
            )
            loan_slip_id = _fetch_scalar_id(cur)

            cur.execute(
                """
                INSERT INTO dbo.LoanItem (BookItemID, LoanSlipID, DueDate)
                OUTPUT inserted.LoanItemID
                VALUES (?, ?, ?);
                """,
                item["id"],
                loan_slip_id,
                due_date,
            )
            loan_item_id = _fetch_scalar_id(cur)
            created_loans += 1

            # Recent loans (last 20 days) have a higher chance of still being active
            if (today - loan_date).days <= 20 and random.random() < 0.35:
                item["final_status"] = "BORROWED"
                continue

            outcome = random.choices(
                ["ON_TIME", "LATE", "DAMAGED", "LOST"],
                weights=[64, 24, 7, 5],
                k=1,
            )[0]

            if outcome == "LOST":
                # LOST fine links directly to LoanItemID (ReturnItemID IS NULL)
                item["final_status"] = "LOST"
                r = rules["LOST"]
                amount = round(item["price"] * r["pct"] + r["fee"], 2)
                fine_status = random.choices(["PAID", "PARTIAL", "UNPAID", "WAIVED"], weights=[45, 25, 20, 10], k=1)[0]
                cur.execute(
                    """
                    INSERT INTO dbo.FineItem (FineRuleID, ReturnItemID, LoanItemID, Amount, Status, Description)
                    OUTPUT inserted.FineItemID
                    VALUES (?, NULL, ?, ?, ?, ?);
                    """,
                    r["id"],
                    loan_item_id,
                    amount,
                    fine_status,
                    "Lost book replacement fine",
                )
                fine_id = _fetch_scalar_id(cur)
                created_fines += 1
                _insert_payment_for_fine(
                    cur, fine_id, amount, fine_status, stu_id, staff_id, admin_ids[0], min(today, due_date + timedelta(days=7))
                )
                continue

            # Book was returned (ON_TIME, LATE, or DAMAGED)
            if outcome == "ON_TIME":
                ret_date = min(today, loan_date + timedelta(days=random.randint(1, 14)))
            else:
                days_late = random.randint(1, 18) if outcome == "LATE" else random.randint(0, 5)
                ret_date = min(today, due_date + timedelta(days=days_late))

            cur.execute(
                """
                INSERT INTO dbo.ReturnSlip (StudentID, StaffID, ReturnDate)
                OUTPUT inserted.ReturnSlipID
                VALUES (?, ?, ?);
                """,
                stu_id,
                staff_id,
                ret_date,
            )
            ret_slip_id = _fetch_scalar_id(cur)

            cur.execute(
                """
                INSERT INTO dbo.ReturnItem (ReturnSlipID, LoanItemID)
                OUTPUT inserted.ReturnItemID
                VALUES (?, ?);
                """,
                ret_slip_id,
                loan_item_id,
            )
            ret_item_id = _fetch_scalar_id(cur)
            created_returns += 1

            # Book becomes available again after return unless damaged
            if outcome == "DAMAGED" and random.random() < 0.3:
                item["final_status"] = "DAMAGED"
            else:
                item["final_status"] = "AVAILABLE"
                item["available_from"] = ret_date + timedelta(days=1)

            if ret_date > due_date:
                days_over = (ret_date - due_date).days
                r = rules["LATE"]
                late_amt = round(days_over * r["rate"] + r["fee"], 2)
                fine_status = random.choices(["PAID", "PARTIAL", "UNPAID", "WAIVED"], weights=[60, 15, 18, 7], k=1)[0]
                cur.execute(
                    """
                    INSERT INTO dbo.FineItem (FineRuleID, ReturnItemID, LoanItemID, Amount, Status, Description)
                    OUTPUT inserted.FineItemID
                    VALUES (?, ?, NULL, ?, ?, ?);
                    """,
                    r["id"],
                    ret_item_id,
                    late_amt,
                    fine_status,
                    f"Overdue return by {days_over} day(s)",
                )
                fine_id = _fetch_scalar_id(cur)
                created_fines += 1
                _insert_payment_for_fine(cur, fine_id, late_amt, fine_status, stu_id, staff_id, admin_ids[0], ret_date)

            if outcome == "DAMAGED":
                r = rules["DAMAGED"]
                dmg_amt = round(item["price"] * r["pct"] + r["fee"], 2)
                fine_status = random.choices(["PAID", "PARTIAL", "UNPAID", "WAIVED"], weights=[55, 15, 20, 10], k=1)[0]
                cur.execute(
                    """
                    INSERT INTO dbo.FineItem (FineRuleID, ReturnItemID, LoanItemID, Amount, Status, Description)
                    OUTPUT inserted.FineItemID
                    VALUES (?, ?, NULL, ?, ?, ?);
                    """,
                    r["id"],
                    ret_item_id,
                    dmg_amt,
                    fine_status,
                    "Damaged book penalty",
                )
                fine_id = _fetch_scalar_id(cur)
                created_fines += 1
                _insert_payment_for_fine(cur, fine_id, dmg_amt, fine_status, stu_id, staff_id, admin_ids[0], ret_date)

        # Persist final BookItem statuses (BORROWED / LOST / DAMAGED)
        for item in book_items:
            if item["final_status"] != "AVAILABLE":
                cur.execute(
                    "UPDATE dbo.BookItem SET StatusID = ? WHERE BookItemID = ?;",
                    item["final_status"],
                    item["id"],
                )

        conn.commit()
        print(
            f"Bulk SQL seed complete: +{len(new_student_ids)} students, +{len(title_ids)} titles, "
            f"+{len(book_items)} copies, +{created_loans} loans, +{created_returns} returns, +{created_fines} fines."
        )


def _insert_payment_for_fine(
    cur: pyodbc.Cursor,
    fine_id: int,
    amount: float,
    fine_status: str,
    stu_id: int,
    staff_id: int,
    admin_id: int,
    pay_date: date,
) -> None:
    if fine_status == "UNPAID":
        return

    if fine_status == "PAID":
        paid = amount
        rtype = "PAYMENT"
        sid = staff_id
    elif fine_status == "PARTIAL":
        paid = round(amount * random.choice([0.3, 0.4, 0.5]), 2)
        rtype = "PAYMENT"
        sid = staff_id
    else:  # WAIVED
        paid = amount
        rtype = "WAIVER"
        sid = admin_id

    cur.execute(
        """
        INSERT INTO dbo.PaymentReceipt (StaffID, StudentID, PaymentDate, ReceiptType, Total)
        OUTPUT inserted.ReceiptID
        VALUES (?, ?, ?, ?, ?);
        """,
        sid,
        stu_id,
        pay_date,
        rtype,
        paid,
    )
    receipt_id = _fetch_scalar_id(cur)
    cur.execute(
        "INSERT INTO dbo.PaymentItem (ReceiptID, FineItemID, AmountPaid) VALUES (?, ?, ?);",
        receipt_id,
        fine_id,
        paid,
    )


if __name__ == "__main__":
    main()
