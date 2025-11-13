-- Library Management System - DDL + Return Transaction

-- ====== TABLES ======

CREATE TABLE Book ( 
    ISBN VARCHAR(20) PRIMARY KEY, 
    title VARCHAR(255) NOT NULL, 
    genre VARCHAR(100), 
    publication_year INT 
); 

-- Author Table   
CREATE TABLE Author ( 
    author_id INT AUTO_INCREMENT PRIMARY KEY, 
    name VARCHAR(255) NOT NULL, 
    nationality VARCHAR(100) 
); 

-- Location Table 
CREATE TABLE Location ( 
    location_id INT AUTO_INCREMENT PRIMARY KEY, 
    shelf_number VARCHAR(50) NOT NULL, 
    floor_number INT NOT NULL 
); 

-- Member Table 
CREATE TABLE Member ( 
    member_id INT AUTO_INCREMENT PRIMARY KEY, 
    name VARCHAR(255) NOT NULL, 
    address VARCHAR(500) NOT NULL, 
    date_of_birth DATE, 
    email VARCHAR(255) UNIQUE, 
    mobile VARCHAR(20), 
    membership_start_date DATE DEFAULT (CURRENT_DATE) 
); 

-- BookCopy Table 
CREATE TABLE BookCopy ( 
    accession_number INT AUTO_INCREMENT PRIMARY KEY, 
    status ENUM('available', 'borrowed') DEFAULT 'available', 
    purchase_price DECIMAL(10,2), 
    acquisition_date DATE DEFAULT (CURRENT_DATE), 
    book_condition ENUM('New', 'Good', 'Damaged') DEFAULT 'Good', 
    acquisition_source ENUM('Purchase', 'Donation', 'Interlibrary Loan') DEFAULT 'Purchase', 
    ISBN VARCHAR(20), 
    location_id INT, 
    FOREIGN KEY (ISBN) REFERENCES Book(ISBN) ON DELETE CASCADE, 
    FOREIGN KEY (location_id) REFERENCES Location(location_id) ON DELETE SET NULL 
); 

-- Checkout Table 
CREATE TABLE Checkout ( 
    checkout_id INT AUTO_INCREMENT PRIMARY KEY, 
    issue_date DATE DEFAULT (CURRENT_DATE), 
    due_date DATE NOT NULL, 
    return_date DATE NULL, 
    member_id INT, 
    accession_number INT, 
    FOREIGN KEY (member_id) REFERENCES Member(member_id) ON DELETE CASCADE, 
    FOREIGN KEY (accession_number) REFERENCES BookCopy(accession_number) ON DELETE CASCADE 
); 

-- Fine Table 
CREATE TABLE Fine ( 
    fine_id INT AUTO_INCREMENT PRIMARY KEY, 
    amount DECIMAL(10,2) DEFAULT 0.0, 
    fine_date DATE DEFAULT (CURRENT_DATE), 
    payment_status ENUM('paid', 'unpaid') DEFAULT 'unpaid', 
    member_id INT, 
    accession_number INT, 
    checkout_id INT, 
    FOREIGN KEY (member_id) REFERENCES Member(member_id) ON DELETE CASCADE, 
    FOREIGN KEY (accession_number) REFERENCES BookCopy(accession_number) ON DELETE CASCADE, 
    FOREIGN KEY (checkout_id) REFERENCES Checkout(checkout_id) ON DELETE CASCADE 
); 

-- Junction Tables 
CREATE TABLE Book_Author ( 
    ISBN VARCHAR(20), 
    author_id INT, 
    PRIMARY KEY (ISBN, author_id), 
    FOREIGN KEY (ISBN) REFERENCES Book(ISBN) ON DELETE CASCADE, 
    FOREIGN KEY (author_id) REFERENCES Author(author_id) ON DELETE CASCADE 
); 

CREATE TABLE Reservation ( 
    member_id INT, 
    ISBN VARCHAR(20), 
    reservation_date DATE DEFAULT (CURRENT_DATE), 
    PRIMARY KEY (member_id, ISBN), 
    FOREIGN KEY (member_id) REFERENCES Member(member_id) ON DELETE CASCADE, 
    FOREIGN KEY (ISBN) REFERENCES Book(ISBN) ON DELETE CASCADE 
); 

-- ====== TRIGGER FOR AUTOMATIC DUE DATE ======

DELIMITER $$ 
CREATE TRIGGER set_due_date_before_insert 
BEFORE INSERT ON Checkout 
FOR EACH ROW 
BEGIN 
    IF NEW.due_date IS NULL THEN 
        SET NEW.due_date = DATE_ADD(NEW.issue_date, INTERVAL 14 DAY); 
    END IF; 
END$$ 
DELIMITER ; 

