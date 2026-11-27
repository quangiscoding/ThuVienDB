USE ThuVien2;
GO

CREATE OR ALTER VIEW dbo.vw_Report_DailyCirculation
AS
WITH DailyBorrows AS (
    SELECT ls.LoanDate AS ActivityDate,
           COUNT(li.LoanItemID) AS BorrowCount
    FROM dbo.LoanSlip ls
    INNER JOIN dbo.LoanItem li ON ls.LoanSlipID = li.LoanSlipID
    GROUP BY ls.LoanDate
),
DailyReturns AS (
    SELECT rs.ReturnDate AS ActivityDate,
           COUNT(ri.ReturnItemID) AS ReturnCount
    FROM dbo.ReturnSlip rs
    INNER JOIN dbo.ReturnItem ri ON rs.ReturnSlipID = ri.ReturnSlipID
    GROUP BY rs.ReturnDate
),
AllDates AS (
    SELECT ActivityDate FROM DailyBorrows
    UNION
    SELECT ActivityDate FROM DailyReturns
)
SELECT d.ActivityDate,
       ISNULL(b.BorrowCount, 0) AS BorrowCount,
       ISNULL(r.ReturnCount, 0) AS ReturnCount,
       ISNULL(b.BorrowCount, 0) - ISNULL(r.ReturnCount, 0) AS NetActiveLoanDelta
FROM AllDates d
LEFT JOIN DailyBorrows b ON d.ActivityDate = b.ActivityDate
LEFT JOIN DailyReturns r ON d.ActivityDate = r.ActivityDate;
GO
