USE ThuVien2;
GO

-- =============================================================================
-- DROP TABLES (dependency order)
-- =============================================================================
DROP TABLE IF EXISTS dbo.DongThu;
DROP TABLE IF EXISTS dbo.PhieuThu;
DROP TABLE IF EXISTS dbo.DongPhat;
DROP TABLE IF EXISTS dbo.FineRule;
DROP TABLE IF EXISTS dbo.DongTra;
DROP TABLE IF EXISTS dbo.PhieuTra;
DROP TABLE IF EXISTS dbo.DongMuon;
DROP TABLE IF EXISTS dbo.PhieuMuon;
DROP TABLE IF EXISTS dbo.BookItem;
DROP TABLE IF EXISTS dbo.Author_BookTitle;
DROP TABLE IF EXISTS dbo.BookTitle;
DROP TABLE IF EXISTS dbo.Author;
DROP TABLE IF EXISTS dbo.Status;
DROP TABLE IF EXISTS dbo.SinhVien;
DROP TABLE IF EXISTS dbo.NhanVien;
DROP TABLE IF EXISTS dbo.Role;
GO

-- =============================================================================
-- 1. ROLES & STAFF
-- =============================================================================
CREATE TABLE dbo.Role (
    RoleID VARCHAR(20) PRIMARY KEY,           -- 'ADMIN', 'LIBRARIAN'
    RoleTitle NVARCHAR(100) NOT NULL
);

CREATE TABLE dbo.NhanVien (
    NhanVienID INT IDENTITY(1,1) PRIMARY KEY,
    MaNhanVien VARCHAR(20) NOT NULL UNIQUE,   -- 'NV01', 'NV02'
    RoleID VARCHAR(20) NOT NULL,
    HoTen NVARCHAR(100) NOT NULL,
    Email VARCHAR(100),
    FOREIGN KEY (RoleID) REFERENCES dbo.Role(RoleID)
);

-- =============================================================================
-- 2. STUDENTS / PATRONS
-- =============================================================================
CREATE TABLE dbo.SinhVien (
    SinhVienID INT IDENTITY(1,1) PRIMARY KEY,
    MaSinhVien VARCHAR(20) NOT NULL UNIQUE,
    HoTen NVARCHAR(100) NOT NULL,
    Lop NVARCHAR(50),
    Email VARCHAR(100)
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
    TenTacGia NVARCHAR(100) NOT NULL
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
    MaVach VARCHAR(30) NOT NULL UNIQUE,       -- 'BI001', 'BI002'
    TitleID INT NOT NULL,
    StatusID VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE',
    Price DECIMAL(18, 2) CHECK (Price IS NULL OR Price >= 0),
    FOREIGN KEY (TitleID) REFERENCES dbo.BookTitle(TitleID),
    FOREIGN KEY (StatusID) REFERENCES dbo.Status(StatusID)
);

-- =============================================================================
-- 4. BORROWING TRANSACTIONS
-- =============================================================================
CREATE TABLE dbo.PhieuMuon (
    BorrowingID INT IDENTITY(1,1) PRIMARY KEY,
    SinhVienID INT NOT NULL,
    NhanVienID INT NOT NULL,
    NgayMuon DATE NOT NULL,
    FOREIGN KEY (SinhVienID) REFERENCES dbo.SinhVien(SinhVienID),
    FOREIGN KEY (NhanVienID) REFERENCES dbo.NhanVien(NhanVienID)
);

CREATE TABLE dbo.DongMuon (
    DongMuonID INT IDENTITY(1,1) PRIMARY KEY,
    BookItemID INT NOT NULL,
    BorrowingID INT NOT NULL,
    NgayHenTra DATE NOT NULL,
    FOREIGN KEY (BookItemID) REFERENCES dbo.BookItem(BookItemID),
    FOREIGN KEY (BorrowingID) REFERENCES dbo.PhieuMuon(BorrowingID)
);

-- =============================================================================
-- 5. RETURN TRANSACTIONS & FINES
-- =============================================================================
CREATE TABLE dbo.PhieuTra (
    PhieuTraID INT IDENTITY(1,1) PRIMARY KEY,
    SinhVienID INT NOT NULL,
    NhanVienID INT NOT NULL,
    NgayTra DATE NOT NULL,
    FOREIGN KEY (SinhVienID) REFERENCES dbo.SinhVien(SinhVienID),
    FOREIGN KEY (NhanVienID) REFERENCES dbo.NhanVien(NhanVienID)
);

