USE ThuVien2;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_CirculationByDateRange
    @StartDate DATE,
    @EndDate   DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @StartDate IS NULL OR @EndDate IS NULL OR @StartDate > @EndDate
    BEGIN
        THROW 50030, 'Invalid date range. @StartDate must be less than or equal to @EndDate.', 1;
    END

    SELECT @StartDate AS StartDate,
           @EndDate   AS EndDate,
           (
               SELECT COUNT(li.LoanItemID)
               FROM dbo.LoanSlip ls
               INNER JOIN dbo.LoanItem li ON ls.LoanSlipID = li.LoanSlipID
               WHERE ls.LoanDate BETWEEN @StartDate AND @EndDate
           ) AS TotalBooksBorrowed,
           (
               SELECT COUNT(ri.ReturnItemID)
               FROM dbo.ReturnSlip rs
               INNER JOIN dbo.ReturnItem ri ON rs.ReturnSlipID = ri.ReturnSlipID
               WHERE rs.ReturnDate BETWEEN @StartDate AND @EndDate
           ) AS TotalBooksReturned,
           (
               SELECT COUNT(ri.ReturnItemID)
               FROM dbo.ReturnSlip rs
               INNER JOIN dbo.ReturnItem ri ON rs.ReturnSlipID = ri.ReturnSlipID
               INNER JOIN dbo.LoanItem   li ON ri.LoanItemID   = li.LoanItemID
               WHERE rs.ReturnDate BETWEEN @StartDate AND @EndDate
                 AND rs.ReturnDate > li.DueDate
           ) AS LateReturns,
           (
               SELECT ISNULL(SUM(Total), 0.00)
               FROM dbo.PaymentReceipt
               WHERE ReceiptType = 'PAYMENT'
                 AND PaymentDate BETWEEN @StartDate AND @EndDate
           ) AS FineRevenueCollected,
           (
               SELECT ISNULL(SUM(Total), 0.00)
               FROM dbo.PaymentReceipt
               WHERE ReceiptType = 'WAIVER'
                 AND PaymentDate BETWEEN @StartDate AND @EndDate
           ) AS FineAmountWaived;
END;
GO
