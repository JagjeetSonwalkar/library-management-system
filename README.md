# 📚 Library Management System

A SQL-backed library management system built with **Python**, **MySQL** and **Streamlit**. It manages books, members, and book issues/returns, and provides reports such as availability, overdue books and the most borrowed titles.

---

## 🎯 Features

- **Books:** add, update quantity, delete (blocked if the book has issue history)
- **Members:** add, activate/deactivate, delete (blocked if the member has issue history)
- **Issue / Return:** transactional, with checks for stock, active membership and duplicate issues
- **Reports:** availability, who borrowed what, overdue books with fines, top 5 borrowed, late returners, and more
- **Dashboard:** key metrics, top books and category chart

---

## 🧰 Tech Stack

| Layer | Technology |
|---|---|
| Database | MySQL 8.0.16+ |
| Backend logic | Python 3.9+, `mysql-connector-python`, `pandas` |
| UI | Streamlit |

---

## 📁 Project Structure

```
library_system/
├── README.md
├── requirements.txt
├── app.py                     # Streamlit UI (5 pages)
├── db.py                      # MySQL connection, CRUD, issue/return, reports
├── sql/
│   ├── 01_schema.sql          # Database, tables, constraints, indexes
│   ├── 02_sample_data.sql     # Sample books, members, issues
│   ├── 03_crud_operations.sql # CRUD statements + issue/return stored procedures
│   └── 04_reports.sql         # All reporting queries
└── screenshots/               # App and database screenshots
```

---

## 🗄️ Database Design

```
books (1) ───< book_issues >─── (1) members
```

### `books`
| Column | Type | Notes |
|---|---|---|
| book_id | INT | PK, AUTO_INCREMENT |
| title | VARCHAR(100) | NOT NULL |
| author | VARCHAR(100) | NOT NULL |
| category | VARCHAR(50) | NOT NULL |
| total_copies | INT | CHECK >= 0 |
| available_copies | INT | CHECK between 0 and total_copies |

### `members`
| Column | Type | Notes |
|---|---|---|
| member_id | INT | PK, AUTO_INCREMENT |
| name | VARCHAR(100) | NOT NULL |
| email | VARCHAR(100) | UNIQUE, NOT NULL |
| join_date | DATE | NOT NULL |
| status | ENUM('active','inactive') | Default `active` |

### `book_issues`
| Column | Type | Notes |
|---|---|---|
| issue_id | INT | PK, AUTO_INCREMENT |
| book_id | INT | FK → books(book_id), ON DELETE RESTRICT |
| member_id | INT | FK → members(member_id), ON DELETE RESTRICT |
| issue_date | DATE | NOT NULL |
| due_date | DATE | CHECK >= issue_date |
| return_date | DATE | NULL until returned |

### Constraints and rules
- Primary keys on all tables; foreign keys from `book_issues` to `books` and `members`
- `available_copies` can never go below 0 or above `total_copies`
- A book can be issued only if `available_copies > 0`, the member is `active`, and the member doesn't already hold that book
- Books and members with issue history cannot be deleted
- **Overdue** = `return_date IS NULL AND due_date < CURDATE()`

---

## 🚀 Setup and Run

### 1. Prerequisites
- Python 3.9+
- MySQL Server 8.0.16 or newer (CHECK constraints are ignored on older versions)

### 2. Install dependencies
```bash
pip install -r requirements.txt
```

### 3. Create the database
**MySQL Workbench:** open each file and click **Execute All** (first lightning icon), in this order:
1. `sql/01_schema.sql`
2. `sql/02_sample_data.sql`

**Command line:**
```bash
mysql -u root -p < sql/01_schema.sql
mysql -u root -p < sql/02_sample_data.sql
```

Verify:
```sql
USE library_db;
SELECT COUNT(*) FROM books;        -- 10
SELECT COUNT(*) FROM members;      -- 8
SELECT COUNT(*) FROM book_issues;  -- 15
```

### 4. Configure the connection
Edit the `_config()` function in `db.py` and set your MySQL password:
```python
password=os.getenv("DB_PASSWORD", "your_mysql_password"),
```
Or use environment variables `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`.

> ⚠️ Don't commit your real password to GitHub.

### 5. Start the app
```bash
streamlit run app.py
```
Open **http://localhost:8501**. If `streamlit` isn't recognized, use `python -m streamlit run app.py`.

---

## 🖥️ Using Without Streamlit

Everything can also be done in SQL:

- **Reports:** run `sql/04_reports.sql`
- **CRUD demos:** run `sql/03_crud_operations.sql` (note: it modifies the sample data)
- **Issue / return:**
  ```sql
  CALL issue_book(2, 1, 14);   -- book_id, member_id, loan days
  CALL return_book(1);         -- issue_id
  ```

---

## 📊 Business Questions and Queries

| Question | Query file | Techniques |
|---|---|---|
| How many books are available? | `04_reports.sql` Q1 | `SUM` aggregate |
| Which member borrowed which book? | Q2 | `JOIN` (3 tables) |
| Which books are overdue? | Q3 | `JOIN`, `DATEDIFF`, `CURDATE` |
| Top 5 most borrowed books | Q4 | `JOIN`, `GROUP BY`, `ORDER BY`, `LIMIT` |
| Members with late returns | Extra | `WHERE return_date > due_date`, `GROUP BY` |
| Members who never borrowed | Extra | Subquery with `NOT IN` |
| Books never issued | Extra | Subquery with `NOT IN` |
| Issues per category / month | Extra | `GROUP BY`, `DATE_FORMAT` |
| Average days a book is kept | Extra | `AVG`, `DATEDIFF` |
| Books due in the next 7 days | Extra | `BETWEEN`, `DATE_ADD` |
| Data integrity check | Extra | `LEFT JOIN`, `HAVING` |

---

## 📸 Screenshots

Save your screenshots in the `screenshots/` folder using these names and they will appear below.

| Page | File |
|---|---|
| Dashboard | `screenshots/dashboard.png` |
| Books | `screenshots/books.png` |
| Members | `screenshots/members.png` |
| Issue / Return | `screenshots/issue_return.png` |
| Reports | `screenshots/reports.png` |
| Database tables in Workbench | `screenshots/database.png` |

### Dashboard
![Dashboard](screenshots/dashboard.png)

### Books
![Books](screenshots/books.png)

### Members
![Members](screenshots/members.png)

### Issue / Return
![Issue and Return](screenshots/issue_return.png)

### Reports
![Reports](screenshots/reports.png)

### Database (MySQL Workbench)
![Database](screenshots/database.png)

---

## 🛠️ Troubleshooting

| Problem | Fix |
|---|---|
| `Cannot connect to MySQL` | Make sure the MySQL service is running and the credentials in `db.py` are correct |
| `Access denied for user` | Wrong username or password |
| `Unknown database 'library_db'` | Run `01_schema.sql` first |
| Error 1064 near `CHECK` | MySQL is older than 8.0.16; upgrade it |
| Error 1175 (safe update mode) | Use the provided `02_sample_data.sql`, or run `SET SQL_SAFE_UPDATES = 0;` |
| `streamlit: command not found` | Run `python -m streamlit run app.py` |

---

## 📚 Learning Outcomes Covered

- Normalized tables with primary keys, foreign keys and constraints
- JOINs, `GROUP BY`, `ORDER BY`, aggregates and subqueries
- Date functions (`CURDATE`, `DATEDIFF`, `DATE_ADD`, `DATE_FORMAT`)
- Transactions, row locking and stored procedures
- Connecting Python to MySQL, with a Streamlit interface on top