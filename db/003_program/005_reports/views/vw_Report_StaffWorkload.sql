USE ThuVien2;
GO

CREATE OR ALTER VIEW dbo.vw_Report_StaffWorkload
AS
WITH LoanCounts AS (
    SELECT StaffID, COUNT(*) AS LoanSlipCount
    FROM dbo.LoanSlip
    GROUP BY StaffID
),
ReturnCounts AS (
    SELECT StaffID, COUNT(*) AS ReturnSlipCount
    FROM dbo.ReturnSlip
    GROUP BY StaffID
),
ReceiptCounts AS (
    SELECT StaffID, COUNT(*) AS PaymentReceiptCount
    FROM dbo.PaymentReceipt
    GROUP BY StaffID
)
SELECT st.StaffID,
       st.StaffCode,
       st.FullName,
       st.RoleID,
       ISNULL(lc.LoanSlipCount, 0) AS LoanSlipCount,
       ISNULL(rc.ReturnSlipCount, 0) AS ReturnSlipCount,
       ISNULL(pc.PaymentReceiptCount, 0) AS PaymentReceiptCount,
       ISNULL(lc.LoanSlipCount, 0)
         + ISNULL(rc.ReturnSlipCount, 0)
         + ISNULL(pc.PaymentReceiptCount, 0) AS TotalActions
FROM dbo.Staff st
LEFT JOIN LoanCounts    lc ON st.StaffID = lc.StaffID
LEFT JOIN ReturnCounts  rc ON st.StaffID = rc.StaffID
LEFT JOIN ReceiptCounts pc ON st.StaffID = pc.StaffID;
GO
