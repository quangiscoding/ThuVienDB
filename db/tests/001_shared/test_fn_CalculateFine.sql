USE ThuVien2;
GO

SET NOCOUNT ON;

BEGIN TRANSACTION;

DECLARE @LateRuleID    INT = (SELECT RuleID FROM dbo.FineRule WHERE RuleCode = 'LATE');
DECLARE @LostRuleID    INT = (SELECT RuleID FROM dbo.FineRule WHERE RuleCode = 'LOST');
DECLARE @DamagedRuleID INT = (SELECT RuleID FROM dbo.FineRule WHERE RuleCode = 'DAMAGED');

CREATE TABLE #FineTestCases (
    TestCaseID    VARCHAR(10)    NOT NULL,
    Description   NVARCHAR(150)  NOT NULL,
    RuleID        INT            NOT NULL,
    DaysOverdue   INT            NOT NULL,
    BookPrice     DECIMAL(18, 2) NOT NULL,
    DamagePercent DECIMAL(5, 2)  NULL,
    ExpectedFine  DECIMAL(18, 2) NULL
);

INSERT INTO #FineTestCases (TestCaseID, Description, RuleID, DaysOverdue, BookPrice, DamagePercent, ExpectedFine)
VALUES
    ('TC01', N'On-time return (0 days)',                               @LateRuleID,     0, 100000.00, NULL,      0.00),
    ('TC02', N'Late 3 days (3 * 5,000)',                               @LateRuleID,     3, 100000.00, NULL,  15000.00),
    ('TC03', N'Late 10 days (10 * 5,000)',                             @LateRuleID,    10, 250000.00, NULL,  50000.00),
    ('TC04', N'Negative overdue days sanitized to 0',                  @LateRuleID,    -5, 100000.00, NULL,      0.00),
    ('TC05', N'Lost book 100k (100% price + 20k fee)',                 @LostRuleID,     0, 100000.00, NULL, 120000.00),
    ('TC06', N'Lost book 250k (100% price + 20k fee)',                 @LostRuleID,     0, 250000.00, NULL, 270000.00),
    ('TC07', N'Damaged book default 20% of 100k + 15k fee',            @DamagedRuleID,  0, 100000.00, NULL,  35000.00),
    ('TC08', N'Damaged book custom 50% of 250k + 15k fee',             @DamagedRuleID,  0, 250000.00, 0.50, 140000.00),
    ('TC09', N'Non-existent RuleID (-999) returns NULL',               -999,            5, 100000.00, NULL,      NULL);

SELECT
    tc.TestCaseID,
    tc.Description,
    tc.ExpectedFine,
    dbo.fn_CalculateFine(tc.RuleID, tc.DaysOverdue, tc.BookPrice, tc.DamagePercent) AS ActualFine,
    CASE
        WHEN (tc.ExpectedFine IS NULL AND dbo.fn_CalculateFine(tc.RuleID, tc.DaysOverdue, tc.BookPrice, tc.DamagePercent) IS NULL)
          OR (tc.ExpectedFine = dbo.fn_CalculateFine(tc.RuleID, tc.DaysOverdue, tc.BookPrice, tc.DamagePercent))
        THEN 'PASS'
        ELSE 'FAIL'
    END AS Result
INTO #FineTestResults
FROM #FineTestCases tc;

SELECT * FROM #FineTestResults;

IF EXISTS (SELECT 1 FROM #FineTestResults WHERE Result = 'FAIL')
BEGIN
    ROLLBACK TRANSACTION;
    THROW 51000, 'One or more test cases in test_fn_CalculateFine FAILED.', 1;
END

PRINT 'ALL test_fn_CalculateFine TESTS PASSED.';

DROP TABLE #FineTestResults;
DROP TABLE #FineTestCases;
ROLLBACK TRANSACTION;
GO
