USE ThuVien2;
GO

-- Khởi tạo Test Class
EXEC tSQLt.NewTestClass 'test_circulation_LapPhieuMuon';
GO

-- =============================================================================
-- TEST CASE 1: Chặn khi mã sinh viên không tồn tại (Lỗi 50001)
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuMuon.[test_ChanMuon_KhiSinhVienKhongTonTai]
AS
BEGIN
    -- Arrange: Giả lập các bảng liên quan ở trạng thái rỗng
    EXEC tSQLt.FakeTable 'dbo.SinhVien';
    EXEC tSQLt.FakeTable 'dbo.BookItem';

    -- Expect: Phải ném mã lỗi 50001
    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 50001;

    -- Act: Gọi thủ tục với mã sinh viên không có trong bảng SinhVien
    EXEC dbo.sp_LapPhieuMuon @SinhVienID = 'SV_INVALID', @BookItemID = 1, @SoNgayMuon = 7;
END;
GO

-- =============================================================================
-- TEST CASE 2: Chặn khi sinh viên còn nợ phạt chưa thanh toán (Lỗi 50002)
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuMuon.[test_ChanMuon_KhiConNoPhatChuaDong]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.SinhVien';
    EXEC tSQLt.FakeTable 'dbo.PhieuTra';
    EXEC tSQLt.FakeTable 'dbo.DongTra';
    EXEC tSQLt.FakeTable 'dbo.DongPhat';
    EXEC tSQLt.FakeTable 'dbo.BookItem';

    -- Arrange: Sinh viên hợp lệ nhưng có dòng phạt UNPAID
    INSERT INTO dbo.SinhVien (SinhVienID) VALUES ('SV001');
    INSERT INTO dbo.PhieuTra (PhieuTraID, SinhVienID) VALUES (10, 'SV001');
    INSERT INTO dbo.DongTra (DongTraID, PhieuTraID) VALUES (100, 10);
    INSERT INTO dbo.DongPhat (DongTraID, Status) VALUES (100, 'UNPAID');

    -- Expect: Bị chặn với lỗi 50002
    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 50002;

    -- Act
    EXEC dbo.sp_LapPhieuMuon @SinhVienID = 'SV001', @BookItemID = 1, @SoNgayMuon = 7;
END;
GO

-- =============================================================================
-- TEST CASE 3: Chặn khi sinh viên đang nợ sách quá hạn chưa trả (Lỗi 50003)
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuMuon.[test_ChanMuon_KhiNoSachQuaHan]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.SinhVien';
    EXEC tSQLt.FakeTable 'dbo.PhieuMuon';
    EXEC tSQLt.FakeTable 'dbo.DongMuon';
    EXEC tSQLt.FakeTable 'dbo.DongTra';
    EXEC tSQLt.FakeTable 'dbo.DongPhat';
    EXEC tSQLt.FakeTable 'dbo.BookItem';

    INSERT INTO dbo.SinhVien (SinhVienID) VALUES ('SV001');
    
    -- Arrange: Có 1 cuốn sách mượn với ngày hẹn trả ở quá khứ và chưa có dòng trả
    INSERT INTO dbo.PhieuMuon (BorrowingID, SinhVienID) VALUES (1, 'SV001');
    INSERT INTO dbo.DongMuon (DongMuonID, BorrowingID, BookItemID, NgayHenTra)
    VALUES (11, 1, 99, DATEADD(DAY, -2, CAST(GETDATE() AS DATE)));

    -- Expect: Bị chặn với lỗi 50003
    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 50003;

    -- Act
    EXEC dbo.sp_LapPhieuMuon @SinhVienID = 'SV001', @BookItemID = 1, @SoNgayMuon = 7;
END;
GO

