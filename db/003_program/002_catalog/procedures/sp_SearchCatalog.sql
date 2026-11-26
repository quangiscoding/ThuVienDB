USE ThuVien2;
GO

CREATE OR ALTER PROCEDURE dbo.sp_SearchCatalog
    @Keyword NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Pattern NVARCHAR(204) =
        CASE
            WHEN @Keyword IS NULL OR LTRIM(RTRIM(@Keyword)) = N'' THEN NULL
            ELSE N'%' + LTRIM(RTRIM(@Keyword)) + N'%'
        END;

    ;WITH TitleAuthors AS (
        SELECT abt.TitleID,
               STRING_AGG(a.AuthorName, N', ') WITHIN GROUP (ORDER BY a.AuthorName) AS Authors
        FROM dbo.Author_BookTitle abt
        INNER JOIN dbo.Author a ON abt.AuthorID = a.AuthorID
        GROUP BY abt.TitleID
    )
    SELECT bt.TitleID,
           bt.BookTitle,
           ISNULL(ta.Authors, N'Unknown') AS Authors,
           COUNT(bi.BookItemID) AS TotalCopies,
           SUM(CASE WHEN bi.StatusID = 'AVAILABLE' THEN 1 ELSE 0 END) AS AvailableCopies,
           ISNULL(MAX(bi.Price), 0.00) AS UnitPrice
    FROM dbo.BookTitle bt
    LEFT JOIN TitleAuthors ta ON bt.TitleID = ta.TitleID
    LEFT JOIN dbo.BookItem bi ON bt.TitleID = bi.TitleID
    WHERE @Pattern IS NULL
       OR bt.BookTitle LIKE @Pattern
       OR ta.Authors   LIKE @Pattern
       OR EXISTS (
              SELECT 1
              FROM dbo.BookItem bi2
              WHERE bi2.TitleID = bt.TitleID
                AND bi2.Barcode LIKE @Pattern
          )
    GROUP BY bt.TitleID, bt.BookTitle, ta.Authors
    ORDER BY bt.TitleID;
END;
GO
