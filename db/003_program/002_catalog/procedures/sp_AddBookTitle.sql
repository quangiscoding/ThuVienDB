USE ThuVien2;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AddBookTitle
    @BookTitle NVARCHAR(200),
    @AuthorIDs NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- =========================================================================
    -- 1. PRE-VALIDATION
    -- =========================================================================
    IF @BookTitle IS NULL OR LTRIM(RTRIM(@BookTitle)) = N''
    BEGIN
        THROW 50010, 'BookTitle must not be empty.', 1;
    END

    IF @AuthorIDs IS NULL OR LTRIM(RTRIM(@AuthorIDs)) = N''
    BEGIN
        THROW 50010, 'At least one AuthorID must be provided.', 1;
    END

    DECLARE @ParsedAuthors TABLE (AuthorID INT PRIMARY KEY);

    INSERT INTO @ParsedAuthors (AuthorID)
    SELECT DISTINCT TRY_CAST(LTRIM(RTRIM(value)) AS INT)
    FROM STRING_SPLIT(@AuthorIDs, ',')
    WHERE LTRIM(RTRIM(value)) <> '';

    IF EXISTS (SELECT 1 FROM @ParsedAuthors WHERE AuthorID IS NULL)
       OR NOT EXISTS (SELECT 1 FROM @ParsedAuthors)
    BEGIN
        THROW 50010, 'Invalid AuthorID list format. Provide comma-separated integer IDs.', 1;
    END

    IF EXISTS (
        SELECT 1
        FROM @ParsedAuthors pa
        LEFT JOIN dbo.Author a ON pa.AuthorID = a.AuthorID
        WHERE a.AuthorID IS NULL
    )
    BEGIN
        THROW 50010, 'One or more specified AuthorIDs do not exist.', 1;
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
            SAVE TRANSACTION sp_AddBookTitle_Inner;
        END

        DECLARE @TitleID INT;

        INSERT INTO dbo.BookTitle (BookTitle)
        VALUES (LTRIM(RTRIM(@BookTitle)));

        SET @TitleID = SCOPE_IDENTITY();

        INSERT INTO dbo.Author_BookTitle (AuthorID, TitleID)
        SELECT AuthorID, @TitleID
        FROM @ParsedAuthors;

        IF @TranStarted = 1
        BEGIN
            COMMIT TRANSACTION;
        END

        SELECT @TitleID AS TitleID,
               LTRIM(RTRIM(@BookTitle)) AS BookTitle,
               N'Book title created successfully.' AS Message;
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
                ROLLBACK TRANSACTION sp_AddBookTitle_Inner;
        END;

        THROW;
    END CATCH
END;
GO
