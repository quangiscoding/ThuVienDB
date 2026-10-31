USE ThuVien2;
GO

CREATE OR ALTER PROCEDURE dbo.sp_LapPhieuTra
    @SinhVienID INT,                         -- Khóa chính SinhVienID (INT)
    @NhanVienID INT,                         -- Thủ thư tiếp nhận trả sách (INT NOT NULL trong PhieuTra)
    @DongMuonID INT,
    @NewBookStatus VARCHAR(20) = 'AVAILABLE', -- Phải tồn tại trong dbo.Status
    @NgayTra DATE = NULL                     -- Mặc định là ngày hiện tại nếu NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Mặc định ngày trả là hôm nay nếu không truyền
    IF @NgayTra IS NULL 
        SET @NgayTra = CAST(GETDATE() AS DATE);

    -- =========================================================================
    -- PHASE 1: PRE-VALIDATION (Pure reads, NO open transaction)
    -- =========================================================================
    DECLARE @BookItemID INT, 
            @NgayHenTra DATE, 
            @BookPrice DECIMAL(18, 2), 
            @OwnerSinhVienID INT;

    SELECT 
        @BookItemID = dm.BookItemID,
        @NgayHenTra = dm.NgayHenTra,
        @BookPrice = bi.Price,
        @OwnerSinhVienID = pm.SinhVienID
    FROM dbo.DongMuon dm
    JOIN dbo.PhieuMuon pm ON dm.BorrowingID = pm.BorrowingID
    JOIN dbo.BookItem bi ON dm.BookItemID = bi.BookItemID
    WHERE dm.DongMuonID = @DongMuonID;

    -- 1. Kiểm tra dòng mượn có tồn tại
    IF @BookItemID IS NULL
    BEGIN
        ;THROW 51001, N'Lỗi: Dòng mượn không tồn tại trong hệ thống.', 1;
    END;

    -- 2. Kiểm tra sinh viên có đúng là người đã mượn
    IF @OwnerSinhVienID <> @SinhVienID
    BEGIN
        ;THROW 51002, N'Lỗi: Dòng mượn không thuộc về sinh viên yêu cầu trả.', 1;
    END;

    -- 3. Kiểm tra sách đã được trả trước đó chưa
    IF EXISTS (SELECT 1 FROM dbo.DongTra WHERE DongMuonID = @DongMuonID)
    BEGIN
        ;THROW 51003, N'Lỗi: Dòng mượn này đã được làm thủ tục trả trước đó.', 1;
    END;

    -- 4. Kiểm tra trạng thái sách hợp lệ
    IF NOT EXISTS (SELECT 1 FROM dbo.[Status] WHERE StatusID = @NewBookStatus)
    BEGIN
        ;THROW 51004, N'Lỗi: Trạng thái sách mới không hợp lệ.', 1;
    END;

    -- 5. Kiểm tra nhân viên tiếp nhận tồn tại
    IF NOT EXISTS (SELECT 1 FROM dbo.NhanVien WHERE NhanVienID = @NhanVienID)
    BEGIN
        ;THROW 51005, N'Lỗi: Nhân viên tiếp nhận không tồn tại.', 1;
    END;

    -- =========================================================================
    -- PHASE 2: ATOMIC MUTATION (Nested-transaction safe)
    -- =========================================================================
    DECLARE @TranStarted BIT = 0;

    BEGIN TRY
        IF @@TRANCOUNT = 0
        BEGIN
            BEGIN TRANSACTION;
            SET @TranStarted = 1;
        END;
        ELSE
        BEGIN
            SAVE TRANSACTION sp_LapPhieuTra_Inner;
        END;

        -- 1. Tạo phiếu trả (Bao gồm cả NhanVienID)
        DECLARE @PhieuTraID INT;
        INSERT INTO dbo.PhieuTra (SinhVienID, NhanVienID, NgayTra)
        VALUES (@SinhVienID, @NhanVienID, @NgayTra);
        SET @PhieuTraID = SCOPE_IDENTITY();

        -- 2. Tạo chi tiết dòng trả
        DECLARE @DongTraID INT;
        INSERT INTO dbo.DongTra (PhieuTraID, DongMuonID)
        VALUES (@PhieuTraID, @DongMuonID);
        SET @DongTraID = SCOPE_IDENTITY();

        -- 3. Cập nhật trạng thái sách trong kho
        UPDATE dbo.BookItem 
        SET StatusID = @NewBookStatus 
        WHERE BookItemID = @BookItemID;

        -- 4. Tính phạt trễ hạn nếu trả sau NgayHenTra
        IF (@NgayTra > @NgayHenTra)
        BEGIN
            DECLARE @DaysOverdue INT = DATEDIFF(DAY, @NgayHenTra, @NgayTra);
            DECLARE @LateRuleID INT;

            SELECT TOP 1 @LateRuleID = RuleID 
            FROM dbo.FineRule 
            WHERE RatePerDay > 0
            ORDER BY RuleID ASC;

            IF @LateRuleID IS NOT NULL
            BEGIN
                DECLARE @LateFine DECIMAL(18, 2) = dbo.fn_CalculateFine(@LateRuleID, @DaysOverdue, @BookPrice);
                
                IF @LateFine > 0
                BEGIN
                    INSERT INTO dbo.DongPhat (FineRuleID, DongTraID, DongMuonID, Amount, Status, Description)
                    VALUES (
                        @LateRuleID, 
                        @DongTraID, 
                        @DongMuonID,
                        @LateFine, 
                        'UNPAID', 
                        N'Trả trễ hạn ' + CAST(@DaysOverdue AS NVARCHAR(10)) + N' ngày'
                    );
                END;
            END;
        END;

        -- 5. Tính phạt hỏng / mất sách nếu có
        IF (@NewBookStatus IN ('DAMAGED', 'LOST'))
        BEGIN
            DECLARE @ConditionRuleID INT;

            SELECT TOP 1 @ConditionRuleID = RuleID 
            FROM dbo.FineRule 
            WHERE (@NewBookStatus = 'DAMAGED' AND (RuleName LIKE N'%hỏng%' OR RuleName LIKE N'%damage%'))
               OR (@NewBookStatus = 'LOST' AND (RuleName LIKE N'%mất%' OR RuleName LIKE N'%lost%'))
            ORDER BY RuleID ASC;

            IF @ConditionRuleID IS NOT NULL
            BEGIN
                DECLARE @ConditionFine DECIMAL(18, 2) = dbo.fn_CalculateFine(@ConditionRuleID, 0, @BookPrice);
                
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
                END;
            END;
        END;

        IF @TranStarted = 1
        BEGIN
            COMMIT TRANSACTION;
        END;

        SELECT 
            @PhieuTraID AS PhieuTraID, 
            @DongTraID AS DongTraID, 
            N'Thành công' AS Message;
    END TRY
    BEGIN CATCH
        IF @TranStarted = 1
        BEGIN
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        END;
        ELSE
        BEGIN
            IF XACT_STATE() = 1
                ROLLBACK TRANSACTION sp_LapPhieuTra_Inner;
        END;

        -- Đặt dấu chấm phẩy trước THROW để tránh lỗi cú pháp 102
        ;THROW;
    END CATCH;
END;
GO