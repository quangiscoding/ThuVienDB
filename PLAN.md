# PLAN.md — ThuVien2 Technical Audit & 100% English Refactoring Plan

> **Status:** Pending User Approval  
> **Scope:** Full technical audit and 100% English standardization of `ThuVien2` across `db/`, `scripts/`, `nosql/`, and `analytics/`, ordered strictly from Phase 1 (Schema) to Phase 8 (Cross-DB Analytics) per `AGENTS.md` and `SPEC.md`.

---

## Executive Summary of Audit Findings

Inspection of all existing files in `db/001_schema/`, `db/002_seed/`, `db/003_program/`, `db/tests/`, and `scripts/` uncovered the following refactoring and bug-fix requirements:

1. **Vietnamese-to-English Standardization:** Current tables, columns, stored procedures, error messages, and seed descriptions mix Vietnamese (`NhanVien`, `SinhVien`, `PhieuMuon`, `DongMuon`, `PhieuTra`, `DongTra`, `DongPhat`, `PhieuThu`, `DongThu`, `MaVach`, `MaSinhVien`, `sp_LapPhieuMuon`, `sp_LapPhieuTra`) with English. All identifiers and error messages must be standardized to **100% English PascalCase**.
2. **Schema Gaps (`001_create-schema.sql`):** Missing `Student.Status`, missing `'PARTIAL'` and `'WAIVED'` in `CK_FineItem_Status`, missing `PaymentReceipt.ReceiptType`, and nullable `BookItem.Price` / `PaymentReceipt.Total`.
3. **Seed & Runner Bugs (`002_seed/`, `02_run_seeds.bat`):**
   - `02_run_seeds.bat` references non-existent `001_master.sql`, skips `003_entity_relationships.sql`, and comments out `003_borrow_return.sql` / `004_fines.sql`.
   - `001_master_lookups.sql` inserts `FineRule` values that violate `CK_FineRule_Components` and `CK_FineRule_Percent`.
   - `004_borrow_return.sql` and `005_fines.sql` pass string `MaSinhVien` (`'29210252479'`) into `INT` FK columns and omit `NhanVienID NOT NULL`.
4. **Stored Procedure Bugs (`003_program/`):**
   - `sp_LapPhieuMuon` (becoming `sp_CreateLoanSlip`) omits `@StaffID` (failing `NOT NULL`), defaults `@LoanDays` to `7` instead of `14`, skips `Student.Status = 'ACTIVE'`, misses `LOST` fines (`LoanItemID` path) and `'PARTIAL'` status in fine checks, and enforces a 5-book cap instead of 3.
   - `sp_LapPhieuTra` (becoming `sp_CreateReturnSlip`) passes **both** `@ReturnItemID` and `@LoanItemID` into `FineItem`, violating the `CK_FineItem_Link` XOR constraint, and omits `@CustomDamagePercent`.
5. **Test Suite Discrepancies (`db/tests/`):** `test_fn_CalculateFine.sql` is duplicated in `001_shared/` and `003_circulations/` with conflicting TC09 expectations (`0.00` vs `NULL`).

---

## Phase 1 — Schema Audit & English Refactor (`db/001_schema/`)

