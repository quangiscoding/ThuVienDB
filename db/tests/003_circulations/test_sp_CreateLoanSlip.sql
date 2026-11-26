USE ThuVien2;
GO

SET NOCOUNT ON;

DECLARE @StaffID INT = (SELECT TOP 1 StaffID FROM dbo.Staff ORDER BY StaffID);
DECLARE @AvailBookID INT = (SELECT TOP 1 BookItemID FROM dbo.BookItem WHERE StatusID = 'AVAILABLE' ORDER BY BookItemID);
DECLARE @BorrowedBookID INT = (SELECT TOP 1 BookItemID FROM dbo.BookItem WHERE StatusID = 'BORROWED' ORDER BY BookItemID);

-- =============================================================================
-- TEST 1: Fails when StudentCode does not exist (50001)
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    EXEC dbo.sp_CreateLoanSlip @StudentCode = 'NON_EXISTENT', @StaffID = @StaffID, @BookItemID = @AvailBookID;
    ROLLBACK TRANSACTION;
    THROW 51001, 'TEST 1 FAILED: Expected error 50001 for non-existent student.', 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() <> 50001
        THROW;
    PRINT 'TEST 1 PASS: Non-existent student blocked (50001).';
END CATCH;
GO

-- =============================================================================
-- TEST 2: Fails when Student.Status is SUSPENDED or EXPIRED (50001)
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @StaffID INT = (SELECT TOP 1 StaffID FROM dbo.Staff ORDER BY StaffID);
    DECLARE @AvailBookID INT = (SELECT TOP 1 BookItemID FROM dbo.BookItem WHERE StatusID = 'AVAILABLE' ORDER BY BookItemID);
    DECLARE @SuspendedCode VARCHAR(20) = (SELECT TOP 1 StudentCode FROM dbo.Student WHERE Status = 'SUSPENDED');

    EXEC dbo.sp_CreateLoanSlip @StudentCode = @SuspendedCode, @StaffID = @StaffID, @BookItemID = @AvailBookID;
    ROLLBACK TRANSACTION;
    THROW 51002, 'TEST 2 FAILED: Expected error 50001 for SUSPENDED student.', 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() <> 50001
        THROW;
    PRINT 'TEST 2 PASS: SUSPENDED student blocked (50001).';
END CATCH;
GO

-- =============================================================================
-- TEST 3: Fails when Student has UNPAID or PARTIAL (including LOST) fines (50002)
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @StaffID INT = (SELECT TOP 1 StaffID FROM dbo.Staff ORDER BY StaffID);
    DECLARE @AvailBookID INT = (SELECT TOP 1 BookItemID FROM dbo.BookItem WHERE StatusID = 'AVAILABLE' ORDER BY BookItemID);

    -- Student 2 ('29210252480') has PARTIAL LOST fine (LoanItemID=4) and UNPAID LATE fine
    EXEC dbo.sp_CreateLoanSlip @StudentCode = '29210252480', @StaffID = @StaffID, @BookItemID = @AvailBookID;
    ROLLBACK TRANSACTION;
    THROW 51003, 'TEST 3 FAILED: Expected error 50002 for student with unpaid/partial fines.', 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() <> 50002
        THROW;
    PRINT 'TEST 3 PASS: Student with unpaid/partial fines blocked (50002).';
END CATCH;
GO

-- =============================================================================
-- TEST 4: Fails when Student has overdue unreturned books (50003)
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @StaffID INT = (SELECT TOP 1 StaffID FROM dbo.Staff ORDER BY StaffID);
    DECLARE @AvailBookID INT = (SELECT TOP 1 BookItemID FROM dbo.BookItem WHERE StatusID = 'AVAILABLE' ORDER BY BookItemID);

    -- Give Student 1 ('29210252479', no unpaid fines) an overdue unreturned loan
    DECLARE @Stu1ID INT = (SELECT StudentID FROM dbo.Student WHERE StudentCode = '29210252479');
    INSERT INTO dbo.LoanSlip (StudentID, StaffID, LoanDate) VALUES (@Stu1ID, @StaffID, DATEADD(DAY, -20, CAST(GETDATE() AS DATE)));
    DECLARE @LSID INT = SCOPE_IDENTITY();
    INSERT INTO dbo.LoanItem (BookItemID, LoanSlipID, DueDate) VALUES (@AvailBookID, @LSID, DATEADD(DAY, -2, CAST(GETDATE() AS DATE)));

    DECLARE @AvailBookID2 INT = (SELECT TOP 1 BookItemID FROM dbo.BookItem WHERE StatusID = 'AVAILABLE' AND BookItemID <> @AvailBookID ORDER BY BookItemID);
    EXEC dbo.sp_CreateLoanSlip @StudentCode = '29210252479', @StaffID = @StaffID, @BookItemID = @AvailBookID2;
    ROLLBACK TRANSACTION;
    THROW 51004, 'TEST 4 FAILED: Expected error 50003 for student with overdue books.', 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() <> 50003
        THROW;
    PRINT 'TEST 4 PASS: Student with overdue unreturned books blocked (50003).';
