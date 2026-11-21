USE ThuVien2;
GO

-- 1. Staff (depends on dbo.Role)
INSERT INTO dbo.Staff (StaffCode, RoleID, FullName, Email) VALUES
('NV01', 'LIBRARIAN', N'Giang Phan',  'giang.phan@library.edu.vn'),
('NV02', 'ADMIN',     N'Linh Nguyen', 'linh.nguyen@library.edu.vn');

-- 2. Students / Patrons (includes ACTIVE, SUSPENDED, and EXPIRED fixtures)
INSERT INTO dbo.Student (StudentCode, FullName, ClassName, Email, Status) VALUES
('29210252479', N'Nguyen Van A',  '29K12.1', 'a.nguyen@uni.edu.vn', 'ACTIVE'),
('29210252480', N'Tran Thi B',    '29K12.2', 'b.tran@uni.edu.vn',   'ACTIVE'),
('29210252481', N'Le Minh C',     '29K12.1', 'c.le@uni.edu.vn',     'ACTIVE'),
('29210252482', N'Pham Quoc D',   '29K12.3', 'd.pham@uni.edu.vn',   'SUSPENDED'),
('29210252483', N'Hoang Anh E',   '28K10.1', 'e.hoang@uni.edu.vn',  'EXPIRED');

-- 3. Authors
INSERT INTO dbo.Author (AuthorName) VALUES
(N'Nguyen Nhat Anh'),
(N'J.K. Rowling'),
(N'Robert C. Martin'),
(N'Martin Kleppmann'),
(N'Andrew Hunt');

-- 4. Book Titles
INSERT INTO dbo.BookTitle (BookTitle) VALUES
(N'Blue Eyes (Mat Biec)'),
(N'Harry Potter and the Sorcerer''s Stone'),
(N'Clean Code'),
(N'Designing Data-Intensive Applications'),
(N'The Pragmatic Programmer');
GO
