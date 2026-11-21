USE ThuVien2;
GO

-- 1. Initialize Test Class
EXEC tSQLt.NewTestClass 'test_circulation_LapPhieuMuon';
GO

-- =============================================================================
-- TEST 1: Block when student code does not exist
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuMuon.[test_BorrowFails_WhenStudentDoesNotExist]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.SinhVien';
    EXEC tSQLt.FakeTable 'dbo.BookItem';

    EXEC tSQLt.ExpectException @ExpectedMessagePattern = N'%không tồn tại%';

    EXEC dbo.sp_LapPhieuMuon @MaSinhVien = 'SV_NON_EXISTENT', @BookItemID = 1, @SoNgayMuon = 7;
END;
GO

-- =============================================================================
-- TEST 2: Block when student has unpaid penalty records
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuMuon.[test_BorrowFails_WhenStudentHasUnpaidFines]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.SinhVien';
    EXEC tSQLt.FakeTable 'dbo.PhieuTra';
    EXEC tSQLt.FakeTable 'dbo.DongTra';
    EXEC tSQLt.FakeTable 'dbo.DongPhat';
    EXEC tSQLt.FakeTable 'dbo.BookItem';

    INSERT INTO dbo.SinhVien (SinhVienID, MaSinhVien, HoTen) VALUES (1, 'SV001', N'Nguyễn Văn A');
    INSERT INTO dbo.PhieuTra (PhieuTraID, SinhVienID) VALUES (10, 1);
    INSERT INTO dbo.DongTra (DongTraID, PhieuTraID) VALUES (100, 10);
    INSERT INTO dbo.DongPhat (DongTraID, Status) VALUES (100, 'UNPAID');

    EXEC tSQLt.ExpectException @ExpectedMessagePattern = N'%khoản phạt chưa đóng%';

    EXEC dbo.sp_LapPhieuMuon @MaSinhVien = 'SV001', @BookItemID = 1, @SoNgayMuon = 7;
END;
GO

-- =============================================================================
-- TEST 3: Block when student holds overdue loans
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuMuon.[test_BorrowFails_WhenStudentHasOverdueBooks]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.SinhVien';
    EXEC tSQLt.FakeTable 'dbo.PhieuMuon';
    EXEC tSQLt.FakeTable 'dbo.DongMuon';
    EXEC tSQLt.FakeTable 'dbo.DongTra';
    EXEC tSQLt.FakeTable 'dbo.DongPhat';
    EXEC tSQLt.FakeTable 'dbo.BookItem';

    INSERT INTO dbo.SinhVien (SinhVienID, MaSinhVien, HoTen) VALUES (1, 'SV001', N'Nguyễn Văn A');
    INSERT INTO dbo.PhieuMuon (BorrowingID, SinhVienID) VALUES (10, 1);
    
    -- Due date set to 3 days ago (overdue, no return record)
    INSERT INTO dbo.DongMuon (DongMuonID, BorrowingID, BookItemID, NgayHenTra)
    VALUES (101, 10, 999, DATEADD(DAY, -3, CAST(GETDATE() AS DATE)));

    EXEC tSQLt.ExpectException @ExpectedMessagePattern = N'%quá hạn chưa trả%';

    EXEC dbo.sp_LapPhieuMuon @MaSinhVien = 'SV001', @BookItemID = 1, @SoNgayMuon = 7;
END;
GO