### 1.1 Vietnamese-to-English Entity & Column Mapping
| Old Table | New Table | Key Column Refactoring |
|---|---|---|
| `dbo.Role` | `dbo.Role` | `RoleID`, `RoleTitle` (unchanged) |
| `dbo.NhanVien` | `dbo.Staff` | `NhanVienID` -> `StaffID`, `MaNhanVien` -> `StaffCode`, `HoTen` -> `FullName`, `RoleID`, `Email` |
| `dbo.SinhVien` | `dbo.Student` | `SinhVienID` -> `StudentID`, `MaSinhVien` -> `StudentCode`, `HoTen` -> `FullName`, `Lop` -> `ClassName`, `Email`, **+ `Status`** |
| `dbo.Status` | `dbo.Status` | `StatusID`, `StatusName` (unchanged) |
| `dbo.Author` | `dbo.Author` | `AuthorID`, `TenTacGia` -> `AuthorName` |
| `dbo.BookTitle` | `dbo.BookTitle` | `TitleID`, `BookTitle` (unchanged) |
| `dbo.Author_BookTitle` | `dbo.Author_BookTitle` | `Author_BookTitle_ID`, `AuthorID`, `TitleID` (unchanged) |
| `dbo.BookItem` | `dbo.BookItem` | `BookItemID`, `MaVach` -> `Barcode`, `TitleID`, `StatusID`, **`Price` NOT NULL** |
| `dbo.PhieuMuon` | `dbo.LoanSlip` | `BorrowingID` -> `LoanSlipID`, `SinhVienID` -> `StudentID`, `NhanVienID` -> `StaffID`, `NgayMuon` -> `LoanDate` |
| `dbo.DongMuon` | `dbo.LoanItem` | `DongMuonID` -> `LoanItemID`, `BookItemID`, `BorrowingID` -> `LoanSlipID`, `NgayHenTra` -> `DueDate` |
| `dbo.PhieuTra` | `dbo.ReturnSlip` | `PhieuTraID` -> `ReturnSlipID`, `SinhVienID` -> `StudentID`, `NhanVienID` -> `StaffID`, `NgayTra` -> `ReturnDate` |
| `dbo.DongTra` | `dbo.ReturnItem` | `DongTraID` -> `ReturnItemID`, `PhieuTraID` -> `ReturnSlipID`, `DongMuonID` -> `LoanItemID`, `UQ_ReturnItem_LoanItem` |
| `dbo.FineRule` | `dbo.FineRule` | `RuleID`, `RuleCode`, `RuleName`, `RatePerDay`, `PercentOfBookValue`, `FixedProcessingFee` |
| `dbo.DongPhat` | `dbo.FineItem` | `DongPhatID` -> `FineItemID`, `FineRuleID`, `DongTraID` -> `ReturnItemID`, `DongMuonID` -> `LoanItemID`, `Amount`, **`Status`**, `Description`, `CK_FineItem_Link` |
| `dbo.PhieuThu` | `dbo.PaymentReceipt` | `PhieuThuID` -> `ReceiptID`, `NhanVienID` -> `StaffID`, `SinhVienID` -> `StudentID`, `NgayThu` -> `PaymentDate`, **+ `ReceiptType`**, **`Total` NOT NULL** |
| `dbo.DongThu` | `dbo.PaymentItem` | `DongThuID` -> `PaymentItemID`, `PhieuThuID` -> `ReceiptID`, `DongPhatID` -> `FineItemID`, `SoTien` -> `AmountPaid` |

### 1.2 Exact DDL Updates in `001_create-schema.sql`
1. **`dbo.Student.Status`:**
   ```sql
   Status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
   CONSTRAINT CK_Student_Status CHECK (Status IN ('ACTIVE', 'SUSPENDED', 'EXPIRED'))
   ```
2. **`dbo.BookItem.Price`:** Enforce non-null replacement value:
   ```sql
   Price DECIMAL(18, 2) NOT NULL DEFAULT 0 CHECK (Price >= 0),
   ```
3. **`dbo.FineItem.Status` & `CK_FineItem_Link`:**
   ```sql
   CONSTRAINT CK_FineItem_Link CHECK (
       (ReturnItemID IS NOT NULL AND LoanItemID IS NULL)
    OR (ReturnItemID IS NULL     AND LoanItemID IS NOT NULL)
   ),
   CONSTRAINT CK_FineItem_Status CHECK (Status IN ('UNPAID', 'PARTIAL', 'PAID', 'WAIVED')),
   ```
