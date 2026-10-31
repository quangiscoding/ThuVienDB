USE ThuVien2
-- =============================================================================
-- DROP OLD TABLES (dbo schema)
-- =============================================================================

-- 1. Xoá các bảng Phiếu Thu & Đóng Phạt (Bảng con phụ thuộc nhiều nhất)
DROP TABLE IF EXISTS dbo.DongThu;
DROP TABLE IF EXISTS dbo.PhieuThu;
DROP TABLE IF EXISTS dbo.DongPhat;
DROP TABLE IF EXISTS dbo.FineRule;

-- 2. Xoá các bảng Trả sách & Mượn sách
DROP TABLE IF EXISTS dbo.DongTra;
DROP TABLE IF EXISTS dbo.PhieuTra;
DROP TABLE IF EXISTS dbo.DongMuon;
DROP TABLE IF EXISTS dbo.PhieuMuon;

-- 3. Xoá các bảng Sách & Danh mục
DROP TABLE IF EXISTS dbo.BookItem;
DROP TABLE IF EXISTS dbo.Author_BookTitle;
DROP TABLE IF EXISTS dbo.BookTitle;
DROP TABLE IF EXISTS dbo.Author;
DROP TABLE IF EXISTS dbo.Status;

-- 4. Xoá các bảng Nhân sự & Sinh viên (Bảng cha gốc)
DROP TABLE IF EXISTS dbo.NhanVien;
DROP TABLE IF EXISTS dbo.Role;
DROP TABLE IF EXISTS dbo.SinhVien;

-- =============================================================================
-- (TÙY CHỌN) XOÁ LUÔN CÁC SCHEMA MỚI NẾU MUỐN RESET HOÀN TOÀN
-- =============================================================================
/*
DROP TABLE IF EXISTS circulation.DongThu, circulation.PhieuThu, circulation.DongPhat, circulation.FineRule, circulation.DongTra, circulation.PhieuTra, circulation.DongMuon, circulation.PhieuMuon;
DROP TABLE IF EXISTS catalog.BookItem, catalog.Author_BookTitle, catalog.BookTitle, catalog.Author, catalog.Status;
DROP TABLE IF EXISTS core.NhanVien, core.Role, core.SinhVien;

DROP SCHEMA IF EXISTS circulation;
DROP SCHEMA IF EXISTS catalog;
DROP SCHEMA IF EXISTS core;
*/