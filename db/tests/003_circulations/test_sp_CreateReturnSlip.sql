USE ThuVien2;
GO

SET NOCOUNT ON;

-- =============================================================================
-- TEST 1: Fails when LoanItemID does not exist (50006)
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @StaffID INT = (SELECT TOP 1 StaffID FROM dbo.Staff ORDER BY StaffID);
    EXEC dbo.sp_CreateReturnSlip @StudentID = 1, @StaffID = @StaffID, @LoanItemID = 999999;
    ROLLBACK TRANSACTION;
    THROW 51001, 'TEST 1 FAILED: Expected error 50006 for missing LoanItemID.', 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() <> 50006
        THROW;
    PRINT 'TEST 1 PASS: Missing LoanItemID blocked (50006).';
END CATCH;
GO

-- =============================================================================
-- TEST 2: Fails when LoanItem belongs to another student (50006)
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @StaffID INT = (SELECT TOP 1 StaffID FROM dbo.Staff ORDER BY StaffID);
    -- LoanItemID=2 belongs to Student 3
    EXEC dbo.sp_CreateReturnSlip @StudentID = 1, @StaffID = @StaffID, @LoanItemID = 2;
    ROLLBACK TRANSACTION;
    THROW 51002, 'TEST 2 FAILED: Expected error 50006 for student mismatch.', 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() <> 50006
        THROW;
    PRINT 'TEST 2 PASS: Student mismatch blocked (50006).';
END CATCH;
GO

-- =============================================================================
-- TEST 3: Fails when LoanItem is already returned (50006)
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @StaffID INT = (SELECT TOP 1 StaffID FROM dbo.Staff ORDER BY StaffID);
    -- LoanItemID=1 is already in ReturnItem
    EXEC dbo.sp_CreateReturnSlip @StudentID = 1, @StaffID = @StaffID, @LoanItemID = 1;
    ROLLBACK TRANSACTION;
    THROW 51003, 'TEST 3 FAILED: Expected error 50006 for already-returned LoanItem.', 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() <> 50006
        THROW;
    PRINT 'TEST 3 PASS: Already-returned LoanItem blocked (50006).';
END CATCH;
GO

-- =============================================================================
-- TEST 4: On-time return restores BookItem to AVAILABLE with no FineItem
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @StaffID INT = (SELECT TOP 1 StaffID FROM dbo.Staff ORDER BY StaffID);
    -- LoanItemID=2 belongs to Student 3, DueDate is +11 days, BookItemID=4
    EXEC dbo.sp_CreateReturnSlip @StudentID = 3, @StaffID = @StaffID, @LoanItemID = 2, @NewBookStatus = 'AVAILABLE';

    IF (SELECT StatusID FROM dbo.BookItem WHERE BookItemID = 4) <> 'AVAILABLE'
        THROW 51004, 'TEST 4 FAILED: BookItem status not restored to AVAILABLE.', 1;

    DECLARE @ReturnItemID INT = (SELECT ReturnItemID FROM dbo.ReturnItem WHERE LoanItemID = 2);
    IF EXISTS (SELECT 1 FROM dbo.FineItem WHERE ReturnItemID = @ReturnItemID OR LoanItemID = 2)
        THROW 51005, 'TEST 4 FAILED: Unexpected FineItem created for on-time return.', 1;

    ROLLBACK TRANSACTION;
    PRINT 'TEST 4 PASS: On-time return restores AVAILABLE with no fine.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- =============================================================================