4. **`dbo.PaymentReceipt.ReceiptType` & `Total`:**
   ```sql
   ReceiptType VARCHAR(20) NOT NULL DEFAULT 'PAYMENT',
   Total DECIMAL(18, 2) NOT NULL DEFAULT 0 CHECK (Total >= 0),
   CONSTRAINT CK_PaymentReceipt_Type CHECK (ReceiptType IN ('PAYMENT', 'WAIVER'))
   ```

### 1.3 Syncing `002_drop-schema.sql` & `003_delete-schema-data.sql`
- **`002_drop-schema.sql`:** Add missing `GO` after `USE ThuVien2;`, drop all 16 English tables in reverse FK dependency order (`PaymentItem`, `PaymentReceipt`, `FineItem`, `FineRule`, `ReturnItem`, `ReturnSlip`, `LoanItem`, `LoanSlip`, `BookItem`, `Author_BookTitle`, `BookTitle`, `Author`, `Status`, `Student`, `Staff`, `Role`), and remove stale commented-out schema drops.
- **`003_delete-schema-data.sql`:** Delete from all 16 English tables in FK dependency order and preserve the `DBCC CHECKIDENT` reseed block.
- **Verification:** Run `scripts/01_reset_schema.bat` and confirm zero errors.

---

## Phase 2 — Seed Data Refactor & Sync (`db/002_seed/` & `scripts/02_run_seeds.bat`)

### 2.1 Refactor & Fix All 5 Seed Files (100% English)
1. **`001_master_lookups.sql`:**
   - Update `RoleTitle`, `StatusName`, and `FineRule.RuleName` to English (`'Administrator'`, `'Librarian'`, `'Available'`, `'Borrowed'`, `'Lost'`, `'Damaged'`).
   - Fix `FineRule` values to satisfy `CK_FineRule_Components` and `CK_FineRule_Percent`:
     - `('LATE',    'Overdue Return Fine',     5000.00, NULL,  0.00)`
     - `('LOST',    'Lost Book Replacement',   NULL,    1.00, 20000.00)`
     - `('DAMAGED', 'Damaged Book Penalty',    NULL,    0.20, 15000.00)`
2. **`002_entities.sql`:**
   - Insert into `dbo.Staff` (`NV01` as `'LIBRARIAN'`, plus `NV02` as `'ADMIN'` for `sp_WaiveFine` tests).
   - Insert into `dbo.Student` with `Status` edge-case fixtures: `ACTIVE` students, 1 `SUSPENDED` student, and 1 `EXPIRED` student.
   - Insert 5–6 `Author` and `BookTitle` records (including a co-authored title) for catalog search and reporting.
3. **`003_entity_relationships.sql`:**
   - Map `Author_BookTitle` and insert `BookItem` copies with `Barcode` (`'BI001'`–`'BI010'`), non-null `Price`, and varied `StatusID`s (`'AVAILABLE'`, `'BORROWED'`, `'DAMAGED'`, `'LOST'`).
4. **`004_borrow_return.sql`:**
   - Add `GO` after `USE ThuVien2;`, use integer `StudentID` and `StaffID` in `LoanSlip` and `ReturnSlip`.
   - Include edge-case fixtures: returned-late loan, active on-time loan, active overdue unreturned loan, and a lost-book loan.
5. **`005_fines.sql`:**
   - Add `GO` after `USE ThuVien2;`, use integer `StudentID`/`StaffID` and `ReceiptType` in `PaymentReceipt`.
   - Include edge-case fixtures: `PAID` fine, `UNPAID` late fine (`ReturnItemID`-linked), `UNPAID` lost fine (`LoanItemID`-linked), `PARTIAL` fine with partial `PaymentReceipt`/`PaymentItem`, and `WAIVED` fine (`ReceiptType = 'WAIVER'`).

### 2.2 `scripts/02_run_seeds.bat`
Update `02_run_seeds.bat` to execute all 5 seed scripts in strict FK order with `-b` (abort on error):
1. `..\db\002_seed\001_master_lookups.sql`
2. `..\db\002_seed\002_entities.sql`
3. `..\db\002_seed\003_entity_relationships.sql`
4. `..\db\002_seed\004_borrow_return.sql`
5. `..\db\002_seed\005_fines.sql`

