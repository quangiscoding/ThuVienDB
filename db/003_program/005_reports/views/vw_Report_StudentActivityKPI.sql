USE ThuVien2;
GO

CREATE OR ALTER VIEW dbo.vw_Report_StudentActivityKPI
AS
WITH LoanStats AS (
    SELECT ls.StudentID,
           COUNT(li.LoanItemID) AS TotalBorrows,
           SUM(CASE WHEN ri.ReturnItemID IS NULL AND bi.StatusID = 'BORROWED' THEN 1 ELSE 0 END) AS ActiveLoans,
           SUM(CASE WHEN ri.ReturnItemID IS NOT NULL AND rs.ReturnDate > li.DueDate THEN 1 ELSE 0 END) AS LateReturns
    FROM dbo.LoanSlip ls
    INNER JOIN dbo.LoanItem li ON ls.LoanSlipID = li.LoanSlipID
    INNER JOIN dbo.BookItem bi ON li.BookItemID = bi.BookItemID
    LEFT  JOIN dbo.ReturnItem ri ON li.LoanItemID = ri.LoanItemID
    LEFT  JOIN dbo.ReturnSlip rs ON ri.ReturnSlipID = rs.ReturnSlipID
    GROUP BY ls.StudentID
),
FineStats AS (
    SELECT COALESCE(rs.StudentID, ls.StudentID) AS StudentID,
           ISNULL(SUM(fi.Amount), 0.00) AS TotalFinesAssessed
    FROM dbo.FineItem fi
    LEFT JOIN dbo.ReturnItem ri ON fi.ReturnItemID = ri.ReturnItemID
    LEFT JOIN dbo.ReturnSlip rs ON ri.ReturnSlipID = rs.ReturnSlipID
    LEFT JOIN dbo.LoanItem   li ON fi.LoanItemID   = li.LoanItemID
    LEFT JOIN dbo.LoanSlip   ls ON li.LoanSlipID   = ls.LoanSlipID
    GROUP BY COALESCE(rs.StudentID, ls.StudentID)
),
PaidStats AS (
    SELECT pr.StudentID,
           ISNULL(SUM(CASE WHEN pr.ReceiptType = 'PAYMENT' THEN pi.AmountPaid ELSE 0.00 END), 0.00) AS TotalPaid,
           ISNULL(SUM(CASE WHEN pr.ReceiptType = 'WAIVER'  THEN pi.AmountPaid ELSE 0.00 END), 0.00) AS TotalWaived
    FROM dbo.PaymentReceipt pr
    INNER JOIN dbo.PaymentItem pi ON pr.ReceiptID = pi.ReceiptID
    GROUP BY pr.StudentID
)
SELECT s.StudentID,
       s.StudentCode,
       s.FullName,
       s.ClassName,
       s.Status AS AccountStatus,
       ISNULL(ln.TotalBorrows, 0) AS TotalBorrows,
       ISNULL(ln.ActiveLoans, 0) AS ActiveLoans,
       ISNULL(ln.LateReturns, 0) AS LateReturns,
       ISNULL(fn.TotalFinesAssessed, 0.00) AS TotalFinesAssessed,
       ISNULL(pd.TotalPaid, 0.00) AS TotalPaid,
       ISNULL(pd.TotalWaived, 0.00) AS TotalWaived,
       ISNULL(fn.TotalFinesAssessed, 0.00) - ISNULL(pd.TotalPaid, 0.00) - ISNULL(pd.TotalWaived, 0.00) AS OutstandingBalance
FROM dbo.Student s
LEFT JOIN LoanStats ln ON s.StudentID = ln.StudentID
LEFT JOIN FineStats fn ON s.StudentID = fn.StudentID
LEFT JOIN PaidStats pd ON s.StudentID = pd.StudentID;
GO
