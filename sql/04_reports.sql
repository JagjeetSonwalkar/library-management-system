USE library_db;

-- Q1. How many books are available?
SELECT SUM(total_copies) AS total_copies,
       SUM(available_copies) AS available_copies,
       SUM(total_copies) - SUM(available_copies) AS currently_issued
FROM books;

-- Q1b. Availability per title
SELECT book_id, title, category, total_copies, available_copies
FROM books
ORDER BY available_copies DESC, title;

-- Q2. Which member has borrowed which book? (currently borrowed)
SELECT m.member_id, m.name AS member, b.title, b.author,
       bi.issue_date, bi.due_date
FROM book_issues bi
JOIN members m ON m.member_id = bi.member_id
JOIN books   b ON b.book_id   = bi.book_id
WHERE bi.return_date IS NULL
ORDER BY m.name, bi.issue_date;

-- Q2b. Full borrowing history
SELECT m.name AS member, b.title, bi.issue_date, bi.due_date,
       COALESCE(bi.return_date, 'Not returned') AS return_status
FROM book_issues bi
JOIN members m ON m.member_id = bi.member_id
JOIN books   b ON b.book_id   = bi.book_id
ORDER BY bi.issue_date DESC;

-- Q3. Which books are overdue?
SELECT bi.issue_id, m.name AS member, m.email, b.title, bi.due_date,
       DATEDIFF(CURDATE(), bi.due_date)      AS days_overdue,
       DATEDIFF(CURDATE(), bi.due_date) * 2  AS fine_rs   -- Rs.2/day
FROM book_issues bi
JOIN members m ON m.member_id = bi.member_id
JOIN books   b ON b.book_id   = bi.book_id
WHERE bi.return_date IS NULL
  AND bi.due_date < CURDATE()
ORDER BY days_overdue DESC;

-- Q4. Top 5 most borrowed books
SELECT b.book_id, b.title, b.author, COUNT(bi.issue_id) AS times_borrowed
FROM books b
JOIN book_issues bi ON bi.book_id = b.book_id
GROUP BY b.book_id, b.title, b.author
ORDER BY times_borrowed DESC, b.title
LIMIT 5;

-- ---------------- Extra reports ----------------

-- Members who returned books late (returned after due date)
SELECT m.name, COUNT(*) AS late_returns
FROM book_issues bi
JOIN members m ON m.member_id = bi.member_id
WHERE bi.return_date > bi.due_date
GROUP BY m.member_id, m.name
ORDER BY late_returns DESC;

-- Members who have never borrowed (subquery)
SELECT member_id, name FROM members
WHERE member_id NOT IN (SELECT DISTINCT member_id FROM book_issues);

-- Books never issued (subquery)
SELECT title FROM books
WHERE book_id NOT IN (SELECT DISTINCT book_id FROM book_issues);

-- Most active members (top borrowers)
SELECT m.name, COUNT(*) AS total_borrowed
FROM members m JOIN book_issues bi ON bi.member_id = m.member_id
GROUP BY m.member_id, m.name
ORDER BY total_borrowed DESC LIMIT 5;

-- Borrowings per category
SELECT b.category, COUNT(*) AS issues
FROM book_issues bi JOIN books b ON b.book_id = bi.book_id
GROUP BY b.category ORDER BY issues DESC;

-- Average days a book is kept (returned books only)
SELECT ROUND(AVG(DATEDIFF(return_date, issue_date)), 1) AS avg_days_kept
FROM book_issues WHERE return_date IS NOT NULL;

-- Books due in the next 7 days
SELECT b.title, m.name, bi.due_date
FROM book_issues bi
JOIN books b ON b.book_id = bi.book_id
JOIN members m ON m.member_id = bi.member_id
WHERE bi.return_date IS NULL
  AND bi.due_date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 7 DAY);

-- Monthly issue count
SELECT DATE_FORMAT(issue_date, '%Y-%m') AS month, COUNT(*) AS issues
FROM book_issues GROUP BY month ORDER BY month;

-- Data integrity check: available_copies should match open issues (expect 0 rows)
SELECT b.book_id, b.title, b.available_copies,
       b.total_copies - COUNT(bi.issue_id) AS expected
FROM books b
LEFT JOIN book_issues bi ON bi.book_id = b.book_id AND bi.return_date IS NULL
GROUP BY b.book_id, b.title, b.available_copies, b.total_copies
HAVING b.available_copies <> expected;
