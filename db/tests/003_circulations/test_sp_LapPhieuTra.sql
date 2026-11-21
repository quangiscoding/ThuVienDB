USE ThuVien2;
GO

-- 1. Initialize Test Class
EXEC tSQLt.NewTestClass 'test_circulation_LapPhieuTra';
GO

-- =============================================================================
-- TEST 1: Block when loan detail ID does not exist
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuTra.[test_ReturnFails_WhenLoanDetailDoesNotExist]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.DongMuon';
    EXEC tSQLt.FakeTable 'dbo.PhieuMuon';
    EXEC tSQLt.FakeTable 'dbo.BookItem';

    EXEC tSQLt.ExpectException @ExpectedMessagePattern = N'%Dòng mượn không tồn tại%';

    EXEC dbo.sp_LapPhieuTra @SinhVienID = 1, @NhanVienID = 1, @DongMuonID = 9999;
END;
GO

-- =============================================================================
-- TEST 2: Block when the returning student is not the one who borrowed the book
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuTra.[test_ReturnFails_WhenStudentMismatch]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.DongMuon';
    EXEC tSQLt.FakeTable 'dbo.PhieuMuon';
    EXEC tSQLt.FakeTable 'dbo.BookItem';

    -- Loan belongs to SinhVienID = 2
    INSERT INTO dbo.PhieuMuon (BorrowingID, SinhVienID) VALUES (10, 2);
    INSERT INTO dbo.BookItem (BookItemID, Price) VALUES (100, 50000.00);
    INSERT INTO dbo.DongMuon (DongMuonID, BorrowingID, BookItemID, NgayHenTra) 
    VALUES (1, 10, 100, CAST(GETDATE() AS DATE));

    EXEC tSQLt.ExpectException @ExpectedMessagePattern = N'%không thuộc về sinh viên%';

    -- SinhVienID = 1 attempts to return
    EXEC dbo.sp_LapPhieuTra @SinhVienID = 1, @NhanVienID = 1, @DongMuonID = 1;
END;
GO

-- =============================================================================
-- TEST 3: Block when the loan item has already been marked as returned
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuTra.[test_ReturnFails_WhenItemAlreadyReturned]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.DongMuon';
    EXEC tSQLt.FakeTable 'dbo.PhieuMuon';
    EXEC tSQLt.FakeTable 'dbo.BookItem';
    EXEC tSQLt.FakeTable 'dbo.DongTra';

    INSERT INTO dbo.PhieuMuon (BorrowingID, SinhVienID) VALUES (10, 1);
    INSERT INTO dbo.BookItem (BookItemID, Price) VALUES (100, 50000.00);
    INSERT INTO dbo.DongMuon (DongMuonID, BorrowingID, BookItemID, NgayHenTra) 
    VALUES (1, 10, 100, CAST(GETDATE() AS DATE));
    
    -- Already recorded in DongTra
    INSERT INTO dbo.DongTra (DongTraID, DongMuonID) VALUES (50, 1);

    EXEC tSQLt.ExpectException @ExpectedMessagePattern = N'%đã được làm thủ tục trả trước đó%';

    EXEC dbo.sp_LapPhieuTra @SinhVienID = 1, @NhanVienID = 1, @DongMuonID = 1;
END;
GO

-- =============================================================================
-- TEST 4: Block when the target book status does not exist in Status lookup
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuTra.[test_ReturnFails_WhenTargetBookStatusInvalid]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.DongMuon';
    EXEC tSQLt.FakeTable 'dbo.PhieuMuon';
    EXEC tSQLt.FakeTable 'dbo.BookItem';
    EXEC tSQLt.FakeTable 'dbo.[Status]';

    INSERT INTO dbo.PhieuMuon (BorrowingID, SinhVienID) VALUES (10, 1);
    INSERT INTO dbo.BookItem (BookItemID, Price) VALUES (100, 50000.00);
    INSERT INTO dbo.DongMuon (DongMuonID, BorrowingID, BookItemID, NgayHenTra) 
    VALUES (1, 10, 100, CAST(GETDATE() AS DATE));

    EXEC tSQLt.ExpectException @ExpectedMessagePattern = N'%Trạng thái sách mới không hợp lệ%';

    -- Provide an invalid status not present in dbo.[Status]
    EXEC dbo.sp_LapPhieuTra @SinhVienID = 1, @NhanVienID = 1, @DongMuonID = 1, @NewBookStatus = 'INVALID_STATUS';
