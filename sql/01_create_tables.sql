-- =====================================================================
-- 01_create_tables.sql
-- Olist E-commerce: create the database, tables and primary keys,
-- then load the raw Kaggle CSV files.
-- =====================================================================

-- Run first, connected to the default "postgres" database:
CREATE DATABASE olist;
-- Then connect to "olist" and run the rest of this script.


-- ---------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------

-- One row = one order
CREATE TABLE orders (
    order_id                       TEXT PRIMARY KEY,
    customer_id                    TEXT NOT NULL,
    order_status                   TEXT NOT NULL,
    order_purchase_timestamp       TIMESTAMP NOT NULL,
    order_approved_at              TIMESTAMP,
    order_delivered_carrier_date   TIMESTAMP,
    order_delivered_customer_date  TIMESTAMP,
    order_estimated_delivery_date  TIMESTAMP
);

-- One row = one customer in one order (customer_id is new for every order;
-- customer_unique_id is the real person)
CREATE TABLE customers (
    customer_id               TEXT PRIMARY KEY,
    customer_unique_id        TEXT NOT NULL,
    customer_zip_code_prefix  TEXT,          -- text: keeps leading zeros
    customer_city             TEXT,
    customer_state            TEXT
);

-- One row = one item in an order
CREATE TABLE order_items (
    order_id             TEXT,
    order_item_id        INT,
    product_id           TEXT,
    seller_id            TEXT,
    shipping_limit_date  TIMESTAMP,
    price                DECIMAL(10,2),
    freight_value        DECIMAL(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

-- One row = one seller
CREATE TABLE sellers (
    seller_id               TEXT PRIMARY KEY,
    seller_zip_code_prefix  TEXT,
    seller_city             TEXT,
    seller_state            TEXT
);

-- One row = one product ("lenght" typo is kept as in the source file)
CREATE TABLE products (
    product_id                  TEXT PRIMARY KEY,
    product_category_name       TEXT,
    product_name_lenght         INT,
    product_description_lenght  INT,
    product_photos_qty          INT,
    product_weight_g            DECIMAL(10,2),
    product_length_cm           DECIMAL(10,2),
    product_height_cm           DECIMAL(10,2),
    product_width_cm            DECIMAL(10,2)
);

-- One row = one payment (an order can be paid in several parts)
CREATE TABLE order_payments (
    order_id              TEXT,
    payment_sequential    INT,
    payment_type          TEXT,
    payment_installments  INT,
    payment_value         DECIMAL(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);

-- One row = one review for one order.
-- Primary key is added after the import (see step 3).
CREATE TABLE order_reviews (
    review_id                TEXT,
    order_id                 TEXT,
    review_score             INT,
    review_comment_title     TEXT,
    review_comment_message   TEXT,
    review_creation_date     TIMESTAMP,
    review_answer_timestamp  TIMESTAMP
);

-- One row = one product category (Portuguese -> English)
CREATE TABLE category_translation (
    product_category_name          TEXT PRIMARY KEY,
    product_category_name_english  TEXT
);


-- ---------------------------------------------------------------------
-- 2. Load the CSV files
-- ---------------------------------------------------------------------
-- Most tables were imported with DBeaver (Import Data -> CSV,
-- header on top, "Set empty strings to NULL" = on).
--
-- order_reviews has multi-line comments that broke the DBeaver import,
-- so it was loaded with psql instead:
--
-- \copy order_reviews FROM '/path/to/olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true);


-- Check row counts after the import (expected values in comments)
SELECT COUNT(*) FROM orders;                -- 99,441
SELECT COUNT(*) FROM customers;             -- 99,441
SELECT COUNT(*) FROM order_items;           -- 112,650
SELECT COUNT(*) FROM sellers;               -- 3,095
SELECT COUNT(*) FROM products;              -- 32,951
SELECT COUNT(*) FROM order_payments;        -- 103,886
SELECT COUNT(*) FROM order_reviews;         -- 99,224
SELECT COUNT(*) FROM category_translation;  -- 71
SELECT * FROM category_translation LIMIT 5;


-- ---------------------------------------------------------------------
-- 3. Primary key for order_reviews
-- ---------------------------------------------------------------------
-- review_id alone is NOT unique (one review can cover several orders).
-- Check that the pair (review_id, order_id) is unique -> expect 0 rows:
SELECT review_id, order_id, COUNT(*)
FROM order_reviews
GROUP BY review_id, order_id
HAVING COUNT(*) > 1;

ALTER TABLE order_reviews ADD PRIMARY KEY (review_id, order_id);
