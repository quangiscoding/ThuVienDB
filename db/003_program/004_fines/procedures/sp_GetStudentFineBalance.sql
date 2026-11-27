USE ThuVien2;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetStudentFineBalance
    @StudentID INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Student WHERE StudentID = @StudentID)
    BEGIN
        THROW 50001, 'Student not found.', 1;
    END

    -- 1. Itemized unpaid/partial fines
    SELECT fi.FineItemID,
           fr.RuleCode,
           fi.Description,
           bt.BookTitle,
           bi.Barcode,
           fi.Amount,
           ISNULL(SUM(pi.AmountPaid), 0.00) AS PaidAmount,
           fi.Amount - ISNULL(SUM(pi.AmountPaid), 0.00) AS RemainingBalance,
           fi.Status
    FROM dbo.FineItem fi
    INNER JOIN dbo.FineRule fr ON fi.FineRuleID = fr.RuleID
    LEFT  JOIN dbo.ReturnItem ri ON fi.ReturnItemID = ri.ReturnItemID
    LEFT  JOIN dbo.ReturnSlip rs ON ri.ReturnSlipID = rs.ReturnSlipID
    LEFT  JOIN dbo.LoanItem   li ON COALESCE(ri.LoanItemID, fi.LoanItemID) = li.LoanItemID
    LEFT  JOIN dbo.LoanSlip   ls ON li.LoanSlipID   = ls.LoanSlipID
    LEFT  JOIN dbo.BookItem   bi ON li.BookItemID   = bi.BookItemID
    LEFT  JOIN dbo.BookTitle  bt ON bi.TitleID      = bt.TitleID
    LEFT  JOIN dbo.PaymentItem pi ON fi.FineItemID  = pi.FineItemID
    WHERE COALESCE(rs.StudentID, ls.StudentID) = @StudentID
      AND fi.Status IN ('UNPAID', 'PARTIAL')
    GROUP BY fi.FineItemID, fr.RuleCode, fi.Description, bt.BookTitle, bi.Barcode, fi.Amount, fi.Status
    ORDER BY fi.FineItemID;

    -- 2. Summary total remaining balance
    ;WITH OpenFines AS (
        SELECT fi.FineItemID,
               fi.Amount - ISNULL(SUM(pi.AmountPaid), 0.00) AS RemainingBalance
        FROM dbo.FineItem fi
        LEFT JOIN dbo.ReturnItem ri ON fi.ReturnItemID = ri.ReturnItemID
        LEFT JOIN dbo.ReturnSlip rs ON ri.ReturnSlipID = rs.ReturnSlipID
        LEFT JOIN dbo.LoanItem   li ON fi.LoanItemID   = li.LoanItemID
        LEFT JOIN dbo.LoanSlip   ls ON li.LoanSlipID   = ls.LoanSlipID
        LEFT JOIN dbo.PaymentItem pi ON fi.FineItemID  = pi.FineItemID
        WHERE COALESCE(rs.StudentID, ls.StudentID) = @StudentID
          AND fi.Status IN ('UNPAID', 'PARTIAL')
        GROUP BY fi.FineItemID, fi.Amount
    )
    SELECT s.StudentID,
           s.StudentCode,
           s.FullName,
           COUNT(ofn.FineItemID) AS OpenFineCount,
           ISNULL(SUM(ofn.RemainingBalance), 0.00) AS TotalRemainingBalance
    FROM dbo.Student s
    LEFT JOIN OpenFines ofn ON 1 = 1
    WHERE s.StudentID = @StudentID
    GROUP BY s.StudentID, s.StudentCode, s.FullName;
END;
GO
