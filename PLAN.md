# PLAN.md — ThuVien2 Technical Audit & Implementation Plan

> **Status:** Pending User Approval  
> **Scope:** Full technical audit of `ThuVien2` across `db/`, `scripts/`, `nosql/`, and `analytics/`, ordered strictly from Phase 1 (Schema) to Phase 8 (Cross-DB Analytics) per `AGENTS.md` and `SPEC.md`.

---

## Executive Summary of Audit Findings

Inspection of all existing files in `db/001_schema/`, `db/002_seed/`, `db/003_program/`, `db/tests/`, and `scripts/` uncovered **critical schema, seed, stored procedure, and runner gaps**:

1. **Schema (`001_create-schema.sql`):** Missing `SinhVien.TrangThai`, missing `'PARTIAL'` and `'WAIVED'` in `CK_DongPhat_Status`, missing `PhieuThu.LoaiPhieu`, and nullable `BookItem.Price` / `PhieuThu.Total`.
2. **Seeds (`002_seed/`) & Runner (`02_run_seeds.bat`):**
   - `02_run_seeds.bat` references non-existent `001_master.sql`, skips `003_entity_relationships.sql`, and comments out `003_borrow_return.sql` / `004_fines.sql`.
   - `001_master_lookups.sql` inserts `FineRule` values that violate `CK_FineRule_Components` and `CK_FineRule_Percent`.
   - `004_borrow_return.sql` and `005_fines.sql` pass string `MaSinhVien` (`'29210252479'`) into `SinhVienID INT` columns and omit `NhanVienID NOT NULL`.
3. **Stored Procedures (`003_program/`):**
   - `sp_LapPhieuMuon` omits `@NhanVienID` (failing `PhieuMuon.NhanVienID NOT NULL`), defaults `@SoNgayMuon` to `7` instead of `14`, skips `SinhVien.TrangThai = 'ACTIVE'`, misses `LOST` fines (`DongMuonID` path) and `'PARTIAL'` status in fine checks, and enforces a 5-book cap instead of 3.
   - `sp_LapPhieuTra` passes **both** `@DongTraID` and `@DongMuonID` into `DongPhat`, violating `CK_DongPhat_Link` (XOR constraint), and omits `@CustomDamagePercent`.
4. **Tests (`db/tests/`):** `test_fn_CalculateFine.sql` is duplicated in `001_shared/` and `003_circulations/` with conflicting TC09 expectations (`0.00` vs `NULL`).

---

## Phase 1 — Schema Audit & Alignment (`db/001_schema/`)

### 1.1 `db/001_schema/001_create-schema.sql`
Apply the following exact DDL updates:

1. **`dbo.SinhVien`** — Add account status column and constraint:
   ```sql
   TrangThai VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
   CONSTRAINT CK_SinhVien_TrangThai CHECK (TrangThai IN ('ACTIVE', 'SUSPENDED', 'EXPIRED'))
   ```
2. **`dbo.BookItem`** — Enforce non-null replacement price so `LOST`/`DAMAGED` fine calculations never silently evaluate `Price` as `0`:
   ```sql
   Price DECIMAL(18, 2) NOT NULL DEFAULT 0 CHECK (Price >= 0),
   ```
3. **`dbo.DongPhat`** — Expand `CK_DongPhat_Status` to support partial payments and admin waivers:
   ```sql
   CONSTRAINT CK_DongPhat_Status CHECK (Status IN ('UNPAID', 'PARTIAL', 'PAID', 'WAIVED')),
   ```
4. **`dbo.PhieuThu`** — Add `LoaiPhieu` discriminator (`PAYMENT` vs `WAIVER`) and tighten `Total`:
   ```sql
   LoaiPhieu VARCHAR(20) NOT NULL DEFAULT 'PAYMENT',
   Total DECIMAL(18, 2) NOT NULL DEFAULT 0 CHECK (Total >= 0),
   CONSTRAINT CK_PhieuThu_LoaiPhieu CHECK (LoaiPhieu IN ('PAYMENT', 'WAIVER'))
   ```

