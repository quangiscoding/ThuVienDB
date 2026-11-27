USE ThuVien2;
GO

SET NOCOUNT ON;

-- =============================================================================
-- Verify all 8 reporting views return expected rows on seeded data
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM dbo.vw_Report_DailyCirculation)
    THROW 51001, 'FAIL: vw_Report_DailyCirculation returned 0 rows.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.vw_Report_MonthlyCirculationTrends)
    THROW 51002, 'FAIL: vw_Report_MonthlyCirculationTrends returned 0 rows.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.vw_Report_TopBorrowedTitles)
    THROW 51003, 'FAIL: vw_Report_TopBorrowedTitles returned 0 rows.', 1;

IF (SELECT SUM(CopyCount) FROM dbo.vw_Report_InventoryStatusSummary) <> 10
    THROW 51004, 'FAIL: vw_Report_InventoryStatusSummary expected 10 total copies.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.vw_Report_OverdueLoans)
    THROW 51005, 'FAIL: vw_Report_OverdueLoans expected at least 1 active overdue loan.', 1;

IF (SELECT SUM(TotalOutstanding) FROM dbo.vw_Report_FineSummaryByRule) <> 285000.00
    THROW 51006, 'FAIL: vw_Report_FineSummaryByRule expected 285,000.00 total outstanding.', 1;

IF (SELECT COUNT(*) FROM dbo.vw_Report_StudentActivityKPI) <> 5
    THROW 51007, 'FAIL: vw_Report_StudentActivityKPI expected 5 students.', 1;

IF (SELECT COUNT(*) FROM dbo.vw_Report_StaffWorkload) <> 2
    THROW 51008, 'FAIL: vw_Report_StaffWorkload expected 2 staff members.', 1;

PRINT 'ALL 8 REPORTING VIEWS PASSED.';

-- =============================================================================
-- Verify both reporting procedures
-- =============================================================================
EXEC dbo.sp_Report_CirculationByDateRange @StartDate = '2026-10-01', @EndDate = '2026-12-31';
EXEC dbo.sp_Report_TopDelinquentStudents @TopN = 5;

-- Negative test: invalid date range throws 50030
BEGIN TRY
    EXEC dbo.sp_Report_CirculationByDateRange @StartDate = '2026-12-31', @EndDate = '2026-10-01';
    THROW 51009, 'FAIL: Expected error 50030 for invalid date range.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 50030
        THROW;
    PRINT 'REPORT PROCEDURES PASSED (including error 50030 check).';
END CATCH;
GO