CREATE TABLE dbo.DongTra (
    DongTraID INT IDENTITY(1,1) PRIMARY KEY,
    PhieuTraID INT NOT NULL,
    DongMuonID INT NOT NULL,
    FOREIGN KEY (PhieuTraID) REFERENCES dbo.PhieuTra(PhieuTraID),
    FOREIGN KEY (DongMuonID) REFERENCES dbo.DongMuon(DongMuonID),
    CONSTRAINT UQ_DongTra_DongMuon UNIQUE (DongMuonID)   -- each loan item can be returned only once
);

-- =============================================================================
-- FineRule: the CHECK constraints below make the "empty cell = not used"
-- convention ENFORCED by the database instead of just remembered by people.
-- PercentOfBookValue is stored as a fraction: 0.20 = 20%, 1.00 = 100%.
-- =============================================================================
CREATE TABLE dbo.FineRule (
    RuleID INT IDENTITY(1,1) PRIMARY KEY,
    RuleCode VARCHAR(20) NOT NULL UNIQUE,     -- 'LATE', 'LOST', 'DAMAGED'
    RuleName NVARCHAR(100) NOT NULL,
    RatePerDay DECIMAL(18, 2) NULL,           -- used by LATE only
    PercentOfBookValue DECIMAL(5, 2) NULL,    -- used by LOST / DAMAGED only
    FixedProcessingFee DECIMAL(18, 2) NOT NULL DEFAULT 0,

    -- LATE must have a daily rate and no percent; LOST/DAMAGED the opposite.
    CONSTRAINT CK_FineRule_Components CHECK (
        (RuleCode = 'LATE'    AND RatePerDay IS NOT NULL AND PercentOfBookValue IS NULL)
     OR (RuleCode = 'LOST'    AND RatePerDay IS NULL     AND PercentOfBookValue IS NOT NULL)
     OR (RuleCode = 'DAMAGED' AND RatePerDay IS NULL     AND PercentOfBookValue IS NOT NULL)
    ),
    -- percent must be a sane fraction (0, 1]
    CONSTRAINT CK_FineRule_Percent CHECK (
        PercentOfBookValue IS NULL OR (PercentOfBookValue > 0 AND PercentOfBookValue <= 1)
    ),
    -- daily rate cannot be negative
    CONSTRAINT CK_FineRule_Rate CHECK (RatePerDay IS NULL OR RatePerDay >= 0)
);

-- =============================================================================
-- DongPhat: a fine is linked EITHER to a return line (LATE/DAMAGED)
-- OR directly to a loan line (LOST - book never came back), never both/none.
-- =============================================================================
CREATE TABLE dbo.DongPhat (
    DongPhatID INT IDENTITY(1,1) PRIMARY KEY,
    FineRuleID INT NOT NULL,
    DongTraID INT NULL,
    DongMuonID INT NULL,
    Amount DECIMAL(18, 2) NOT NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'UNPAID',
    Description NVARCHAR(255),
    FOREIGN KEY (FineRuleID) REFERENCES dbo.FineRule(RuleID),
    FOREIGN KEY (DongTraID) REFERENCES dbo.DongTra(DongTraID),
    FOREIGN KEY (DongMuonID) REFERENCES dbo.DongMuon(DongMuonID),
    CONSTRAINT CK_DongPhat_Link CHECK (
        (DongTraID IS NOT NULL AND DongMuonID IS NULL)   -- fine from a return
     OR (DongTraID IS NULL     AND DongMuonID IS NOT NULL) -- fine for a lost book
    ),
    CONSTRAINT CK_DongPhat_Status CHECK (Status IN ('UNPAID', 'PAID')),
    CONSTRAINT CK_DongPhat_Amount CHECK (Amount >= 0)
);

-- =============================================================================
-- 6. FINE PAYMENT RECEIPTS
-- =============================================================================
CREATE TABLE dbo.PhieuThu (
    PhieuThuID INT IDENTITY(1,1) PRIMARY KEY,
    NhanVienID INT NOT NULL,
    SinhVienID INT NOT NULL,
    NgayThu DATE NOT NULL,
    Total DECIMAL(18, 2),
    FOREIGN KEY (NhanVienID) REFERENCES dbo.NhanVien(NhanVienID),
    FOREIGN KEY (SinhVienID) REFERENCES dbo.SinhVien(SinhVienID)
);

CREATE TABLE dbo.DongThu (
    DongThuID INT IDENTITY(1,1) PRIMARY KEY,
    PhieuThuID INT NOT NULL,
    DongPhatID INT NOT NULL,
    SoTien DECIMAL(18, 2) NOT NULL CHECK (SoTien >= 0),
    FOREIGN KEY (PhieuThuID) REFERENCES dbo.PhieuThu(PhieuThuID),
    FOREIGN KEY (DongPhatID) REFERENCES dbo.DongPhat(DongPhatID)
);
GO
