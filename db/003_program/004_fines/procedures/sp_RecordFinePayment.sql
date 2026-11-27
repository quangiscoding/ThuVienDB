USE ThuVien2;
GO

CREATE OR ALTER PROCEDURE dbo.sp_RecordFinePayment
    @StudentID   INT,
    @StaffID     INT,
    @FineItemID  INT,
    @AmountPaid  DECIMAL(18, 2),
    @PaymentDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @PaymentDate IS NULL
        SET @PaymentDate = CAST(GETDATE() AS DATE);

    -- =========================================================================
    -- 1. PRE-VALIDATION
    -- =========================================================================
    IF NOT EXISTS (SELECT 1 FROM dbo.Student WHERE StudentID = @StudentID)
    BEGIN
        THROW 50001, 'Student not found.', 1;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.Staff WHERE StaffID = @StaffID)
    BEGIN
        THROW 50001, 'Staff member not found.', 1;
    END

    IF @AmountPaid IS NULL OR @AmountPaid <= 0
    BEGIN
        THROW 50007, 'Payment amount must be greater than 0.', 1;
    END

    DECLARE @FineAmount     DECIMAL(18, 2),
            @FineStatus     VARCHAR(20),
            @OwnerStudentID INT;

    SELECT @FineAmount     = fi.Amount,
           @FineStatus     = fi.Status,
           @OwnerStudentID = COALESCE(rs.StudentID, ls.StudentID)
    FROM dbo.FineItem fi
    LEFT JOIN dbo.ReturnItem ri ON fi.ReturnItemID = ri.ReturnItemID
    LEFT JOIN dbo.ReturnSlip rs ON ri.ReturnSlipID = rs.ReturnSlipID
    LEFT JOIN dbo.LoanItem   li ON fi.LoanItemID   = li.LoanItemID
    LEFT JOIN dbo.LoanSlip   ls ON li.LoanSlipID   = ls.LoanSlipID
    WHERE fi.FineItemID = @FineItemID;

    IF @FineAmount IS NULL
    BEGIN
        THROW 50007, 'FineItem not found.', 1;
    END

    IF @OwnerStudentID <> @StudentID
    BEGIN
        THROW 50007, 'FineItem does not belong to the specified student.', 1;
    END

    IF @FineStatus NOT IN ('UNPAID', 'PARTIAL')
    BEGIN
        THROW 50007, 'FineItem is already settled (PAID or WAIVED).', 1;
    END

    DECLARE @AlreadyPaid DECIMAL(18, 2);
    SELECT @AlreadyPaid = ISNULL(SUM(AmountPaid), 0.00)
    FROM dbo.PaymentItem
    WHERE FineItemID = @FineItemID;

    DECLARE @RemainingBalance DECIMAL(18, 2) = @FineAmount - @AlreadyPaid;

    IF @AmountPaid > @RemainingBalance
    BEGIN
        THROW 50007, 'Payment exceeds remaining fine balance.', 1;
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
            SAVE TRANSACTION sp_RecordFinePayment_Inner;
        END

        DECLARE @ReceiptID INT;
        INSERT INTO dbo.PaymentReceipt (StaffID, StudentID, PaymentDate, ReceiptType, Total)
        VALUES (@StaffID, @StudentID, @PaymentDate, 'PAYMENT', @AmountPaid);

        SET @ReceiptID = SCOPE_IDENTITY();

        INSERT INTO dbo.PaymentItem (ReceiptID, FineItemID, AmountPaid)
        VALUES (@ReceiptID, @FineItemID, @AmountPaid);

        DECLARE @NewStatus VARCHAR(20) =
            CASE WHEN @AmountPaid = @RemainingBalance THEN 'PAID' ELSE 'PARTIAL' END;

        UPDATE dbo.FineItem
        SET Status = @NewStatus
        WHERE FineItemID = @FineItemID;

        IF @TranStarted = 1
        BEGIN
            COMMIT TRANSACTION;
        END

        SELECT @ReceiptID AS ReceiptID,
               @FineItemID AS FineItemID,
               @AmountPaid AS AmountPaid,
               (@RemainingBalance - @AmountPaid) AS RemainingBalance,
               @NewStatus AS FineStatus,
               N'Fine payment recorded successfully.' AS Message;
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
                ROLLBACK TRANSACTION sp_RecordFinePayment_Inner;
        END;

        THROW;
    END CATCH
END;
GO
