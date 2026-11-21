USE ThuVien2;
GO

-- =============================================================================
-- DROP TABLES (reverse FK dependency order)
-- =============================================================================
DROP TABLE IF EXISTS dbo.PaymentItem;
DROP TABLE IF EXISTS dbo.PaymentReceipt;
DROP TABLE IF EXISTS dbo.FineItem;
DROP TABLE IF EXISTS dbo.FineRule;
DROP TABLE IF EXISTS dbo.ReturnItem;
DROP TABLE IF EXISTS dbo.ReturnSlip;
DROP TABLE IF EXISTS dbo.LoanItem;
DROP TABLE IF EXISTS dbo.LoanSlip;
DROP TABLE IF EXISTS dbo.BookItem;
DROP TABLE IF EXISTS dbo.Author_BookTitle;
DROP TABLE IF EXISTS dbo.BookTitle;
DROP TABLE IF EXISTS dbo.Author;
DROP TABLE IF EXISTS dbo.Status;
DROP TABLE IF EXISTS dbo.Student;
DROP TABLE IF EXISTS dbo.Staff;
DROP TABLE IF EXISTS dbo.Role;
GO

-- =============================================================================
-- 1. ROLES & STAFF
-- =============================================================================
CREATE TABLE dbo.Role (
    RoleID VARCHAR(20) PRIMARY KEY,           -- 'ADMIN', 'LIBRARIAN'
    RoleTitle NVARCHAR(100) NOT NULL
);

CREATE TABLE dbo.Staff (
    StaffID INT IDENTITY(1,1) PRIMARY KEY,
    StaffCode VARCHAR(20) NOT NULL UNIQUE,    -- 'NV01', 'NV02'
    RoleID VARCHAR(20) NOT NULL,
    FullName NVARCHAR(100) NOT NULL,
    Email VARCHAR(100),
    FOREIGN KEY (RoleID) REFERENCES dbo.Role(RoleID)
);

-- =============================================================================
-- 2. STUDENTS / PATRONS
-- =============================================================================
CREATE TABLE dbo.Student (
    StudentID INT IDENTITY(1,1) PRIMARY KEY,
    StudentCode VARCHAR(20) NOT NULL UNIQUE,
    FullName NVARCHAR(100) NOT NULL,
    ClassName NVARCHAR(50),
    Email VARCHAR(100),
    Status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT CK_Student_Status CHECK (Status IN ('ACTIVE', 'SUSPENDED', 'EXPIRED'))
);

-- =============================================================================
-- 3. BOOKS, AUTHORS & PHYSICAL ITEMS
-- =============================================================================
CREATE TABLE dbo.Status (
    StatusID VARCHAR(20) PRIMARY KEY,         -- 'AVAILABLE', 'BORROWED', 'LOST', 'DAMAGED'
    StatusName NVARCHAR(100) NOT NULL
);

CREATE TABLE dbo.Author (
    AuthorID INT IDENTITY(1,1) PRIMARY KEY,
    AuthorName NVARCHAR(100) NOT NULL
);

CREATE TABLE dbo.BookTitle (
    TitleID INT IDENTITY(1,1) PRIMARY KEY,
    BookTitle NVARCHAR(200) NOT NULL
);

CREATE TABLE dbo.Author_BookTitle (
    Author_BookTitle_ID INT IDENTITY(1,1) PRIMARY KEY,
    AuthorID INT NOT NULL,
    TitleID INT NOT NULL,
    FOREIGN KEY (AuthorID) REFERENCES dbo.Author(AuthorID),
    FOREIGN KEY (TitleID) REFERENCES dbo.BookTitle(TitleID),
    CONSTRAINT UQ_Author_Title UNIQUE (AuthorID, TitleID)
);

CREATE TABLE dbo.BookItem (
    BookItemID INT IDENTITY(1,1) PRIMARY KEY,
    Barcode VARCHAR(30) NOT NULL UNIQUE,      -- 'BI001', 'BI002'
    TitleID INT NOT NULL,
    StatusID VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE',
    Price DECIMAL(18, 2) NOT NULL DEFAULT 0 CHECK (Price >= 0),
    FOREIGN KEY (TitleID) REFERENCES dbo.BookTitle(TitleID),
    FOREIGN KEY (StatusID) REFERENCES dbo.Status(StatusID)
);

-- =============================================================================
-- 4. BORROWING TRANSACTIONS
-- =============================================================================
CREATE TABLE dbo.LoanSlip (
    LoanSlipID INT IDENTITY(1,1) PRIMARY KEY,
    StudentID INT NOT NULL,
    StaffID INT NOT NULL,
    LoanDate DATE NOT NULL,
    FOREIGN KEY (StudentID) REFERENCES dbo.Student(StudentID),
    FOREIGN KEY (StaffID) REFERENCES dbo.Staff(StaffID)
);

CREATE TABLE dbo.LoanItem (
    LoanItemID INT IDENTITY(1,1) PRIMARY KEY,
    BookItemID INT NOT NULL,
    LoanSlipID INT NOT NULL,
    DueDate DATE NOT NULL,
    FOREIGN KEY (BookItemID) REFERENCES dbo.BookItem(BookItemID),
    FOREIGN KEY (LoanSlipID) REFERENCES dbo.LoanSlip(LoanSlipID)
);

