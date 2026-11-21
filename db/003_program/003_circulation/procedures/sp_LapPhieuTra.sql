USE ThuVien2;
GO

CREATE OR ALTER PROCEDURE dbo.sp_LapPhieuTra
    @SinhVienID INT,
    @NhanVienID INT,
    @DongMuonID INT,
    @NewBookStatus VARCHAR(20) = 'AVAILABLE',
    @NgayTra DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @NgayTra IS NULL
        SET @NgayTra = CAST(GETDATE() AS DATE);

    -- =========================================================================
    -- PHASE 1: PRE-VALIDATION
    -- =========================================================================
    DECLARE @BookItemID INT, 
            @NgayHenTra DATE, 
            @BookPrice DECIMAL(18, 2), 
            @OwnerSinhVienID INT;

    SELECT @BookItemID = dm.BookItemID,
           @NgayHenTra = dm.NgayHenTra,
           @BookPrice = bi.Price,
           @OwnerSinhVienID = pm.SinhVienID
    FROM dbo.DongMuon dm
    INNER JOIN dbo.PhieuMuon pm ON dm.BorrowingID = pm.BorrowingID
    INNER JOIN dbo.BookItem bi ON dm.BookItemID = bi.BookItemID
    WHERE dm.DongMuonID = @DongMuonID;

    IF @BookItemID IS NULL
    BEGIN
        RAISERROR(N'Lỗi: Dòng mượn không tồn tại trong hệ thống.', 16, 1);
        RETURN;
    END

    IF @OwnerSinhVienID <> @SinhVienID
    BEGIN
        RAISERROR(N'Lỗi: Dòng mượn không thuộc về sinh viên yêu cầu trả.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.DongTra WHERE DongMuonID = @DongMuonID)
    BEGIN
        RAISERROR(N'Lỗi: Dòng mượn này đã được làm thủ tục trả trước đó.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.[Status] WHERE StatusID = @NewBookStatus)
    BEGIN
        RAISERROR(N'Lỗi: Trạng thái sách mới không hợp lệ.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.NhanVien WHERE NhanVienID = @NhanVienID)
    BEGIN
        RAISERROR(N'Lỗi: Nhân viên tiếp nhận không tồn tại.', 16, 1);
        RETURN;
    END

    -- =========================================================================
    -- PHASE 2: ATOMIC MUTATION
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
            SAVE TRANSACTION sp_LapPhieuTra_Inner;
        END

        -- 1. Tạo phiếu trả
        DECLARE @PhieuTraID INT;
        INSERT INTO dbo.PhieuTra (SinhVienID, NhanVienID, NgayTra)
        VALUES (@SinhVienID, @NhanVienID, @NgayTra);
        
        SET @PhieuTraID = SCOPE_IDENTITY();

        -- 2. Tạo dòng trả
        DECLARE @DongTraID INT;
        INSERT INTO dbo.DongTra (PhieuTraID, DongMuonID)
        VALUES (@PhieuTraID, @DongMuonID);
        
        SET @DongTraID = SCOPE_IDENTITY();

        -- 3. Cập nhật trạng thái sách
        UPDATE dbo.BookItem
        SET StatusID = @NewBookStatus
        WHERE BookItemID = @BookItemID;

        -- 4. Tính phạt trễ hạn nếu có
        IF (@NgayTra > @NgayHenTra)
        BEGIN
            DECLARE @DaysOverdue INT = DATEDIFF(DAY, @NgayHenTra, @NgayTra);
            DECLARE @LateRuleID INT;

            SELECT TOP 1 @LateRuleID = RuleID
            FROM dbo.FineRule
            WHERE RuleCode = 'LATE';

            IF @LateRuleID IS NOT NULL
            BEGIN
                DECLARE @LateFine DECIMAL(18, 2) = dbo.fn_CalculateFine(@LateRuleID, @DaysOverdue, @BookPrice, NULL);
                IF @LateFine > 0
                BEGIN
                    INSERT INTO dbo.DongPhat (FineRuleID, DongTraID, DongMuonID, Amount, Status, Description)
                    VALUES (@LateRuleID, @DongTraID, @DongMuonID, @LateFine, 'UNPAID', N'Trả trễ hạn ' + CAST(@DaysOverdue AS NVARCHAR(10)) + N' ngày');
                END
            END
        END

        -- 5. Tính phạt hỏng / mất sách nếu có
        IF (@NewBookStatus IN ('DAMAGED', 'LOST'))
        BEGIN
            DECLARE @ConditionRuleID INT;

            SELECT TOP 1 @ConditionRuleID = RuleID
            FROM dbo.FineRule
            WHERE RuleCode = @NewBookStatus;

            IF @ConditionRuleID IS NOT NULL
            BEGIN
                DECLARE @ConditionFine DECIMAL(18, 2) = dbo.fn_CalculateFine(@ConditionRuleID, 0, @BookPrice, NULL);
                IF @ConditionFine > 0
                BEGIN
                    INSERT INTO dbo.DongPhat (FineRuleID, DongTraID, DongMuonID, Amount, Status, Description)
                    VALUES (
                        @ConditionRuleID, 
                        @DongTraID, 
                        @DongMuonID, 
                        @ConditionFine, 
                        'UNPAID', 
                        CASE WHEN @NewBookStatus = 'DAMAGED' THEN N'Phạt làm hỏng sách' ELSE N'Phạt làm mất sách' END
                    );
                END
            END
        END

        IF @TranStarted = 1
        BEGIN
            COMMIT TRANSACTION;
        END

        SELECT @PhieuTraID AS PhieuTraID,
               @DongTraID AS DongTraID,
               N'Thành công' AS Message;
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
                ROLLBACK TRANSACTION sp_LapPhieuTra_Inner;
        END

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrState INT = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSeverity, @ErrState);
    END CATCH
END;
GO