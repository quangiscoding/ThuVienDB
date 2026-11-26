USE ThuVien2;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CreateLoanSlip
    @StudentCode VARCHAR(20),
    @StaffID     INT,
    @BookItemID  INT,
    @LoanDays    INT = 14
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- =========================================================================
    -- 1. PRE-VALIDATION
    -- =========================================================================
    IF @LoanDays IS NULL OR @LoanDays <= 0
    BEGIN
        THROW 50004, 'Loan duration must be greater than 0 days.', 1;
    END

    DECLARE @StudentID     INT,
            @StudentStatus VARCHAR(20);

    SELECT @StudentID     = StudentID,
           @StudentStatus = Status
    FROM dbo.Student
    WHERE StudentCode = @StudentCode;

    IF @StudentID IS NULL OR @StudentStatus <> 'ACTIVE'
    BEGIN
        THROW 50001, 'Student not found or account is not ACTIVE.', 1;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.Staff WHERE StaffID = @StaffID)
    BEGIN
        THROW 50001, 'Staff member not found.', 1;
    END

    -- Check unpaid or partial fines across BOTH ReturnItem (LATE/DAMAGED) and LoanItem (LOST) paths
    IF EXISTS (
        SELECT 1
        FROM dbo.FineItem fi
        LEFT JOIN dbo.ReturnItem ri ON fi.ReturnItemID = ri.ReturnItemID
        LEFT JOIN dbo.ReturnSlip rs ON ri.ReturnSlipID = rs.ReturnSlipID
        LEFT JOIN dbo.LoanItem   li ON fi.LoanItemID   = li.LoanItemID
        LEFT JOIN dbo.LoanSlip   ls ON li.LoanSlipID   = ls.LoanSlipID
        WHERE fi.Status IN ('UNPAID', 'PARTIAL')
          AND (rs.StudentID = @StudentID OR ls.StudentID = @StudentID)
    )
    BEGIN
        THROW 50002, 'Student has unpaid or partial fines. Please settle all fines before borrowing.', 1;
    END

    -- Check overdue unreturned books
    IF EXISTS (
        SELECT 1
        FROM dbo.LoanItem li
        INNER JOIN dbo.LoanSlip ls   ON li.LoanSlipID = ls.LoanSlipID
        LEFT  JOIN dbo.ReturnItem ri ON li.LoanItemID = ri.LoanItemID
        WHERE ls.StudentID = @StudentID
          AND ri.ReturnItemID IS NULL
          AND li.DueDate < CAST(GETDATE() AS DATE)
    )
    BEGIN
        THROW 50003, 'Student has overdue unreturned books.', 1;
    END

    -- Check max active borrow limit (3 books)
    DECLARE @CurrentlyBorrowedCount INT;
    SELECT @CurrentlyBorrowedCount = COUNT(li.LoanItemID)
    FROM dbo.LoanItem li
    INNER JOIN dbo.LoanSlip ls   ON li.LoanSlipID = ls.LoanSlipID
    LEFT  JOIN dbo.ReturnItem ri ON li.LoanItemID = ri.LoanItemID
    WHERE ls.StudentID = @StudentID
      AND ri.ReturnItemID IS NULL;

    IF @CurrentlyBorrowedCount >= 3
    BEGIN
        THROW 50004, 'Max borrow limit (3 active books) exceeded.', 1;
    END

    -- =========================================================================
    -- 2. ATOMIC MUTATION (nested-safe transaction)
    -- =========================================================================
    DECLARE @TranStarted BIT = 0;

    BEGIN TRY
        IF @@TRANCOUNT = 0
        BEGIN
            BEGIN TRANSACTION;
            SET @TranStarted = 1;
        END
        ELSE
        BEGIN
            SAVE TRANSACTION sp_CreateLoanSlip_Inner;
        END

        UPDATE dbo.BookItem
        SET StatusID = 'BORROWED'
        WHERE BookItemID = @BookItemID
          AND StatusID = 'AVAILABLE';

        IF @@ROWCOUNT = 0
        BEGIN
            THROW 50005, 'BookItem not found or is not AVAILABLE.', 1;
        END

        DECLARE @LoanSlipID INT,
                @LoanItemID INT,
                @Today      DATE = CAST(GETDATE() AS DATE);

        INSERT INTO dbo.LoanSlip (StudentID, StaffID, LoanDate)
        VALUES (@StudentID, @StaffID, @Today);

        SET @LoanSlipID = SCOPE_IDENTITY();

        INSERT INTO dbo.LoanItem (BookItemID, LoanSlipID, DueDate)
        VALUES (@BookItemID, @LoanSlipID, DATEADD(DAY, @LoanDays, @Today));

        SET @LoanItemID = SCOPE_IDENTITY();

        IF @TranStarted = 1
        BEGIN
            COMMIT TRANSACTION;
        END

        SELECT @LoanSlipID AS LoanSlipID,
               @LoanItemID AS LoanItemID,
               N'Loan slip created successfully.' AS Message;
    END TRY
    BEGIN CATCH
        IF @TranStarted = 1
        BEGIN
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;
        END
        ELSE
        BEGIN
            IF XACT_STATE() = 1
                ROLLBACK TRANSACTION sp_CreateLoanSlip_Inner;
        END;

        THROW;
    END CATCH
END;
GO
