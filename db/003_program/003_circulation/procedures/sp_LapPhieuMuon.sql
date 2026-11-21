USE ThuVien2;
GO

CREATE OR ALTER PROCEDURE dbo.sp_LapPhieuMuon 
    @MaSinhVien VARCHAR(20), 
    @BookItemID INT, 
    @SoNgayMuon INT = 7
AS
BEGIN
    SET NOCOUNT ON;

    -- =========================================================================
    -- 1. PRE-VALIDATION
    -- =========================================================================
    DECLARE @SinhVienID INT;

    SELECT @SinhVienID = SinhVienID 
    FROM dbo.SinhVien 
    WHERE MaSinhVien = @MaSinhVien;

    IF @SinhVienID IS NULL
    BEGIN
        RAISERROR(N'Lỗi: Mã sinh viên không tồn tại trong hệ thống.', 16, 1);
        RETURN;
    END

    -- Kiểm tra nợ tiền phạt chưa thanh toán
    IF EXISTS (
        SELECT 1 
        FROM dbo.DongPhat dp
        JOIN dbo.DongTra dt ON dp.DongTraID = dt.DongTraID
        JOIN dbo.PhieuTra pt ON dt.PhieuTraID = pt.PhieuTraID
        WHERE pt.SinhVienID = @SinhVienID AND dp.Status = 'UNPAID'
    )
    BEGIN
        RAISERROR(N'Lỗi: Sinh viên đang có khoản phạt chưa đóng. Vui lòng thanh toán trước khi mượn tiếp.', 16, 1);
        RETURN;
    END

    -- Kiểm tra nợ sách quá hạn
    IF EXISTS (
        SELECT 1 
        FROM dbo.DongMuon dm
        JOIN dbo.PhieuMuon pm ON dm.BorrowingID = pm.BorrowingID
        LEFT JOIN dbo.DongTra dt ON dm.DongMuonID = dt.DongMuonID
        WHERE pm.SinhVienID = @SinhVienID 
          AND dt.DongTraID IS NULL 
          AND dm.NgayHenTra < CAST(GETDATE() AS DATE)
    )
    BEGIN
        RAISERROR(N'Lỗi: Sinh viên đang nợ sách quá hạn chưa trả.', 16, 1);
        RETURN;
    END

    -- Kiểm tra giới hạn 5 cuốn
    DECLARE @CurrentlyBorrowedCount INT;
    SELECT @CurrentlyBorrowedCount = COUNT(dm.DongMuonID)
    FROM dbo.DongMuon dm
    JOIN dbo.PhieuMuon pm ON dm.BorrowingID = pm.BorrowingID
    LEFT JOIN dbo.DongTra dt ON dm.DongMuonID = dt.DongMuonID
    WHERE pm.SinhVienID = @SinhVienID AND dt.DongTraID IS NULL;

    IF (@CurrentlyBorrowedCount >= 5)
    BEGIN
        RAISERROR(N'Lỗi: Sinh viên đã đạt giới hạn mượn tối đa (5 cuốn).', 16, 1);
        RETURN;
    END

    -- =========================================================================
    -- 2. ATOMIC MUTATION
    -- =========================================================================
    DECLARE @TranStarted BIT = 0;

    BEGIN TRY
        IF @@TRANCOUNT = 0
        BEGIN
            BEGIN TRANSACTION;
            SET @TranStarted = 1;
        END
        ELSE
        BEGIN
            SAVE TRANSACTION sp_LapPhieuMuon_Inner;
        END

        UPDATE dbo.BookItem 
        SET StatusID = 'BORROWED' 
        WHERE BookItemID = @BookItemID AND StatusID = 'AVAILABLE';

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR(N'Lỗi: Cuốn sách không tồn tại hoặc hiện không ở trạng thái sẵn sàng (AVAILABLE).', 16, 1);
            RETURN;
        END

        DECLARE @BorrowingID INT;
        INSERT INTO dbo.PhieuMuon (SinhVienID, NgayMuon) 
        VALUES (@SinhVienID, CAST(GETDATE() AS DATE));
        
        SET @BorrowingID = SCOPE_IDENTITY();

        INSERT INTO dbo.DongMuon (BookItemID, BorrowingID, NgayHenTra) 
        VALUES (@BookItemID, @BorrowingID, DATEADD(DAY, @SoNgayMuon, CAST(GETDATE() AS DATE)));

        IF @TranStarted = 1
        BEGIN
            COMMIT TRANSACTION;
        END

        SELECT @BorrowingID AS BorrowingID, N'Thành công' AS Message;
    END TRY
    BEGIN CATCH
        IF @TranStarted = 1
        BEGIN
            IF @@TRANCOUNT > 0 
                ROLLBACK TRANSACTION;
        END
        ELSE
        BEGIN
            IF XACT_STATE() = 1
                ROLLBACK TRANSACTION sp_LapPhieuMuon_Inner;
        END

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrState INT = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSeverity, @ErrState);
    END CATCH
END;
GO