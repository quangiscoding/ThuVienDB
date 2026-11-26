USE ThuVien2;
GO

CREATE OR ALTER PROCEDURE dbo.sp_UpdateCopyStatus
    @BookItemID  INT,
    @NewStatusID VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- =========================================================================
    -- 1. PRE-VALIDATION
    -- =========================================================================
    IF NOT EXISTS (SELECT 1 FROM dbo.BookItem WHERE BookItemID = @BookItemID)
    BEGIN
        THROW 50005, 'BookItem not found.', 1;
    END

    IF @NewStatusID NOT IN ('AVAILABLE', 'DAMAGED', 'LOST')
       OR NOT EXISTS (SELECT 1 FROM dbo.[Status] WHERE StatusID = @NewStatusID)
    BEGIN
        THROW 50005, 'Invalid administrative status. Allowed values: AVAILABLE, DAMAGED, LOST.', 1;
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
            SAVE TRANSACTION sp_UpdateCopyStatus_Inner;
        END

        UPDATE dbo.BookItem
        SET StatusID = @NewStatusID
        WHERE BookItemID = @BookItemID;

        IF @TranStarted = 1
        BEGIN
            COMMIT TRANSACTION;
        END

        SELECT @BookItemID  AS BookItemID,
               @NewStatusID AS StatusID,
               N'BookItem status updated successfully.' AS Message;
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
                ROLLBACK TRANSACTION sp_UpdateCopyStatus_Inner;
        END;

        THROW;
    END CATCH
END;
GO
