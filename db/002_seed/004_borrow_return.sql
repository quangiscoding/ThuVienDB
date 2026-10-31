USE ThuVien2
-- Step 3.1: Sinh viên '29210252479' mượn cuốn sách Bill Gates (BookItemID = 3)
INSERT INTO PhieuMuon (SinhVienID, NgayMuon) VALUES 
('29210252479', '2026-10-01');

INSERT INTO DongMuon (BookItemID, BorrowingID, NgayHenTra) VALUES 
(3, 1, '2026-10-08');

-- Cập nhật trạng thái cuốn sách sang 'BORROWED'
UPDATE BookItem SET StatusID = 'BORROWED' WHERE BookItemID = 3;

-- Step 3.2: Sinh viên mang trả sách vào ngày 2026-10-10 (Bị trễ 2 ngày)
INSERT INTO PhieuTra (SinhVienID, NgayTra) VALUES 
('29210252479', '2026-10-10');

INSERT INTO DongTra (PhieuTraID, DongMuonID) VALUES 
(1, 1);

-- Đổi lại trạng thái kho thành 'AVAILABLE' sau khi trả xong
UPDATE BookItem SET StatusID = 'AVAILABLE' WHERE BookItemID = 3;