USE ThuVien2;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AddBookCopies
    @TitleID  INT,
    @Barcodes NVARCHAR(MAX),
    @Price    DECIMAL(18, 2)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- =========================================================================
    -- 1. PRE-VALIDATION
    -- =========================================================================
    IF NOT EXISTS (SELECT 1 FROM dbo.BookTitle WHERE TitleID = @TitleID)
    BEGIN
        THROW 50011, 'BookTitle not found.', 1;
    END

    IF @Price IS NULL OR @Price < 0
    BEGIN
        THROW 50011, 'Price must be non-negative.', 1;
    END

    IF @Barcodes IS NULL OR LTRIM(RTRIM(@Barcodes)) = N''
    BEGIN
        THROW 50011, 'At least one Barcode must be provided.', 1;
    END

    DECLARE @ParsedBarcodes TABLE (
        Barcode VARCHAR(30) NOT NULL
    );

    INSERT INTO @ParsedBarcodes (Barcode)
    SELECT LTRIM(RTRIM(CAST(value AS VARCHAR(30))))
    FROM STRING_SPLIT(@Barcodes, ',')
    WHERE LTRIM(RTRIM(value)) <> '';

    IF NOT EXISTS (SELECT 1 FROM @ParsedBarcodes)
    BEGIN
        THROW 50011, 'No valid Barcodes provided.', 1;
    END

    IF EXISTS (
        SELECT Barcode
        FROM @ParsedBarcodes
        GROUP BY Barcode
        HAVING COUNT(*) > 1
    )
    BEGIN
        THROW 50011, 'Duplicate Barcodes found in input list.', 1;
    END

    IF EXISTS (
        SELECT 1
        FROM @ParsedBarcodes pb
        INNER JOIN dbo.BookItem bi ON pb.Barcode = bi.Barcode
    )
    BEGIN
        THROW 50011, 'One or more Barcodes already exist in BookItem.', 1;
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
            SAVE TRANSACTION sp_AddBookCopies_Inner;
        END

        DECLARE @Inserted TABLE (
            BookItemID INT,
            Barcode    VARCHAR(30),
            TitleID    INT,
            StatusID   VARCHAR(20),
            Price      DECIMAL(18, 2)
        );

        INSERT INTO dbo.BookItem (Barcode, TitleID, StatusID, Price)
        OUTPUT inserted.BookItemID, inserted.Barcode, inserted.TitleID, inserted.StatusID, inserted.Price
        INTO @Inserted
        SELECT Barcode, @TitleID, 'AVAILABLE', @Price
        FROM @ParsedBarcodes;

        IF @TranStarted = 1
        BEGIN
            COMMIT TRANSACTION;
        END

        SELECT BookItemID, Barcode, TitleID, StatusID, Price
        FROM @Inserted;
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
                ROLLBACK TRANSACTION sp_AddBookCopies_Inner;
        END;

        THROW;
    END CATCH
END;
GO
