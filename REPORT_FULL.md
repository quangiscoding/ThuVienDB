# BÁO CÁO ĐỒ ÁN MÔN HỌC — HỆ THỐNG QUẢN LÝ THƯ VIỆN VÀ PHÂN TÍCH DỮ LIỆU ĐA MÔ HÌNH (THUVIEN2)

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

Trong môi trường thư viện đại học hiện đại, hệ thống quản lý không chỉ dừng lại ở việc lưu trữ danh mục sách và ghi nhận giao dịch mượn – trả truyền thống, mà còn phải xử lý đồng thời hai nhóm dữ liệu có bản chất khác nhau:

1. **Dữ liệu giao dịch có cấu trúc chặt chẽ (OLTP):** Quản lý danh mục đầu sách (`BookTitle`), bản sao vật lý theo mã vạch (`BookItem.Barcode`), hồ sơ sinh viên (`Student`), nhân viên (`Staff`), phiếu mượn – trả (`LoanSlip`, `ReturnSlip`), công thức tính phạt (`FineRule`), sổ cái tiền phạt (`FineItem`) và biên lai thu/miễn giảm (`PaymentReceipt`, `PaymentItem`). Dữ liệu này đòi hỏi tính toàn vẹn tham chiếu tuyệt đối và tính nguyên tử giao dịch (ACID).
2. **Dữ liệu nhật ký tương tác tần suất cao (High-Frequency Event Logs):** Ghi nhận hàng nghìn lượt quét mã vạch tại Kiosk tự phục vụ (`KIOSK_SCAN`), lượt tìm kiếm trên cổng tra cứu trực tuyến (`CATALOG_SEARCH`) và tín hiệu kiểm soát an ninh tại cổng từ RFID (`RFID_GATE_PING`).

Mục tiêu của đồ án **ThuVien2** là xây dựng một hệ thống lai (Hybrid Database Architecture) kết hợp **Microsoft SQL Server** cho tầng nghiệp vụ lõi (Database-first) và **MongoDB** cho tầng lưu trữ nhật ký phi cấu trúc, sau đó sử dụng **Python (`pandas`, `matplotlib`, `seaborn`)** để đối chiếu, gộp dữ liệu đa nguồn và trực quan hóa các chỉ số hỗ trợ ra quyết định.

#### 1.1.2 Kiến trúc tổng thể đa mô hình (SQL Server + MongoDB + Python Analytics)

Hệ thống được tổ chức thành 3 tầng xử lý liên thông với nhau thông qua khóa nghiệp vụ chung (`StudentCode` và `Barcode`):

- **Tầng CSDL Quan hệ (`ThuVien2` trên SQL Server):** Gồm 16 bảng chuẩn hóa 3NF, 1 hàm tính phạt (`fn_CalculateFine`), 11 thủ tục lưu trữ (`Stored Procedures`) chia theo 5 phân hệ (`001_shared`, `002_catalog`, `003_circulation`, `004_fines`, `005_reports`), cùng 8 `VIEW` phân tích và bộ kiểm thử T-SQL tự động trong `db/tests/`.
- **Tầng CSDL NoSQL (`ThuVien2Logs` trên MongoDB):** Lưu trữ collection `library_event_logs` với 8.000 tài liệu JSON được sinh tự động từ `nosql/generate_logs.py` dựa trên danh sách `StudentCode` và `Barcode` thực tế truy vấn trực tiếp từ SQL Server.
- **Tầng Phân tích Dữ liệu (`analytics/join_and_analyze.py`):** Kết nối đồng thời tới SQL Server (qua `pyodbc`) và MongoDB (qua `pymongo`), nạp dữ liệu vào `pandas.DataFrame`, thực hiện phép gộp (`merge`) theo `Barcode` và `StudentCode`, và xuất 4 biểu đồ trực quan định dạng `.png` vào `analytics/charts/`.

`[CHÈN HÌNH ẢNH: Sơ đồ kiến trúc tổng thể hệ thống ThuVien2 kết nối SQL Server, MongoDB và Python]`

### 1.2 Mô tả các quy trình nghiệp vụ thực tế

#### 1.2.1 Quy trình quản lý danh mục đầu sách, tác giả và bản sao vật lý (`002_catalog`)

Thủ thư thực hiện thêm mới đầu sách thông qua `dbo.sp_AddBookTitle`, liên kết một hoặc nhiều tác giả trong bảng trung gian `dbo.Author_BookTitle`. Sau đó, từng cuốn sách vật lý được nhập kho bằng `dbo.sp_AddBookCopies` với mã vạch (`Barcode`) duy nhất, giá trị thay thế (`Price >= 0`) và trạng thái mặc định `'AVAILABLE'`. Khi kiểm kê kho, thủ thư có thể điều chỉnh trạng thái bản sao sang `'AVAILABLE'`, `'DAMAGED'` hoặc `'LOST'` thông qua `dbo.sp_UpdateCopyStatus` (ngăn chặn gán thủ công trạng thái `'BORROWED'`), đồng thời tra cứu tổng hợp tồn kho theo từ khóa qua `dbo.sp_SearchCatalog`.

#### 1.2.2 Quy trình mượn sách và kiểm tra điều kiện độc giả (`sp_CreateLoanSlip`)

