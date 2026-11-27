# KHUNG SƯỜN BÁO CÁO ĐỒ ÁN MÔN HỌC — HỆ THỐNG QUẢN LÝ THƯ VIỆN (THUVIEN2)

---

## TRANG BÌA

`[CHÈN HÌNH ẢNH / THÔNG TIN TRANG BÌA: Tên trường, Khoa, Tên môn học IS 401 A, Tên đề tài "Hệ thống Quản lý Thư viện và Phân tích Dữ liệu Đa mô hình ThuVien2", Giảng viên hướng dẫn, Thành viên nhóm, Thời gian thực hiện]`

---

## MỤC LỤC

`[CHÈN MỤC LỤC TỰ ĐỘNG (Table of Contents)]`

---

## 1. Tổng quan bài toán

### 1.1 Mô tả đề tài & kiến trúc hệ thống

#### 1.1.1 Bối cảnh bài toán và mục tiêu hệ thống Quản lý Thư viện (ThuVien2)

#### 1.1.2 Kiến trúc tổng thể đa mô hình (SQL Server + MongoDB + Python Analytics)

`[CHÈN HÌNH ẢNH: Sơ đồ kiến trúc tổng thể hệ thống ThuVien2 kết nối SQL Server, MongoDB và Python]`

### 1.2 Mô tả các quy trình nghiệp vụ thực tế

#### 1.2.1 Quy trình quản lý danh mục đầu sách, tác giả và bản sao vật lý (`002_catalog`)

#### 1.2.2 Quy trình mượn sách và kiểm tra điều kiện độc giả (`sp_CreateLoanSlip`)

#### 1.2.3 Quy trình trả sách, cập nhật trạng thái và ghi nhận vi phạm (`sp_CreateReturnSlip`)

#### 1.2.4 Quy trình tính phạt, thu tiền phạt từng phần và miễn giảm phạt (`004_fines`)

#### 1.2.5 Quy trình ghi nhận nhật ký tương tác tần suất cao (Kiosk, OPAC, cổng RFID)

### 1.3 Xác định 10 yêu cầu nghiệp vụ phục vụ thống kê, phân tích

#### 1.3.1 Nhóm yêu cầu thống kê lưu thông & xu hướng mượn/trả (`vw_Report_DailyCirculation`, `vw_Report_MonthlyCirculationTrends`, `vw_Report_TopBorrowedTitles`, `sp_Report_CirculationByDateRange`)

#### 1.3.2 Nhóm yêu cầu kiểm soát tồn kho, quá hạn & thu hồi tiền phạt (`vw_Report_InventoryStatusSummary`, `vw_Report_OverdueLoans`, `vw_Report_FineSummaryByRule`)

#### 1.3.3 Nhóm yêu cầu đánh giá hoạt động sinh viên & hiệu suất nhân viên (`vw_Report_StudentActivityKPI`, `vw_Report_StaffWorkload`, `sp_Report_TopDelinquentStudents`)

---

## 2. Thiết kế và Quản trị CSDL Quan hệ (SQL Server)

### 2.1 Mô hình thực thể quan hệ (ERD)

#### 2.1.1 Xác định các thực thể, thuộc tính và mối quan hệ (16 bảng trong `ThuVien2`)

#### 2.1.2 Sơ đồ ERD mức khái niệm và mức vật lý

`[CHÈN HÌNH ẢNH: Sơ đồ ERD đầy đủ 16 bảng của CSDL ThuVien2]`

### 2.2 Lược đồ quan hệ & Chuẩn hóa

#### 2.2.1 Chuyển đổi từ ERD sang lược đồ quan hệ 100% chuẩn tiếng Anh (`Role`, `Staff`, `Student`, `BookTitle`, `BookItem`, `LoanSlip`, `LoanItem`, `ReturnSlip`, `ReturnItem`, `FineRule`, `FineItem`, `PaymentReceipt`, `PaymentItem`)

#### 2.2.2 Đánh giá mức độ chuẩn hóa (1NF, 2NF, 3NF) và tách thực thể kết nối (`Author_BookTitle`)

### 2.3 Ràng buộc toàn vẹn & Lựa chọn kiểu dữ liệu

#### 2.3.1 Ràng buộc khóa chính, khóa ngoại, duy nhất (`UNIQUE`) và miền giá trị (`CHECK` trên `Student.Status`, `BookItem.Price`, `FineRule`, `FineItem.Status`, `PaymentReceipt.ReceiptType`)

#### 2.3.2 Ràng buộc toàn vẹn nghiệp vụ đặc thù (`CK_FineItem_Link` XOR giữa `ReturnItemID` và `LoanItemID`, `UQ_ReturnItem_LoanItem`)

`[DÁN ĐOẠN CODE: Trích đoạn DDL các ràng buộc CHECK và FOREIGN KEY tiêu biểu trong db/001_schema/001_create-schema.sql]`

### 2.4 Trực quan hóa và Triển khai trên SQL Server

#### 2.4.1 Thiết kế CSDL và kịch bản khởi tạo tự động (`db/001_schema/`, `scripts/01_reset_schema.bat`)

`[CHÈN HÌNH ẢNH: Database Diagram trực quan trong SQL Server Management Studio (SSMS)]`

