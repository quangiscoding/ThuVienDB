USE ThuVien2;
GO

-- 1. Fine Receipts & Fines (Deepest leaf children)
DELETE FROM dbo.DongThu;
DELETE FROM dbo.PhieuThu;
DELETE FROM dbo.DongPhat;

-- 2. Returns (Depends on DongMuon & PhieuTra)
DELETE FROM dbo.DongTra;
DELETE FROM dbo.PhieuTra;

-- 3. Loans (Depends on BookItem & PhieuMuon)
DELETE FROM dbo.DongMuon;
DELETE FROM dbo.PhieuMuon;

-- 4. Inventory & Titles
DELETE FROM dbo.BookItem;
DELETE FROM dbo.Author_BookTitle;
DELETE FROM dbo.BookTitle;
DELETE FROM dbo.Author;

-- 5. Reference & Master catalogs (Parents)
DELETE FROM dbo.Status;
DELETE FROM dbo.FineRule;
DELETE FROM dbo.SinhVien;
DELETE FROM dbo.NhanVien;
DELETE FROM dbo.Role;
GO

-- Reseed only tables that actually have an IDENTITY column
EXEC sp_MSforeachtable "
    IF OBJECTPROPERTY(OBJECT_ID('?'), 'TableHasIdentity') = 1
    BEGIN
        DBCC CHECKIDENT ('?', RESEED, 0);
    END
";
GO