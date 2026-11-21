# SPEC.md — ThuVien2 Library Management System Specification

## 1. System Overview
Database-first Library Management System built on **Microsoft SQL Server (T-SQL)**, extended with a **MongoDB** high-frequency event log store and a **Python** cross-database analytics pipeline. All core relational business rules, validation, and transactional state changes live in SQL Server stored procedures and functions using **100% English identifiers**.

## 2. Domain Entities & English Schema Mapping
- **Staff & Roles:**
  - `dbo.Role` (`RoleID` PK: `'ADMIN'`, `'LIBRARIAN'`, `RoleTitle`)
  - `dbo.Staff` (`StaffID` PK, `StaffCode` UNIQUE, `RoleID` FK, `FullName`, `Email`)
- **Patrons:**
  - `dbo.Student` (`StudentID` PK, `StudentCode` UNIQUE, `FullName`, `ClassName`, `Email`, `Status`: `'ACTIVE'`, `'SUSPENDED'`, `'EXPIRED'`)
- **Catalog:**
  - `dbo.Status` (`StatusID` PK: `'AVAILABLE'`, `'BORROWED'`, `'LOST'`, `'DAMAGED'`, `StatusName`)
  - `dbo.Author` (`AuthorID` PK, `AuthorName`)
  - `dbo.BookTitle` (`TitleID` PK, `BookTitle`)
  - `dbo.Author_BookTitle` (`Author_BookTitle_ID` PK, `AuthorID` FK, `TitleID` FK)
  - `dbo.BookItem` (`BookItemID` PK, `Barcode` UNIQUE, `TitleID` FK, `StatusID` FK, `Price` DECIMAL(18,2) NOT NULL CHECK (`Price >= 0`))
- **Circulation:**
  - `dbo.LoanSlip` (`LoanSlipID` PK, `StudentID` FK, `StaffID` FK, `LoanDate`)
  - `dbo.LoanItem` (`LoanItemID` PK, `BookItemID` FK, `LoanSlipID` FK, `DueDate` — default 14 days from `LoanDate`)
  - `dbo.ReturnSlip` (`ReturnSlipID` PK, `StudentID` FK, `StaffID` FK, `ReturnDate`)
  - `dbo.ReturnItem` (`ReturnItemID` PK, `ReturnSlipID` FK, `LoanItemID` FK UNIQUE)
- **Fines & Receipts:**
  - `dbo.FineRule` (`RuleID` PK, `RuleCode` UNIQUE: `'LATE'`, `'LOST'`, `'DAMAGED'`, `RuleName`, `RatePerDay`, `PercentOfBookValue`, `FixedProcessingFee`)
  - `dbo.FineItem` (`FineItemID` PK, `FineRuleID` FK, `ReturnItemID` FK NULL, `LoanItemID` FK NULL, `Amount`, `Status`: `'UNPAID'`, `'PARTIAL'`, `'PAID'`, `'WAIVED'`, `Description`, `CK_FineItem_Link` XOR constraint)
  - `dbo.PaymentReceipt` (`ReceiptID` PK, `StaffID` FK, `StudentID` FK, `PaymentDate`, `ReceiptType`: `'PAYMENT'`, `'WAIVER'`, `Total`)
  - `dbo.PaymentItem` (`PaymentItemID` PK, `ReceiptID` FK, `FineItemID` FK, `AmountPaid`)

## 3. Business Rules & Modules

### 3.1 Shared (`001_shared`)
- **`fn_CalculateFine(@RuleID, @DaysOverdue, @BookPrice, @CustomDamagePercent)`**:
  - Looks up `FineRule` by `@RuleID`. Returns `NULL` if `@RuleID` does not exist.
  - Formula: `(@DaysOverdue * RatePerDay) + (@BookPrice * Percent) + FixedProcessingFee`.
  - Allows `@CustomDamagePercent` in `(0, 1]` to override `PercentOfBookValue` for `'DAMAGED'` rules only.

### 3.2 Catalog (`002_catalog`)
- **`sp_AddBookTitle`**: Creates a `BookTitle` record and links one or more `AuthorID`s in `Author_BookTitle`.
- **`sp_AddBookCopies`**: Inserts physical copies into `dbo.BookItem` with unique `Barcode`, `Price`, and default status `'AVAILABLE'`.
- **`sp_UpdateCopyStatus`**: Updates `BookItem.StatusID` (`'AVAILABLE'`, `'DAMAGED'`, `'LOST'`) for administrative inventory adjustments.
- **`sp_SearchCatalog`**: Queries `BookTitle` joined with `Author` and `BookItem`, returning book metadata, total copies, and count of `'AVAILABLE'` copies.

