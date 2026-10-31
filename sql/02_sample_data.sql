USE library_db;

INSERT INTO books (title, author, category, total_copies, available_copies) VALUES
('The Alchemist',               'Paulo Coelho',        'Fiction',    5, 5),
('Wings of Fire',               'A.P.J. Abdul Kalam',  'Biography',  4, 4),
('Clean Code',                  'Robert C. Martin',    'Technology', 3, 3),
('Introduction to Algorithms',  'Thomas H. Cormen',    'Technology', 2, 2),
('Sapiens',                     'Yuval Noah Harari',   'History',    4, 4),
('The Guide',                   'R.K. Narayan',        'Fiction',    3, 3),
('Atomic Habits',               'James Clear',         'Self-Help',  6, 6),
('Database System Concepts',    'Abraham Silberschatz','Technology', 3, 3),
('Discovery of India',          'Jawaharlal Nehru',    'History',    2, 2),
('Rich Dad Poor Dad',           'Robert Kiyosaki',     'Finance',    4, 4);

INSERT INTO members (name, email, join_date, status) VALUES
('Aarav Sharma',  'aarav@example.com',  '2024-01-10', 'active'),
('Priya Patil',   'priya@example.com',  '2024-02-15', 'active'),
('Rohan Deshmukh','rohan@example.com',  '2024-03-05', 'active'),
('Sneha Kulkarni','sneha@example.com',  '2024-04-20', 'active'),
('Vikram Singh',  'vikram@example.com', '2024-05-12', 'active'),
('Neha Joshi',    'neha@example.com',   '2024-06-01', 'inactive'),
('Karan Mehta',   'karan@example.com',  '2024-07-18', 'active'),
('Ananya Rao',    'ananya@example.com', '2024-08-25', 'active');

-- Dates are relative to today so overdue data always exists
INSERT INTO book_issues (book_id, member_id, issue_date, due_date, return_date) VALUES
-- returned books
(1, 1, DATE_SUB(CURDATE(), INTERVAL 60 DAY), DATE_SUB(CURDATE(), INTERVAL 46 DAY), DATE_SUB(CURDATE(), INTERVAL 50 DAY)),
(3, 2, DATE_SUB(CURDATE(), INTERVAL 55 DAY), DATE_SUB(CURDATE(), INTERVAL 41 DAY), DATE_SUB(CURDATE(), INTERVAL 35 DAY)), -- returned late
(7, 3, DATE_SUB(CURDATE(), INTERVAL 50 DAY), DATE_SUB(CURDATE(), INTERVAL 36 DAY), DATE_SUB(CURDATE(), INTERVAL 40 DAY)),
(7, 4, DATE_SUB(CURDATE(), INTERVAL 45 DAY), DATE_SUB(CURDATE(), INTERVAL 31 DAY), DATE_SUB(CURDATE(), INTERVAL 30 DAY)),
(1, 5, DATE_SUB(CURDATE(), INTERVAL 40 DAY), DATE_SUB(CURDATE(), INTERVAL 26 DAY), DATE_SUB(CURDATE(), INTERVAL 20 DAY)), -- returned late
(5, 1, DATE_SUB(CURDATE(), INTERVAL 35 DAY), DATE_SUB(CURDATE(), INTERVAL 21 DAY), DATE_SUB(CURDATE(), INTERVAL 25 DAY)),
(3, 7, DATE_SUB(CURDATE(), INTERVAL 30 DAY), DATE_SUB(CURDATE(), INTERVAL 16 DAY), DATE_SUB(CURDATE(), INTERVAL 18 DAY)),
(10,8, DATE_SUB(CURDATE(), INTERVAL 28 DAY), DATE_SUB(CURDATE(), INTERVAL 14 DAY), DATE_SUB(CURDATE(), INTERVAL 15 DAY)),
(7, 2, DATE_SUB(CURDATE(), INTERVAL 25 DAY), DATE_SUB(CURDATE(), INTERVAL 11 DAY), DATE_SUB(CURDATE(), INTERVAL 12 DAY)),
-- currently issued, overdue
(4, 1, DATE_SUB(CURDATE(), INTERVAL 30 DAY), DATE_SUB(CURDATE(), INTERVAL 16 DAY), NULL),
(8, 3, DATE_SUB(CURDATE(), INTERVAL 25 DAY), DATE_SUB(CURDATE(), INTERVAL 11 DAY), NULL),
(1, 4, DATE_SUB(CURDATE(), INTERVAL 20 DAY), DATE_SUB(CURDATE(), INTERVAL 6 DAY),  NULL),
-- currently issued, not yet due
(7, 5, DATE_SUB(CURDATE(), INTERVAL 5 DAY),  DATE_ADD(CURDATE(), INTERVAL 9 DAY),  NULL),
(3, 8, DATE_SUB(CURDATE(), INTERVAL 3 DAY),  DATE_ADD(CURDATE(), INTERVAL 11 DAY), NULL),
(2, 7, DATE_SUB(CURDATE(), INTERVAL 2 DAY),  DATE_ADD(CURDATE(), INTERVAL 12 DAY), NULL);

-- Keep available_copies consistent with open issues
UPDATE books b
SET available_copies = total_copies -
    (SELECT COUNT(*) FROM book_issues bi WHERE bi.book_id = b.book_id AND bi.return_date IS NULL);
