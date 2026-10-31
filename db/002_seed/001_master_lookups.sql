USE ThuVien2;
GO

-- 1. System roles
INSERT INTO dbo.[Role] (RoleID, RoleTitle) VALUES 
('ADMIN', N'Quản trị viên'),
('LIBRARIAN', N'Thủ thư');

-- 2. Item & loan statuses
INSERT INTO dbo.[Status] (StatusID, StatusName) VALUES 
('AVAILABLE', N'Có sẵn'),
('BORROWED', N'Đang mượn'),
('LOST', N'Bị mất'),
('DAMAGED', N'Hư hỏng');

-- 3. Business fine policies (Đã thêm RuleCode định danh nghiệp vụ)
INSERT INTO dbo.FineRule (RuleCode, RuleName, RatePerDay, PercentOfBookValue, FixedProcessingFee) VALUES 
('LATE',    N'Phạt trả quá hạn',  5000.00, 0.0, 0.00),
('LOST',    N'Bồi thường mất sách',   0.00, 1.0, 20000.00),
('DAMAGED', N'Phạt làm hỏng sách',   0.00, 0.0, 15000.00);
GO