-- =============================================================================
-- TEST 4: Block when active borrowing quota of 5 books is reached
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuMuon.[test_BorrowFails_WhenQuotaLimitExceeded]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.SinhVien';
    EXEC tSQLt.FakeTable 'dbo.PhieuMuon';
    EXEC tSQLt.FakeTable 'dbo.DongMuon';
    EXEC tSQLt.FakeTable 'dbo.DongTra';
    EXEC tSQLt.FakeTable 'dbo.DongPhat';
    EXEC tSQLt.FakeTable 'dbo.BookItem';

    INSERT INTO dbo.SinhVien (SinhVienID, MaSinhVien, HoTen) VALUES (1, 'SV001', N'Nguyễn Văn A');
    INSERT INTO dbo.PhieuMuon (BorrowingID, SinhVienID) VALUES (10, 1);

    -- 5 active items within due date
    INSERT INTO dbo.DongMuon (DongMuonID, BorrowingID, BookItemID, NgayHenTra)
    VALUES 
        (1, 10, 101, DATEADD(DAY, 5, CAST(GETDATE() AS DATE))),
        (2, 10, 102, DATEADD(DAY, 5, CAST(GETDATE() AS DATE))),
        (3, 10, 103, DATEADD(DAY, 5, CAST(GETDATE() AS DATE))),
        (4, 10, 104, DATEADD(DAY, 5, CAST(GETDATE() AS DATE))),
        (5, 10, 105, DATEADD(DAY, 5, CAST(GETDATE() AS DATE)));

    EXEC tSQLt.ExpectException @ExpectedMessagePattern = N'%tối đa (5 cuốn)%';

    EXEC dbo.sp_LapPhieuMuon @MaSinhVien = 'SV001', @BookItemID = 106, @SoNgayMuon = 7;
END;
GO

-- =============================================================================
-- TEST 5: Block when copy status is not AVAILABLE
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuMuon.[test_BorrowFails_WhenBookStatusNotAvailable]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.SinhVien';
    EXEC tSQLt.FakeTable 'dbo.PhieuMuon';
    EXEC tSQLt.FakeTable 'dbo.DongMuon';
    EXEC tSQLt.FakeTable 'dbo.DongTra';
    EXEC tSQLt.FakeTable 'dbo.DongPhat';
    EXEC tSQLt.FakeTable 'dbo.BookItem';

    INSERT INTO dbo.SinhVien (SinhVienID, MaSinhVien, HoTen) VALUES (1, 'SV001', N'Nguyễn Văn A');
    INSERT INTO dbo.BookItem (BookItemID, StatusID) VALUES (200, 'BORROWED');

    EXEC tSQLt.ExpectException @ExpectedMessagePattern = N'%AVAILABLE%';

    EXEC dbo.sp_LapPhieuMuon @MaSinhVien = 'SV001', @BookItemID = 200, @SoNgayMuon = 7;
END;
GO

-- =============================================================================
-- TEST 6: Happy Path -> Verify item status change and loan line insertion
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuMuon.[test_BorrowSuccess_UpdatesBookStatusToBorrowedAndInsertsLoanRecord]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.SinhVien';
    EXEC tSQLt.FakeTable 'dbo.PhieuMuon';
    EXEC tSQLt.FakeTable 'dbo.DongMuon';
    EXEC tSQLt.FakeTable 'dbo.DongTra';
    EXEC tSQLt.FakeTable 'dbo.DongPhat';
    EXEC tSQLt.FakeTable 'dbo.BookItem';

    INSERT INTO dbo.SinhVien (SinhVienID, MaSinhVien, HoTen) VALUES (1, 'SV001', N'Nguyễn Văn A');
    INSERT INTO dbo.BookItem (BookItemID, StatusID) VALUES (300, 'AVAILABLE');

    -- Act
    EXEC dbo.sp_LapPhieuMuon @MaSinhVien = 'SV001', @BookItemID = 300, @SoNgayMuon = 7;

    -- Assert 1: Book status changed to BORROWED
    DECLARE @ActualBookStatus VARCHAR(20);
    SELECT @ActualBookStatus = StatusID FROM dbo.BookItem WHERE BookItemID = 300;
    EXEC tSQLt.AssertEqualsString 'BORROWED', @ActualBookStatus;

    -- Assert 2: Exactly 1 loan item record created for BookItemID 300
    DECLARE @DongMuonCount INT;
    SELECT @DongMuonCount = COUNT(1) FROM dbo.DongMuon WHERE BookItemID = 300;
    EXEC tSQLt.AssertEquals 1, @DongMuonCount;
END;
GO

USE ThuVien2;
GO
EXEC tSQLt.Run 'test_circulation_LapPhieuMuon';