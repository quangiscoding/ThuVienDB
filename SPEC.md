# SPEC.md — ThuVien2 Library Management System Specification

## 1. System Overview
Database-first Library Management System built on **Microsoft SQL Server (T-SQL)**, extended with a **MongoDB** high-frequency event log store and a **Python** cross-database analytics pipeline. All core relational business rules, validation, and transactional state changes live in SQL Server stored procedures and functions.

## 2. Domain Entities (Relational Schema)
- **Staff & Roles:** `dbo.Role` (`ADMIN`, `LIBRARIAN`), `dbo.NhanVien`
- **Patrons:** `dbo.SinhVien` (`TrangThai`: `ACTIVE`, `SUSPENDED`, `EXPIRED`)
- **Catalog:** `dbo.BookTitle`, `dbo.Author`, `dbo.Author_BookTitle`, `dbo.BookItem` (individual barcodes `MaVach`, `Price`, `StatusID`: `AVAILABLE`, `BORROWED`, `LOST`, `DAMAGED`)
- **Circulation:** `dbo.PhieuMuon` (header) + `dbo.DongMuon` (line items, 14-day default loan), `dbo.PhieuTra` (header) + `dbo.DongTra` (line items)
- **Fines & Receipts:** `dbo.FineRule` (`LATE`, `LOST`, `DAMAGED`), `dbo.DongPhat` (fine ledger linked XOR to `DongTraID` or `DongMuonID`), `dbo.PhieuThu` (`LoaiPhieu`: `PAYMENT`, `WAIVER`) + `dbo.DongThu` (payment/waiver line items)

## 3. Business Rules & Modules

### 3.1 Shared (`001_shared`)
- **`fn_CalculateFine(@RuleID, @DaysOverdue, @BookPrice, @CustomDamagePercent)`**:
  - Looks up `FineRule` by `@RuleID`. Returns `NULL` if `@RuleID` does not exist.
  - Formula: `(@DaysOverdue * RatePerDay) + (@BookPrice * Percent) + FixedProcessingFee`.
  - Allows `@CustomDamagePercent` in `(0, 1]` to override `PercentOfBookValue` for `DAMAGED` rules only.

### 3.2 Catalog (`002_catalog`) — English Naming
- **`sp_AddBookTitle`**: Creates a `BookTitle` record and links one or more `AuthorID`s in `Author_BookTitle`.
- **`sp_AddBookCopies`**: Inserts physical copies into `dbo.BookItem` with unique `MaVach`, `Price`, and default status `'AVAILABLE'`.
- **`sp_UpdateCopyStatus`**: Updates `BookItem.StatusID` (`AVAILABLE`, `DAMAGED`, `LOST`) for administrative inventory adjustments.
- **`sp_SearchCatalog`**: Queries `BookTitle` joined with `Author` and `BookItem`, returning book metadata, total copies, and count of `'AVAILABLE'` copies.

### 3.3 Circulation (`003_circulation`) — Existing Vietnamese Naming
- **`sp_LapPhieuMuon(@MaSinhVien, @NhanVienID, @BookItemID, @SoNgayMuon = 14)`**:
  - **Bug Fixes Required:** Must accept `@NhanVienID INT` (required by `PhieuMuon.NhanVienID NOT NULL`) and check unpaid fines across **both** `DongTraID` and `DongMuonID` paths (`Status IN ('UNPAID', 'PARTIAL')`).
  - **Borrower Eligibility Checks:**
    1. Student exists (`@MaSinhVien`) and `SinhVien.TrangThai = 'ACTIVE'`.
    2. Staff exists (`@NhanVienID`).
    3. Student has **no** fines in `DongPhat` with `Status IN ('UNPAID', 'PARTIAL')`.
    4. Student has **no** currently unreturned books past `NgayHenTra`.
    5. Active unreturned books $< 3$ (max borrow cap; updated from 5 to 3).
  - **Item Check:** `BookItemID` has `StatusID = 'AVAILABLE'`.
  - **State Change:** Updates `BookItem.StatusID` to `'BORROWED'`, inserts `PhieuMuon` & `DongMuon`.