### 3.3 Circulation (`003_circulation`)
- **`sp_CreateLoanSlip(@StudentCode, @StaffID, @BookItemID, @LoanDays = 14)`**:
  - **Bug Fixes Required:** Accepts `@StaffID INT` (required by `LoanSlip.StaffID NOT NULL`) and checks unpaid fines across **both** `ReturnItemID` and `LoanItemID` paths (`Status IN ('UNPAID', 'PARTIAL')`).
  - **Borrower Eligibility Checks:**
    1. Student exists (`@StudentCode`) and `Student.Status = 'ACTIVE'`.
    2. Staff exists (`@StaffID`).
    3. Student has **no** fines in `FineItem` with `Status IN ('UNPAID', 'PARTIAL')`.
    4. Student has **no** currently unreturned books past `DueDate`.
    5. Active unreturned books $< 3$ (max borrow cap).
  - **Item Check:** `BookItemID` has `StatusID = 'AVAILABLE'`.
  - **State Change:** Updates `BookItem.StatusID` to `'BORROWED'`, inserts `LoanSlip` & `LoanItem`.

- **`sp_CreateReturnSlip(@StudentID, @StaffID, @LoanItemID, @NewBookStatus = 'AVAILABLE', @ReturnDate = NULL, @CustomDamagePercent = NULL)`**:
  - **Bug Fix Required (`CK_FineItem_Link`):** When inserting into `dbo.FineItem`, pass `(@ReturnItemID, NULL)` for `'LATE'` and `'DAMAGED'` fines, and `(NULL, @LoanItemID)` for `'LOST'` fines so the XOR check constraint succeeds.
  - Validates `@LoanItemID` exists, belongs to `@StudentID`, and is not already in `ReturnItem`.
  - Inserts `ReturnSlip` & `ReturnItem`, updates `BookItem.StatusID` to `@NewBookStatus` (`'AVAILABLE'`, `'DAMAGED'`, or `'LOST'`).
  - Calls `dbo.fn_CalculateFine` for overdue (`'LATE'`) and/or `'DAMAGED'`/`'LOST'` rules and inserts `FineItem` rows (`Status = 'UNPAID'`) when fine $> 0$.

### 3.4 Fines (`004_fines`)
- **`sp_RecordFinePayment`**:
  - Creates a `PaymentReceipt` (`ReceiptType = 'PAYMENT'`) and `PaymentItem` line items.
  - Supports **partial payments**: calculates total paid (`SUM(PaymentItem.AmountPaid)`) per `FineItemID`. Rejects overpayment (`AmountPaid > RemainingBalance`).
  - Updates `FineItem.Status` to `'PARTIAL'` if `0 < Paid < Amount`, or `'PAID'` if `Paid = Amount`.
- **`sp_WaiveFine`**:
  - Forgives remaining balance on a `FineItem` record (requires `'ADMIN'` role or authorized `StaffID`).
  - Records a `PaymentReceipt` (`ReceiptType = 'WAIVER'`) + `PaymentItem` entry for auditability and sets `FineItem.Status = 'WAIVED'`.
- **`sp_GetStudentFineBalance`**:
  - Returns itemized unpaid/partial fines and total remaining balance for a `StudentID`.

## 4. Error Handling & Transaction Standards
- **Nested-Safe Transactions:** Follow the existing nested-safe pattern (`IF @@TRANCOUNT = 0 BEGIN TRANSACTION ... ELSE SAVE TRANSACTION ...`) so procedures compose cleanly inside T-SQL test wrappers.
- **Validation Errors:** Raise descriptive English errors with severity `16` (`RAISERROR` or `THROW` `50001`–`50007`) on all validation failures:
  - `50001`: Student not found or account not `ACTIVE`
  - `50002`: Student has unpaid or partial fines
  - `50003`: Student has overdue unreturned books
  - `50004`: Max borrow limit (3 books) exceeded
  - `50005`: BookItem is not `AVAILABLE`
  - `50006`: Invalid or already-returned loan item (`LoanItemID`)
  - `50007`: Payment exceeds remaining fine balance

## 5. Analytical & Reporting Module (`005_reports`) — Course Report Ch. 1 & 2
- **Deliverable:** Create 10 SQL `VIEW`s or `sp_Report_*` procedures in `db/003_program/005_reports/` covering library KPIs (circulation trends, overdue/fine analytics, inventory status, student activity, and staff workload).
- **Agent Autonomy:** Antigravity should propose the exact 10 analytical queries based on the English schema in `PLAN.md` for user approval before implementation.

## 6. NoSQL Logs & Cross-DB Analytics (`nosql/`, `analytics/`) — Course Report Ch. 3 & 4
- **MongoDB (`nosql/`):** Store high-frequency library event logs (e.g., kiosk barcode scans and catalog searches) in MongoDB.
  - **Join Key Constraint:** Every generated JSON log document **must** reference real `Barcode` and/or `StudentCode` values queried directly from `ThuVien2` (SQL Server) so cross-database joins succeed.
  - **Scale:** Provide a Python generator script (`generate_logs.py`) that inserts at least 5,000 realistic mock log documents.
- **Python Analytics (`analytics/`):**
  - Connect to both SQL Server (`pyodbc`/`sqlalchemy`) and MongoDB (`pymongo`), join the datasets using `pandas` on `Barcode` / `StudentCode`, and export 3–4 business insight charts (`.png`) to `analytics/charts/`.
  - **Agent Autonomy:** Antigravity should propose the exact JSON document schema and chart insights in `PLAN.md` for user approval.