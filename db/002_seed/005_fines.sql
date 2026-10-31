USE ThuVien2
-- Step 4.1: Hệ thống/Thủ thư tự động ghi nhận dòng phạt (Trễ 2 ngày x 5.000đ = 10.000đ)
INSERT INTO DongPhat (FineRuleID, DongTraID, Amount, Status, Description) VALUES 
(1, 1, 10000, 'UNPAID', N'Trễ hạn trả sách 2 ngày');

-- Step 4.2: Thủ thư thu tiền phạt và tạo Phiếu thu
INSERT INTO PhieuThu (NhanVienID, SinhVienID, NgayThu, Total) VALUES 
(1, '29210252479', '2026-10-10', 10000);

INSERT INTO DongThu (PhieuThuID, DongPhatID, SoTien) VALUES 
(1, 1, 10000);

-- Cập nhật trạng thái dòng phạt sang 'PAID'
UPDATE DongPhat SET Status = 'PAID' WHERE DongPhatID = 1;