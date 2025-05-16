/*
LIBRARY MANAGEMENT SYSTEM DATABASE
Author: [Your Name]
Date: [YYYY-MM-DD]
*/
-- Core Tables --
CREATE TABLE members (
    member_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    join_date DATE NOT NULL,
	membership_status ENUM('Active', 'Expired', 'Suspended')
    DEFAULT 'Active');
    
-- Books table --
CREATE TABLE books (
    book_id INT AUTO_INCREMENT PRIMARY KEY,
    isbn VARCHAR(20) UNIQUE NOT NULL,
    title VARCHAR(100) NOT NULL,
    publication_year INT,
    edition VARCHAR(10),
    total_copies INT NOT NULL DEFAULT 1,
    available_copies INT NOT NULL DEFAULT 1,
    CONSTRAINT chk_copies CHECK (available_copies <= total_copies AND available_copies >= 0)
) COMMENT 'Book inventory information';

-- Authors table
CREATE TABLE authors (
    author_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    birth_year INT,
    nationality VARCHAR(50)
) COMMENT 'Book authors information';

-- Publishers table --
CREATE TABLE publishers (
    publisher_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    address TEXT,
    website VARCHAR(100)
) COMMENT 'Book publishers information';

-- RELATIONSHIP TABLES --
-- Book-Author many-to-many relationship --
CREATE TABLE book_authors (
    book_id INT NOT NULL,
    author_id INT NOT NULL,
    PRIMARY KEY (book_id, author_id),
    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE,
    FOREIGN KEY (author_id) REFERENCES authors(author_id) ON DELETE CASCADE
) COMMENT 'Links books to their authors';

-- Book-Publisher relationship
ALTER TABLE books ADD COLUMN publisher_id INT;
ALTER TABLE books ADD CONSTRAINT fk_publisher 
    FOREIGN KEY (publisher_id) REFERENCES publishers(publisher_id);
    
    -- TRANSACTION TABLES --
    -- Book loans --
CREATE TABLE loans (
    loan_id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT NOT NULL,
    member_id INT NOT NULL,
    loan_date DATE NOT NULL,
    due_date DATE NOT NULL,
    return_date DATE,
    status ENUM('Active', 'Returned', 'Overdue') NOT NULL DEFAULT 'Active'
    );
    alter table loans
    Add Constraint book_id
    Foreign key (book_id)
    References books(book_id);
    
    alter table loans
    Add Constraint member_id
    Foreign key (member_id)
    References members(member_id);
    
    -- Fines table --
CREATE TABLE fines (
    fine_id INT AUTO_INCREMENT PRIMARY KEY,
    loan_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    issue_date DATE NOT NULL,
    payment_date DATE,
    status ENUM('Pending', 'Paid') DEFAULT 'Pending',
    FOREIGN KEY (loan_id) REFERENCES loans(loan_id),
    CONSTRAINT chk_amount CHECK (amount > 0)
) COMMENT 'Late return fines';

-- INDEXES FOR PERFORMANCE --
-- Indexes for frequently queried columns --
CREATE INDEX idx_books_title ON books(title);
CREATE INDEX idx_members_name ON members(last_name, first_name);
CREATE INDEX idx_loans_dates ON loans(loan_date, due_date);
CREATE INDEX idx_fines_status ON fines(status);

-- Sample Data --

-- Insert sample publishers --
INSERT INTO publishers (name, website) VALUES 
('Penguin Random House', 'www.penguinrandomhouse.com'),
('HarperCollins', 'www.harpercollins.com');

-- Insert sample authors
INSERT INTO authors (first_name, last_name, nationality) VALUES
('George', 'Orwell', 'British'),
('J.K.', 'Rowling', 'British'),
('Stephen', 'King', 'American');

-- Insert sample books
INSERT INTO books (isbn, title, publication_year, publisher_id, total_copies, available_copies) VALUES
('9780451524935', '1984', 1949, 1, 5, 3),
('9780439554930', 'Harry Potter and the Sorcerer''s Stone', 1997, 2, 3, 1),
('9780307743657', 'The Shining', 1977, 1, 4, 4);

-- Link books to authors
INSERT INTO book_authors VALUES
(1, 1), -- 1984 by George Orwell
(2, 2), -- Harry Potter by J.K. Rowling
(3, 3); -- The Shining by Stephen King

-- Insert sample members
INSERT INTO members (first_name, last_name, email, join_date) VALUES
('John', 'Smith', 'john.smith@email.com', '2023-01-15'),
('Sarah', 'Johnson', 'sarah.j@email.com', '2023-03-22');

-- STORED PROCEDUCERS --

-- Procedure to borrow a book --
DELIMITER //
CREATE PROCEDURE borrow_book(
    IN p_book_id INT,
    IN p_member_id INT,
    IN p_loan_days INT
)
BEGIN
    DECLARE available INT;
    
    -- Check book availability
    SELECT available_copies INTO available FROM books WHERE book_id = p_book_id;
    
    IF available > 0 THEN
        -- Record loan
        INSERT INTO loans (book_id, member_id, loan_date, due_date, status)
        VALUES (p_book_id, p_member_id, CURDATE(), DATE_ADD(CURDATE(), INTERVAL p_loan_days DAY), 'Active');
        
        -- Update available copies
        UPDATE books SET available_copies = available_copies - 1 WHERE book_id = p_book_id;
        
        SELECT 'Loan successful' AS message;
    ELSE
        SELECT 'Book not available' AS message;
    END IF;
END //
DELIMITER ;

-- Procedure to return a book --
DELIMITER //
CREATE PROCEDURE return_book(
    IN p_loan_id INT
)
BEGIN
    DECLARE v_book_id INT;
    DECLARE v_due_date DATE;
    
    -- Get loan details
    SELECT book_id, due_date INTO v_book_id, v_due_date FROM loans WHERE loan_id = p_loan_id;
    
    -- Update loan record
    UPDATE loans 
    SET return_date = CURDATE(),
        status = IF(CURDATE() > due_date, 'Overdue', 'Returned')
    WHERE loan_id = p_loan_id;
    
    -- Update book availability
    UPDATE books SET available_copies = available_copies + 1 WHERE book_id = v_book_id;
    
    -- Apply fine if overdue
    IF CURDATE() > v_due_date THEN
        INSERT INTO fines (loan_id, amount, issue_date)
        VALUES (p_loan_id, DATEDIFF(CURDATE(), v_due_date) * 0.50, CURDATE());
    END IF;
    
    SELECT 'Return processed' AS message;
END //
DELIMITER ;