-- ====== INDEXES ======

CREATE INDEX idx_checkout_member ON Checkout(member_id); 
CREATE INDEX idx_checkout_due_date ON Checkout(due_date); 
CREATE INDEX idx_fine_member_status ON Fine(member_id, payment_status); 
CREATE INDEX idx_reservation_isbn_date ON Reservation(ISBN, reservation_date); 
CREATE INDEX idx_bookcopy_status ON BookCopy(status); 
CREATE INDEX idx_checkout_return_date ON Checkout(return_date); 

-- ====== NOTES: Constraints Not Definable in DDL ======
-- 1) Complex CHECK constraints (examples, not implemented here):
--    CHECK (publication_year <= YEAR(CURDATE()))
--    CHECK (address LIKE '%Edinburgh%')
--    CHECK (purchase_price > 0) 
-- 2) Dynamic business rules:
--    - Fine calculation (£0.5 per overdue day)
--    - First-come-first-served reservation priority
--    - Maximum concurrent checkouts per member
-- 3) Cross-table validations:
--    - Member cannot reserve a book they already have checked out
--    - Additional validation before checkout

-- ====== BOOK RETURN TRANSACTION PROCEDURE ======

DELIMITER $$ 
CREATE PROCEDURE ProcessBookReturn( 
    IN p_checkout_id INT 
) 
BEGIN 
    DECLARE v_member_id INT; 
    DECLARE v_accession_number INT; 
    DECLARE v_due_date DATE; 
    DECLARE v_overdue_days INT; 
    DECLARE v_fine_amount DECIMAL(10,2); 
    DECLARE v_book_isbn VARCHAR(20); 
    DECLARE v_next_reserver_id INT; 
    DECLARE v_next_reserver_name VARCHAR(255); 
    DECLARE v_checkout_exists INT DEFAULT 0; 

    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN 
        ROLLBACK; 
        RESIGNAL; 
    END; 

    -- Check if checkout exists and is not returned 
    SELECT COUNT(*) INTO v_checkout_exists 
    FROM Checkout  
    WHERE checkout_id = p_checkout_id AND return_date IS NULL; 

    IF v_checkout_exists = 0 THEN 
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Checkout record not found or already returned'; 
    END IF; 

    START TRANSACTION; 

    -- Get checkout details with book ISBN 
    SELECT c.member_id, c.accession_number, c.due_date, bc.ISBN  
    INTO v_member_id, v_accession_number, v_due_date, v_book_isbn 
    FROM Checkout c  
    JOIN BookCopy bc ON c.accession_number = bc.accession_number 
    WHERE c.checkout_id = p_checkout_id; 

    -- (a) Calculate and record fine if overdue 
    IF CURRENT_DATE > v_due_date THEN 
        SET v_overdue_days = DATEDIFF(CURRENT_DATE, v_due_date); 
        SET v_fine_amount = v_overdue_days * 0.5; 

        INSERT INTO Fine (amount, member_id, accession_number, checkout_id) 
        VALUES (v_fine_amount, v_member_id, v_accession_number, p_checkout_id); 

        SELECT CONCAT('FINE RECORDED: £', v_fine_amount, ' for ', v_overdue_days, ' overdue days') AS message; 
    ELSE 
        SELECT 'No fine charged - book returned on time' AS message; 
    END IF; 

    -- (b) Update book return date 
    UPDATE Checkout  
    SET return_date = CURRENT_DATE  
    WHERE checkout_id = p_checkout_id; 
    SELECT 'Return date updated to current date' AS message; 

    -- (c) Update book copy status to available 
    UPDATE BookCopy  
    SET status = 'available'  
    WHERE accession_number = v_accession_number; 
    SELECT 'Book copy status updated to available' AS message; 

    -- (d) Find next member who reserved this book (first come first served) 
    SELECT r.member_id, m.name INTO v_next_reserver_id, v_next_reserver_name 
    FROM Reservation r 
    JOIN Member m ON r.member_id = m.member_id 
    WHERE r.ISBN = v_book_isbn  
    ORDER BY r.reservation_date ASC  
    LIMIT 1; 

    IF v_next_reserver_id IS NOT NULL THEN 
        SELECT CONCAT('NEXT RESERVER: ', v_next_reserver_name, ' (Member ID: ', v_next_reserver_id, ')') AS message; 

        -- (e) Delete the reservation for the next member 
        DELETE FROM Reservation  
        WHERE member_id = v_next_reserver_id AND ISBN = v_book_isbn; 
        SELECT 'Reservation deleted for the next member in queue' AS message; 
    ELSE 
        SELECT 'No pending reservations for this book' AS message; 
    END IF; 

    COMMIT; 
END $$ 
DELIMITER ;
