# app.py
import streamlit as st
import mysql.connector
import pandas as pd
from datetime import date

from config import MYSQL_HOST, MYSQL_PORT, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE

# ---------- DB CONNECTION ----------

def get_connection():
    return mysql.connector.connect(
        host=MYSQL_HOST,
        port=MYSQL_PORT,
        user=MYSQL_USER,
        password=MYSQL_PASSWORD,
        database=MYSQL_DATABASE
    )

def run_query(query, params=None, fetch=False):
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute(query, params or ())
    data = cursor.fetchall() if fetch else None
    conn.commit()
    cursor.close()
    conn.close()
    return data

# ---------- PAGE HELPERS ----------

def page_products():
    st.header("Catalog Management")

    # Create
    st.subheader("Add New Product")
    with st.form("add_product_form"):
        sku = st.text_input("SKU")
        name = st.text_input("Product Name")
        category = st.text_input("Category")
        unit_cost = st.number_input("Unit Cost", min_value=0.0, step=0.1)
        submitted = st.form_submit_button("Add Product")
        if submitted:
            if sku and name and category:
                run_query(
                    "INSERT INTO products (sku, product_name, category, unit_cost) VALUES (%s, %s, %s, %s)",
                    (sku, name, category, unit_cost)
                )
                st.success("Product added.")
            else:
                st.error("Please fill all fields.")

    st.subheader("Existing Products")

    products = run_query("SELECT product_id, sku, product_name, category, unit_cost FROM products", fetch=True)
    df = pd.DataFrame(products)
    st.dataframe(df)

    # Update / Delete
    st.subheader("Update / Delete Product")
    if df.empty:
        st.info("No products yet.")
        return

    selected_id = st.selectbox("Select product_id to edit", df["product_id"].tolist())
    selected_row = df[df["product_id"] == selected_id].iloc[0]

    col1, col2 = st.columns(2)
    with col1:
        new_name = st.text_input("Product Name", value=selected_row["product_name"])
        new_category = st.text_input("Category", value=selected_row["category"])
    with col2:
        new_sku = st.text_input("SKU", value=selected_row["sku"])
        new_unit_cost = st.number_input("Unit Cost", min_value=0.0, step=0.1, value=float(selected_row["unit_cost"]))

    c1, c2 = st.columns(2)
    with c1:
        if st.button("Update Product"):
            run_query(
                """
                UPDATE products
                SET sku=%s, product_name=%s, category=%s, unit_cost=%s
                WHERE product_id=%s
                """,
                (new_sku, new_name, new_category, new_unit_cost, selected_id)
            )
            st.success("Product updated. Use 'Rerun' if needed.")
    with c2:
        if st.button("Delete Product"):
            run_query("DELETE FROM products WHERE product_id=%s", (selected_id,))
            st.warning("Product deleted. Use 'Rerun' if needed.")

def page_inventory():
    st.header("Add Inventory Snapshot")

    products = run_query("SELECT product_id, sku FROM products ORDER BY sku", fetch=True)
    if not products:
        st.info("No products available. Add products first.")
        return

    product_map = {f'{p["sku"]} (id {p["product_id"]})': p["product_id"] for p in products}
    prod_label = st.selectbox("Product", list(product_map.keys()))
    product_id = product_map[prod_label]

    inv_date = st.date_input("Inventory Date", value=date.today())
    on_hand = st.number_input("On-hand Quantity", min_value=0, step=1)

    if st.button("Save Inventory Snapshot"):
        run_query(
            """
            INSERT INTO inventory_daily (product_id, inv_date, on_hand)
            VALUES (%s, %s, %s)
            ON DUPLICATE KEY UPDATE on_hand = VALUES(on_hand)
            """,
            (product_id, inv_date, on_hand)
        )
        st.success("Inventory snapshot saved.")

    st.subheader("Recent Inventory")
    rows = run_query(
        """
        SELECT i.product_id, p.sku, i.inv_date, i.on_hand
        FROM inventory_daily i
        JOIN products p ON p.product_id = i.product_id
        ORDER BY i.inv_date DESC, p.sku
        LIMIT 50
        """,
        fetch=True
    )
    if rows:
        st.dataframe(pd.DataFrame(rows))
    else:
        st.info("No inventory records yet.")