-- =============================================================================
-- 5. RETURN TRANSACTIONS & FINES
-- =============================================================================
CREATE TABLE dbo.ReturnSlip (
    ReturnSlipID INT IDENTITY(1,1) PRIMARY KEY,
    StudentID INT NOT NULL,
    StaffID INT NOT NULL,
    ReturnDate DATE NOT NULL,
    FOREIGN KEY (StudentID) REFERENCES dbo.Student(StudentID),
    FOREIGN KEY (StaffID) REFERENCES dbo.Staff(StaffID)
);

CREATE TABLE dbo.ReturnItem (
    ReturnItemID INT IDENTITY(1,1) PRIMARY KEY,
    ReturnSlipID INT NOT NULL,
    LoanItemID INT NOT NULL,
    FOREIGN KEY (ReturnSlipID) REFERENCES dbo.ReturnSlip(ReturnSlipID),
    FOREIGN KEY (LoanItemID) REFERENCES dbo.LoanItem(LoanItemID),
    CONSTRAINT UQ_ReturnItem_LoanItem UNIQUE (LoanItemID) -- each loan item can be returned only once
);

-- =============================================================================
-- FineRule: CHECK constraints enforce component rules per RuleCode.
-- PercentOfBookValue is stored as a fraction: 0.20 = 20%, 1.00 = 100%.
-- =============================================================================
CREATE TABLE dbo.FineRule (
    RuleID INT IDENTITY(1,1) PRIMARY KEY,
    RuleCode VARCHAR(20) NOT NULL UNIQUE,     -- 'LATE', 'LOST', 'DAMAGED'
    RuleName NVARCHAR(100) NOT NULL,
    RatePerDay DECIMAL(18, 2) NULL,           -- used by LATE only
    PercentOfBookValue DECIMAL(5, 2) NULL,    -- used by LOST / DAMAGED only
    FixedProcessingFee DECIMAL(18, 2) NOT NULL DEFAULT 0,

    CONSTRAINT CK_FineRule_Components CHECK (
        (RuleCode = 'LATE'    AND RatePerDay IS NOT NULL AND PercentOfBookValue IS NULL)
     OR (RuleCode = 'LOST'    AND RatePerDay IS NULL     AND PercentOfBookValue IS NOT NULL)
     OR (RuleCode = 'DAMAGED' AND RatePerDay IS NULL     AND PercentOfBookValue IS NOT NULL)
    ),
    CONSTRAINT CK_FineRule_Percent CHECK (
        PercentOfBookValue IS NULL OR (PercentOfBookValue > 0 AND PercentOfBookValue <= 1)
    ),
    CONSTRAINT CK_FineRule_Rate CHECK (RatePerDay IS NULL OR RatePerDay >= 0)
);

-- =============================================================================
-- FineItem: linked EITHER to a ReturnItem (LATE/DAMAGED)
-- OR directly to a LoanItem (LOST - book never came back), never both/none.
-- =============================================================================
CREATE TABLE dbo.FineItem (
    FineItemID INT IDENTITY(1,1) PRIMARY KEY,
    FineRuleID INT NOT NULL,
    ReturnItemID INT NULL,
    LoanItemID INT NULL,
    Amount DECIMAL(18, 2) NOT NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'UNPAID',
    Description NVARCHAR(255),
    FOREIGN KEY (FineRuleID) REFERENCES dbo.FineRule(RuleID),
    FOREIGN KEY (ReturnItemID) REFERENCES dbo.ReturnItem(ReturnItemID),
    FOREIGN KEY (LoanItemID) REFERENCES dbo.LoanItem(LoanItemID),
    CONSTRAINT CK_FineItem_Link CHECK (
        (ReturnItemID IS NOT NULL AND LoanItemID IS NULL)   -- fine from a return
     OR (ReturnItemID IS NULL     AND LoanItemID IS NOT NULL) -- fine for a lost book
    ),
    CONSTRAINT CK_FineItem_Status CHECK (Status IN ('UNPAID', 'PARTIAL', 'PAID', 'WAIVED')),
    CONSTRAINT CK_FineItem_Amount CHECK (Amount >= 0)
);

-- =============================================================================
-- 6. FINE PAYMENT & WAIVER RECEIPTS
-- =============================================================================
CREATE TABLE dbo.PaymentReceipt (
    ReceiptID INT IDENTITY(1,1) PRIMARY KEY,
    StaffID INT NOT NULL,
    StudentID INT NOT NULL,
    PaymentDate DATE NOT NULL,
    ReceiptType VARCHAR(20) NOT NULL DEFAULT 'PAYMENT',
    Total DECIMAL(18, 2) NOT NULL DEFAULT 0 CHECK (Total >= 0),
    FOREIGN KEY (StaffID) REFERENCES dbo.Staff(StaffID),
    FOREIGN KEY (StudentID) REFERENCES dbo.Student(StudentID),
    CONSTRAINT CK_PaymentReceipt_Type CHECK (ReceiptType IN ('PAYMENT', 'WAIVER'))
);

CREATE TABLE dbo.PaymentItem (
    PaymentItemID INT IDENTITY(1,1) PRIMARY KEY,
    ReceiptID INT NOT NULL,
    FineItemID INT NOT NULL,
    AmountPaid DECIMAL(18, 2) NOT NULL CHECK (AmountPaid >= 0),
    FOREIGN KEY (ReceiptID) REFERENCES dbo.PaymentReceipt(ReceiptID),
    FOREIGN KEY (FineItemID) REFERENCES dbo.FineItem(FineItemID)
);
GO
