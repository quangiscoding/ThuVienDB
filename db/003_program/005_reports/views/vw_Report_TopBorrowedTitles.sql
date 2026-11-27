USE ThuVien2;
GO

CREATE OR ALTER VIEW dbo.vw_Report_TopBorrowedTitles
AS
WITH TitleAuthors AS (
    SELECT abt.TitleID,
           STRING_AGG(a.AuthorName, N', ') WITHIN GROUP (ORDER BY a.AuthorName) AS Authors
    FROM dbo.Author_BookTitle abt
    INNER JOIN dbo.Author a ON abt.AuthorID = a.AuthorID
    GROUP BY abt.TitleID
),
TitleCopies AS (
    SELECT bi.TitleID,
           COUNT(bi.BookItemID) AS TotalCopies,
           SUM(CASE WHEN bi.StatusID = 'AVAILABLE' THEN 1 ELSE 0 END) AS AvailableCopies
    FROM dbo.BookItem bi
    GROUP BY bi.TitleID
),
TitleBorrows AS (
    SELECT bi.TitleID,
           COUNT(li.LoanItemID) AS TotalBorrows
    FROM dbo.BookItem bi
    LEFT JOIN dbo.LoanItem li ON bi.BookItemID = li.BookItemID
    GROUP BY bi.TitleID
)
SELECT bt.TitleID,
       bt.BookTitle,
       ISNULL(ta.Authors, N'Unknown') AS Authors,
       ISNULL(tb.TotalBorrows, 0) AS TotalBorrows,
       ISNULL(tc.TotalCopies, 0) AS TotalCopies,
       ISNULL(tc.AvailableCopies, 0) AS AvailableCopies
FROM dbo.BookTitle bt
LEFT JOIN TitleAuthors ta ON bt.TitleID = ta.TitleID
LEFT JOIN TitleCopies  tc ON bt.TitleID = tc.TitleID
LEFT JOIN TitleBorrows tb ON bt.TitleID = tb.TitleID;
GO