Khi sinh viên mang sách tới quầy hoặc Kiosk, thủ tục `dbo.sp_CreateLoanSlip` thực hiện 5 bước kiểm tra tiền điều kiện trước khi ghi nhận giao dịch:
1. Sinh viên tồn tại theo `@StudentCode` và có `Student.Status = 'ACTIVE'` (nếu không, ném lỗi `50001`).
2. Nhân viên tiếp nhận `@StaffID` tồn tại trong `dbo.Staff`.
3. Sinh viên không còn khoản phạt nào ở trạng thái `'UNPAID'` hoặc `'PARTIAL'` trong `dbo.FineItem`, kiểm tra trên **cả hai nhánh** liên kết: phạt từ trả sách (`ReturnItemID`) và phạt mất sách (`LoanItemID`) (lỗi `50002`).
4. Sinh viên không có sách đang mượn quá hạn (`DueDate < GETDATE()` chưa có `ReturnItem`) (lỗi `50003`).
5. Tổng số sách đang mượn chưa trả nhỏ hơn giới hạn tối đa **3 cuốn** (lỗi `50004`).

Nếu đạt mọi điều kiện và bản sao đang ở trạng thái `'AVAILABLE'` (lỗi `50005` nếu không sẵn sàng), hệ thống cập nhật `BookItem.StatusID = 'BORROWED'`, tạo `LoanSlip` và `LoanItem` với hạn trả mặc định 14 ngày.

#### 1.2.3 Quy trình trả sách, cập nhật trạng thái và ghi nhận vi phạm (`sp_CreateReturnSlip`)

Khi trả sách, `dbo.sp_CreateReturnSlip` xác thực `LoanItemID` tồn tại, thuộc về đúng `@StudentID` và chưa từng được trả trong `dbo.ReturnItem` (lỗi `50006`). Trong cùng một giao dịch nguyên tử, thủ tục tạo `ReturnSlip` và `ReturnItem`, cập nhật `BookItem.StatusID` theo `@NewBookStatus` (`'AVAILABLE'`, `'DAMAGED'`, hoặc `'LOST'`), và gọi `dbo.fn_CalculateFine` để tự động phát sinh `FineItem`:
- Nếu `ReturnDate > DueDate`: tính phạt `'LATE'` theo số ngày trễ và gắn vào `ReturnItemID` (`LoanItemID = NULL`).
- Nếu `'DAMAGED'`: tính phạt hư hỏng (có thể ghi đè tỷ lệ `@CustomDamagePercent` trong `(0, 1]`) và gắn vào `ReturnItemID`.
- Nếu `'LOST'`: tính phạt bồi thường 100% giá sách + phí xử lý và gắn trực tiếp vào `LoanItemID` (`ReturnItemID = NULL`) để tuân thủ ràng buộc XOR `CK_FineItem_Link`.

#### 1.2.4 Quy trình tính phạt, thu tiền phạt từng phần và miễn giảm phạt (`004_fines`)

Hệ thống hỗ trợ theo dõi công nợ linh hoạt qua 3 thủ tục:
- `dbo.sp_GetStudentFineBalance`: Trả về chi tiết từng khoản phạt `'UNPAID'`/`'PARTIAL'` (kèm `BookTitle`, `Barcode`, số tiền đã đóng và dư nợ còn lại) cùng dòng tổng hợp dư nợ của sinh viên.
- `dbo.sp_RecordFinePayment`: Tạo `PaymentReceipt` (`ReceiptType = 'PAYMENT'`) và `PaymentItem`, hỗ trợ **đóng phạt nhiều lần (partial payment)**. Nếu `AmountPaid > RemainingBalance`, thủ tục từ chối giao dịch với mã lỗi `50007`; ngược lại cập nhật `FineItem.Status` thành `'PARTIAL'` hoặc `'PAID'`.
- `dbo.sp_WaiveFine`: Cho phép nhân viên có vai trò `'ADMIN'` (kiểm tra `RoleID = 'ADMIN'`, lỗi `50020` nếu không đủ quyền) miễn giảm phần dư nợ còn lại, đồng thời vẫn ghi nhận một biên lai `ReceiptType = 'WAIVER'` và chuyển `FineItem.Status` sang `'WAIVED'` để đảm bảo tính kiểm toán.

#### 1.2.5 Quy trình ghi nhận nhật ký tương tác tần suất cao (Kiosk, OPAC, cổng RFID)

Song song với các giao dịch tài chính/lưu thông trên SQL Server, mọi sự kiện tương tác vi mô của độc giả — bao gồm quét mã vạch tại Kiosk tự động (`SELF_CHECKOUT_ATTEMPT`, `SELF_RETURN_SCAN`, `BARCODE_LOOKUP`), tìm kiếm từ khóa trên OPAC (`OPAC_KEYWORD_SEARCH`) và quét thẻ tại cổng từ (`EXIT_GATE_CHECK`) — được đẩy trực tiếp vào MongoDB dưới dạng document JSON chứa `StudentCode` và `Barcode`.

### 1.3 Xác định 10 yêu cầu nghiệp vụ phục vụ thống kê, phân tích

#### 1.3.1 Nhóm yêu cầu thống kê lưu thông & xu hướng mượn/trả
1. **`vw_Report_DailyCirculation`:** Thống kê số lượt mượn, số lượt trả và biến động sách đang lưu thông ròng (`NetActiveLoanDelta`) theo từng ngày.
2. **`vw_Report_MonthlyCirculationTrends`:** Phân tích xu hướng mượn/trả theo tháng (`yyyy-MM`) kèm số lượt trả trễ và tỷ lệ trả trễ (`LateReturnRatePct`).
3. **`vw_Report_TopBorrowedTitles`:** Xếp hạng các đầu sách được mượn nhiều nhất kèm danh sách tác giả, tổng số bản sao và số bản đang sẵn sàng (`AvailableCopies`).
4. **`sp_Report_CirculationByDateRange`:** Báo cáo tổng hợp theo khoảng thời gian tùy chọn (`@StartDate`, `@EndDate`) về tổng lượt mượn, lượt trả, lượt trả trễ, doanh thu tiền phạt đã thu và tổng tiền đã miễn giảm.

