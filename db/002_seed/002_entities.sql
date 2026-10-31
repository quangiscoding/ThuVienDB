USE ThuVien2;
GO

-- Staff (depends on dbo.Role)
INSERT INTO dbo.NhanVien (MaNhanVien, RoleID, HoTen, Email) VALUES 
('NV01', 'LIBRARIAN', N'Phan Văn Giang', 'giang.phanvan@library.edu.vn');

-- Patrons / Students
INSERT INTO dbo.SinhVien (MaSinhVien, HoTen, Lop, Email) VALUES 
('29210252479', N'Nguyễn Văn A', '29K12.1', 'a.nguyen@uni.edu.vn'),
('29210252480', N'Trần Thị B', '29K12.2', 'b.tran@uni.edu.vn');

-- Authors
INSERT INTO dbo.Author (TenTacGia) VALUES 
(N'Nguyễn Nhật Ánh'),
(N'JK Rowling');

-- Conceptual Titles
INSERT INTO dbo.BookTitle (BookTitle) VALUES 
(N'Mắt Biếc'), 
(N'Harry Potter');
GO