USE ThuVien2;
SET NOCOUNT ON;

-- =============================================================================
-- AUTOMATED TEST SUITE: PROCEDURES (sp_LapPhieuTra)
-- File: db/tests/003_circulation/test_sp_LapPhieuTra.sql
-- =============================================================================

PRINT '=======================================================';
PRINT 'START TEST SUITE: sp_LapPhieuTra';
PRINT '=======================================================';

DECLARE @TotalTests INT = 0;
DECLARE @PassedTests INT = 0;
DECLARE @FailedTests INT = 0;

-- Ensure required status lookups exist
IF NOT EXISTS (SELECT 1 FROM Status WHERE StatusID = 'AVAILABLE')
    INSERT INTO Status (StatusID, StatusName) VALUES ('AVAILABLE', N'Available');
IF NOT EXISTS (SELECT 1 FROM Status WHERE StatusID = 'BORROWED')
    INSERT INTO Status (StatusID, StatusName) VALUES ('BORROWED', N'Borrowed');
IF NOT EXISTS (SELECT 1 FROM Status WHERE StatusID = 'DAMAGED')
    INSERT INTO Status (StatusID, StatusName) VALUES ('DAMAGED', N'Damaged');
IF NOT EXISTS (SELECT 1 FROM Status WHERE StatusID = 'LOST')
    INSERT INTO Status (StatusID, StatusName) VALUES ('LOST', N'Lost');

-- Ensure FineRule for late returns exists
IF NOT EXISTS (SELECT 1 FROM FineRule WHERE RatePerDay > 0)
BEGIN
    INSERT INTO FineRule (RuleName, RatePerDay, PercentOfBookValue, FixedProcessingFee)
    VALUES (N'[TEST] Phat tre han', 5000.00, NULL, 0.00);
END;

-- =============================================================================
-- TC1: Reject non-existent DongMuonID (Expect 51001)
-- =============================================================================
SET @TotalTests = @TotalTests + 1;
BEGIN TRANSACTION;
BEGIN TRY
    EXEC dbo.sp_LapPhieuTra 
        @SinhVienID = 'SV_NON_EXISTENT', 
        @DongMuonID = -9999;
    
    PRINT '[FAIL] TC1: Allowed return on non-existent DongMuonID';
    SET @FailedTests = @FailedTests + 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 51001 OR ERROR_MESSAGE() LIKE N'%không tồn tại%'
    BEGIN
        PRINT '[PASS] TC1: Blocked non-existent DongMuonID';
        SET @PassedTests = @PassedTests + 1;
    END
    ELSE
    BEGIN
        PRINT '[FAIL] TC1: Expected 51001 or missing error, got: ' + CAST(ERROR_NUMBER() AS VARCHAR) + ' - ' + ERROR_MESSAGE();
        SET @FailedTests = @FailedTests + 1;
    END
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

-- =============================================================================
-- TC2: Reject when SinhVienID does not match the loan owner (Expect 51002)
-- =============================================================================
SET @TotalTests = @TotalTests + 1;
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @StudentOwner_TC2 VARCHAR(20) = 'SV_OWNER_TC2';
    DECLARE @StudentWrong_TC2 VARCHAR(20) = 'SV_WRONG_TC2';

    INSERT INTO SinhVien (SinhVienID, HoTen) VALUES 
    (@StudentOwner_TC2, N'Student Owner'),
    (@StudentWrong_TC2, N'Student Impostor');

    DECLARE @TitleID_TC2 INT, @BookID_TC2 INT;
    INSERT INTO BookTitle (BookTitle) VALUES (N'Title TC2');
    SET @TitleID_TC2 = SCOPE_IDENTITY();

    INSERT INTO BookItem (TitleID, StatusID, Price) VALUES (@TitleID_TC2, 'BORROWED', 100000);
    SET @BookID_TC2 = SCOPE_IDENTITY();

    DECLARE @BorrowID_TC2 INT, @LineID_TC2 INT;
    INSERT INTO PhieuMuon (SinhVienID, NgayMuon) VALUES (@StudentOwner_TC2, CAST(GETDATE() AS DATE));
    SET @BorrowID_TC2 = SCOPE_IDENTITY();

    INSERT INTO DongMuon (BookItemID, BorrowingID, NgayHenTra) VALUES (@BookID_TC2, @BorrowID_TC2, DATEADD(DAY, 7, CAST(GETDATE() AS DATE)));
    SET @LineID_TC2 = SCOPE_IDENTITY();

    -- Act: Pass mismatched student ID
    EXEC dbo.sp_LapPhieuTra 
        @SinhVienID = @StudentWrong_TC2, 
        @DongMuonID = @LineID_TC2;

    PRINT '[FAIL] TC2: Allowed return by mismatched student ID';
    SET @FailedTests = @FailedTests + 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 51002 OR ERROR_MESSAGE() LIKE N'%không khớp%' OR ERROR_MESSAGE() LIKE N'%không thuộc%'
    BEGIN
        PRINT '[PASS] TC2: Blocked return by mismatched student ID';
        SET @PassedTests = @PassedTests + 1;
    END
    ELSE
    BEGIN
        PRINT '[FAIL] TC2: Expected 51002 or mismatch error, got: ' + CAST(ERROR_NUMBER() AS VARCHAR) + ' - ' + ERROR_MESSAGE();
        SET @FailedTests = @FailedTests + 1;
    END
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

