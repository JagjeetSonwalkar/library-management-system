USE library_db;

-- ===================== CREATE =====================
INSERT INTO books (title, author, category, total_copies, available_copies)
VALUES ('Deep Work', 'Cal Newport', 'Self-Help', 3, 3);

INSERT INTO members (name, email, join_date, status)
VALUES ('Isha Verma', 'isha@example.com', CURDATE(), 'active');

-- ===================== UPDATE =====================
-- Add 2 copies of a book (keeps available_copies in sync)
UPDATE books
SET total_copies = total_copies + 2,
    available_copies = available_copies + 2
WHERE book_id = 1;

-- Deactivate / reactivate a member
UPDATE members SET status = 'inactive' WHERE member_id = 6;

-- ===================== DELETE (with checks) =====================
-- Delete a book only if it has no issue history
DELETE FROM books
WHERE book_id = 9
  AND NOT EXISTS (SELECT 1 FROM book_issues WHERE book_id = 9);

-- Delete a member only if they have no issue history
DELETE FROM members
WHERE member_id = 6
  AND NOT EXISTS (SELECT 1 FROM book_issues WHERE member_id = 6);
-- (The FOREIGN KEY ... ON DELETE RESTRICT is a second safety net.)

-- ===================== ISSUE / RETURN =====================
DELIMITER $$

CREATE PROCEDURE issue_book(IN p_book_id INT, IN p_member_id INT, IN p_days INT)
BEGIN
    DECLARE v_avail INT;
    DECLARE v_status VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

    START TRANSACTION;
    SELECT available_copies INTO v_avail FROM books WHERE book_id = p_book_id FOR UPDATE;
    SELECT status INTO v_status FROM members WHERE member_id = p_member_id;

    IF v_status IS NULL OR v_avail IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Book or member not found';
    ELSEIF v_status <> 'active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Member is inactive';
    ELSEIF v_avail <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No copies available';
    ELSEIF EXISTS (SELECT 1 FROM book_issues
                   WHERE book_id = p_book_id AND member_id = p_member_id AND return_date IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Member already has this book';
    END IF;

    INSERT INTO book_issues (book_id, member_id, issue_date, due_date)
    VALUES (p_book_id, p_member_id, CURDATE(), DATE_ADD(CURDATE(), INTERVAL p_days DAY));
    UPDATE books SET available_copies = available_copies - 1 WHERE book_id = p_book_id;
    COMMIT;
END$$

CREATE PROCEDURE return_book(IN p_issue_id INT)
BEGIN
    DECLARE v_book INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

    START TRANSACTION;
    SELECT book_id INTO v_book FROM book_issues
    WHERE issue_id = p_issue_id AND return_date IS NULL FOR UPDATE;

    IF v_book IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Issue not found or already returned';
    END IF;

    UPDATE book_issues SET return_date = CURDATE() WHERE issue_id = p_issue_id;
    UPDATE books SET available_copies = available_copies + 1 WHERE book_id = v_book;
    COMMIT;
END$$

DELIMITER ;

-- Usage:
-- CALL issue_book(2, 1, 14);   -- book 2 to member 1 for 14 days
-- CALL return_book(1);