#### 1.3.2 Nhóm yêu cầu kiểm soát tồn kho, quá hạn & thu hồi tiền phạt
5. **`vw_Report_InventoryStatusSummary`:** Thống kê số lượng bản sao và tổng giá trị tài sản sách phân theo trạng thái (`AVAILABLE`, `BORROWED`, `DAMAGED`, `LOST`).
6. **`vw_Report_OverdueLoans`:** Danh sách chi tiết các sách đang mượn quá hạn chưa trả (`DueDate < GETDATE()`), số ngày quá hạn (`DaysOverdue`) và thông tin liên hệ sinh viên để nhắc trả.
7. **`vw_Report_FineSummaryByRule`:** Tổng hợp công nợ tiền phạt theo từng loại quy tắc (`LATE`, `LOST`, `DAMAGED`): tổng phạt đã ghi nhận, đã thu (`PAYMENT`), đã miễn giảm (`WAIVER`) và còn tồn đọng (`TotalOutstanding`).

#### 1.3.3 Nhóm yêu cầu đánh giá hoạt động sinh viên & hiệu suất nhân viên
8. **`vw_Report_StudentActivityKPI`:** Hồ sơ KPI của từng sinh viên gồm tổng lượt mượn, số sách đang giữ, số lần trả trễ, tổng tiền phạt, đã thanh toán và dư nợ hiện tại.
9. **`vw_Report_StaffWorkload`:** Đánh giá khối lượng xử lý công việc của từng nhân viên (`LoanSlipCount`, `ReturnSlipCount`, `PaymentReceiptCount`, `TotalActions`).
10. **`sp_Report_TopDelinquentStudents`:** Xếp hạng Top N sinh viên có dư nợ tiền phạt và số lần vi phạm quá hạn cao nhất để hỗ trợ xử lý học vụ.

---

## 2. Thiết kế và Quản trị CSDL Quan hệ (SQL Server)

### 2.1 Mô hình thực thể quan hệ (ERD)

#### 2.1.1 Xác định các thực thể, thuộc tính và mối quan hệ (16 bảng trong `ThuVien2`)

CSDL `ThuVien2` gồm 16 bảng được phân thành 6 cụm thực thể chính:
- **Nhân sự & Phân quyền:** `Role` (1–N) `Staff`.
- **Độc giả:** `Student` (quản lý `StudentCode` duy nhất và `Status`).
- **Danh mục & Kho sách:** `Author` (N–N) `BookTitle` qua `Author_BookTitle`; `BookTitle` (1–N) `BookItem`; `Status` (1–N) `BookItem`.
- **Mượn sách:** `Student` & `Staff` (1–N) `LoanSlip`; `LoanSlip` (1–N) `LoanItem`; `BookItem` (1–N) `LoanItem`.
- **Trả sách:** `Student` & `Staff` (1–N) `ReturnSlip`; `ReturnSlip` (1–N) `ReturnItem`; `LoanItem` (1–1) `ReturnItem` (ràng buộc `UQ_ReturnItem_LoanItem`).
- **Phạt & Biên lai:** `FineRule` (1–N) `FineItem`; `FineItem` liên kết XOR với `ReturnItem` hoặc `LoanItem`; `Student` & `Staff` (1–N) `PaymentReceipt`; `PaymentReceipt` (1–N) `PaymentItem`; `FineItem` (1–N) `PaymentItem`.

#### 2.1.2 Sơ đồ ERD mức khái niệm và mức vật lý

`[CHÈN HÌNH ẢNH: Sơ đồ ERD đầy đủ 16 bảng của CSDL ThuVien2]`

### 2.2 Lược đồ quan hệ & Chuẩn hóa

#### 2.2.1 Chuyển đổi từ ERD sang lược đồ quan hệ 100% chuẩn tiếng Anh

Toàn bộ lược đồ được chuẩn hóa đặt tên theo quy ước **English PascalCase** thống nhất giữa tầng CSDL và tầng phân tích:
- `dbo.Role(RoleID, RoleTitle)`
- `dbo.Staff(StaffID, StaffCode, RoleID, FullName, Email)`
- `dbo.Student(StudentID, StudentCode, FullName, ClassName, Email, Status)`
- `dbo.Status(StatusID, StatusName)`
- `dbo.Author(AuthorID, AuthorName)`
- `dbo.BookTitle(TitleID, BookTitle)`
- `dbo.Author_BookTitle(Author_BookTitle_ID, AuthorID, TitleID)`
- `dbo.BookItem(BookItemID, Barcode, TitleID, StatusID, Price)`
- `dbo.LoanSlip(LoanSlipID, StudentID, StaffID, LoanDate)`
- `dbo.LoanItem(LoanItemID, BookItemID, LoanSlipID, DueDate)`
- `dbo.ReturnSlip(ReturnSlipID, StudentID, StaffID, ReturnDate)`
- `dbo.ReturnItem(ReturnItemID, ReturnSlipID, LoanItemID)`
- `dbo.FineRule(RuleID, RuleCode, RuleName, RatePerDay, PercentOfBookValue, FixedProcessingFee)`
- `dbo.FineItem(FineItemID, FineRuleID, ReturnItemID, LoanItemID, Amount, Status, Description)`
- `dbo.PaymentReceipt(ReceiptID, StaffID, StudentID, PaymentDate, ReceiptType, Total)`
- `dbo.PaymentItem(PaymentItemID, ReceiptID, FineItemID, AmountPaid)`