-- =============================================================================
-- TC3: Reject duplicate return on already returned loan (Expect 51003)
-- =============================================================================
SET @TotalTests = @TotalTests + 1;
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @StudentID_TC3 VARCHAR(20) = 'SV_TRA_TC3';
    INSERT INTO SinhVien (SinhVienID, HoTen) VALUES (@StudentID_TC3, N'Student TC3');

    DECLARE @TitleID_TC3 INT, @BookID_TC3 INT;
    INSERT INTO BookTitle (BookTitle) VALUES (N'Title TC3');
    SET @TitleID_TC3 = SCOPE_IDENTITY();

    INSERT INTO BookItem (TitleID, StatusID, Price) VALUES (@TitleID_TC3, 'BORROWED', 100000);
    SET @BookID_TC3 = SCOPE_IDENTITY();

    DECLARE @BorrowID_TC3 INT, @LineID_TC3 INT;
    INSERT INTO PhieuMuon (SinhVienID, NgayMuon) VALUES (@StudentID_TC3, DATEADD(DAY, -5, CAST(GETDATE() AS DATE)));
    SET @BorrowID_TC3 = SCOPE_IDENTITY();

    INSERT INTO DongMuon (BookItemID, BorrowingID, NgayHenTra) VALUES (@BookID_TC3, @BorrowID_TC3, CAST(GETDATE() AS DATE));
    SET @LineID_TC3 = SCOPE_IDENTITY();

    -- First return: Valid
    EXEC dbo.sp_LapPhieuTra 
        @SinhVienID = @StudentID_TC3, 
        @DongMuonID = @LineID_TC3;

    -- Second return: Duplicate, must fail
    EXEC dbo.sp_LapPhieuTra 
        @SinhVienID = @StudentID_TC3, 
        @DongMuonID = @LineID_TC3;

    PRINT '[FAIL] TC3: Allowed double return of the same loan';
    SET @FailedTests = @FailedTests + 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 51003 OR ERROR_MESSAGE() LIKE N'%trước đó%'
    BEGIN
        PRINT '[PASS] TC3: Blocked duplicate return attempt';
        SET @PassedTests = @PassedTests + 1;
    END
    ELSE
    BEGIN
        PRINT '[FAIL] TC3: Expected 51003 or duplicate error, got: ' + CAST(ERROR_NUMBER() AS VARCHAR) + ' - ' + ERROR_MESSAGE();
        SET @FailedTests = @FailedTests + 1;
    END
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

-- =============================================================================
-- TC4: On-time return (Status reverted to AVAILABLE, NO penalty created)
-- =============================================================================
SET @TotalTests = @TotalTests + 1;
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @StudentID_TC4 VARCHAR(20) = 'SV_TRA_TC4';
    INSERT INTO SinhVien (SinhVienID, HoTen) VALUES (@StudentID_TC4, N'Student TC4');

    DECLARE @TitleID_TC4 INT, @BookID_TC4 INT;
    INSERT INTO BookTitle (BookTitle) VALUES (N'Title TC4');
    SET @TitleID_TC4 = SCOPE_IDENTITY();

    INSERT INTO BookItem (TitleID, StatusID, Price) VALUES (@TitleID_TC4, 'BORROWED', 100000);
    SET @BookID_TC4 = SCOPE_IDENTITY();

    DECLARE @BorrowID_TC4 INT, @LineID_TC4 INT;
    INSERT INTO PhieuMuon (SinhVienID, NgayMuon) VALUES (@StudentID_TC4, DATEADD(DAY, -5, CAST(GETDATE() AS DATE)));
    SET @BorrowID_TC4 = SCOPE_IDENTITY();

    -- Due date is today (on-time)
    INSERT INTO DongMuon (BookItemID, BorrowingID, NgayHenTra) VALUES (@BookID_TC4, @BorrowID_TC4, CAST(GETDATE() AS DATE));
    SET @LineID_TC4 = SCOPE_IDENTITY();

    -- Act: Return on time
    EXEC dbo.sp_LapPhieuTra 
        @SinhVienID = @StudentID_TC4, 
        @DongMuonID = @LineID_TC4,
        @NewBookStatus = 'AVAILABLE';

    -- Assert 1: BookItem reset to AVAILABLE
    IF NOT EXISTS (SELECT 1 FROM BookItem WHERE BookItemID = @BookID_TC4 AND StatusID = 'AVAILABLE')
        THROW 59201, 'BookItem status was not reset to AVAILABLE', 1;

    -- Assert 2: DongTra created
    DECLARE @DongTraID_TC4 INT;
    SELECT @DongTraID_TC4 = DongTraID FROM DongTra WHERE DongMuonID = @LineID_TC4;
    IF @DongTraID_TC4 IS NULL
        THROW 59202, 'DongTra record was not created', 1;

    -- Assert 3: No DongPhat generated
    IF EXISTS (SELECT 1 FROM DongPhat WHERE DongTraID = @DongTraID_TC4)
        THROW 59203, 'DongPhat record was unexpectedly created for on-time return', 1;

    PRINT '[PASS] TC4: On-time return verified (Status = AVAILABLE, 0 fines)';
    SET @PassedTests = @PassedTests + 1;