END;
GO

-- =============================================================================
-- TEST 5: Block when receiving staff member ID does not exist
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuTra.[test_ReturnFails_WhenStaffDoesNotExist]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.DongMuon';
    EXEC tSQLt.FakeTable 'dbo.PhieuMuon';
    EXEC tSQLt.FakeTable 'dbo.BookItem';
    EXEC tSQLt.FakeTable 'dbo.[Status]';
    EXEC tSQLt.FakeTable 'dbo.NhanVien';

    INSERT INTO dbo.[Status] (StatusID) VALUES ('AVAILABLE');
    INSERT INTO dbo.PhieuMuon (BorrowingID, SinhVienID) VALUES (10, 1);
    INSERT INTO dbo.BookItem (BookItemID, Price) VALUES (100, 50000.00);
    INSERT INTO dbo.DongMuon (DongMuonID, BorrowingID, BookItemID, NgayHenTra) 
    VALUES (1, 10, 100, CAST(GETDATE() AS DATE));

    EXEC tSQLt.ExpectException @ExpectedMessagePattern = N'%Nhân viên tiếp nhận không tồn tại%';

    -- Provide non-existent NhanVienID = 999
    EXEC dbo.sp_LapPhieuTra @SinhVienID = 1, @NhanVienID = 999, @DongMuonID = 1, @NewBookStatus = 'AVAILABLE';
END;
GO

-- =============================================================================
-- TEST 6: On-time return with intact book restores status and charges no fine
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuTra.[test_ReturnSuccess_OnTime_RestoresBookStatusWithoutFine]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.DongMuon';
    EXEC tSQLt.FakeTable 'dbo.PhieuMuon';
    EXEC tSQLt.FakeTable 'dbo.BookItem';
    EXEC tSQLt.FakeTable 'dbo.PhieuTra';
    EXEC tSQLt.FakeTable 'dbo.DongTra';
    EXEC tSQLt.FakeTable 'dbo.DongPhat';
    EXEC tSQLt.FakeTable 'dbo.[Status]';
    EXEC tSQLt.FakeTable 'dbo.NhanVien';

    INSERT INTO dbo.[Status] (StatusID) VALUES ('AVAILABLE');
    INSERT INTO dbo.NhanVien (NhanVienID) VALUES (1);
    INSERT INTO dbo.BookItem (BookItemID, Price, StatusID) VALUES (100, 100000.00, 'BORROWED');
    INSERT INTO dbo.PhieuMuon (BorrowingID, SinhVienID) VALUES (10, 1);
    
    -- Due tomorrow, returned today -> On time
    INSERT INTO dbo.DongMuon (DongMuonID, BorrowingID, BookItemID, NgayHenTra) 
    VALUES (1, 10, 100, DATEADD(DAY, 1, CAST(GETDATE() AS DATE)));

    -- Act
    EXEC dbo.sp_LapPhieuTra @SinhVienID = 1, @NhanVienID = 1, @DongMuonID = 1, @NewBookStatus = 'AVAILABLE';

    -- Assert 1: Book status transitions back to AVAILABLE
    DECLARE @ActualStatus VARCHAR(20);
    SELECT @ActualStatus = StatusID FROM dbo.BookItem WHERE BookItemID = 100;
    EXEC tSQLt.AssertEqualsString 'AVAILABLE', @ActualStatus;

    -- Assert 2: Exactly 1 DongTra record created
    DECLARE @DongTraCount INT;
    SELECT @DongTraCount = COUNT(1) FROM dbo.DongTra WHERE DongMuonID = 1;
    EXEC tSQLt.AssertEquals 1, @DongTraCount;

    -- Assert 3: No penalty record generated
    DECLARE @FineCount INT;
    SELECT @FineCount = COUNT(1) FROM dbo.DongPhat WHERE DongMuonID = 1;
    EXEC tSQLt.AssertEquals 0, @FineCount;
