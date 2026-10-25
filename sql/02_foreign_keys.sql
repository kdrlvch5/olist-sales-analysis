-- =====================================================================
-- 02_foreign_keys.sql
-- Olist E-commerce: fix missing category translations,
-- then add foreign keys (every reference must exist in its parent table).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Categories without an English translation (anti-join)
-- ---------------------------------------------------------------------
-- Found 2: pc_gamer, portateis_cozinha_e_preparadores_de_alimentos
SELECT DISTINCT p.product_category_name
FROM products p
LEFT JOIN category_translation t
    ON p.product_category_name = t.product_category_name
WHERE t.product_category_name IS NULL
  AND p.product_category_name IS NOT NULL;

-- Add the missing translations
INSERT INTO category_translation (product_category_name, product_category_name_english)
VALUES
    ('pc_gamer', 'pc_gamer'),
    ('portateis_cozinha_e_preparadores_de_alimentos', 'portable_kitchen_and_food_preparers');


-- ---------------------------------------------------------------------
-- 2. Foreign keys
-- ---------------------------------------------------------------------
-- Run one by one: in a single batch, one error rolls back all of them.
ALTER TABLE orders         ADD FOREIGN KEY (customer_id) REFERENCES customers (customer_id);
ALTER TABLE order_items    ADD FOREIGN KEY (order_id)    REFERENCES orders (order_id);
ALTER TABLE order_items    ADD FOREIGN KEY (product_id)  REFERENCES products (product_id);
ALTER TABLE order_items    ADD FOREIGN KEY (seller_id)   REFERENCES sellers (seller_id);
ALTER TABLE order_payments ADD FOREIGN KEY (order_id)    REFERENCES orders (order_id);
ALTER TABLE order_reviews  ADD FOREIGN KEY (order_id)    REFERENCES orders (order_id);
ALTER TABLE products       ADD FOREIGN KEY (product_category_name) REFERENCES category_translation (product_category_name);


-- ---------------------------------------------------------------------
-- 3. Check: list all foreign keys -> expect 7 rows
-- ---------------------------------------------------------------------
SELECT conrelid::regclass AS table_name, conname
FROM pg_constraint
WHERE contype = 'f';