-- TEST 5: Overdue return creates LATE fine linked to ReturnItemID only (XOR check)
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @StaffID INT = (SELECT TOP 1 StaffID FROM dbo.Staff ORDER BY StaffID);
    -- LoanItemID=3 belongs to Student 2, DueDate is -6 days (6 * 5,000 = 30,000)
    EXEC dbo.sp_CreateReturnSlip @StudentID = 2, @StaffID = @StaffID, @LoanItemID = 3, @NewBookStatus = 'AVAILABLE';

    DECLARE @ReturnItemID INT = (SELECT ReturnItemID FROM dbo.ReturnItem WHERE LoanItemID = 3);
    DECLARE @FineAmt DECIMAL(18, 2), @LinkedLoanItemID INT;
    SELECT @FineAmt = Amount, @LinkedLoanItemID = LoanItemID
    FROM dbo.FineItem
    WHERE ReturnItemID = @ReturnItemID;

    IF @FineAmt <> 30000.00 OR @LinkedLoanItemID IS NOT NULL
        THROW 51006, 'TEST 5 FAILED: LATE fine amount or CK_FineItem_Link XOR incorrect.', 1;

    ROLLBACK TRANSACTION;
    PRINT 'TEST 5 PASS: Overdue return creates LATE fine (30,000) linked to ReturnItemID only.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- =============================================================================
-- TEST 6: Damaged return with @CustomDamagePercent=0.50 links to ReturnItemID only
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @StaffID INT = (SELECT TOP 1 StaffID FROM dbo.Staff ORDER BY StaffID);
    -- LoanItemID=2 (Student 3, BookItemID=4, Price=250,000): 50% * 250,000 + 15,000 = 140,000
    EXEC dbo.sp_CreateReturnSlip
        @StudentID = 3,
        @StaffID = @StaffID,
        @LoanItemID = 2,
        @NewBookStatus = 'DAMAGED',
        @CustomDamagePercent = 0.50;

    DECLARE @ReturnItemID INT = (SELECT ReturnItemID FROM dbo.ReturnItem WHERE LoanItemID = 2);
    DECLARE @FineAmt DECIMAL(18, 2), @LinkedLoanItemID INT;
    SELECT @FineAmt = Amount, @LinkedLoanItemID = LoanItemID
    FROM dbo.FineItem
    WHERE ReturnItemID = @ReturnItemID;

    IF @FineAmt <> 140000.00 OR @LinkedLoanItemID IS NOT NULL
        THROW 51007, 'TEST 6 FAILED: DAMAGED fine amount or XOR link incorrect.', 1;

    IF (SELECT StatusID FROM dbo.BookItem WHERE BookItemID = 4) <> 'DAMAGED'
        THROW 51008, 'TEST 6 FAILED: BookItem status not updated to DAMAGED.', 1;

    ROLLBACK TRANSACTION;
    PRINT 'TEST 6 PASS: Damaged return with custom 50% creates 140,000 fine linked to ReturnItemID only.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- =============================================================================
-- TEST 7: LOST book return links fine to LoanItemID only (ReturnItemID IS NULL)
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @StaffID INT = (SELECT TOP 1 StaffID FROM dbo.Staff ORDER BY StaffID);
    -- LoanItemID=2 (Student 3, BookItemID=4, Price=250,000): 100% * 250,000 + 20,000 = 270,000
    EXEC dbo.sp_CreateReturnSlip
        @StudentID = 3,
        @StaffID = @StaffID,
        @LoanItemID = 2,
        @NewBookStatus = 'LOST';

    DECLARE @FineAmt DECIMAL(18, 2), @LinkedReturnItemID INT;
    SELECT @FineAmt = Amount, @LinkedReturnItemID = ReturnItemID
    FROM dbo.FineItem
    WHERE LoanItemID = 2;

    IF @FineAmt <> 270000.00 OR @LinkedReturnItemID IS NOT NULL
        THROW 51009, 'TEST 7 FAILED: LOST fine amount or CK_FineItem_Link XOR incorrect.', 1;

    IF (SELECT StatusID FROM dbo.BookItem WHERE BookItemID = 4) <> 'LOST'
        THROW 51010, 'TEST 7 FAILED: BookItem status not updated to LOST.', 1;

    ROLLBACK TRANSACTION;
    PRINT 'TEST 7 PASS: LOST book return creates 270,000 fine linked to LoanItemID only.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