def page_sales():
    st.header("Add Daily Sales")

    products = run_query("SELECT product_id, sku FROM products ORDER BY sku", fetch=True)
    if not products:
        st.info("No products available. Add products first.")
        return

    product_map = {f'{p["sku"]} (id {p["product_id"]})': p["product_id"] for p in products}
    prod_label = st.selectbox("Product", list(product_map.keys()))
    product_id = product_map[prod_label]

    sales_date = st.date_input("Sales Date", value=date.today())
    qty_sold = st.number_input("Quantity Sold", min_value=0, step=1)

    if st.button("Save Sales"):
        run_query(
            """
            INSERT INTO sales_daily (product_id, sales_date, qty_sold)
            VALUES (%s, %s, %s)
            ON DUPLICATE KEY UPDATE qty_sold = VALUES(qty_sold)
            """,
            (product_id, sales_date, qty_sold)
        )
        st.success("Sales record saved.")

    st.subheader("Recent Sales")
    rows = run_query(
        """
        SELECT s.product_id, p.sku, s.sales_date, s.qty_sold
        FROM sales_daily s
        JOIN products p ON p.product_id = s.product_id
        ORDER BY s.sales_date DESC, p.sku
        LIMIT 50
        """,
        fetch=True
    )
    if rows:
        st.dataframe(pd.DataFrame(rows))
    else:
        st.info("No sales records yet.")

def page_reorder():
    st.header("Reorder Suggestions")

    # Main reorder view
    rows = run_query("SELECT * FROM v_reorder_suggestions", fetch=True)
    if not rows:
        st.info("No data in v_reorder_suggestions.")
        return

    df = pd.DataFrame(rows)

    st.subheader("Full Reorder Table")
    st.dataframe(df)

    # Only items that need reorder
    df_reorder = df[df["action"] == "REORDER"]

    st.subheader("Items to Reorder")
    if df_reorder.empty:
        st.success("No items currently below reorder point.")
    else:
        st.dataframe(
            df_reorder[
                ["sku", "abc_class", "avg_daily_sales", "on_hand",
                 "reorder_point", "suggested_order_qty", "action"]
            ]
        )

        # Suggested order qty by SKU
        st.subheader("Suggested Order Qty by SKU")
        chart_order = df_reorder[["sku", "suggested_order_qty"]].set_index("sku")
        st.bar_chart(chart_order, use_container_width=True) 

    # Days of supply by SKU (from v_days_of_supply)
    st.subheader("Days of Supply by SKU")
    dos_rows = run_query("SELECT sku, days_of_supply FROM v_days_of_supply", fetch=True)
    if dos_rows:
        df_dos = pd.DataFrame(dos_rows)
        df_dos = df_dos.sort_values("days_of_supply", ascending=True)
        chart_dos = df_dos.set_index("sku")
        st.bar_chart(chart_dos, use_container_width=True)  
    else:
        st.info("No data in v_days_of_supply.")

    # Annual consumption value by SKU
    st.subheader("Annual Consumption Value by SKU")
    abc_rows = run_query(
        "SELECT sku, annual_consumption_value, abc_class FROM v_abc",
        fetch=True
    )
    if abc_rows:
        df_abc = pd.DataFrame(abc_rows)
        df_abc = df_abc.sort_values("annual_consumption_value", ascending=False)
        chart_acv = df_abc.set_index("sku")[["annual_consumption_value"]]
        st.bar_chart(chart_acv, use_container_width=True)  
        st.caption("Higher bars are A items; lower bars are B/C items.")
    else:
        st.info("No data in v_abc.")



# ---------- MAIN APP ----------

def main():
    st.set_page_config(page_title="E-commerce Inventory App", layout="wide")

    st.sidebar.title("Navigation")
    page = st.sidebar.radio(
        "Go to",
        ("Products", "Inventory Snapshots", "Daily Sales", "Reorder Suggestions")
        )

    if page == "Products":
        page_products()
    elif page == "Inventory Snapshots":
        page_inventory()
    elif page == "Daily Sales":
        page_sales()
    elif page == "Reorder Suggestions":
        page_reorder()

if __name__ == "__main__":
    main()