### 1.2 `db/001_schema/002_drop-schema.sql` & `003_delete-schema-data.sql`
- **`002_drop-schema.sql`:** Add missing `GO` after `USE ThuVien2;` and remove stale commented-out `circulation.*` / `catalog.*` / `core.*` schema drops so the file stays cleanly synced with `dbo.*` in `001_create-schema.sql`.
- **`003_delete-schema-data.sql`:** Verify FK delete order (`DongThu` -> `PhieuThu` -> `DongPhat` -> `DongTra` -> `PhieuTra` -> `DongMuon` -> `PhieuMuon` -> `BookItem` -> `Author_BookTitle` -> `BookTitle` -> `Author` -> `Status` -> `FineRule` -> `SinhVien` -> `NhanVien` -> `Role`) and `DBCC CHECKIDENT` reseed work cleanly after Phase 1 DDL updates.
- **Verification:** Run `scripts/01_reset_schema.bat` and confirm zero errors.

---

## Phase 2 — Seed Data Sync (`db/002_seed/` & `scripts/02_run_seeds.bat`)

### 2.1 Fix Existing Seed Bugs
1. **`001_master_lookups.sql`:** Fix `FineRule` inserts to satisfy `CK_FineRule_Components` and `CK_FineRule_Percent`:
   - `('LATE',    N'Phạt trả quá hạn',     5000.00, NULL,  0.00)`
   - `('LOST',    N'Bồi thường mất sách',  NULL,    1.00, 20000.00)`
   - `('DAMAGED', N'Phạt làm hỏng sách',   NULL,    0.20, 15000.00)`
2. **`004_borrow_return.sql`:** Add `GO` after `USE ThuVien2;`, replace `'29210252479'` with integer `SinhVienID` (`1`), and provide `NhanVienID` (`1`) in both `PhieuMuon` and `PhieuTra`.
3. **`005_fines.sql`:** Add `GO` after `USE ThuVien2;`, replace `'29210252479'` with integer `SinhVienID` (`1`), and include `LoaiPhieu = 'PAYMENT'` in `PhieuThu`.

### 2.2 Add Edge-Case Fixtures
- **`002_entities.sql`:**
  - Add an `ADMIN` staff account (`NV02`, `RoleID = 'ADMIN'`) alongside `NV01` (`LIBRARIAN`) to support `sp_WaiveFine` tests.
  - Seed `SinhVien` with `TrangThai` coverage: `ACTIVE` patrons, 1 `SUSPENDED` patron, and 1 `EXPIRED` patron.
  - Expand `Author` and `BookTitle` (5–6 titles, including a co-authored title) for catalog search and analytics.
- **`003_entity_relationships.sql`:**
  - Seed `BookItem` copies with explicit `Price` values and initial statuses (`AVAILABLE`, `BORROWED`, `DAMAGED`, `LOST`).
- **`004_borrow_return.sql`:**
  - Fixtures for: returned-late loan (historical), active on-time loan, active overdue unreturned loan, and a lost-book loan.
- **`005_fines.sql`:**
  - Fixtures for: `PAID` fine, `UNPAID` late fine (`DongTraID`-linked), `UNPAID` lost fine (`DongMuonID`-linked), `PARTIAL` fine with partial `PhieuThu`/`DongThu`, and `WAIVED` fine (`LoaiPhieu = 'WAIVER'`).

### 2.3 `scripts/02_run_seeds.bat`
Update `02_run_seeds.bat` to execute all 5 seed scripts in strict FK order with `-b` (fail on SQL error):
1. `..\db\002_seed\001_master_lookups.sql`
2. `..\db\002_seed\002_entities.sql`
3. `..\db\002_seed\003_entity_relationships.sql`
4. `..\db\002_seed\004_borrow_return.sql`
5. `..\db\002_seed\005_fines.sql`

---

## Phase 3 — Existing SP & Function Audit (`db/003_program/001_shared/` & `003_circulation/`)

### 3.1 `fn_CalculateFine.sql` (`001_shared/functions/`)
- **Audit Result:** Logic matches `SPEC.md` §3.1 (`NULL` on missing `@RuleID`, input sanitization, `@CustomDamagePercent` in `(0, 1]` for `DAMAGED` rules only, formula `(@DaysOverdue * @RatePerDay) + (@BookPrice * @Percent) + @FixedFee`).
- **Action:** Keep function logic intact; ensure `SET` / `CREATE OR ALTER` idempotency is preserved.

