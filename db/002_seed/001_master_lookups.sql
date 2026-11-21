USE ThuVien2;
GO

-- 1. System roles
INSERT INTO dbo.[Role] (RoleID, RoleTitle) VALUES
('ADMIN',     N'Administrator'),
('LIBRARIAN', N'Librarian');

-- 2. Item statuses
INSERT INTO dbo.[Status] (StatusID, StatusName) VALUES
('AVAILABLE', N'Available'),
('BORROWED',  N'Borrowed'),
('LOST',      N'Lost'),
('DAMAGED',   N'Damaged');

-- 3. Business fine policies (must satisfy CK_FineRule_Components and CK_FineRule_Percent)
INSERT INTO dbo.FineRule (RuleCode, RuleName, RatePerDay, PercentOfBookValue, FixedProcessingFee) VALUES
('LATE',    N'Overdue Return Fine',     5000.00, NULL,  0.00),
('LOST',    N'Lost Book Replacement',   NULL,    1.00, 20000.00),
('DAMAGED', N'Damaged Book Penalty',    NULL,    0.20, 15000.00);
GO