- **`sp_LapPhieuTra(@SinhVienID, @NhanVienID, @DongMuonID, @NewBookStatus = 'AVAILABLE', @NgayTra = NULL, @CustomDamagePercent = NULL)`**:
  - **Bug Fix Required (`CK_DongPhat_Link`):** When inserting into `dbo.DongPhat`, pass `(@DongTraID, NULL)` for `LATE` and `DAMAGED` fines, and `(NULL, @DongMuonID)` for `LOST` fines so the XOR check constraint succeeds.
  - Validates `@DongMuonID` exists, belongs to `@SinhVienID`, and is not already in `DongTra`.
  - Inserts `PhieuTra` & `DongTra`, updates `BookItem.StatusID` to `@NewBookStatus` (`AVAILABLE`, `DAMAGED`, or `'LOST'`).
  - Calls `dbo.fn_CalculateFine` for overdue (`LATE`) and/or `DAMAGED`/`LOST` rules and inserts `DongPhat` rows (`Status = 'UNPAID'`) when fine $> 0$.

### 3.4 Fines (`004_fines`) — English Naming
- **`sp_RecordFinePayment`**:
  - Creates a `PhieuThu` (`LoaiPhieu = 'PAYMENT'`) and `DongThu` line items.
  - Supports **partial payments**: calculates total paid (`SUM(DongThu.SoTien)`) per `DongPhatID`. Rejects overpayment (`SoTien > RemainingBalance`).
  - Updates `DongPhat.Status` to `'PARTIAL'` if `0 < Paid < Amount`, or `'PAID'` if `Paid = Amount`.
- **`sp_WaiveFine`**:
  - Forgives remaining balance on a `DongPhat` record (requires `ADMIN` role or authorized `NhanVienID`).
  - Records a `PhieuThu` (`LoaiPhieu = 'WAIVER'`) + `DongThu` entry for auditability and sets `DongPhat.Status = 'WAIVED'`.
- **`sp_GetStudentFineBalance`**:
  - Returns itemized unpaid/partial fines and total remaining balance for a `SinhVienID`.

## 4. Error Handling & Transaction Standards
- **Nested-Safe Transactions:** Follow the existing pattern in `sp_LapPhieuMuon` / `sp_LapPhieuTra` (`IF @@TRANCOUNT = 0 BEGIN TRANSACTION ... ELSE SAVE TRANSACTION ...`) so procedures compose cleanly inside T-SQL test wrappers.
- **Validation Errors:** Raise descriptive errors with severity `16` (`RAISERROR` or `THROW` `50001`–`50007`) on all validation failures:
  - `50001`: Student not found or account not `ACTIVE`
  - `50002`: Student has unpaid/partial fines
  - `50003`: Student has overdue unreturned books
  - `50004`: Max borrow limit (3 books) exceeded
  - `50005`: BookItem is not `AVAILABLE`
  - `50006`: Invalid or already-returned loan item (`DongMuonID`)
  - `50007`: Payment exceeds remaining fine balance

## 5. Analytical & Reporting Module (`005_reports`) — Course Report Ch. 1 & 2
- **Deliverable:** Create 10 SQL `VIEW`s or `sp_Report_*` procedures in `db/003_program/005_reports/` covering library KPIs (circulation trends, overdue/fine analytics, inventory status, student activity, and staff workload).
- **Agent Autonomy:** Antigravity should propose the exact 10 analytical queries based on the existing schema in `PLAN.md` for user approval before implementation.

## 6. NoSQL Logs & Cross-DB Analytics (`nosql/`, `analytics/`) — Course Report Ch. 3 & 4
- **MongoDB (`nosql/`):** Store high-frequency library event logs (e.g., kiosk barcode scans and catalog searches) in MongoDB.
  - **Join Key Constraint:** Every generated JSON log document **must** reference real `MaVach` and/or `MaSinhVien` values queried directly from `ThuVien2` (SQL Server) so cross-database joins succeed.
  - **Scale:** Provide a Python generator script (`generate_logs.py`) that inserts at least 5,000 realistic mock log documents.
- **Python Analytics (`analytics/`):**
  - Connect to both SQL Server (`pyodbc`/`sqlalchemy`) and MongoDB (`pymongo`), join the datasets using `pandas` on `MaVach` / `MaSinhVien`, and export 3–4 business insight charts (`.png`) to `analytics/charts/`.
  - **Agent Autonomy:** Antigravity should propose the exact JSON document schema and chart insights in `PLAN.md` for user approval.