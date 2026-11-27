USE ThuVien2;
GO

CREATE OR ALTER VIEW dbo.vw_Report_MonthlyCirculationTrends
AS
WITH MonthlyBorrows AS (
    SELECT FORMAT(ls.LoanDate, 'yyyy-MM') AS YearMonth,
           COUNT(li.LoanItemID) AS BorrowCount
    FROM dbo.LoanSlip ls
    INNER JOIN dbo.LoanItem li ON ls.LoanSlipID = li.LoanSlipID
    GROUP BY FORMAT(ls.LoanDate, 'yyyy-MM')
),
MonthlyReturns AS (
    SELECT FORMAT(rs.ReturnDate, 'yyyy-MM') AS YearMonth,
           COUNT(ri.ReturnItemID) AS ReturnCount,
           SUM(CASE WHEN rs.ReturnDate > li.DueDate THEN 1 ELSE 0 END) AS LateReturnCount
    FROM dbo.ReturnSlip rs
    INNER JOIN dbo.ReturnItem ri ON rs.ReturnSlipID = ri.ReturnSlipID
    INNER JOIN dbo.LoanItem li ON ri.LoanItemID = li.LoanItemID
    GROUP BY FORMAT(rs.ReturnDate, 'yyyy-MM')
),
AllMonths AS (
    SELECT YearMonth FROM MonthlyBorrows
    UNION
    SELECT YearMonth FROM MonthlyReturns
)
SELECT m.YearMonth,
       ISNULL(b.BorrowCount, 0) AS BorrowCount,
       ISNULL(r.ReturnCount, 0) AS ReturnCount,
       ISNULL(r.LateReturnCount, 0) AS LateReturnCount,
       CASE
           WHEN ISNULL(r.ReturnCount, 0) = 0 THEN 0.00
           ELSE CAST(ROUND(100.0 * r.LateReturnCount / r.ReturnCount, 2) AS DECIMAL(5, 2))
       END AS LateReturnRatePct
FROM AllMonths m
LEFT JOIN MonthlyBorrows b ON m.YearMonth = b.YearMonth
LEFT JOIN MonthlyReturns r ON m.YearMonth = r.YearMonth;
GO