---

## Phase 3 — Existing SP Refactor & Bug Fixes (`db/003_program/001_shared/` & `003_circulation/`)

### 3.1 `fn_CalculateFine.sql` (`001_shared/functions/`)
- **Audit Result:** Formula and `NULL` handling match `SPEC.md` §3.1. Update comments to English and ensure `CREATE OR ALTER FUNCTION` idempotency.

### 3.2 `sp_LapPhieuMuon.sql` -> `sp_CreateLoanSlip.sql` (`003_circulation/procedures/`)
- **Rename & Signature:** `dbo.sp_CreateLoanSlip(@StudentCode VARCHAR(20), @StaffID INT, @BookItemID INT, @LoanDays INT = 14)` (remove legacy `sp_LapPhieuMuon.sql`).
- **Bug Fixes & Spec Alignment:**
  1. Enable `SET XACT_ABORT ON`.
  2. Validate `Student` exists **and** `Status = 'ACTIVE'` (`THROW 50001`).
  3. Validate `@StaffID` exists in `dbo.Staff` (`THROW 50001` / staff validation error).
  4. Fix unpaid fine check to cover `fi.Status IN ('UNPAID', 'PARTIAL')` across **both** `ReturnItemID -> ReturnItem -> ReturnSlip` (return fines) **and** `LoanItemID -> LoanItem -> LoanSlip` (`LOST` fines) (`THROW 50002`).
  5. Keep overdue unreturned book check (`DueDate < CAST(GETDATE() AS DATE)` with no `ReturnItem`) (`THROW 50003`).
  6. Lower max borrow cap from `5` to `3` (`@CurrentlyBorrowedCount >= 3` -> `THROW 50004`).
  7. Validate `BookItem` is `'AVAILABLE'` (`THROW 50005`), insert `LoanSlip` (with `StaffID`) and `LoanItem`, and return `LoanSlipID` + English status message.
  8. Replace `RAISERROR + RETURN` inside `TRY` with `THROW` so `CATCH` handles nested-safe rollback cleanly.

### 3.3 `sp_LapPhieuTra.sql` -> `sp_CreateReturnSlip.sql` (`003_circulation/procedures/`)
- **Rename & Signature:** `dbo.sp_CreateReturnSlip(@StudentID INT, @StaffID INT, @LoanItemID INT, @NewBookStatus VARCHAR(20) = 'AVAILABLE', @ReturnDate DATE = NULL, @CustomDamagePercent DECIMAL(5, 2) = NULL)` (remove legacy `sp_LapPhieuTra.sql`).
- **Bug Fixes & Spec Alignment:**
  1. Enable `SET XACT_ABORT ON`.
  2. Enforce `CK_FineItem_Link` XOR constraint on `dbo.FineItem` inserts:
     - `'LATE'` fine: `(@ReturnItemID, NULL)`
     - `'DAMAGED'` fine: `(@ReturnItemID, NULL)` and pass `@CustomDamagePercent` to `dbo.fn_CalculateFine`
     - `'LOST'` fine: `(NULL, @LoanItemID)`
  3. Restrict `@NewBookStatus` to `('AVAILABLE', 'DAMAGED', 'LOST')` (reject `'BORROWED'`).
  4. Standardize validation errors with `THROW 50006` (invalid or already-returned `LoanItemID`) and English messages.

### 3.4 Phase 3 Test Updates (`db/tests/`)
- Reconcile `001_shared/test_fn_CalculateFine.sql` (fix TC09 expected value from `0.00` to `NULL`; remove duplicate in `003_circulations/test_fn_CalculateFine.sql`).
- Rename and update `test_sp_LapPhieuMuon.sql` -> `test_sp_CreateLoanSlip.sql` and `test_sp_LapPhieuTra.sql` -> `test_sp_CreateReturnSlip.sql` to test all English identifiers, `@StaffID`, 3-book cap (`50004`), `Student.Status` (`50001`), `LOST`/`PARTIAL` fine blocks (`50002`), `CK_FineItem_Link` XOR, and `@CustomDamagePercent`.

