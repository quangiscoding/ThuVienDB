USE ThuVien2;
GO

-- Map Authors to Titles (N-N join entity, including a co-authored title)
INSERT INTO dbo.Author_BookTitle (AuthorID, TitleID) VALUES
(1, 1), -- Nguyen Nhat Anh -> Blue Eyes
(2, 2), -- J.K. Rowling -> Harry Potter
(3, 3), -- Robert C. Martin -> Clean Code
(4, 4), -- Martin Kleppmann -> Designing Data-Intensive Applications
(5, 5), -- Andrew Hunt -> The Pragmatic Programmer
(3, 5); -- Robert C. Martin -> The Pragmatic Programmer (co-authored fixture)

-- Physical copies on shelves / in circulation (depends on BookTitle and Status)
INSERT INTO dbo.BookItem (Barcode, TitleID, StatusID, Price) VALUES
('BI001', 1, 'AVAILABLE', 100000.00),
('BI002', 1, 'AVAILABLE', 100000.00),
('BI003', 2, 'AVAILABLE', 250000.00),
('BI004', 2, 'BORROWED',  250000.00),
('BI005', 3, 'BORROWED',  320000.00),
('BI006', 3, 'AVAILABLE', 320000.00),
('BI007', 4, 'LOST',      450000.00),
('BI008', 4, 'AVAILABLE', 450000.00),
('BI009', 5, 'DAMAGED',   280000.00),
('BI010', 5, 'AVAILABLE', 280000.00);
GO