-- =============================================================================
-- TEST CASE 4: Chặn khi sinh viên đã đạt giới hạn 5 cuốn (Lỗi 50004)
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuMuon.[test_ChanMuon_KhiDaDatGioiHan5Cuon]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.SinhVien';
    EXEC tSQLt.FakeTable 'dbo.PhieuMuon';
    EXEC tSQLt.FakeTable 'dbo.DongMuon';
    EXEC tSQLt.FakeTable 'dbo.DongTra';
    EXEC tSQLt.FakeTable 'dbo.DongPhat';
    EXEC tSQLt.FakeTable 'dbo.BookItem';

    INSERT INTO dbo.SinhVien (SinhVienID) VALUES ('SV001');
    INSERT INTO dbo.PhieuMuon (BorrowingID, SinhVienID) VALUES (1, 'SV001');

    -- Arrange: Sinh viên đang mượn đủ 5 cuốn sách (chưa trả, vẫn trong hạn)
    INSERT INTO dbo.DongMuon (DongMuonID, BorrowingID, BookItemID, NgayHenTra)
    VALUES 
        (1, 1, 101, DATEADD(DAY, 5, CAST(GETDATE() AS DATE))),
        (2, 1, 102, DATEADD(DAY, 5, CAST(GETDATE() AS DATE))),
        (3, 1, 103, DATEADD(DAY, 5, CAST(GETDATE() AS DATE))),
        (4, 1, 104, DATEADD(DAY, 5, CAST(GETDATE() AS DATE))),
        (5, 1, 105, DATEADD(DAY, 5, CAST(GETDATE() AS DATE)));

    -- Expect: Bị chặn với lỗi 50004
    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 50004;

    -- Act
    EXEC dbo.sp_LapPhieuMuon @SinhVienID = 'SV001', @BookItemID = 106, @SoNgayMuon = 7;
END;
GO

-- =============================================================================
-- TEST CASE 5: Chặn khi cuốn sách không ở trạng thái AVAILABLE (Lỗi 50005)
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuMuon.[test_ChanMuon_KhiSachKhongSanSang]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.SinhVien';
    EXEC tSQLt.FakeTable 'dbo.PhieuMuon';
    EXEC tSQLt.FakeTable 'dbo.DongMuon';
    EXEC tSQLt.FakeTable 'dbo.DongTra';
    EXEC tSQLt.FakeTable 'dbo.DongPhat';
    EXEC tSQLt.FakeTable 'dbo.BookItem';

    INSERT INTO dbo.SinhVien (SinhVienID) VALUES ('SV001');
    -- Arrange: Sách đang ở trạng thái BORROWED hoặc LOST
    INSERT INTO dbo.BookItem (BookItemID, StatusID) VALUES (200, 'BORROWED');

    -- Expect: Bị chặn với lỗi 50005
    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 50005;

    -- Act
    EXEC dbo.sp_LapPhieuMuon @SinhVienID = 'SV001', @BookItemID = 200, @SoNgayMuon = 7;
END;
GO

-- =============================================================================
-- TEST CASE 6: Mượn thành công (Happy Path) -> Kiểm tra cập nhật bảng & trạng thái sách
-- =============================================================================
CREATE OR ALTER PROCEDURE test_circulation_LapPhieuMuon.[test_MuonThanhCong_CapNhatTrangThaiVaThemDongMuon]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.SinhVien';
    EXEC tSQLt.FakeTable 'dbo.PhieuMuon';
    EXEC tSQLt.FakeTable 'dbo.DongMuon';
    EXEC tSQLt.FakeTable 'dbo.DongTra';
    EXEC tSQLt.FakeTable 'dbo.DongPhat';
    EXEC tSQLt.FakeTable 'dbo.BookItem';

    INSERT INTO dbo.SinhVien (SinhVienID) VALUES ('SV001');
    INSERT INTO dbo.BookItem (BookItemID, StatusID) VALUES (300, 'AVAILABLE');

    -- Act: Mượn sách hợp lệ
    EXEC dbo.sp_LapPhieuMuon @SinhVienID = 'SV001', @BookItemID = 300, @SoNgayMuon = 7;

    -- Assert 1: Trạng thái của BookItem phải chuyển sang 'BORROWED'
    DECLARE @ActualBookStatus VARCHAR(20);
    SELECT @ActualBookStatus = StatusID FROM dbo.BookItem WHERE BookItemID = 300;
    EXEC tSQLt.AssertEqualsString 'BORROWED', @ActualBookStatus;

    -- Assert 2: Phải có đúng 1 dòng được thêm vào DongMuon cho cuốn sách 300
    DECLARE @DongMuonCount INT;
    SELECT @DongMuonCount = COUNT(1) FROM dbo.DongMuon WHERE BookItemID = 300;
    EXEC tSQLt.AssertEquals 1, @DongMuonCount;
END;
GO

USE ThuVien2;
GO
EXEC tSQLt.Run 'test_circulation_LapPhieuMuon';