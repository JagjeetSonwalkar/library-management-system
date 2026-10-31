-- Requires MySQL 8.0.16+ (CHECK constraints are enforced)
DROP DATABASE IF EXISTS library_db;
CREATE DATABASE library_db CHARACTER SET utf8mb4;
USE library_db;

CREATE TABLE books (
    book_id          INT PRIMARY KEY AUTO_INCREMENT,
    title            VARCHAR(100) NOT NULL,
    author           VARCHAR(100) NOT NULL,
    category         VARCHAR(50)  NOT NULL,
    total_copies     INT NOT NULL DEFAULT 1,
    available_copies INT NOT NULL DEFAULT 1,
    CONSTRAINT chk_total_nonneg  CHECK (total_copies >= 0),
    CONSTRAINT chk_avail_range   CHECK (available_copies >= 0 AND available_copies <= total_copies),
    INDEX idx_books_category (category)
);

CREATE TABLE members (
    member_id  INT PRIMARY KEY AUTO_INCREMENT,
    name       VARCHAR(100) NOT NULL,
    email      VARCHAR(100) NOT NULL UNIQUE,
    join_date  DATE NOT NULL,
    status     ENUM('active','inactive') NOT NULL DEFAULT 'active'
);

CREATE TABLE book_issues (
    issue_id    INT PRIMARY KEY AUTO_INCREMENT,
    book_id     INT NOT NULL,
    member_id   INT NOT NULL,
    issue_date  DATE NOT NULL,
    due_date    DATE NOT NULL,
    return_date DATE NULL,
    CONSTRAINT fk_issue_book   FOREIGN KEY (book_id)   REFERENCES books(book_id)     ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_issue_member FOREIGN KEY (member_id) REFERENCES members(member_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_due_after_issue    CHECK (due_date >= issue_date),
    CONSTRAINT chk_return_after_issue CHECK (return_date IS NULL OR return_date >= issue_date),
    INDEX idx_issue_book (book_id),
    INDEX idx_issue_member (member_id),
    INDEX idx_issue_open (return_date, due_date)
);
