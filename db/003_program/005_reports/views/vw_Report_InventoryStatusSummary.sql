USE ThuVien2;
GO

CREATE OR ALTER VIEW dbo.vw_Report_InventoryStatusSummary
AS
SELECT s.StatusID,
       s.StatusName,
       COUNT(bi.BookItemID) AS CopyCount,
       ISNULL(SUM(bi.Price), 0.00) AS TotalAssetValue
FROM dbo.[Status] s
LEFT JOIN dbo.BookItem bi ON s.StatusID = bi.StatusID
GROUP BY s.StatusID, s.StatusName;
GO
