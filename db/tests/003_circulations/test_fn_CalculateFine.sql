USE ThuVien2;
GO

-- 1. Đăng ký Test Class
EXEC tSQLt.NewTestClass 'testCalculateFine';
GO

-- 2. Test Trả đúng hạn (0 ngày) -> Tiền phạt = 0
CREATE OR ALTER PROCEDURE testCalculateFine.[test_TraDungHan_KhongPhat]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.FineRule';
    INSERT INTO dbo.FineRule (RuleID, RuleCode, RatePerDay, FixedProcessingFee)
    VALUES (1, 'LATE', 5000.00, 0.00);

    DECLARE @Actual DECIMAL(18, 2) = dbo.fn_CalculateFine(1, 0, 100000.00, NULL);

    EXEC tSQLt.AssertEquals 0.00, @Actual;
END;
GO

-- 3. Test Trễ hạn 3 ngày (3 * 5k) -> Tiền phạt = 15.000đ
CREATE OR ALTER PROCEDURE testCalculateFine.[test_TraTre3Ngay_Phat15000]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.FineRule';
    INSERT INTO dbo.FineRule (RuleID, RuleCode, RatePerDay, FixedProcessingFee)
    VALUES (1, 'LATE', 5000.00, 0.00);

    DECLARE @Actual DECIMAL(18, 2) = dbo.fn_CalculateFine(1, 3, 100000.00, NULL);

    EXEC tSQLt.AssertEquals 15000.00, @Actual;
END;
GO

-- 4. Test Mất sách (100% giá + 20k phí xử lý) -> Phạt 120.000đ
CREATE OR ALTER PROCEDURE testCalculateFine.[test_MatSach100k_Phat120000]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.FineRule';
    INSERT INTO dbo.FineRule (RuleID, RuleCode, PercentOfBookValue, FixedProcessingFee)
    VALUES (2, 'LOST', 1.00, 20000.00);

    DECLARE @Actual DECIMAL(18, 2) = dbo.fn_CalculateFine(2, 0, 100000.00, NULL);

    EXEC tSQLt.AssertEquals 120000.00, @Actual;
END;
GO

-- 5. Test Hỏng 20% sách 100k (20k + 15k phí xử lý) -> Phạt 35.000đ
CREATE OR ALTER PROCEDURE testCalculateFine.[test_Hong20PhanTram_Phat35000]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.FineRule';
    INSERT INTO dbo.FineRule (RuleID, RuleCode, FixedProcessingFee)
    VALUES (3, 'DAMAGED', 15000.00);

    DECLARE @Actual DECIMAL(18, 2) = dbo.fn_CalculateFine(3, 0, 100000.00, 0.20);

    EXEC tSQLt.AssertEquals 35000.00, @Actual;
END;
GO

-- 6. Test Truyền sai RuleID không tồn tại -> Phải trả về NULL
CREATE OR ALTER PROCEDURE testCalculateFine.[test_SaiRuleID_TraVeNull]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.FineRule';

    DECLARE @Actual DECIMAL(18, 2) = dbo.fn_CalculateFine(999, 0, 100000.00, NULL);

    EXEC tSQLt.AssertEquals NULL, @Actual;
END;
GO

EXEC tSQLt.Run 'testCalculateFine';