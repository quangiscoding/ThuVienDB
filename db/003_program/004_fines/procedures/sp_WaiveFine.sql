USE ThuVien2;
GO

CREATE OR ALTER PROCEDURE dbo.sp_WaiveFine
    @FineItemID  INT,
    @StaffID     INT,
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
    DECLARE @StaffRole VARCHAR(20);
    SELECT @StaffRole = RoleID
    FROM dbo.Staff
    WHERE StaffID = @StaffID;

    IF @StaffRole IS NULL
    BEGIN
        THROW 50001, 'Staff member not found.', 1;
    END

    IF @StaffRole <> 'ADMIN'
    BEGIN
        THROW 50020, 'Only ADMIN staff can waive fines.', 1;
    END

    DECLARE @FineAmount DECIMAL(18, 2),
            @FineStatus VARCHAR(20),
            @StudentID  INT;

    SELECT @FineAmount = fi.Amount,
           @FineStatus = fi.Status,
           @StudentID  = COALESCE(rs.StudentID, ls.StudentID)
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

    IF @FineStatus NOT IN ('UNPAID', 'PARTIAL')
    BEGIN
        THROW 50007, 'FineItem is already settled (PAID or WAIVED).', 1;
    END

    DECLARE @AlreadyPaid DECIMAL(18, 2);
    SELECT @AlreadyPaid = ISNULL(SUM(AmountPaid), 0.00)
    FROM dbo.PaymentItem
    WHERE FineItemID = @FineItemID;

    DECLARE @RemainingBalance DECIMAL(18, 2) = @FineAmount - @AlreadyPaid;

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
            SAVE TRANSACTION sp_WaiveFine_Inner;
        END

        DECLARE @ReceiptID INT;
        INSERT INTO dbo.PaymentReceipt (StaffID, StudentID, PaymentDate, ReceiptType, Total)
        VALUES (@StaffID, @StudentID, @PaymentDate, 'WAIVER', @RemainingBalance);

        SET @ReceiptID = SCOPE_IDENTITY();

        INSERT INTO dbo.PaymentItem (ReceiptID, FineItemID, AmountPaid)
        VALUES (@ReceiptID, @FineItemID, @RemainingBalance);

        UPDATE dbo.FineItem
        SET Status = 'WAIVED'
        WHERE FineItemID = @FineItemID;

        IF @TranStarted = 1
        BEGIN
            COMMIT TRANSACTION;
        END

        SELECT @ReceiptID AS ReceiptID,
               @FineItemID AS FineItemID,
               @RemainingBalance AS WaivedAmount,
               'WAIVED' AS FineStatus,
               N'Fine waived successfully.' AS Message;
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
                ROLLBACK TRANSACTION sp_WaiveFine_Inner;
        END;

        THROW;
    END CATCH
END;
GO
