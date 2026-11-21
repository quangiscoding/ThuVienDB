USE ThuVien2;
GO

-- 1. Fine receipts & fines (deepest leaf children)
DELETE FROM dbo.PaymentItem;
DELETE FROM dbo.PaymentReceipt;
DELETE FROM dbo.FineItem;

-- 2. Returns (depends on LoanItem & ReturnSlip)
DELETE FROM dbo.ReturnItem;
DELETE FROM dbo.ReturnSlip;

-- 3. Loans (depends on BookItem & LoanSlip)
DELETE FROM dbo.LoanItem;
DELETE FROM dbo.LoanSlip;

-- 4. Inventory & titles
DELETE FROM dbo.BookItem;
DELETE FROM dbo.Author_BookTitle;
DELETE FROM dbo.BookTitle;
DELETE FROM dbo.Author;

-- 5. Reference & master catalogs (parents)
DELETE FROM dbo.Status;
DELETE FROM dbo.FineRule;
DELETE FROM dbo.Student;
DELETE FROM dbo.Staff;
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
