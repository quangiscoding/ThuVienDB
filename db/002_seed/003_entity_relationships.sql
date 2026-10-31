USE ThuVien2;
GO

-- Map Authors to Titles (N-N join entity)
INSERT INTO dbo.Author_BookTitle (AuthorID, TitleID) VALUES 
(1, 1), -- Nguyen Nhat Anh -> Mat Biec
(2, 2); -- JK Rowling -> Harry Potter

-- Physical copies in warehouse / on shelves (depends on BookTitle and Status)
INSERT INTO dbo.BookItem (MaVach, TitleID, StatusID, Price) VALUES 
('BI001', 1, 'AVAILABLE', 100000.00),
('BI002', 1, 'AVAILABLE', 100000.00),
('BI003', 2, 'AVAILABLE', 250000.00);
GO