#### 2.2.2 Đánh giá mức độ chuẩn hóa (1NF, 2NF, 3NF) và tách thực thể kết nối (`Author_BookTitle`)

- **Đạt 1NF:** Mọi thuộc tính đều mang giá trị nguyên tố; quan hệ nhiều-nhiều giữa `Author` và `BookTitle` được tách thành bảng kết nối `Author_BookTitle` với ràng buộc `UQ_Author_Title (AuthorID, TitleID)`. Một phiếu mượn/trả/thu có nhiều đầu mục được tách thành cặp Header–Detail (`LoanSlip`–`LoanItem`, `ReturnSlip`–`ReturnItem`, `PaymentReceipt`–`PaymentItem`).
- **Đạt 2NF:** Mọi bảng đều sử dụng khóa chính đơn (`IDENTITY` hoặc mã định danh đơn), không tồn tại phụ thuộc hàm bộ phận.
- **Đạt 3NF:** Không có phụ thuộc bắc cầu giữa các thuộc tính không khóa (ví dụ thông tin `BookTitle` và `Price` tách biệt khỏi `LoanItem`, chính sách phạt tách thành `FineRule` riêng khỏi `FineItem`).

### 2.3 Ràng buộc toàn vẹn & Lựa chọn kiểu dữ liệu

#### 2.3.1 Ràng buộc khóa chính, khóa ngoại, duy nhất (`UNIQUE`) và miền giá trị (`CHECK`)

- Các giá trị tiền tệ (`Price`, `RatePerDay`, `FixedProcessingFee`, `Amount`, `Total`, `AmountPaid`) sử dụng kiểu `DECIMAL(18, 2)` để tránh sai số dấu phẩy động của `FLOAT`, kết hợp `CHECK (... >= 0)` và `NOT NULL` trên `BookItem.Price` nhằm đảm bảo công thức tính phạt mất/hỏng sách luôn chính xác.
- Các trạng thái và phân loại nghiệp vụ sử dụng `VARCHAR(20)` kết hợp `CHECK`:
  - `CK_Student_Status`: `Status IN ('ACTIVE', 'SUSPENDED', 'EXPIRED')`
  - `CK_FineItem_Status`: `Status IN ('UNPAID', 'PARTIAL', 'PAID', 'WAIVED')`
  - `CK_PaymentReceipt_Type`: `ReceiptType IN ('PAYMENT', 'WAIVER')`
- Các mã định danh nghiệp vụ dùng làm khóa kết nối đa CSDL (`Student.StudentCode`, `BookItem.Barcode`, `Staff.StaffCode`) được gắn ràng buộc `NOT NULL UNIQUE`.

#### 2.3.2 Ràng buộc toàn vẹn nghiệp vụ đặc thù (`CK_FineItem_Link` XOR và `UQ_ReturnItem_LoanItem`)

- **`UQ_ReturnItem_LoanItem`:** Đảm bảo mỗi dòng mượn (`LoanItemID`) chỉ có thể xuất hiện tối đa 1 lần trong `ReturnItem` (chống trả trùng lặp).
- **`CK_FineRule_Components` & `CK_FineRule_Percent`:** Ép buộc quy tắc `'LATE'` chỉ được dùng `RatePerDay`, trong khi `'LOST'` và `'DAMAGED'` chỉ được dùng `PercentOfBookValue` trong khoảng `(0, 1]`.
- **`CK_FineItem_Link` (ràng buộc XOR):** Một dòng phạt phải gắn **hoặc** với dòng trả (`ReturnItemID IS NOT NULL AND LoanItemID IS NULL` cho phạt `'LATE'`/`'DAMAGED'`) **hoặc** gắn trực tiếp với dòng mượn (`ReturnItemID IS NULL AND LoanItemID IS NOT NULL` cho phạt `'LOST'` khi sách không bao giờ được trả lại), tuyệt đối không được đồng thời có cả hai hoặc thiếu cả hai.

```sql
-- Trích đoạn từ db/001_schema/001_create-schema.sql
CREATE TABLE dbo.FineItem (
    FineItemID INT IDENTITY(1,1) PRIMARY KEY,
    FineRuleID INT NOT NULL,
    ReturnItemID INT NULL,
    LoanItemID INT NULL,
    Amount DECIMAL(18, 2) NOT NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'UNPAID',
    Description NVARCHAR(255),
    FOREIGN KEY (FineRuleID) REFERENCES dbo.FineRule(RuleID),
    FOREIGN KEY (ReturnItemID) REFERENCES dbo.ReturnItem(ReturnItemID),
    FOREIGN KEY (LoanItemID) REFERENCES dbo.LoanItem(LoanItemID),
    CONSTRAINT CK_FineItem_Link CHECK (
        (ReturnItemID IS NOT NULL AND LoanItemID IS NULL)
     OR (ReturnItemID IS NULL     AND LoanItemID IS NOT NULL)
    ),
    CONSTRAINT CK_FineItem_Status CHECK (Status IN ('UNPAID', 'PARTIAL', 'PAID', 'WAIVED')),
    CONSTRAINT CK_FineItem_Amount CHECK (Amount >= 0)
);
```

### 2.4 Trực quan hóa và Triển khai trên SQL Server