END TRY
BEGIN CATCH
    PRINT '[FAIL] TC4: ' + ERROR_MESSAGE();
    SET @FailedTests = @FailedTests + 1;
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

-- =============================================================================
-- TC5: Overdue return (Generates Late Fine in DongPhat)
-- =============================================================================
SET @TotalTests = @TotalTests + 1;
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @LateRuleID_TC5 INT;
    SELECT TOP 1 @LateRuleID_TC5 = RuleID FROM FineRule WHERE RatePerDay > 0 ORDER BY RuleID ASC;

    DECLARE @StudentID_TC5 VARCHAR(20) = 'SV_TRA_TC5';
    INSERT INTO SinhVien (SinhVienID, HoTen) VALUES (@StudentID_TC5, N'Student TC5');

    DECLARE @TitleID_TC5 INT, @BookID_TC5 INT;
    INSERT INTO BookTitle (BookTitle) VALUES (N'Title TC5');
    SET @TitleID_TC5 = SCOPE_IDENTITY();

    INSERT INTO BookItem (TitleID, StatusID, Price) VALUES (@TitleID_TC5, 'BORROWED', 100000);
    SET @BookID_TC5 = SCOPE_IDENTITY();

    DECLARE @BorrowID_TC5 INT, @LineID_TC5 INT;
    INSERT INTO PhieuMuon (SinhVienID, NgayMuon) VALUES (@StudentID_TC5, DATEADD(DAY, -15, CAST(GETDATE() AS DATE)));
    SET @BorrowID_TC5 = SCOPE_IDENTITY();

    -- Due date: 5 days ago -> 5 days overdue
    DECLARE @HenTra_TC5 DATE = DATEADD(DAY, -5, CAST(GETDATE() AS DATE));
    INSERT INTO DongMuon (BookItemID, BorrowingID, NgayHenTra) VALUES (@BookID_TC5, @BorrowID_TC5, @HenTra_TC5);
    SET @LineID_TC5 = SCOPE_IDENTITY();

    -- Act: Return today (overdue)
    EXEC dbo.sp_LapPhieuTra 
        @SinhVienID = @StudentID_TC5, 
        @DongMuonID = @LineID_TC5,
        @NewBookStatus = 'AVAILABLE';

    -- Assert DongPhat created with UNPAID status
    DECLARE @DongTraID_TC5 INT;
    SELECT @DongTraID_TC5 = DongTraID FROM DongTra WHERE DongMuonID = @LineID_TC5;

    IF NOT EXISTS (
        SELECT 1 FROM DongPhat 
        WHERE DongTraID = @DongTraID_TC5 
          AND Amount > 0 
          AND Status = 'UNPAID'
    )
        THROW 59204, 'DongPhat late fine record missing or status not UNPAID', 1;

    PRINT '[PASS] TC5: Overdue return verified (Generated UNPAID fine in DongPhat)';
    SET @PassedTests = @PassedTests + 1;
END TRY
BEGIN CATCH
    PRINT '[FAIL] TC5: ' + ERROR_MESSAGE();
    SET @FailedTests = @FailedTests + 1;
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

-- =============================================================================
-- SUMMARY
-- =============================================================================
PRINT '-------------------------------------------------------';
PRINT 'RESULT: ' + CAST(@PassedTests AS VARCHAR) + '/' + CAST(@TotalTests AS VARCHAR) + ' PASSED | ' + CAST(@FailedTests AS VARCHAR) + ' FAILED';
PRINT '-------------------------------------------------------';

IF @FailedTests > 0
BEGIN
    RAISERROR('Test suite sp_LapPhieuTra encountered failures!', 16, 1);
END;