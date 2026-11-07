-- =====================================================================
-- 00_setup_postgres.sql
-- Creates the database and table, then loads the CSV (PostgreSQL / psql).
-- Run this from the PROJECT ROOT folder so the relative CSV path works:
--     psql -U postgres -f sql/00_setup_postgres.sql
-- Dataset: synthetic, 20,000 users. Not real company data.
-- =====================================================================

DROP DATABASE IF EXISTS ab_test_db;
CREATE DATABASE ab_test_db;
\c ab_test_db

-- "group" is a reserved word in SQL, so the column is named group_name
CREATE TABLE ab_test (
    user_id      VARCHAR(10) PRIMARY KEY,
    group_name   CHAR(1)     NOT NULL CHECK (group_name IN ('A', 'B')),
    offer        VARCHAR(20) NOT NULL,
    cart_value   INTEGER     NOT NULL,
    purchased    SMALLINT    NOT NULL CHECK (purchased IN (0, 1)),
    order_value  INTEGER     NOT NULL,
    complaint    SMALLINT    NOT NULL CHECK (complaint IN (0, 1)),
    returned     SMALLINT    NOT NULL CHECK (returned IN (0, 1))
);

-- \copy reads the file on the client side (works without superuser rights)
-- ENCODING 'UTF8' keeps the rupee symbol in the offer text intact
\copy ab_test FROM 'data/ecommerce_discount_ab_test.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

SELECT COUNT(*) AS rows_loaded FROM ab_test;