---

## Phase 4 — Catalog Module (`db/003_program/002_catalog/procedures/`)

All procedures will use `CREATE OR ALTER PROCEDURE`, `SET XACT_ABORT ON`, nested-safe transactions, and English `THROW` error handling:

1. **`sp_AddBookTitle(@BookTitle NVARCHAR(200), @AuthorIDs NVARCHAR(MAX))`**
   - Validates non-empty title and that all comma-separated `AuthorID`s exist in `dbo.Author`; inserts `dbo.BookTitle` and `dbo.Author_BookTitle` atomically; returns `TitleID`.
2. **`sp_AddBookCopies(@TitleID INT, @Barcodes NVARCHAR(MAX), @Price DECIMAL(18, 2))`**
   - Validates `TitleID` exists, `@Price >= 0`, and no duplicate `Barcode`; inserts one or more `dbo.BookItem` rows with `StatusID = 'AVAILABLE'`.
3. **`sp_UpdateCopyStatus(@BookItemID INT, @NewStatusID VARCHAR(20))`**
   - Updates `BookItem.StatusID` for administrative adjustments (`'AVAILABLE'`, `'DAMAGED'`, `'LOST'`), rejecting `'BORROWED'` outside `sp_CreateLoanSlip`.
4. **`sp_SearchCatalog(@Keyword NVARCHAR(200) = NULL)`**
   - Joins `BookTitle`, `Author_BookTitle`, `Author`, and `BookItem`; filters by `BookTitle`, `AuthorName`, or `Barcode`; returns `TitleID`, `BookTitle`, `Authors` (`STRING_AGG`), `TotalCopies`, `AvailableCopies`, and `UnitPrice`.

---

## Phase 5 — Fines Module (`db/003_program/004_fines/procedures/`)

1. **`sp_RecordFinePayment(@StudentID INT, @StaffID INT, @FineItemID INT, @AmountPaid DECIMAL(18, 2), @PaymentDate DATE = NULL)`**
   - Validates `StaffID`, `StudentID`, and that `FineItemID` belongs to `@StudentID` (via `ReturnItem -> ReturnSlip` or `LoanItem -> LoanSlip`) with `Status IN ('UNPAID', 'PARTIAL')`.
   - Computes `RemainingBalance = Amount - ISNULL(SUM(PaymentItem.AmountPaid), 0)`.
   - Rejects `@AmountPaid <= 0` or `@AmountPaid > RemainingBalance` (`THROW 50007`).
   - Inserts `PaymentReceipt` (`ReceiptType = 'PAYMENT'`, `Total = @AmountPaid`), `PaymentItem`, and updates `FineItem.Status` to `'PARTIAL'` or `'PAID'`.
2. **`sp_WaiveFine(@FineItemID INT, @StaffID INT, @PaymentDate DATE = NULL)`**
   - Validates `@StaffID` exists and has `RoleID = 'ADMIN'`.
   - Validates `FineItemID` is in `('UNPAID', 'PARTIAL')`.
   - Computes `RemainingBalance`, inserts `PaymentReceipt` (`ReceiptType = 'WAIVER'`, `Total = @RemainingBalance`) + `PaymentItem` (`AmountPaid = @RemainingBalance`), and sets `FineItem.Status = 'WAIVED'`.
3. **`sp_GetStudentFineBalance(@StudentID INT)`**
   - Returns (1) itemized `UNPAID`/`PARTIAL` fines (`FineItemID`, `RuleCode`, `Description`, `BookTitle`, `Barcode`, `Amount`, `PaidAmount`, `RemainingBalance`, `Status`) and (2) total remaining balance for `@StudentID`.

---