#### 2.4.1 Thiết kế CSDL và kịch bản khởi tạo tự động (`db/001_schema/`, `scripts/01_reset_schema.bat`)

Quy trình DDL được tách thành 3 script độc lập trong `db/001_schema/`: `001_create-schema.sql` (tạo mới), `002_drop-schema.sql` (xóa bảng theo thứ tự phụ thuộc ngược), và `003_delete-schema-data.sql` (xóa sạch dữ liệu và `DBCC CHECKIDENT RESEED`). Script `scripts/01_reset_schema.bat` tự động hóa việc kiểm tra tồn tại CSDL `ThuVien2`, xóa cấu trúc cũ và tái tạo lại toàn bộ 16 bảng với cờ `sqlcmd -b` dừng ngay nếu phát sinh lỗi.

`[CHÈN HÌNH ẢNH: Database Diagram trực quan trong SQL Server Management Studio (SSMS)]`

#### 2.4.2 Tự động tạo dữ liệu giả lập (`db/002_seed/` và `scripts/seed_bulk_sql.py`)

Dữ liệu mẫu được nạp theo hai lớp:
1. **Dữ liệu nền & ca biên (`db/002_seed/`):** Thực thi qua `scripts/02_run_seeds.bat` theo đúng thứ tự khóa ngoại (`001_master_lookups.sql` -> `002_entities.sql` -> `003_entity_relationships.sql` -> `004_borrow_return.sql` -> `005_fines.sql`), bao phủ đầy đủ các trạng thái sinh viên (`ACTIVE`, `SUSPENDED`, `EXPIRED`) và 4 trạng thái phạt (`PAID`, `PARTIAL`, `WAIVED`, `UNPAID`).
2. **Dữ liệu mở rộng quy mô lớn (`scripts/seed_bulk_sql.py`):** Bổ sung thêm 40 sinh viên, 10 tác giả, 20 đầu sách, 75 bản sao (`BI101`–`BI175`), cùng 300 lượt mượn, 269 lượt trả và 120 khoản phạt trong vòng 6 tháng gần nhất (nâng tổng quy mô lên 45 sinh viên, 25 đầu sách và 85 bản sao).

```text
> .\scripts\setup_all.bat
> py .\scripts\seed_bulk_sql.py
Bulk SQL seed complete: +40 students, +20 titles, +75 copies, +300 loans, +269 returns, +120 fines.
```

`[CHÈN HÌNH ẢNH: Ảnh chụp kết quả kiểm tra số lượng bản ghi các bảng trong SSMS]`

#### 2.4.3 Xây dựng Function, Stored Procedure và 10 View/Procedure báo cáo (`db/003_program/` và `db/tests/`)

Toàn bộ đối tượng lập trình trong `db/003_program/` đều sử dụng `CREATE OR ALTER` để đảm bảo tính lũy đẳng (idempotent) khi chạy lại `scripts/03_run_programs.bat`, áp dụng mẫu giao dịch lồng nhau an toàn (`IF @@TRANCOUNT = 0 BEGIN TRANSACTION ... ELSE SAVE TRANSACTION ...`) kết hợp `SET XACT_ABORT ON` và chuẩn mã lỗi `THROW 50001`–`50030`.

```sql
-- Trích đoạn hàm tính phạt dbo.fn_CalculateFine (db/003_program/001_shared/functions/fn_CalculateFine.sql)
CREATE OR ALTER FUNCTION dbo.fn_CalculateFine (
    @RuleID INT,
    @DaysOverdue INT = 0,
    @BookPrice DECIMAL(18, 2) = 0,
    @CustomDamagePercent DECIMAL(5, 2) = NULL
)
RETURNS DECIMAL(18, 2)
AS
BEGIN
    DECLARE @RatePerDay DECIMAL(18, 2),
            @Percent   DECIMAL(5, 2),
            @FixedFee  DECIMAL(18, 2),
            @RuleCode  VARCHAR(20);

    SELECT  @RatePerDay = ISNULL(RatePerDay, 0),
            @Percent    = ISNULL(PercentOfBookValue, 0),
            @FixedFee   = ISNULL(FixedProcessingFee, 0),
            @RuleCode   = RuleCode
    FROM dbo.FineRule
    WHERE RuleID = @RuleID;

    IF @RuleCode IS NULL RETURN NULL;
    IF @DaysOverdue IS NULL OR @DaysOverdue < 0 SET @DaysOverdue = 0;
    IF @BookPrice IS NULL SET @BookPrice = 0;

    IF @CustomDamagePercent IS NOT NULL AND @RuleCode = 'DAMAGED'
       AND @CustomDamagePercent > 0 AND @CustomDamagePercent <= 1
        SET @Percent = @CustomDamagePercent;

    RETURN (@DaysOverdue * @RatePerDay) + (@BookPrice * @Percent) + @FixedFee;
END;
```

