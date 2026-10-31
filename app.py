import streamlit as st
import db

st.set_page_config(page_title="Library Management System", page_icon="📚", layout="wide")
st.title("📚 Library Management System")

page = st.sidebar.radio("Navigate", ["Dashboard", "Books", "Members", "Issue / Return", "Reports"])


def run(action, ok_msg):
    """Run a DB action and show success / friendly error."""
    try:
        action()
        st.success(ok_msg)
        return True
    except Exception as e:
        st.error(str(e))
        return False


try:
    db.fetch_df("SELECT 1")
except Exception as e:
    st.error(f"Cannot connect to MySQL: {e}")
    st.info("Set DB_HOST, DB_USER, DB_PASSWORD, DB_NAME environment variables (see README).")
    st.stop()

# ---------------------------------------------------------------- Dashboard
if page == "Dashboard":
    a = db.report("availability").iloc[0]
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Total copies", int(a.total_copies or 0))
    c2.metric("Available", int(a.available_copies or 0))
    c3.metric("Currently issued", int(a.currently_issued or 0))
    c4.metric("Overdue", len(db.report("overdue")))
    left, right = st.columns(2)
    left.subheader("Top 5 most borrowed")
    left.dataframe(db.report("top5"), hide_index=True, use_container_width=True)
    right.subheader("Issues by category")
    cat = db.report("by_category")
    if not cat.empty:
        right.bar_chart(cat.set_index("category"))

# -------------------------------------------------------------------- Books
elif page == "Books":
    st.dataframe(db.report("books"), hide_index=True, use_container_width=True)
    t1, t2, t3 = st.tabs(["Add book", "Update quantity", "Delete book"])
    with t1:
        with st.form("add_book", clear_on_submit=True):
            title = st.text_input("Title"); author = st.text_input("Author")
            category = st.text_input("Category"); copies = st.number_input("Copies", 1, 1000, 1)
            if st.form_submit_button("Add"):
                if title and author and category:
                    run(lambda: db.add_book(title, author, category, int(copies)), "Book added.")
                else:
                    st.warning("Fill all fields.")
    books = db.report("books")
    opts = {f"{r.book_id} - {r.title}": r.book_id for r in books.itertuples()}
    with t2:
        if opts:
            sel = st.selectbox("Book", opts, key="upd_b")
            new_total = st.number_input("New total copies", 0, 1000, 1)
            if st.button("Update quantity"):
                run(lambda: db.update_book_quantity(opts[sel], int(new_total)), "Quantity updated.")
    with t3:
        if opts:
            sel = st.selectbox("Book", opts, key="del_b")
            if st.button("Delete book", type="primary"):
                run(lambda: db.delete_book(opts[sel]), "Book deleted.")

# ------------------------------------------------------------------ Members
elif page == "Members":
    st.dataframe(db.report("members"), hide_index=True, use_container_width=True)
    t1, t2, t3 = st.tabs(["Add member", "Change status", "Delete member"])
    with t1:
        with st.form("add_member", clear_on_submit=True):
            name = st.text_input("Full name"); email = st.text_input("Email")
            status = st.selectbox("Status", ["active", "inactive"])
            if st.form_submit_button("Add"):
                if name and "@" in email:
                    run(lambda: db.add_member(name, email, status), "Member added.")
                else:
                    st.warning("Enter a valid name and email.")
    members = db.report("members")
    mopts = {f"{r.member_id} - {r.name}": r.member_id for r in members.itertuples()}
    with t2:
        if mopts:
            sel = st.selectbox("Member", mopts, key="st_m")
            ns = st.selectbox("New status", ["active", "inactive"])
            if st.button("Update status"):
                run(lambda: db.set_member_status(mopts[sel], ns), "Status updated.")
    with t3:
        if mopts:
            sel = st.selectbox("Member", mopts, key="del_m")
            if st.button("Delete member", type="primary"):
                run(lambda: db.delete_member(mopts[sel]), "Member deleted.")

# ----------------------------------------------------------- Issue / Return
elif page == "Issue / Return":
    c1, c2 = st.columns(2)
    with c1:
        st.subheader("Issue a book")
        books = db.fetch_df("SELECT book_id, title, available_copies FROM books WHERE available_copies > 0 ORDER BY title")
        members = db.fetch_df("SELECT member_id, name FROM members WHERE status='active' ORDER BY name")
        bopts = {f"{r.title} ({r.available_copies} left)": r.book_id for r in books.itertuples()}
        mopts = {r.name: r.member_id for r in members.itertuples()}
        if bopts and mopts:
            b = st.selectbox("Book", bopts); m = st.selectbox("Member", mopts)
            days = st.slider("Loan period (days)", 1, 30, 14)
            if st.button("Issue"):
                run(lambda: db.issue_book(bopts[b], mopts[m], days), "Book issued.")
        else:
            st.info("No available books or active members.")
    with c2:
        st.subheader("Return a book")
        open_df = db.report("borrowed")
        ropts = {f"#{r.issue_id}: {r.title} → {r.member} (due {r.due_date})": r.issue_id
                 for r in open_df.itertuples()}
        if ropts:
            sel = st.selectbox("Open issue", ropts)
            if st.button("Return"):
                run(lambda: db.return_book(ropts[sel]), "Book returned.")
        else:
            st.info("Nothing to return.")
    st.subheader("Currently borrowed")
    st.dataframe(db.report("borrowed"), hide_index=True, use_container_width=True)

# ------------------------------------------------------------------ Reports
else:
    reports = {
        "Books available": "availability",
        "Who borrowed what (current)": "borrowed",
        "Full issue history": "history",
        "Overdue books (₹2/day fine)": "overdue",
        "Top 5 most borrowed books": "top5",
        "Members with late returns": "late_returns",
        "Members who never borrowed": "never_borrowed",
        "Issues by category": "by_category",
    }
    choice = st.selectbox("Report", list(reports))
    df = db.report(reports[choice])
    st.dataframe(df, hide_index=True, use_container_width=True)
    with st.expander("SQL used"):
        st.code(db.Q[reports[choice]], language="sql")