END;
GO

-- =============================================================================
-- TEST 7: Overdue return by 3 days automatically calculates and writes late fine
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuTra.[test_ReturnSuccess_Overdue_GeneratesLateFineRecord]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.DongMuon';
    EXEC tSQLt.FakeTable 'dbo.PhieuMuon';
    EXEC tSQLt.FakeTable 'dbo.BookItem';
    EXEC tSQLt.FakeTable 'dbo.PhieuTra';
    EXEC tSQLt.FakeTable 'dbo.DongTra';
    EXEC tSQLt.FakeTable 'dbo.DongPhat';
    EXEC tSQLt.FakeTable 'dbo.[Status]';
    EXEC tSQLt.FakeTable 'dbo.NhanVien';
    EXEC tSQLt.FakeTable 'dbo.FineRule';

    INSERT INTO dbo.[Status] (StatusID) VALUES ('AVAILABLE');
    INSERT INTO dbo.NhanVien (NhanVienID) VALUES (1);
    INSERT INTO dbo.FineRule (RuleID, RuleCode, RatePerDay, FixedProcessingFee) 
    VALUES (1, 'LATE', 5000.00, 0.00);

    INSERT INTO dbo.BookItem (BookItemID, Price, StatusID) VALUES (100, 100000.00, 'BORROWED');
    INSERT INTO dbo.PhieuMuon (BorrowingID, SinhVienID) VALUES (10, 1);
    
    -- Due 3 days ago -> Overdue by 3 days (3 * 5,000 = 15,000)
    INSERT INTO dbo.DongMuon (DongMuonID, BorrowingID, BookItemID, NgayHenTra) 
    VALUES (1, 10, 100, DATEADD(DAY, -3, CAST(GETDATE() AS DATE)));

    -- Act
    EXEC dbo.sp_LapPhieuTra @SinhVienID = 1, @NhanVienID = 1, @DongMuonID = 1, @NewBookStatus = 'AVAILABLE';

    -- Assert: Verify overdue fine amount and status
    DECLARE @ActualFine DECIMAL(18, 2);
    DECLARE @FineStatus VARCHAR(20);
    SELECT @ActualFine = Amount, @FineStatus = Status 
    FROM dbo.DongPhat 
    WHERE DongMuonID = 1;

    EXEC tSQLt.AssertEquals 15000.00, @ActualFine;
    EXEC tSQLt.AssertEqualsString 'UNPAID', @FineStatus;
END;
GO

