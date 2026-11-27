USE ThuVien2;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_TopDelinquentStudents
    @TopN INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    IF @TopN IS NULL OR @TopN <= 0
        SET @TopN = 10;

    SELECT TOP (@TopN)
           kpi.StudentID,
           kpi.StudentCode,
           kpi.FullName,
           kpi.ClassName,
           kpi.AccountStatus,
           kpi.LateReturns + ISNULL(ov.CurrentOverdueCount, 0) AS OverdueIncidents,
           kpi.TotalFinesAssessed,
           kpi.TotalPaid,
           kpi.TotalWaived,
           kpi.OutstandingBalance
    FROM dbo.vw_Report_StudentActivityKPI kpi
    LEFT JOIN (
        SELECT StudentID, COUNT(*) AS CurrentOverdueCount
        FROM dbo.vw_Report_OverdueLoans
        GROUP BY StudentID
    ) ov ON kpi.StudentID = ov.StudentID
    WHERE kpi.OutstandingBalance > 0
       OR (kpi.LateReturns + ISNULL(ov.CurrentOverdueCount, 0)) > 0
    ORDER BY kpi.OutstandingBalance DESC,
             (kpi.LateReturns + ISNULL(ov.CurrentOverdueCount, 0)) DESC,
             kpi.StudentID;
END;
GO