### 3.2 `sp_LapPhieuMuon.sql` (`003_circulation/procedures/`)
- **Signature Update:** Add `@NhanVienID INT` and change default `@SoNgayMuon INT = 14`.
- **Bug Fixes & Spec Alignment:**
  1. Enable `SET XACT_ABORT ON`.
  2. Validate student exists **and** `TrangThai = 'ACTIVE'` (`THROW 50001`).
  3. Validate `@NhanVienID` exists in `dbo.NhanVien` (`THROW 50001` or descriptive staff error).
  4. Fix unpaid fine check to cover `dp.Status IN ('UNPAID', 'PARTIAL')` across **both** `DongTraID -> DongTra -> PhieuTra` (return fines) **and** `DongMuonID -> DongMuon -> PhieuMuon` (lost-book fines) (`THROW 50002`).
  5. Keep overdue unreturned book check (`THROW 50003`).
  6. Lower active borrow cap from `5` to `3` (`@CurrentlyBorrowedCount >= 3` -> `THROW 50004`).
  7. Validate `BookItem` is `'AVAILABLE'` (`THROW 50005`) and insert `NhanVienID` into `dbo.PhieuMuon`.
  8. Replace `RAISERROR(...) + RETURN` inside `TRY` with `THROW` so `CATCH` handles rollback cleanly.

### 3.3 `sp_LapPhieuTra.sql` (`003_circulation/procedures/`)
- **Signature Update:** Add `@CustomDamagePercent DECIMAL(5, 2) = NULL`.
- **Bug Fixes & Spec Alignment:**
  1. Enable `SET XACT_ABORT ON`.
  2. Enforce `CK_DongPhat_Link` XOR constraint on `dbo.DongPhat` inserts:
     - `LATE` fine: `(@DongTraID, NULL)`
     - `DAMAGED` fine: `(@DongTraID, NULL)` and pass `@CustomDamagePercent` to `dbo.fn_CalculateFine`
     - `LOST` fine: `(NULL, @DongMuonID)`
  3. Restrict `@NewBookStatus` to `('AVAILABLE', 'DAMAGED', 'LOST')` (reject `'BORROWED'`).
  4. Standardize validation errors with `THROW 50006` (invalid or already-returned `DongMuonID`) and descriptive `THROW` codes for student/status/staff mismatches.

---

## Phase 4 — Catalog Module (`db/003_program/002_catalog/procedures/`)

All procedures will use English naming, `CREATE OR ALTER PROCEDURE`, `SET XACT_ABORT ON`, nested-safe transactions, and `THROW` error handling:

1. **`sp_AddBookTitle`**
   - Parameters: `@BookTitle NVARCHAR(200)`, `@AuthorIDs NVARCHAR(MAX)` (comma-separated list of `AuthorID`s).
   - Behavior: Validates non-empty title and that every `AuthorID` exists in `dbo.Author`; inserts `dbo.BookTitle` and `dbo.Author_BookTitle` rows atomically; returns `TitleID`.
2. **`sp_AddBookCopies`**
   - Parameters: `@TitleID INT`, `@MaVachList NVARCHAR(MAX)` (or single `@MaVach VARCHAR(30)` + batch support via comma-separated barcodes), `@Price DECIMAL(18, 2)`.
   - Behavior: Validates `TitleID` exists, `@Price >= 0`, and no duplicate `MaVach`; inserts into `dbo.BookItem` with `StatusID = 'AVAILABLE'`.
3. **`sp_UpdateCopyStatus`**
   - Parameters: `@BookItemID INT`, `@NewStatusID VARCHAR(20)`.
   - Behavior: Allows administrative adjustments to `'AVAILABLE'`, `'DAMAGED'`, or `'LOST'` (rejects setting `'BORROWED'` outside `sp_LapPhieuMuon`); validates `BookItemID` exists.
4. **`sp_SearchCatalog`**
   - Parameters: `@Keyword NVARCHAR(200) = NULL`.
   - Behavior: Joins `BookTitle`, `Author_BookTitle`, `Author`, and `BookItem`; filters by `BookTitle` or `TenTacGia` or `MaVach` when `@Keyword` is provided; returns `TitleID`, `BookTitle`, `Authors` (`STRING_AGG`), `TotalCopies`, `AvailableCopies`, `UnitPrice`.

---

## Phase 5 — Fines Module (`db/003_program/004_fines/procedures/`)

1. **`sp_RecordFinePayment`**
   - Parameters: `@SinhVienID INT`, `@NhanVienID INT`, `@DongPhatID INT`, `@SoTien DECIMAL(18, 2)`, `@NgayThu DATE = NULL`.
   - Behavior:
     - Validates `NhanVienID`, `SinhVienID`, and that `DongPhatID` belongs to `@SinhVienID` (via `DongTra -> PhieuTra` or `DongMuon -> PhieuMuon`) with `Status IN ('UNPAID', 'PARTIAL')`.
     - Computes `RemainingBalance = Amount - ISNULL(SUM(DongThu.SoTien), 0)`.
     - Rejects `@SoTien <= 0` or `@SoTien > RemainingBalance` with `THROW 50007`.
     - Inserts `PhieuThu` (`LoaiPhieu = 'PAYMENT'`, `Total = @SoTien`), `DongThu`, and updates `DongPhat.Status` to `'PARTIAL'` or `'PAID'`.
