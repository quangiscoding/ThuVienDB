USE ThuVien2;
GO

SET NOCOUNT ON;

BEGIN TRANSACTION;

-- =============================================================================
-- BƯỚC 1: TẠO BẢNG TEST DOUBLE (Cố định ID và thông số, không phụ thuộc DB ngoài)
-- =============================================================================
CREATE TABLE #EnterpriseTestCase (
    TestCaseID       VARCHAR(10)     NOT NULL,
    Description      NVARCHAR(150)   NOT NULL,
    RuleID           INT             NOT NULL,
    DaysOverdue      INT             NOT NULL,
    BookPrice        DECIMAL(18, 2)  NOT NULL,
    DamagePercent    DECIMAL(5, 2)   NULL,
    ExpectedFine     DECIMAL(18, 2)  NOT NULL
);

-- Bơm dữ liệu kiểm thử (Input -> Expected Output)
INSERT INTO #EnterpriseTestCase 
    (TestCaseID, Description, RuleID, DaysOverdue, BookPrice, DamagePercent, ExpectedFine)
VALUES
    ('TC01', N'Đúng hạn (0 ngày)',                            1,  0, 100000.00, NULL,      0.00),
    ('TC02', N'Trễ hạn 3 ngày (3 * 5.000đ)',                 1,  3, 100000.00, NULL,  15000.00),
    ('TC03', N'Trễ hạn 10 ngày (10 * 5.000đ)',               1, 10, 250000.00, NULL,  50000.00),
    ('TC04', N'Mất sách 100k (100% giá + 20k phí xử lý)',    2,  0, 100000.00, NULL, 120000.00),
    ('TC05', N'Mất sách 250k (100% giá + 20k phí xử lý)',    2,  0, 250000.00, NULL, 270000.00),
    ('TC06', N'Hỏng chỉ tính phí cố định (không nhập %)',    3,  0, 100000.00, NULL,  15000.00),
    ('TC07', N'Hỏng 20% sách 100k + 15k phí xử lý',          3,  0, 100000.00, 0.20,  35000.00),
    ('TC08', N'Hỏng 50% sách 250k + 15k phí xử lý',          3,  0, 250000.00, 0.50, 140000.00),
    ('TC09', N'Mã RuleID không tồn tại (-999)',           -999,  5, 100000.00, NULL,      0.00);

-- =============================================================================
-- BƯỚC 2: CHẠY KIỂM THỬ VÀ ĐỐI CHIẾU KẾT QUẢ
-- =============================================================================
SELECT 
    tc.TestCaseID                                                            AS [Mã Test],
    tc.Description                                                           AS [Mô Tả Kịch Bản],
    tc.ExpectedFine                                                          AS [Kỳ Vọng],
    dbo.fn_CalculateFine(tc.RuleID, tc.DaysOverdue, tc.BookPrice, tc.DamagePercent) AS [Thực Tế],
    CASE 
        WHEN dbo.fn_CalculateFine(tc.RuleID, tc.DaysOverdue, tc.BookPrice, tc.DamagePercent) = tc.ExpectedFine 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END                                                                      AS [Kết Quả]
FROM #EnterpriseTestCase tc;

-- =============================================================================
-- BƯỚC 3: DỌN DẸP SẠCH SẼ BỘ NHỚ VÀ HỦY TRANSACTION
-- =============================================================================
DROP TABLE #EnterpriseTestCase;
ROLLBACK TRANSACTION;
GO