```sql
-- Trích đoạn View báo cáo công nợ phạt theo quy tắc (db/003_program/005_reports/views/vw_Report_FineSummaryByRule.sql)
CREATE OR ALTER VIEW dbo.vw_Report_FineSummaryByRule
AS
WITH FineSettlements AS (
    SELECT pi.FineItemID,
           SUM(CASE WHEN pr.ReceiptType = 'PAYMENT' THEN pi.AmountPaid ELSE 0.00 END) AS CollectedAmount,
           SUM(CASE WHEN pr.ReceiptType = 'WAIVER'  THEN pi.AmountPaid ELSE 0.00 END) AS WaivedAmount
    FROM dbo.PaymentItem pi
    INNER JOIN dbo.PaymentReceipt pr ON pi.ReceiptID = pr.ReceiptID
    GROUP BY pi.FineItemID
)
SELECT fr.RuleID, fr.RuleCode, fr.RuleName,
       COUNT(fi.FineItemID) AS FineCount,
       ISNULL(SUM(fi.Amount), 0.00) AS TotalAssessed,
       ISNULL(SUM(fs.CollectedAmount), 0.00) AS TotalCollected,
       ISNULL(SUM(fs.WaivedAmount), 0.00) AS TotalWaived,
       ISNULL(SUM(fi.Amount), 0.00) - ISNULL(SUM(fs.CollectedAmount), 0.00) - ISNULL(SUM(fs.WaivedAmount), 0.00) AS TotalOutstanding
FROM dbo.FineRule fr
LEFT JOIN dbo.FineItem fi ON fr.RuleID = fi.FineRuleID
LEFT JOIN FineSettlements fs ON fi.FineItemID = fs.FineItemID
GROUP BY fr.RuleID, fr.RuleCode, fr.RuleName;
```

`[CHÈN HÌNH ẢNH: Kết quả chạy kiểm thử các test script trong db/tests/ (PASS toàn bộ)]`

---

## 3. Lưu trữ Dữ liệu phi cấu trúc (NoSQL - MongoDB)

### 3.1 Cấu trúc Document JSON lưu trữ log tần suất cao

#### 3.1.1 Lý do lựa chọn MongoDB cho nhật ký sự kiện (`ThuVien2Logs.library_event_logs`)

Các sự kiện như quét Kiosk, tìm kiếm từ khóa trên OPAC hay tín hiệu cổng RFID phát sinh với tần suất rất lớn, cấu trúc `metadata` linh hoạt theo từng loại thiết bị (`Windows-Kiosk`, `Web-Browser`, `RFID-Firmware-v2`) và không yêu cầu giao dịch đa bảng chặt chẽ như phiếu thu hay phiếu mượn. Việc tách sang MongoDB giúp giảm tải ghi (write contention) cho SQL Server trong giờ cao điểm, đồng thời dễ dàng mở rộng schema theo từng loại sự kiện mới.

#### 3.1.2 Thiết kế cấu trúc Document JSON cho 3 loại sự kiện (`KIOSK_SCAN`, `CATALOG_SEARCH`, `RFID_GATE_PING`)

Mỗi bản ghi JSON trong collection `library_event_logs` gồm các trường định danh sự kiện (`event_id`, `event_type`, `timestamp`), khóa liên kết chéo (`StudentCode`, `Barcode`), thông tin trạm (`station_id`, `action`, `result`, `search_query`, `response_time_ms`) và đối tượng lồng nhau `metadata`:

```json
[
  {
    "event_id": "a1b2c3d4-e5f6-4890-abcd-ef1234567890",
    "event_type": "KIOSK_SCAN",
    "timestamp": "2026-10-15T09:23:11Z",
    "StudentCode": "29210252479",
    "Barcode": "BI001",
    "station_id": "KIOSK-01",
    "action": "SELF_CHECKOUT_ATTEMPT",
    "result": "SUCCESS",
    "search_query": null,
    "response_time_ms": 142,
    "metadata": {
      "client_os": "Windows-Kiosk",
      "session_duration_sec": 18
    }
  },
  {
    "event_id": "b2c3d4e5-f6a7-4901-bcde-f12345678901",
    "event_type": "CATALOG_SEARCH",
    "timestamp": "2026-10-16T14:05:44Z",
    "StudentCode": "29210252480",
    "Barcode": "BI007",
    "station_id": "OPAC-WEB-02",
    "action": "OPAC_KEYWORD_SEARCH",
    "result": "UNAVAILABLE",
    "search_query": "Designing Data-Intensive Applications",
    "response_time_ms": 87,
    "metadata": {
      "client_os": "Web-Browser",
      "session_duration_sec": 45
    }
  }
]
```

#### 3.1.3 Chiến lược bảo toàn khóa liên kết chéo (`StudentCode`, `Barcode`) và đánh chỉ mục (`Index`)

Để đảm bảo 100% tài liệu log trong MongoDB có thể nối (join) thành công với CSDL quan hệ, mọi giá trị `StudentCode` và `Barcode` đều được lấy trực tiếp từ `dbo.Student` và `dbo.BookItem` tại thời điểm sinh log. Sau khi nạp dữ liệu, script tạo 4 chỉ mục tăng dần (`ASCENDING`) trên `StudentCode`, `Barcode`, `event_type` và `timestamp` để tăng tốc độ truy vấn và lọc theo thời gian.

### 3.2 Kịch bản sinh dữ liệu tự động và đẩy vào MongoDB

#### 3.2.1 Luồng truy vấn khóa thực từ SQL Server và phân phối trọng số Zipf trong `nosql/generate_logs.py`

Thay vì sinh dữ liệu phân bố đều (uniform) kém thực tế, `nosql/generate_logs.py` sử dụng hàm `build_skewed_weights` theo quy luật lũy thừa Zipf (`1.0 / (r ** exponent)`) với hệ số `1.15` cho sinh viên và `1.30` cho đầu sách, đồng thời phân bổ khung giờ theo giờ hoạt động khuôn viên trường (07:00–21:00). Kết quả kiểm tra trạng thái sinh viên (`ACTIVE`/`SUSPENDED`/`EXPIRED`) và trạng thái sách (`AVAILABLE`/`BORROWED`/`LOST`/`DAMAGED`) từ SQL Server được ánh xạ trực tiếp vào kết quả sự kiện (`SUCCESS`, `UNAVAILABLE`, `DENIED_FINES`, `DENIED_LIMIT`, `UNRETURNED_ALERT`).