END CATCH;
GO

-- =============================================================================
-- TEST 5: Fails when Student reaches 3-book active borrow limit (50004)
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @StaffID INT = (SELECT TOP 1 StaffID FROM dbo.Staff ORDER BY StaffID);
    DECLARE @Stu1ID INT = (SELECT StudentID FROM dbo.Student WHERE StudentCode = '29210252479');

    -- Borrow 3 available books for Student 1
    DECLARE @B1 INT, @B2 INT, @B3 INT, @B4 INT;
    SELECT @B1 = MIN(BookItemID) FROM dbo.BookItem WHERE StatusID = 'AVAILABLE';
    SELECT @B2 = MIN(BookItemID) FROM dbo.BookItem WHERE StatusID = 'AVAILABLE' AND BookItemID > @B1;
    SELECT @B3 = MIN(BookItemID) FROM dbo.BookItem WHERE StatusID = 'AVAILABLE' AND BookItemID > @B2;
    SELECT @B4 = MIN(BookItemID) FROM dbo.BookItem WHERE StatusID = 'AVAILABLE' AND BookItemID > @B3;

    EXEC dbo.sp_CreateLoanSlip @StudentCode = '29210252479', @StaffID = @StaffID, @BookItemID = @B1;
    EXEC dbo.sp_CreateLoanSlip @StudentCode = '29210252479', @StaffID = @StaffID, @BookItemID = @B2;
    EXEC dbo.sp_CreateLoanSlip @StudentCode = '29210252479', @StaffID = @StaffID, @BookItemID = @B3;

    -- 4th borrow must fail with 50004
    EXEC dbo.sp_CreateLoanSlip @StudentCode = '29210252479', @StaffID = @StaffID, @BookItemID = @B4;
    ROLLBACK TRANSACTION;
    THROW 51005, 'TEST 5 FAILED: Expected error 50004 for 3-book borrow limit.', 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() <> 50004
        THROW;
    PRINT 'TEST 5 PASS: 3-book borrow limit enforced (50004).';
END CATCH;
GO

-- =============================================================================
-- TEST 6: Fails when BookItem is not AVAILABLE (50005)
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @StaffID INT = (SELECT TOP 1 StaffID FROM dbo.Staff ORDER BY StaffID);
    DECLARE @BorrowedBookID INT = (SELECT TOP 1 BookItemID FROM dbo.BookItem WHERE StatusID = 'BORROWED' ORDER BY BookItemID);

    EXEC dbo.sp_CreateLoanSlip @StudentCode = '29210252479', @StaffID = @StaffID, @BookItemID = @BorrowedBookID;
    ROLLBACK TRANSACTION;
    THROW 51006, 'TEST 6 FAILED: Expected error 50005 for non-AVAILABLE BookItem.', 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() <> 50005
        THROW;
    PRINT 'TEST 6 PASS: Non-AVAILABLE BookItem blocked (50005).';
END CATCH;
GO

-- =============================================================================
-- TEST 7: Happy Path - Creates LoanSlip, LoanItem (14-day default), and sets BORROWED
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @StaffID INT = (SELECT TOP 1 StaffID FROM dbo.Staff ORDER BY StaffID);
    DECLARE @AvailBookID INT = (SELECT TOP 1 BookItemID FROM dbo.BookItem WHERE StatusID = 'AVAILABLE' ORDER BY BookItemID);

    EXEC dbo.sp_CreateLoanSlip @StudentCode = '29210252479', @StaffID = @StaffID, @BookItemID = @AvailBookID;

    DECLARE @NewStatus VARCHAR(20) = (SELECT StatusID FROM dbo.BookItem WHERE BookItemID = @AvailBookID);
    IF @NewStatus <> 'BORROWED'
        THROW 51007, 'TEST 7 FAILED: BookItem StatusID did not change to BORROWED.', 1;

    DECLARE @DueDate DATE = (SELECT TOP 1 DueDate FROM dbo.LoanItem WHERE BookItemID = @AvailBookID ORDER BY LoanItemID DESC);
    IF @DueDate <> DATEADD(DAY, 14, CAST(GETDATE() AS DATE))
        THROW 51008, 'TEST 7 FAILED: Default DueDate is not 14 days from today.', 1;

    ROLLBACK TRANSACTION;
    PRINT 'TEST 7 PASS: Happy path LoanSlip created with 14-day DueDate and BORROWED status.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
