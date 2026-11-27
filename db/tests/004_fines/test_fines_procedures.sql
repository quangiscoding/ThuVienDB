USE ThuVien2;
GO

SET NOCOUNT ON;

-- =============================================================================
-- TEST 1: sp_RecordFinePayment rejects overpayment (50007)
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    -- FineItemID=4 belongs to Student 2, Amount=15,000, UNPAID
    EXEC dbo.sp_RecordFinePayment @StudentID = 2, @StaffID = 1, @FineItemID = 4, @AmountPaid = 20000.00;
    ROLLBACK TRANSACTION;
    THROW 51001, 'TEST 1 FAILED: Expected error 50007 for overpayment.', 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() <> 50007
        THROW;
    PRINT 'TEST 1 PASS: Overpayment rejected (50007).';
END CATCH;
GO

-- =============================================================================
-- TEST 2: sp_RecordFinePayment supports PARTIAL then full PAID transition
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    -- FineItemID=4 (Student 2, Amount=15,000, UNPAID) -> pay 5,000 -> PARTIAL
    EXEC dbo.sp_RecordFinePayment @StudentID = 2, @StaffID = 1, @FineItemID = 4, @AmountPaid = 5000.00;
    IF (SELECT Status FROM dbo.FineItem WHERE FineItemID = 4) <> 'PARTIAL'
        THROW 51002, 'TEST 2 FAILED: Expected Status = PARTIAL after partial payment.', 1;

    -- Pay remaining 10,000 -> PAID
    EXEC dbo.sp_RecordFinePayment @StudentID = 2, @StaffID = 1, @FineItemID = 4, @AmountPaid = 10000.00;
    IF (SELECT Status FROM dbo.FineItem WHERE FineItemID = 4) <> 'PAID'
        THROW 51003, 'TEST 2 FAILED: Expected Status = PAID after final payment.', 1;

    ROLLBACK TRANSACTION;
    PRINT 'TEST 2 PASS: Partial payment transitions UNPAID -> PARTIAL -> PAID.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- =============================================================================
-- TEST 3: sp_WaiveFine rejects non-ADMIN staff (50020)
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    -- StaffID=1 is LIBRARIAN
    EXEC dbo.sp_WaiveFine @FineItemID = 4, @StaffID = 1;
    ROLLBACK TRANSACTION;
    THROW 51004, 'TEST 3 FAILED: Expected error 50020 for non-ADMIN staff.', 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() <> 50020
        THROW;
    PRINT 'TEST 3 PASS: Non-ADMIN staff rejected from waiving fine (50020).';
END CATCH;
GO

-- =============================================================================
-- TEST 4: sp_WaiveFine by ADMIN creates WAIVER receipt and sets Status = WAIVED
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    -- StaffID=2 is ADMIN; FineItemID=2 (Student 2, 470,000 total, 200,000 paid -> 270,000 remaining)
    EXEC dbo.sp_WaiveFine @FineItemID = 2, @StaffID = 2;

    IF (SELECT Status FROM dbo.FineItem WHERE FineItemID = 2) <> 'WAIVED'
        THROW 51005, 'TEST 4 FAILED: Expected Status = WAIVED.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.PaymentReceipt pr
        INNER JOIN dbo.PaymentItem pi ON pr.ReceiptID = pi.ReceiptID
        WHERE pi.FineItemID = 2
          AND pr.ReceiptType = 'WAIVER'
          AND pr.Total = 270000.00
    )
        THROW 51006, 'TEST 4 FAILED: Expected WAIVER receipt for remaining 270,000.00.', 1;

    ROLLBACK TRANSACTION;
    PRINT 'TEST 4 PASS: ADMIN waiver created WAIVER receipt for 270,000 and set WAIVED.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- =============================================================================
-- TEST 5: sp_GetStudentFineBalance returns open fines and total remaining balance
-- =============================================================================
BEGIN TRANSACTION;
BEGIN TRY
    -- Student 2 has FineItem 2 (270,000 remaining) + FineItem 4 (15,000 remaining) = 285,000
    EXEC dbo.sp_GetStudentFineBalance @StudentID = 2;
    ROLLBACK TRANSACTION;
    PRINT 'TEST 5 PASS: sp_GetStudentFineBalance executed cleanly.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