## Phase 6 — Analytical Reports (`005_reports/`), SQL Tests (`db/tests/`), & `scripts/`

### 6.1 Proposed 10 Analytical Views & Procedures (`db/003_program/005_reports/`)
| # | Object Name | Type | Folder | Business Purpose |
|---|---|---|---|---|
| 1 | `vw_Report_DailyCirculation` | View | `views/` | Daily borrow count, return count, and net active loan delta by date. |
| 2 | `vw_Report_MonthlyCirculationTrends` | View | `views/` | Monthly borrow/return volume and late-return rate (`ReturnDate > DueDate`). |
| 3 | `vw_Report_TopBorrowedTitles` | View | `views/` | Most borrowed `BookTitle`s with authors, total borrows, and current `AVAILABLE` copies. |
| 4 | `vw_Report_InventoryStatusSummary` | View | `views/` | Copy count and total `Price` value grouped by `StatusID` (`AVAILABLE`, `BORROWED`, `DAMAGED`, `LOST`). |
| 5 | `vw_Report_OverdueLoans` | View | `views/` | Currently unreturned overdue loans (`DueDate < GETDATE()`) with days overdue, student contact, and `Barcode`. |
| 6 | `vw_Report_FineSummaryByRule` | View | `views/` | Total fines assessed, collected (`PAYMENT`), waived (`WAIVER`), and outstanding grouped by `FineRule.RuleCode`. |
| 7 | `vw_Report_StudentActivityKPI` | View | `views/` | Per-student borrow count, overdue count, total fines assessed, and unpaid balance. |
| 8 | `vw_Report_StaffWorkload` | View | `views/` | Per-staff (`Staff`) count of `LoanSlip`, `ReturnSlip`, and `PaymentReceipt` records processed. |
| 9 | `sp_Report_CirculationByDateRange` | Proc | `procedures/` | Parameterized (`@StartDate DATE`, `@EndDate DATE`) borrow/return/fine-revenue summary. |
| 10 | `sp_Report_TopDelinquentStudents` | Proc | `procedures/` | Parameterized (`@TopN INT = 10`) ranking of students by outstanding fine balance and overdue incidents. |

### 6.2 Complete SQL Test Suite (`db/tests/`)
- Add `db/tests/002_catalog/test_catalog_procedures.sql`
- Add `db/tests/004_fines/test_fines_procedures.sql`
- Add `db/tests/005_reports/test_reports.sql`

### 6.3 `scripts/03_run_programs.bat` & `scripts/setup_all.bat`
- Add `-b` (fail on SQL error) and `if errorlevel 1 exit /b 1` checks across `01_reset_schema.bat`, `02_run_seeds.bat`, and `03_run_programs.bat` so `setup_all.bat` stops immediately if any script fails.
- Run `scripts/setup_all.bat` and all test scripts to confirm zero errors.

---

## Phase 7 — NoSQL Log Pipeline (`nosql/`)

### 7.1 Proposed MongoDB Document Schema (`nosql/sample_logs.json`)
- **Database / Collection:** `ThuVien2Logs.library_event_logs`
- **Join Key Integrity:** `generate_logs.py` queries live `StudentCode` (`dbo.Student`) and `Barcode` (`dbo.BookItem`) from SQL Server `ThuVien2` before generating documents.
- **Document Structure:**
  ```json
  {
    "event_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "event_type": "KIOSK_SCAN",
    "timestamp": "2026-10-15T09:23:11Z",
    "StudentCode": "29210252479",
    "Barcode": "BI001",
    "station_id": "KIOSK-01",
    "action": "SELF_CHECKOUT_ATTEMPT",
    "result": "SUCCESS",
    "search_query": null,
    "response_time_ms": 142,
    "metadata": {
      "client_os": "Windows-Kiosk",
      "session_duration_sec": 18
    }
  }
  ```
