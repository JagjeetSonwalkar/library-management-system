"""MySQL connectivity + all business logic (CRUD, issue/return, reports)."""
import os
from contextlib import contextmanager
import mysql.connector
import pandas as pd


def _config():
    return dict(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", 3306)),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""), # use own password
        database=os.getenv("DB_NAME", "library_db"),
    )


@contextmanager
def get_conn():
    conn = mysql.connector.connect(**_config())
    try:
        yield conn
    finally:
        conn.close()


def fetch_df(sql, params=None):
    with get_conn() as conn:
        cur = conn.cursor(dictionary=True)
        cur.execute(sql, params or ())
        rows = cur.fetchall()
        cur.close()
    return pd.DataFrame(rows)


def execute(sql, params=None):
    with get_conn() as conn:
        cur = conn.cursor()
        try:
            cur.execute(sql, params or ())
            conn.commit()
            return cur.rowcount
        except Exception:
            conn.rollback()
            raise
        finally:
            cur.close()


# ------------------------------ BOOKS ------------------------------
def add_book(title, author, category, copies):
    execute("INSERT INTO books (title, author, category, total_copies, available_copies) "
            "VALUES (%s,%s,%s,%s,%s)", (title, author, category, copies, copies))


def update_book_quantity(book_id, new_total):
    """Set a new total; available changes by the same delta. Cannot drop below issued count."""
    with get_conn() as conn:
        cur = conn.cursor()
        try:
            cur.execute("SELECT total_copies, available_copies FROM books WHERE book_id=%s FOR UPDATE", (book_id,))
            row = cur.fetchone()
            if not row:
                raise ValueError("Book not found")
            total, avail = row
            issued = total - avail
            if new_total < issued:
                raise ValueError(f"{issued} copies are currently issued; total cannot be below that.")
            cur.execute("UPDATE books SET total_copies=%s, available_copies=%s WHERE book_id=%s",
                        (new_total, new_total - issued, book_id))
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            cur.close()


def delete_book(book_id):
    n = fetch_df("SELECT COUNT(*) AS n FROM book_issues WHERE book_id=%s", (book_id,)).iloc[0, 0]
    if n:
        raise ValueError(f"Cannot delete: book has {n} issue record(s) in history.")
    execute("DELETE FROM books WHERE book_id=%s", (book_id,))


# ----------------------------- MEMBERS -----------------------------
def add_member(name, email, status="active"):
    execute("INSERT INTO members (name, email, join_date, status) VALUES (%s,%s,CURDATE(),%s)",
            (name, email, status))


def set_member_status(member_id, status):
    execute("UPDATE members SET status=%s WHERE member_id=%s", (status, member_id))


def delete_member(member_id):
    n = fetch_df("SELECT COUNT(*) AS n FROM book_issues WHERE member_id=%s", (member_id,)).iloc[0, 0]
    if n:
        raise ValueError(f"Cannot delete: member has {n} issue record(s). Mark inactive instead.")
    execute("DELETE FROM members WHERE member_id=%s", (member_id,))


# -------------------------- ISSUE / RETURN --------------------------
def issue_book(book_id, member_id, days=14):
    with get_conn() as conn:
        cur = conn.cursor()
        try:
            cur.execute("SELECT available_copies FROM books WHERE book_id=%s FOR UPDATE", (book_id,))
            b = cur.fetchone()
            cur.execute("SELECT status FROM members WHERE member_id=%s", (member_id,))
            m = cur.fetchone()
            if not b or not m:
                raise ValueError("Book or member not found")
            if m[0] != "active":
                raise ValueError("Member is inactive")
            if b[0] <= 0:
                raise ValueError("No copies available")
            cur.execute("SELECT 1 FROM book_issues WHERE book_id=%s AND member_id=%s AND return_date IS NULL",
                        (book_id, member_id))
            if cur.fetchone():
                raise ValueError("Member already has this book")
            cur.execute("INSERT INTO book_issues (book_id, member_id, issue_date, due_date) "
                        "VALUES (%s,%s,CURDATE(),DATE_ADD(CURDATE(), INTERVAL %s DAY))",
                        (book_id, member_id, days))
            cur.execute("UPDATE books SET available_copies = available_copies - 1 WHERE book_id=%s", (book_id,))
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            cur.close()


def return_book(issue_id):
    with get_conn() as conn:
        cur = conn.cursor()
        try:
            cur.execute("SELECT book_id FROM book_issues WHERE issue_id=%s AND return_date IS NULL FOR UPDATE",
                        (issue_id,))
            r = cur.fetchone()
            if not r:
                raise ValueError("Issue not found or already returned")
            cur.execute("UPDATE book_issues SET return_date=CURDATE() WHERE issue_id=%s", (issue_id,))
            cur.execute("UPDATE books SET available_copies = available_copies + 1 WHERE book_id=%s", (r[0],))
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            cur.close()


# ------------------------------ REPORTS ------------------------------
Q = {
 "availability": """
    SELECT SUM(total_copies) AS total_copies, SUM(available_copies) AS available_copies,
           SUM(total_copies) - SUM(available_copies) AS currently_issued FROM books""",
 "books": "SELECT * FROM books ORDER BY title",
 "members": "SELECT * FROM members ORDER BY name",
 "borrowed": """
    SELECT bi.issue_id, m.name AS member, b.title, bi.issue_date, bi.due_date
    FROM book_issues bi JOIN members m ON m.member_id=bi.member_id
    JOIN books b ON b.book_id=bi.book_id
    WHERE bi.return_date IS NULL ORDER BY m.name""",
 "history": """
    SELECT m.name AS member, b.title, bi.issue_date, bi.due_date, bi.return_date
    FROM book_issues bi JOIN members m ON m.member_id=bi.member_id
    JOIN books b ON b.book_id=bi.book_id ORDER BY bi.issue_date DESC""",
 "overdue": """
    SELECT bi.issue_id, m.name AS member, m.email, b.title, bi.due_date,
           DATEDIFF(CURDATE(), bi.due_date) AS days_overdue,
           DATEDIFF(CURDATE(), bi.due_date) * 2 AS fine_rs
    FROM book_issues bi JOIN members m ON m.member_id=bi.member_id
    JOIN books b ON b.book_id=bi.book_id
    WHERE bi.return_date IS NULL AND bi.due_date < CURDATE()
    ORDER BY days_overdue DESC""",
 "top5": """
    SELECT b.title, b.author, COUNT(bi.issue_id) AS times_borrowed
    FROM books b JOIN book_issues bi ON bi.book_id=b.book_id
    GROUP BY b.book_id, b.title, b.author
    ORDER BY times_borrowed DESC, b.title LIMIT 5""",
 "late_returns": """
    SELECT m.name, COUNT(*) AS late_returns FROM book_issues bi
    JOIN members m ON m.member_id=bi.member_id
    WHERE bi.return_date > bi.due_date GROUP BY m.member_id, m.name ORDER BY late_returns DESC""",
 "never_borrowed": """
    SELECT member_id, name FROM members
    WHERE member_id NOT IN (SELECT DISTINCT member_id FROM book_issues)""",
 "by_category": """
    SELECT b.category, COUNT(*) AS issues FROM book_issues bi
    JOIN books b ON b.book_id=bi.book_id GROUP BY b.category ORDER BY issues DESC""",
}


def report(name):
    return fetch_df(Q[name])
