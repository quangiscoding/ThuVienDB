USE ThuVien2;
GO

-- =============================================================================
-- DROP TABLES (reverse FK dependency order)
-- =============================================================================

-- 1. Fine receipts & fines (deepest leaf children)
DROP TABLE IF EXISTS dbo.PaymentItem;
DROP TABLE IF EXISTS dbo.PaymentReceipt;
DROP TABLE IF EXISTS dbo.FineItem;
DROP TABLE IF EXISTS dbo.FineRule;

-- 2. Return & loan transactions
DROP TABLE IF EXISTS dbo.ReturnItem;
DROP TABLE IF EXISTS dbo.ReturnSlip;
DROP TABLE IF EXISTS dbo.LoanItem;
DROP TABLE IF EXISTS dbo.LoanSlip;

-- 3. Catalog & physical inventory
DROP TABLE IF EXISTS dbo.BookItem;
DROP TABLE IF EXISTS dbo.Author_BookTitle;
DROP TABLE IF EXISTS dbo.BookTitle;
DROP TABLE IF EXISTS dbo.Author;
DROP TABLE IF EXISTS dbo.Status;

-- 4. Staff, roles & students (root parent tables)
DROP TABLE IF EXISTS dbo.Student;
DROP TABLE IF EXISTS dbo.Staff;
DROP TABLE IF EXISTS dbo.Role;
GO
