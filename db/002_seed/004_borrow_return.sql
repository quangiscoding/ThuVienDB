USE ThuVien2;
GO

-- =============================================================================
-- 1. Historical Loan 1: Student 1 borrowed BI003 (BookItemID=3) and returned 2 days late
-- =============================================================================
INSERT INTO dbo.LoanSlip (StudentID, StaffID, LoanDate) VALUES
(1, 1, '2026-10-01');

INSERT INTO dbo.LoanItem (BookItemID, LoanSlipID, DueDate) VALUES
(3, 1, '2026-10-15');

INSERT INTO dbo.ReturnSlip (StudentID, StaffID, ReturnDate) VALUES
(1, 1, '2026-10-17');

INSERT INTO dbo.ReturnItem (ReturnSlipID, LoanItemID) VALUES
(1, 1);

-- =============================================================================
-- 2. Active On-Time Loan 2: Student 3 currently holds BI004 (BookItemID=4)
-- =============================================================================
INSERT INTO dbo.LoanSlip (StudentID, StaffID, LoanDate) VALUES
(3, 1, DATEADD(DAY, -3, CAST(GETDATE() AS DATE)));

INSERT INTO dbo.LoanItem (BookItemID, LoanSlipID, DueDate) VALUES
(4, 2, DATEADD(DAY, 11, CAST(GETDATE() AS DATE)));

-- =============================================================================
-- 3. Active Overdue Loan 3: Student 2 holds BI005 (BookItemID=5), 6 days overdue
-- =============================================================================
INSERT INTO dbo.LoanSlip (StudentID, StaffID, LoanDate) VALUES
(2, 1, DATEADD(DAY, -20, CAST(GETDATE() AS DATE)));

INSERT INTO dbo.LoanItem (BookItemID, LoanSlipID, DueDate) VALUES
(5, 3, DATEADD(DAY, -6, CAST(GETDATE() AS DATE)));

-- =============================================================================
-- 4. Lost Book Loan 4: Student 2 lost BI007 (BookItemID=7), never returned
-- =============================================================================
INSERT INTO dbo.LoanSlip (StudentID, StaffID, LoanDate) VALUES
(2, 1, '2026-10-05');

INSERT INTO dbo.LoanItem (BookItemID, LoanSlipID, DueDate) VALUES
(7, 4, '2026-10-19');

-- =============================================================================
-- 5. Damaged Return Loan 5: Student 3 returned BI009 (BookItemID=9) damaged
-- =============================================================================
INSERT INTO dbo.LoanSlip (StudentID, StaffID, LoanDate) VALUES
(3, 1, '2026-10-06');

INSERT INTO dbo.LoanItem (BookItemID, LoanSlipID, DueDate) VALUES
(9, 5, '2026-10-20');

INSERT INTO dbo.ReturnSlip (StudentID, StaffID, ReturnDate) VALUES
(3, 1, '2026-10-18');

INSERT INTO dbo.ReturnItem (ReturnSlipID, LoanItemID) VALUES
(2, 5);

-- =============================================================================
-- 6. Historical Late Return 6: Student 2 returned BI001 (BookItemID=1) 3 days late (unpaid fine)
-- =============================================================================
INSERT INTO dbo.LoanSlip (StudentID, StaffID, LoanDate) VALUES
(2, 1, '2026-10-02');

INSERT INTO dbo.LoanItem (BookItemID, LoanSlipID, DueDate) VALUES
(1, 6, '2026-10-16');

INSERT INTO dbo.ReturnSlip (StudentID, StaffID, ReturnDate) VALUES
(2, 1, '2026-10-19');

INSERT INTO dbo.ReturnItem (ReturnSlipID, LoanItemID) VALUES
(3, 6);
GO
