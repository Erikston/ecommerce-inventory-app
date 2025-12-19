# E‑commerce Inventory Dashboard 📦

Streamlit dashboard for managing e‑commerce products, daily sales, inventory snapshots, and smart reorder suggestions backed by a MySQL database.

---

## Features

- CRUD management for **products** (add, update, delete SKUs).
- Capture **daily sales** per SKU and store them in MySQL.
- Take **inventory snapshots** to track on‑hand stock over time.
- Compute **ABC classification**, days of supply, and **reorder suggestions** by SKU.
- Visualizations for stock levels, days of supply, and annual consumption value.
- Built as a portfolio project to demonstrate end‑to‑end data handling: SQL schema + Python + Streamlit UI.

---
## Uses of This Project

This project simulates how a small e‑commerce business could manage inventory using data instead of spreadsheets.

- Manage products, daily sales, and inventory snapshots in a structured MySQL database.
- Use the Streamlit app to enter data and view current stock, sales trends, and key inventory metrics.
- Apply inventory analytics such as ABC classification, days of supply, and reorder point logic.
- Help a non‑technical operations or supply‑chain manager decide **what to reorder and when**.
- Showcase end‑to‑end skills for data analyst / data engineer roles: SQL, Python, dashboarding, and business‑oriented design.
  
---
## Tech Stack

- **Frontend / App**: Streamlit  
- **Backend**: Python (pandas, mysql‑connector / pymysql)  
- **Database**: MySQL  
- **Other**: Git, requirements.txt for dependency management

---

## Project Structure

ecommerce_inventory_app/
├─ app.py # Main Streamlit app
├─ config.py # Local DB connection settings (not for production)
├─ ecommerce_inventory_project.sql # MySQL schema + sample data
├─ requirements.txt # Python dependencies
├─ app_snapshots/ # UI screenshots used in README
└─ .gitignore


> Note: In a public repo, store real passwords in environment variables or `secrets.toml`, not directly in `config.py`.

---


1. **Clone the repository**

git clone https://github.com/Erikston/ecommerce-inventory-app.git
cd ecommerce-inventory-app


2. **Create and activate a virtual environment (optional but recommended)**

python -m venv venv
venv\Scripts\activate # Windows


3. **Install dependencies**

pip install -r requirements.txt


4. **Create the MySQL database**

- Create an empty database in MySQL, for example `ecommerce_inventory`.
- Run the SQL script:


5. **Update config**

- Open `config.py` and set your MySQL host, user, password, and database name.

6. **Run the app**
   
  streamlit run app.py

- Open the URL shown in the terminal (usually `http://localhost:8501`).

---
---

## Contact

If you’d like to discuss this project or opportunities:

- Email: rahulbabubu3@gmail.com