2. **`sp_WaiveFine`**
   - Parameters: `@DongPhatID INT`, `@NhanVienID INT`, `@NgayThu DATE = NULL`.
   - Behavior:
     - Validates `@NhanVienID` exists and has `RoleID = 'ADMIN'`.
     - Validates `DongPhatID` exists and `Status IN ('UNPAID', 'PARTIAL')`.
     - Computes `RemainingBalance`, inserts `PhieuThu` (`LoaiPhieu = 'WAIVER'`, `Total = @RemainingBalance`) + `DongThu` (`SoTien = @RemainingBalance`) for full auditability, and sets `DongPhat.Status = 'WAIVED'`.
3. **`sp_GetStudentFineBalance`**
   - Parameters: `@SinhVienID INT`.
   - Behavior: Returns (1) itemized unpaid/partial fines (`DongPhatID`, `RuleCode`, `Description`, `BookTitle`, `MaVach`, `Amount`, `PaidAmount`, `RemainingBalance`, `Status`) and (2) summary total remaining balance for `@SinhVienID`.

---

## Phase 6 — Analytical Reports (`005_reports/`), SQL Tests (`db/tests/`), & `scripts/`

### 6.1 Proposed 10 Analytical Views & Procedures (`db/003_program/005_reports/`)
| # | Object Name | Type | Folder | Business Purpose |
|---|---|---|---|---|
| 1 | `vw_Report_DailyCirculation` | View | `views/` | Daily borrow count, return count, and net active loan delta by date. |
| 2 | `vw_Report_MonthlyCirculationTrends` | View | `views/` | Monthly borrow/return volume and late-return percentage (`NgayTra > NgayHenTra`). |
| 3 | `vw_Report_TopBorrowedTitles` | View | `views/` | Most borrowed `BookTitle`s with authors, total borrows, and current `AVAILABLE` copies. |
| 4 | `vw_Report_InventoryStatusSummary` | View | `views/` | Copy count and total `Price` value grouped by `StatusID` (`AVAILABLE`, `BORROWED`, `DAMAGED`, `LOST`). |
| 5 | `vw_Report_OverdueLoans` | View | `views/` | Currently unreturned overdue loans (`NgayHenTra < GETDATE()`) with days overdue, student info, and `MaVach`. |
| 6 | `vw_Report_FineSummaryByRule` | View | `views/` | Total fines assessed, collected (`PAYMENT`), waived (`WAIVER`), and outstanding grouped by `FineRule.RuleCode`. |
| 7 | `vw_Report_StudentActivityKPI` | View | `views/` | Per-student borrow count, overdue count, total fines assessed, and current unpaid balance. |
| 8 | `vw_Report_StaffWorkload` | View | `views/` | Per-staff (`NhanVien`) count of `PhieuMuon`, `PhieuTra`, and `PhieuThu` transactions handled. |
| 9 | `sp_Report_CirculationByDateRange` | Proc | `procedures/` | Parameterized (`@StartDate DATE`, `@EndDate DATE`) borrow/return/fine-revenue summary. |
| 10 | `sp_Report_TopDelinquentStudents` | Proc | `procedures/` | Parameterized (`@TopN INT = 10`) ranking of students by outstanding fine balance and overdue incidents. |

### 6.2 SQL Tests (`db/tests/`)
- **`001_shared/test_fn_CalculateFine.sql`:** Update TC09 expected value from `0.00` to `NULL` to match `fn_CalculateFine` and `SPEC.md`; remove duplicate `db/tests/003_circulations/test_fn_CalculateFine.sql` per `AGENTS.md`.
- **`003_circulations/test_sp_LapPhieuMuon.sql`:** Update all tests for `@NhanVienID`, 3-book limit (`50004`), `TrangThai <> 'ACTIVE'` (`50001`), `LOST` (`DongMuonID`-linked) unpaid fine block, and `PARTIAL` fine block (`50002`).
- **`003_circulations/test_sp_LapPhieuTra.sql`:** Verify `CK_DongPhat_Link` XOR (`DongTraID` vs `DongMuonID` non-null checks) for `LATE`, `DAMAGED` (with `@CustomDamagePercent`), and `LOST`.
- **New Test Suites:**
  - `db/tests/002_catalog/test_catalog_procedures.sql`
  - `db/tests/004_fines/test_fines_procedures.sql`
  - `db/tests/005_reports/test_reports.sql`