-- =============================================================================
-- TEST 8: Returning a damaged book triggers a damage penalty record
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuTra.[test_ReturnSuccess_DamagedBook_GeneratesDamageFineRecord]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.DongMuon';
    EXEC tSQLt.FakeTable 'dbo.PhieuMuon';
    EXEC tSQLt.FakeTable 'dbo.BookItem';
    EXEC tSQLt.FakeTable 'dbo.PhieuTra';
    EXEC tSQLt.FakeTable 'dbo.DongTra';
    EXEC tSQLt.FakeTable 'dbo.DongPhat';
    EXEC tSQLt.FakeTable 'dbo.[Status]';
    EXEC tSQLt.FakeTable 'dbo.NhanVien';
    EXEC tSQLt.FakeTable 'dbo.FineRule';

    INSERT INTO dbo.[Status] (StatusID) VALUES ('DAMAGED');
    INSERT INTO dbo.NhanVien (NhanVienID) VALUES (1);
    -- 20% default damage fee + 15,000 fixed handling fee
    INSERT INTO dbo.FineRule (RuleID, RuleCode, PercentOfBookValue, FixedProcessingFee) 
    VALUES (2, 'DAMAGED', 0.20, 15000.00);

    INSERT INTO dbo.BookItem (BookItemID, Price, StatusID) VALUES (100, 100000.00, 'BORROWED');
    INSERT INTO dbo.PhieuMuon (BorrowingID, SinhVienID) VALUES (10, 1);
    
    -- On-time return
    INSERT INTO dbo.DongMuon (DongMuonID, BorrowingID, BookItemID, NgayHenTra) 
    VALUES (1, 10, 100, DATEADD(DAY, 1, CAST(GETDATE() AS DATE)));

    -- Act: Returned damaged (Expected fine: 100,000 * 0.20 + 15,000 = 35,000)
    EXEC dbo.sp_LapPhieuTra @SinhVienID = 1, @NhanVienID = 1, @DongMuonID = 1, @NewBookStatus = 'DAMAGED';

    -- Assert
    DECLARE @ActualFine DECIMAL(18, 2);
    SELECT @ActualFine = Amount FROM dbo.DongPhat WHERE DongMuonID = 1;
    EXEC tSQLt.AssertEquals 35000.00, @ActualFine;

    DECLARE @ActualStatus VARCHAR(20);
    SELECT @ActualStatus = StatusID FROM dbo.BookItem WHERE BookItemID = 100;
    EXEC tSQLt.AssertEqualsString 'DAMAGED', @ActualStatus;
END;
GO

-- =============================================================================
-- TEST 9: Reporting a lost book triggers a full replacement penalty record
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuTra.[test_ReturnSuccess_LostBook_GeneratesLostFineRecord]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.DongMuon';
    EXEC tSQLt.FakeTable 'dbo.PhieuMuon';
    EXEC tSQLt.FakeTable 'dbo.BookItem';
    EXEC tSQLt.FakeTable 'dbo.PhieuTra';
    EXEC tSQLt.FakeTable 'dbo.DongTra';
    EXEC tSQLt.FakeTable 'dbo.DongPhat';
    EXEC tSQLt.FakeTable 'dbo.[Status]';
    EXEC tSQLt.FakeTable 'dbo.NhanVien';
    EXEC tSQLt.FakeTable 'dbo.FineRule';

    INSERT INTO dbo.[Status] (StatusID) VALUES ('LOST');
    INSERT INTO dbo.NhanVien (NhanVienID) VALUES (1);
    -- 100% price + 20,000 administrative fee
    INSERT INTO dbo.FineRule (RuleID, RuleCode, PercentOfBookValue, FixedProcessingFee) 
    VALUES (3, 'LOST', 1.00, 20000.00);

    INSERT INTO dbo.BookItem (BookItemID, Price, StatusID) VALUES (100, 100000.00, 'BORROWED');
    INSERT INTO dbo.PhieuMuon (BorrowingID, SinhVienID) VALUES (10, 1);
    
    INSERT INTO dbo.DongMuon (DongMuonID, BorrowingID, BookItemID, NgayHenTra) 
    VALUES (1, 10, 100, DATEADD(DAY, 1, CAST(GETDATE() AS DATE)));

    -- Act: Reported lost (Expected fine: 100,000 * 1.00 + 20,000 = 120,000)
    EXEC dbo.sp_LapPhieuTra @SinhVienID = 1, @NhanVienID = 1, @DongMuonID = 1, @NewBookStatus = 'LOST';

    -- Assert
    DECLARE @ActualFine DECIMAL(18, 2);
    SELECT @ActualFine = Amount FROM dbo.DongPhat WHERE DongMuonID = 1;
    EXEC tSQLt.AssertEquals 120000.00, @ActualFine;

    DECLARE @ActualStatus VARCHAR(20);
    SELECT @ActualStatus = StatusID FROM dbo.BookItem WHERE BookItemID = 100;
    EXEC tSQLt.AssertEqualsString 'LOST', @ActualStatus;
END;
GO

USE ThuVien2;
GO
EXEC tSQLt.Run 'test_circulation_LapPhieuTra';