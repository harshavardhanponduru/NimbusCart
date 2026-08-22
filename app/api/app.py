import os
import time
import psycopg2
from psycopg2.extras import RealDictCursor
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_NAME = os.getenv("DB_NAME", "nimbusdb")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASS = os.getenv("DB_PASSWORD", "postgrespassword")
DB_PORT = os.getenv("DB_PORT", "5432")

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASS,
        port=DB_PORT
    )

def init_db():
    retries = 10
    while retries > 0:
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute("""
                CREATE TABLE IF NOT EXISTS products (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR(255) NOT NULL,
                    price NUMERIC(10, 2) NOT NULL,
                    stock INT NOT NULL
                );
            """)
            conn.commit()
            cur.close()
            conn.close()
            print("Database initialized successfully.")
            break
        except Exception as e:
            print(f"Database connection waiting... ({e})")
            retries -= 1
            time.sleep(3)

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"}), 200

@app.route("/items", methods=["GET"])
def get_items():
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT id, name, price, stock FROM products ORDER BY id ASC;")
        rows = cur.fetchall()
        cur.close()
        conn.close()
        return jsonify([dict(row) for row in rows]), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/items", methods=["POST"])
def add_item():
    data = request.get_json()
    if not data or not all(k in data for k in ("name", "price", "stock")):
        return jsonify({"error": "Invalid payload"}), 400

    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            "INSERT INTO products (name, price, stock) VALUES (%s, %s, %s) RETURNING id, name, price, stock;",
            (data["name"], data["price"], data["stock"])
        )
        new_row = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()
        return jsonify(dict(new_row)), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000)