USE ThuVien2;
GO

SET NOCOUNT ON;

-- =============================================================================
-- TEST 1: sp_AddBookTitle fails on empty title or invalid AuthorID (50010)
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    EXEC dbo.sp_AddBookTitle @BookTitle = N'Invalid Author Book', @AuthorIDs = '1,999999';
    ROLLBACK TRANSACTION;
    THROW 51001, 'TEST 1 FAILED: Expected error 50010 for non-existent AuthorID.', 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() <> 50010
        THROW;
    PRINT 'TEST 1 PASS: Invalid AuthorID rejected (50010).';
END CATCH;
GO

-- =============================================================================
-- TEST 2: sp_AddBookTitle + sp_AddBookCopies happy path
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @TempTitle TABLE (TitleID INT, BookTitle NVARCHAR(200), Message NVARCHAR(200));
    INSERT INTO @TempTitle
    EXEC dbo.sp_AddBookTitle @BookTitle = N'Refactoring', @AuthorIDs = '3,5';

    DECLARE @NewTitleID INT = (SELECT TitleID FROM @TempTitle);
    IF @NewTitleID IS NULL
        THROW 51002, 'TEST 2 FAILED: TitleID was not returned.', 1;

    DECLARE @AuthorLinks INT = (SELECT COUNT(*) FROM dbo.Author_BookTitle WHERE TitleID = @NewTitleID);
    IF @AuthorLinks <> 2
        THROW 51003, 'TEST 2 FAILED: Expected 2 Author_BookTitle links.', 1;

    EXEC dbo.sp_AddBookCopies @TitleID = @NewTitleID, @Barcodes = 'BI901, BI902', @Price = 350000.00;

    DECLARE @CopyCount INT = (SELECT COUNT(*) FROM dbo.BookItem WHERE TitleID = @NewTitleID AND StatusID = 'AVAILABLE');
    IF @CopyCount <> 2
        THROW 51004, 'TEST 2 FAILED: Expected 2 AVAILABLE copies inserted.', 1;

    ROLLBACK TRANSACTION;
    PRINT 'TEST 2 PASS: sp_AddBookTitle and sp_AddBookCopies inserted title, authors, and 2 AVAILABLE copies.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- =============================================================================
-- TEST 3: sp_AddBookCopies rejects duplicate Barcode (50011)
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    EXEC dbo.sp_AddBookCopies @TitleID = 1, @Barcodes = 'BI001', @Price = 100000.00;
    ROLLBACK TRANSACTION;
    THROW 51005, 'TEST 3 FAILED: Expected error 50011 for duplicate Barcode.', 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() <> 50011
        THROW;
    PRINT 'TEST 3 PASS: Duplicate Barcode rejected (50011).';
END CATCH;
GO

-- =============================================================================
-- TEST 4: sp_UpdateCopyStatus happy path & rejects BORROWED status (50005)
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    EXEC dbo.sp_UpdateCopyStatus @BookItemID = 1, @NewStatusID = 'DAMAGED';
    IF (SELECT StatusID FROM dbo.BookItem WHERE BookItemID = 1) <> 'DAMAGED'
        THROW 51006, 'TEST 4 FAILED: StatusID was not updated to DAMAGED.', 1;

    BEGIN TRY
        EXEC dbo.sp_UpdateCopyStatus @BookItemID = 1, @NewStatusID = 'BORROWED';
        THROW 51007, 'TEST 4 FAILED: Expected error 50005 when setting BORROWED manually.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() <> 50005
            THROW;
    END CATCH;

    ROLLBACK TRANSACTION;
    PRINT 'TEST 4 PASS: sp_UpdateCopyStatus updates administrative status and blocks BORROWED.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- =============================================================================
-- TEST 5: sp_SearchCatalog returns metadata, aggregated authors, and copy counts
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @SearchResults TABLE (
        TitleID         INT,
        BookTitle       NVARCHAR(200),
        Authors         NVARCHAR(MAX),
        TotalCopies     INT,
        AvailableCopies INT,
        UnitPrice       DECIMAL(18, 2)
    );

    INSERT INTO @SearchResults
    EXEC dbo.sp_SearchCatalog @Keyword = N'Pragmatic';

    IF NOT EXISTS (
        SELECT 1
        FROM @SearchResults
        WHERE BookTitle = N'The Pragmatic Programmer'
          AND TotalCopies = 2
          AND AvailableCopies = 1
          AND Authors LIKE N'%Andrew Hunt%'
          AND Authors LIKE N'%Robert C. Martin%'
    )
        THROW 51008, 'TEST 5 FAILED: sp_SearchCatalog did not return expected co-authored title and counts.', 1;

    ROLLBACK TRANSACTION;
    PRINT 'TEST 5 PASS: sp_SearchCatalog returned expected metadata, co-authors, and availability counts.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
