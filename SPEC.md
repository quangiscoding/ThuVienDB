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
- **`fn_CalculateFine`**:
  - `LATE`: `DATEDIFF(DAY, NgayHenTra, NgayTra) * RatePerDay + FixedProcessingFee` (returns `0` if `NgayTra <= NgayHenTra`).
  - `LOST` / `DAMAGED`: `(BookItem.Price * PercentOfBookValue) + FixedProcessingFee`.

### 3.2 Catalog (`002_catalog`) — English Naming
- **`sp_AddBookTitle`**: Creates a `BookTitle` record and links one or more `AuthorID`s in `Author_BookTitle`.
- **`sp_AddBookCopies`**: Inserts physical copies into `dbo.BookItem` with unique `MaVach`, `Price`, and default status `'AVAILABLE'`.
- **`sp_UpdateCopyStatus`**: Updates `BookItem.StatusID` (`AVAILABLE`, `DAMAGED`, `LOST`) for administrative inventory adjustments.
- **`sp_SearchCatalog`**: Queries `BookTitle` joined with `Author` and `BookItem`, returning book metadata, total copies, and count of `'AVAILABLE'` copies.

### 3.3 Circulation (`003_circulation`) — Existing Vietnamese Naming
- **`sp_LapPhieuMuon`** (Create Borrow Slip):
  - **Loan Duration:** Default `NgayHenTra = DATEADD(DAY, 14, NgayMuon)`.
  - **Borrower Eligibility Checks (must throw error if violated):**
    1. Student exists and `SinhVien.TrangThai = 'ACTIVE'`.
    2. Student has **no** fines in `DongPhat` with `Status IN ('UNPAID', 'PARTIAL')`.
    3. Student has **no** currently unreturned books past `NgayHenTra`.
    4. Active unreturned books + new books requested $\le 3$ (max borrow cap).
  - **Item Check:** Every requested `BookItemID` must have `StatusID = 'AVAILABLE'`.
  - **State Change:** Inserts `PhieuMuon` & `DongMuon`, updates `BookItem.StatusID` to `'BORROWED'`.
- **`sp_LapPhieuTra`** (Create Return Slip):
  - Validates each `DongMuonID` is currently unreturned (not in `DongTra`) and belongs to the student.
  - Inserts `PhieuTra` & `DongTra`.
  - Evaluates return condition (`NORMAL`, `DAMAGED`, `LOST`):
    - Updates `BookItem.StatusID` to `'AVAILABLE'`, `'DAMAGED'`, or `'LOST'`.
    - Calls `fn_CalculateFine` for overdue (`LATE`) and/or `DAMAGED`/`LOST` rules; inserts `DongPhat` rows (`Status = 'UNPAID'`) whenever calculated amount $> 0$ (linking `DongTraID` for `LATE`/`DAMAGED`, or `DongMuonID` for `LOST`).

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
- **Transactions:** All multi-table write procedures must wrap logic in `SET XACT_ABORT ON; BEGIN TRY BEGIN TRAN ... COMMIT TRAN END TRY BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK TRAN; THROW; END CATCH`.
- **Custom Error Codes (`THROW`):**
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