```python
# Trích đoạn từ nosql/generate_logs.py
def fetch_sql_keys(conn: pyodbc.Connection) -> tuple[list[dict], list[dict]]:
    cursor = conn.cursor()
    cursor.execute("SELECT StudentCode, Status FROM dbo.Student ORDER BY StudentID;")
    students = [{"StudentCode": row[0], "Status": row[1]} for row in cursor.fetchall()]

    cursor.execute("""
        SELECT bi.Barcode, bi.StatusID, bt.BookTitle
        FROM dbo.BookItem bi
        INNER JOIN dbo.BookTitle bt ON bi.TitleID = bt.TitleID
        ORDER BY bi.BookItemID;
    """)
    books = [{"Barcode": row[0], "StatusID": row[1], "BookTitle": row[2]} for row in cursor.fetchall()]
    return students, books
```

#### 3.2.2 Thực thi sinh 8.000 bản ghi log vào MongoDB và kiểm chứng chỉ mục

Khi chạy `py nosql/generate_logs.py`, chương trình xóa collection cũ (đảm bảo idempotent), nạp **8.000** tài liệu JSON theo từng lô 1.000 bản ghi (`insert_many`) vào `ThuVien2Logs.library_event_logs` và khởi tạo đầy đủ 4 chỉ mục.

`[CHÈN HÌNH ẢNH: Kết quả chạy py nosql/generate_logs.py và giao diện MongoDB Compass hiển thị collection library_event_logs (8,000 documents)]`

#### 3.2.3 Kiểm tra tính khớp khóa liên kết giữa MongoDB và SQL Server

Kết quả thực thi ghi nhận script nạp thành công **45 `StudentCode`** và **85 `Barcode`** trực tiếp từ SQL Server `ThuVien2` trước khi sinh 8.000 log, đảm bảo toàn vẹn khóa liên kết chéo ở mức 100%.

---

## 4. Xử lý và Phân tích Dữ liệu lớn (Big Data Analytics)

### 4.1 Luồng kết nối, đối chiếu và gộp dữ liệu bằng Python

#### 4.1.1 Kiến trúc pipeline phân tích trong `analytics/join_and_analyze.py` (`pyodbc`, `pymongo`, `pandas`)

Pipeline phân tích dữ liệu đa nguồn thực hiện theo 4 bước tuần tự:
1. **Trích xuất dữ liệu quan hệ (`load_sql_data`):** Truy vấn thông tin sách (`BookItem` kết nối `BookTitle`), chỉ số hoạt động sinh viên (`vw_Report_StudentActivityKPI`), và tổng hợp tiền phạt (`vw_Report_FineSummaryByRule`) từ SQL Server vào các `DataFrame`.
2. **Trích xuất dữ liệu phi cấu trúc (`load_mongo_logs`):** Đọc toàn bộ 8.000 bản ghi từ `ThuVien2Logs.library_event_logs`, chuyển đổi `timestamp` sang định dạng UTC datetime và trích xuất đặc trưng `hour` (giờ trong ngày).
3. **Gộp dữ liệu đa CSDL (`merge`):** Thực hiện inner join giữa tập log MongoDB với `df_books` theo khóa `Barcode` và với `df_students` theo khóa `StudentCode`.
4. **Tổng hợp và xuất biểu đồ:** Sử dụng `matplotlib` (backend `Agg`) và `seaborn` xuất 4 biểu đồ PNG độ phân giải 150 DPI vào `analytics/charts/`.

```python
# Trích đoạn từ analytics/join_and_analyze.py
with get_sql_connection() as conn:
    sql_data = load_sql_data(conn)

df_logs = load_mongo_logs()

# Cross-DB joins on Barcode and StudentCode
df_logs_books = df_logs.merge(sql_data["books"], on="Barcode", how="inner")
df_logs_students = df_logs.merge(sql_data["students"], on="StudentCode", how="inner")
```

#### 4.1.2 Kết quả đối chiếu và làm sạch tập dữ liệu gộp (8.000/8.000 dòng khớp khóa)

Khi thực thi `py analytics/join_and_analyze.py`, toàn bộ **8.000/8.000** bản ghi log từ MongoDB đều khớp hoàn toàn khi nối theo `Barcode` và `StudentCode` với SQL Server (tỷ lệ thất thoát khóa = 0%), sẵn sàng cho quá trình trực quan hóa.

`[CHÈN HÌNH ẢNH: Console output khi chạy py analytics/join_and_analyze.py]`

### 4.2 Trực quan hóa và ý nghĩa nghiệp vụ

#### 4.2.1 Biểu đồ 1: Top 10 đầu sách — Nhu cầu tìm kiếm/quét số so với độ sẵn sàng bản sao vật lý (`01_search_demand_vs_availability.png`)

Biểu đồ thanh ngang so sánh 10 đầu sách có tổng lượt tìm kiếm OPAC và quét Kiosk cao nhất từ MongoDB (`DigitalDemand`) cùng số lượt gặp trạng thái không sẵn sàng (`UnavailableHits`), đối chiếu với tỷ lệ bản sao vật lý `AvailableCopies / TotalCopies` từ SQL Server. Các đầu sách đứng đầu như *Clean Code* hay *Database Internals* có nhu cầu số cao và số lượt `UNAVAILABLE` lớn trong khi số bản sẵn sàng thấp là tín hiệu trực tiếp để thư viện ưu tiên bổ sung thêm bản sao nhập kho.