### 6.3 `scripts/03_run_programs.bat` & `scripts/setup_all.bat`
- Add `-b` (abort on SQL error) and `if errorlevel 1 exit /b 1` checks in `01_reset_schema.bat`, `02_run_seeds.bat`, and `03_run_programs.bat` so `setup_all.bat` never silently masks failures.
- Run `scripts/setup_all.bat` to verify end-to-end clean execution.

---

## Phase 7 — NoSQL Log Pipeline (`nosql/`)

### 7.1 Proposed MongoDB Document Schema (`nosql/sample_logs.json`)
- **Database / Collection:** `ThuVien2Logs.library_event_logs`
- **Join Key Integrity:** `generate_logs.py` queries live `MaSinhVien` (`dbo.SinhVien`) and `MaVach` (`dbo.BookItem`) from SQL Server `ThuVien2` before generating documents.
- **Document Structure:**
  ```json
  {
    "event_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "event_type": "KIOSK_SCAN",
    "timestamp": "2026-10-15T09:23:11Z",
    "ma_sinh_vien": "29210252479",
    "ma_vach": "BI001",
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
  - `KIOSK_SCAN` (`SELF_CHECKOUT_ATTEMPT`, `SELF_RETURN_SCAN`, `BARCODE_LOOKUP`) — always carries real `ma_vach` and `ma_sinh_vien`; `result` in `["SUCCESS", "UNAVAILABLE", "DENIED_FINES", "DENIED_LIMIT"]`.
  - `CATALOG_SEARCH` (`OPAC_KEYWORD_SEARCH`) — carries `search_query` and optional `ma_sinh_vien` + matched `ma_vach`.
  - `RFID_GATE_PING` (`EXIT_GATE_CHECK`) — carries real `ma_vach` and `result` in `["CLEARED", "UNRETURNED_ALERT"]`.

### 7.2 Bulk Generator (`nosql/generate_logs.py`)
- Connects to SQL Server (`pyodbc`) to load valid `MaSinhVien` and `MaVach` lists (plus `BookTitle` keywords for realistic `search_query` values).
- Generates **5,500+** realistic log documents over a 60-day window (with daytime campus traffic peaks) and inserts into MongoDB (`pymongo`) in batches of 1,000, creating indexes on `ma_sinh_vien`, `ma_vach`, `event_type`, and `timestamp`.

---

## Phase 8 — Cross-DB Analytics & Visualization (`analytics/`)

### 8.1 Dependencies (`analytics/requirements.txt`)
`pyodbc`, `sqlalchemy`, `pymongo`, `pandas`, `matplotlib`, `seaborn`

### 8.2 Cross-DB Pipeline (`analytics/join_and_analyze.py`)
Connects to SQL Server (`ThuVien2`) and MongoDB (`ThuVien2Logs`), loads relational tables and event logs into `pandas.DataFrame`s, joins on `MaVach` and `MaSinhVien`, and exports **4 charts** to `analytics/charts/`:

1. **`01_search_demand_vs_availability.png`** — Joins MongoDB `CATALOG_SEARCH` / `KIOSK_SCAN` demand per `MaVach` with SQL `BookItem` & `BookTitle` to compare digital demand against physical `AVAILABLE` copy ratio (highlights under-stocked titles).
2. **`02_kiosk_hourly_traffic_vs_checkouts.png`** — Aggregates MongoDB `KIOSK_SCAN` volume by hour of day alongside `DENIED_FINES` / `UNAVAILABLE` failure rates to guide kiosk staffing and peak-hour capacity.
3. **`03_student_engagement_vs_delinquency.png`** — Joins MongoDB scan/search frequency per `MaSinhVien` with SQL `SinhVien.TrangThai`, overdue count, and unpaid fine balance to profile patron engagement vs. delinquency.
4. **`04_fine_revenue_and_recovery_breakdown.png`** — Combines SQL `DongPhat` + `PhieuThu` (`PAYMENT` vs `WAIVER` vs `UNPAID`/`PARTIAL`) by `FineRule.RuleCode` with MongoDB `RFID_GATE_PING` / `LOST` item scan timelines.

---

## Next Step
Awaiting your approval of `PLAN.md` before starting **Phase 1 (Schema Alignment)**.