- **Event Types Covered:**
  - `KIOSK_SCAN` (`SELF_CHECKOUT_ATTEMPT`, `SELF_RETURN_SCAN`, `BARCODE_LOOKUP`) — references real `Barcode` and `StudentCode`; `result` in `["SUCCESS", "UNAVAILABLE", "DENIED_FINES", "DENIED_LIMIT"]`.
  - `CATALOG_SEARCH` (`OPAC_KEYWORD_SEARCH`) — carries `search_query` and real `StudentCode` / matched `Barcode`.
  - `RFID_GATE_PING` (`EXIT_GATE_CHECK`) — carries real `Barcode` and `result` in `["CLEARED", "UNRETURNED_ALERT"]`.

### 7.2 Bulk Generator (`nosql/generate_logs.py`)
- Queries SQL Server (`pyodbc`) for live `StudentCode` and `Barcode` values (plus `BookTitle` keywords).
- Inserts **5,500+** realistic documents over a 60-day window into MongoDB (`pymongo`) in batches of 1,000, creating indexes on `StudentCode`, `Barcode`, `event_type`, and `timestamp`.

---

## Phase 8 — Cross-DB Analytics & Visualization (`analytics/`)

### 8.1 Dependencies (`analytics/requirements.txt`)
`pyodbc`, `sqlalchemy`, `pymongo`, `pandas`, `matplotlib`, `seaborn`

### 8.2 Cross-DB Pipeline (`analytics/join_and_analyze.py`)
Joins SQL Server (`Student`, `BookTitle`, `BookItem`, `LoanSlip`, `LoanItem`, `FineItem`, `PaymentReceipt`) with MongoDB `library_event_logs` on `Barcode` and `StudentCode` via `pandas`, and exports **4 charts** to `analytics/charts/`:

1. **`01_search_demand_vs_availability.png`** — Joins MongoDB `CATALOG_SEARCH` / `KIOSK_SCAN` demand per `Barcode` with SQL `BookItem` & `BookTitle` to compare digital demand against physical `AVAILABLE` copy ratio (highlights under-stocked titles).
2. **`02_kiosk_hourly_traffic_vs_checkouts.png`** — Aggregates MongoDB `KIOSK_SCAN` volume by hour of day alongside `DENIED_FINES` / `UNAVAILABLE` failure rates to guide kiosk staffing and capacity.
3. **`03_student_engagement_vs_delinquency.png`** — Joins MongoDB scan/search frequency per `StudentCode` with SQL `Student.Status`, overdue count, and unpaid fine balance to profile patron engagement vs. delinquency.
4. **`04_fine_revenue_and_recovery_breakdown.png`** — Combines SQL `FineItem` + `PaymentReceipt` (`PAYMENT` vs `WAIVER` vs `UNPAID`/`PARTIAL`) by `FineRule.RuleCode` with MongoDB `RFID_GATE_PING` / `LOST` item scan timelines.

---

## Next Step
Awaiting your approval of `PLAN.md` before starting **Phase 1 (Schema Audit & English Refactor)**.

---

## Phase 9 — Bulk Dataset Scaling & Chart Polish (`scripts/`, `nosql/`, `analytics/`)
- **SQL Bulk Seeder (`scripts/seed_bulk_sql.py`):** Preserves existing `002_seed/` fixtures and inserts ~40 students, ~20 book titles, ~75 `BookItem` copies, and ~300 historical loans, returns, `CK_FineItem_Link`-compliant fines, and payments/waivers over the past 6 months (`random.seed(42)`).
- **NoSQL Scale & Skew (`nosql/generate_logs.py`):** Increases log volume to 8,000 documents with skewed Zipf-like popularity weights across `BookTitle`/`Barcode` and `StudentCode`.
- **Chart Readability (`analytics/join_and_analyze.py`):** Slices Chart 1 and Chart 3 to Top 10 (`.head(10)`), moves Chart 1's legend outside the plot area with `xlim * 1.25`, and rotates Chart 3's x-axis labels (`rotation=20, ha='right'`) with a unified legend.