`[CHÈN HÌNH ẢNH: analytics/charts/01_search_demand_vs_availability.png]`

#### 4.2.2 Biểu đồ 2: Lưu lượng quét Kiosk theo khung giờ và tỷ lệ kết quả giao dịch (`02_kiosk_hourly_traffic_vs_checkouts.png`)

Biểu đồ cột chồng theo từng giờ trong ngày (UTC) phân tách các giao dịch `KIOSK_SCAN` thành 4 nhóm kết quả: `SUCCESS`, `UNAVAILABLE`, `DENIED_FINES` và `DENIED_LIMIT`. Biểu đồ giúp ban quản lý nhận diện các khung giờ cao điểm (buổi sáng 09:00–11:00 và buổi chiều 14:00–16:00) để bố trí nhân sự hỗ trợ trực quầy cũng như kiểm soát tỷ lệ sinh viên bị từ chối mượn do nợ phạt.

`[CHÈN HÌNH ẢNH: analytics/charts/02_kiosk_hourly_traffic_vs_checkouts.png]`

#### 4.2.3 Biểu đồ 3: Top 10 độc giả tích cực — Mức độ tương tác so với dư nợ tiền phạt và trạng thái tài khoản (`03_student_engagement_vs_delinquency.png`)

Biểu đồ kết hợp hai trục tung đối chiếu Top 10 sinh viên có tần suất tương tác Kiosk/OPAC cao nhất (cột màu phân theo trạng thái `ACTIVE`, `SUSPENDED`, `EXPIRED` và chú thích số lượt bị từ chối `Denied`) với đường biểu diễn dư nợ tiền phạt hiện tại (`OutstandingBalance`, đơn vị nghìn VNĐ). Kết quả cho thấy rõ mối tương quan giữa nhóm độc giả tương tác nhiều nhưng tài khoản `EXPIRED` hoặc đang mang dư nợ cao sẽ kéo theo số lượt `DENIED_FINES` tăng vọt tại Kiosk.

`[CHÈN HÌNH ẢNH: analytics/charts/03_student_engagement_vs_delinquency.png]`

#### 4.2.4 Biểu đồ 4: Cơ cấu thu hồi tiền phạt theo quy tắc (`LATE`, `LOST`, `DAMAGED`) và cảnh báo cổng RFID (`04_fine_revenue_and_recovery_breakdown.png`)

Biểu đồ cột chồng tổng hợp tình hình tài chính tiền phạt theo 3 quy tắc (`LATE`, `LOST`, `DAMAGED`) gồm phần đã thu (`PAYMENT`), đã miễn giảm (`WAIVER`) và còn tồn đọng (`UNPAID`/`PARTIAL`), kết hợp thông số số lượt cảnh báo sách chưa trả đi qua cổng từ (`RFID_GATE_PING` với `result = 'UNRETURNED_ALERT'`). Biểu đồ giúp đánh giá hiệu quả thu hồi công nợ và nhận diện rủi ro thất thoát tài sản sách giá trị cao.

`[CHÈN HÌNH ẢNH: analytics/charts/04_fine_revenue_and_recovery_breakdown.png]`

---

## 5. Kết luận và Hướng phát triển

### 5.1 Kết quả đạt được

Đồ án **ThuVien2** đã hoàn thành đầy đủ cả 4 trụ cột kỹ thuật theo đúng lộ trình 9 giai đoạn:
- Chuẩn hóa 100% tên bảng, cột, hàm và thủ tục sang tiếng Anh PascalCase trên SQL Server (`16` bảng chuẩn 3NF), khắc phục triệt để các ràng buộc toàn vẹn phức tạp như `CK_FineItem_Link` (XOR) và `CK_FineRule_Components`.
- Xây dựng hoàn chỉnh bộ đối tượng lập trình (`1` hàm, `8` view báo cáo, `11` thủ tục lưu trữ) kèm kịch bản kiểm thử T-SQL (`db/tests/`) và quy trình triển khai tự động một lệnh (`scripts/setup_all.bat`).
- Triển khai thành công kho nhật ký NoSQL trên MongoDB với 8.000 document log phân bố thực tế theo quy luật Zipf, bảo toàn toàn vẹn khóa `StudentCode` và `Barcode`.
- Xây dựng pipeline phân tích đa CSDL bằng Python (`pandas`) gộp khớp 100% (8.000/8.000 bản ghi) và xuất 4 biểu đồ trực quan phục vụ ra quyết định quản trị thư viện.

### 5.2 Hướng phát triển tiếp theo

- **Xây dựng giao diện Web / API RESTful:** Tích hợp tầng thủ tục SQL Server và MongoDB lên ứng dụng web (FastAPI/ASP.NET Core) cho thủ thư và cổng tra cứu sinh viên thời gian thực.
- **Tích hợp cảnh báo tự động & gợi ý sách:** Sử dụng lịch sử tìm kiếm trên MongoDB để xây dựng hệ thống gợi ý đầu sách (Recommendation System) và gửi email tự động nhắc hạn trả trước 2 ngày qua `vw_Report_OverdueLoans`.
- **Mở rộng luồng dữ liệu Streaming:** Chuyển đổi luồng ghi nhận sự kiện Kiosk/RFID sang hàng đợi thông điệp (Apache Kafka) để cập nhật chỉ số cảnh báo an ninh cổng từ theo thời gian thực.
