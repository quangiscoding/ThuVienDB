USE ThuVien2;
GO

-- =============================================================================
-- 1. FineItem fixtures covering PAID, PARTIAL, WAIVED, UNPAID & both XOR paths
-- =============================================================================
INSERT INTO dbo.FineItem (FineRuleID, ReturnItemID, LoanItemID, Amount, Status, Description) VALUES
(1, 1,    NULL, 10000.00,  'PAID',    N'Late return by 2 days (BI003)'),
(2, NULL, 4,    470000.00, 'PARTIAL', N'Lost book replacement: 100% of 450,000 + 20,000 fee (BI007)'),
(3, 2,    NULL, 71000.00,  'WAIVED',  N'Damaged book penalty: 20% of 280,000 + 15,000 fee (BI009)'),
(1, 3,    NULL, 15000.00,  'UNPAID',  N'Late return by 3 days (BI001)');

-- =============================================================================
-- 2. PaymentReceipt & PaymentItem fixtures (PAYMENT and WAIVER)
-- =============================================================================
-- Full payment for FineItem 1 (Student 1, Librarian NV01)
INSERT INTO dbo.PaymentReceipt (StaffID, StudentID, PaymentDate, ReceiptType, Total) VALUES
(1, 1, '2026-10-17', 'PAYMENT', 10000.00);

INSERT INTO dbo.PaymentItem (ReceiptID, FineItemID, AmountPaid) VALUES
(1, 1, 10000.00);

-- Partial payment for FineItem 2 (Student 2, Librarian NV01; 270,000 remaining)
INSERT INTO dbo.PaymentReceipt (StaffID, StudentID, PaymentDate, ReceiptType, Total) VALUES
(1, 2, '2026-10-22', 'PAYMENT', 200000.00);

INSERT INTO dbo.PaymentItem (ReceiptID, FineItemID, AmountPaid) VALUES
(2, 2, 200000.00);

-- Admin waiver for FineItem 3 (Student 3, Admin NV02)
INSERT INTO dbo.PaymentReceipt (StaffID, StudentID, PaymentDate, ReceiptType, Total) VALUES
(2, 3, '2026-10-19', 'WAIVER', 71000.00);

INSERT INTO dbo.PaymentItem (ReceiptID, FineItemID, AmountPaid) VALUES
(3, 3, 71000.00);
GO