#### 2.4.2 Tự động tạo dữ liệu giả lập (`db/002_seed/` và `scripts/seed_bulk_sql.py` với ~45 sinh viên, ~25 đầu sách, ~85 bản sao, ~300+ giao dịch 6 tháng)

`[DÁN ĐOẠN CODE: Kết quả chạy scripts/setup_all.bat và scripts/seed_bulk_sql.py]`

`[CHÈN HÌNH ẢNH: Ảnh chụp kết quả kiểm tra số lượng bản ghi các bảng trong SSMS]`

#### 2.4.3 Xây dựng Function, Stored Procedure và 10 View/Procedure báo cáo (`db/003_program/` và `db/tests/`)

`[DÁN ĐOẠN CODE: Hàm dbo.fn_CalculateFine và thủ tục dbo.sp_CreateLoanSlip / dbo.sp_CreateReturnSlip]`

`[DÁN ĐOẠN CODE: Một số View/Procedure báo cáo tiêu biểu trong db/003_program/005_reports/]`

`[CHÈN HÌNH ẢNH: Kết quả chạy kiểm thử các test script trong db/tests/ (PASS toàn bộ)]`

---

## 3. Lưu trữ Dữ liệu phi cấu trúc (NoSQL - MongoDB)

### 3.1 Cấu trúc Document JSON lưu trữ log tần suất cao

#### 3.1.1 Lý do lựa chọn MongoDB cho nhật ký sự kiện (`ThuVien2Logs.library_event_logs`)

#### 3.1.2 Thiết kế cấu trúc Document JSON cho 3 loại sự kiện (`KIOSK_SCAN`, `CATALOG_SEARCH`, `RFID_GATE_PING`)

`[DÁN ĐOẠN CODE: Nội dung file mẫu nosql/sample_logs.json]`

#### 3.1.3 Chiến lược bảo toàn khóa liên kết chéo (`StudentCode`, `Barcode`) và đánh chỉ mục (`Index`)

### 3.2 Kịch bản sinh dữ liệu tự động và đẩy vào MongoDB

#### 3.2.1 Luồng truy vấn khóa thực từ SQL Server và phân phối trọng số Zipf trong `nosql/generate_logs.py`

`[DÁN ĐOẠN CODE: Đoạn mã Python kết nối pyodbc + pymongo và hàm sinh log trong nosql/generate_logs.py]`

#### 3.2.2 Thực thi sinh 8.000 bản ghi log vào MongoDB và kiểm chứng chỉ mục

`[CHÈN HÌNH ẢNH: Kết quả chạy py nosql/generate_logs.py và giao diện MongoDB Compass hiển thị collection library_event_logs (8,000 documents)]`

#### 3.2.3 Kiểm tra tính khớp khóa liên kết giữa MongoDB và SQL Server

---

## 4. Xử lý và Phân tích Dữ liệu lớn (Big Data Analytics)

### 4.1 Luồng kết nối, đối chiếu và gộp dữ liệu bằng Python

#### 4.1.1 Kiến trúc pipeline phân tích trong `analytics/join_and_analyze.py` (`pyodbc`, `pymongo`, `pandas`)

`[DÁN ĐOẠN CODE: Đoạn mã đọc dữ liệu từ SQL Server, MongoDB và thực hiện pandas merge trên Barcode & StudentCode]`

#### 4.1.2 Kết quả đối chiếu và làm sạch tập dữ liệu gộp (8.000/8.000 dòng khớp khóa)

`[CHÈN HÌNH ẢNH: Console output khi chạy py analytics/join_and_analyze.py]`

### 4.2 Trực quan hóa và ý nghĩa nghiệp vụ

#### 4.2.1 Biểu đồ 1: Top 10 đầu sách — Nhu cầu tìm kiếm/quét số so với độ sẵn sàng bản sao vật lý (`01_search_demand_vs_availability.png`)

`[CHÈN HÌNH ẢNH: analytics/charts/01_search_demand_vs_availability.png]`

#### 4.2.2 Biểu đồ 2: Lưu lượng quét Kiosk theo khung giờ và tỷ lệ kết quả giao dịch (`02_kiosk_hourly_traffic_vs_checkouts.png`)

`[CHÈN HÌNH ẢNH: analytics/charts/02_kiosk_hourly_traffic_vs_checkouts.png]`

#### 4.2.3 Biểu đồ 3: Top 10 độc giả tích cực — Mức độ tương tác so với dư nợ tiền phạt và trạng thái tài khoản (`03_student_engagement_vs_delinquency.png`)

`[CHÈN HÌNH ẢNH: analytics/charts/03_student_engagement_vs_delinquency.png]`

#### 4.2.4 Biểu đồ 4: Cơ cấu thu hồi tiền phạt theo quy tắc (`LATE`, `LOST`, `DAMAGED`) và cảnh báo cổng RFID (`04_fine_revenue_and_recovery_breakdown.png`)

`[CHÈN HÌNH ẢNH: analytics/charts/04_fine_revenue_and_recovery_breakdown.png]`

---

## 5. Kết luận và Hướng phát triển

### 5.1 Kết quả đạt được

### 5.2 Hướng phát triển tiếp theo
