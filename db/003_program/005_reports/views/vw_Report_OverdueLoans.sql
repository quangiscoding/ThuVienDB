USE ThuVien2;
GO

CREATE OR ALTER VIEW dbo.vw_Report_OverdueLoans
AS
SELECT li.LoanItemID,
       ls.LoanSlipID,
       st.StudentID,
       st.StudentCode,
       st.FullName,
       st.Email,
       bi.BookItemID,
       bi.Barcode,
       bt.BookTitle,
       ls.LoanDate,
       li.DueDate,
       DATEDIFF(DAY, li.DueDate, CAST(GETDATE() AS DATE)) AS DaysOverdue
FROM dbo.LoanItem li
INNER JOIN dbo.LoanSlip  ls ON li.LoanSlipID = ls.LoanSlipID
INNER JOIN dbo.Student   st ON ls.StudentID  = st.StudentID
INNER JOIN dbo.BookItem  bi ON li.BookItemID = bi.BookItemID
INNER JOIN dbo.BookTitle bt ON bi.TitleID    = bt.TitleID
LEFT  JOIN dbo.ReturnItem ri ON li.LoanItemID = ri.LoanItemID
WHERE ri.ReturnItemID IS NULL
  AND bi.StatusID = 'BORROWED'
  AND li.DueDate < CAST(GETDATE() AS DATE);
GO
