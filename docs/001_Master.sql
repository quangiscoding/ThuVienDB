-- 1. Vai trò & Trạng thái
INSERT INTO Role (RoleID, RoleTitle) VALUES 
('ADMIN', 'Quản trị hệ thống'),
('LIBRARIAN', 'Thủ thư');

INSERT INTO Status (StatusID, StatusName) VALUES 
('AVAILABLE', 'Có sẵn trong kho'),
('BORROWED', 'Đang cho mượn'),
('LOST', 'Đã làm mất');

-- 2. Quy tắc phạt
INSERT INTO FinerRule (RuleName, RatePerDay, PercentOfBookValue, FixedProcessingFee) VALUES 
('Phạt trả trễ', 5000, 0, 0),
('Phạt làm mất sách', 0, 1.0, 20000);

-- 3. Tác giả & Tên sách (Chưa có cuốn sách vật lý)
INSERT INTO Author (TenTacGia) VALUES 
('Nguyễn Nhật Ánh'), 
('Bill Gates');

INSERT INTO BookTitle (BookTitle) VALUES 
('Mắt Biếc'), 
('Business @ the Speed of Thought');

INSERT INTO Author_BookTitle (AuthorID, TitleID) VALUES 
(1, 1), 
(2, 2);