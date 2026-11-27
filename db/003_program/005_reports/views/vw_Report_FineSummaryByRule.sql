USE ThuVien2;
GO

CREATE OR ALTER VIEW dbo.vw_Report_FineSummaryByRule
AS
WITH FineSettlements AS (
    SELECT pi.FineItemID,
           SUM(CASE WHEN pr.ReceiptType = 'PAYMENT' THEN pi.AmountPaid ELSE 0.00 END) AS CollectedAmount,
           SUM(CASE WHEN pr.ReceiptType = 'WAIVER'  THEN pi.AmountPaid ELSE 0.00 END) AS WaivedAmount
    FROM dbo.PaymentItem pi
    INNER JOIN dbo.PaymentReceipt pr ON pi.ReceiptID = pr.ReceiptID
    GROUP BY pi.FineItemID
)
SELECT fr.RuleID,
       fr.RuleCode,
       fr.RuleName,
       COUNT(fi.FineItemID) AS FineCount,
       ISNULL(SUM(fi.Amount), 0.00) AS TotalAssessed,
       ISNULL(SUM(fs.CollectedAmount), 0.00) AS TotalCollected,
       ISNULL(SUM(fs.WaivedAmount), 0.00) AS TotalWaived,
       ISNULL(SUM(fi.Amount), 0.00)
         - ISNULL(SUM(fs.CollectedAmount), 0.00)
         - ISNULL(SUM(fs.WaivedAmount), 0.00) AS TotalOutstanding
FROM dbo.FineRule fr
LEFT JOIN dbo.FineItem fi ON fr.RuleID = fi.FineRuleID
LEFT JOIN FineSettlements fs ON fi.FineItemID = fs.FineItemID
GROUP BY fr.RuleID, fr.RuleCode, fr.RuleName;
GO
