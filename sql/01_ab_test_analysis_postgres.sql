-- =====================================================================
-- 01_ab_test_analysis_postgres.sql
-- E-commerce Discount Framing A/B Test: Rs 200 OFF (Group A) vs 20% OFF (Group B)
-- PostgreSQL analysis. Run after 00_setup_postgres.sql:
--     psql -U postgres -d ab_test_db -f sql/01_ab_test_analysis_postgres.sql
-- Dataset: synthetic, 20,000 users (10,000 per group). Not real company data.
-- Table: ab_test(user_id, group_name, offer, cart_value, purchased,
--                order_value, complaint, returned)
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. DATA VALIDATION: count rows that VIOLATE each business rule (expect 0)
-- ---------------------------------------------------------------------
SELECT
    SUM(CASE WHEN purchased = 0 AND order_value <> 0   THEN 1 ELSE 0 END) AS rule1_no_purchase_has_order_value,
    SUM(CASE WHEN purchased = 1 AND order_value <> 800 THEN 1 ELSE 0 END) AS rule2_purchase_not_800,
    SUM(CASE WHEN purchased = 0 AND complaint <> 0     THEN 1 ELSE 0 END) AS rule3_complaint_without_purchase,
    SUM(CASE WHEN purchased = 0 AND returned <> 0      THEN 1 ELSE 0 END) AS rule4_return_without_purchase,
    SUM(CASE WHEN complaint = 1 AND purchased <> 1     THEN 1 ELSE 0 END) AS rule5_complaint_not_purchaser,
    SUM(CASE WHEN returned = 1 AND purchased <> 1      THEN 1 ELSE 0 END) AS rule6_return_not_purchaser,
    SUM(CASE WHEN group_name = 'A' AND offer NOT LIKE '%200 OFF' THEN 1 ELSE 0 END) AS rule7_group_a_wrong_offer,
    SUM(CASE WHEN group_name = 'B' AND offer <> '20% OFF'        THEN 1 ELSE 0 END) AS rule8_group_b_wrong_offer
FROM ab_test;


-- ---------------------------------------------------------------------
-- 1. Total users (denominator) and uniqueness check
-- ---------------------------------------------------------------------
SELECT
    COUNT(*)                AS total_users,
    COUNT(DISTINCT user_id) AS unique_users
FROM ab_test;


-- ---------------------------------------------------------------------
-- 2. Users and purchases by group
-- ---------------------------------------------------------------------
SELECT
    group_name,
    offer,
    COUNT(*)       AS users,
    SUM(purchased) AS purchases
FROM ab_test
GROUP BY group_name, offer
ORDER BY group_name;


-- ---------------------------------------------------------------------
-- 3. PRIMARY METRIC: purchase conversion rate by group
--    Conversion = purchases / users * 100
-- ---------------------------------------------------------------------
SELECT
    group_name,
    offer,
    COUNT(*)       AS users,
    SUM(purchased) AS purchases,
    ROUND(100.0 * SUM(purchased) / COUNT(*), 2) AS conversion_rate_pct
FROM ab_test
GROUP BY group_name, offer
ORDER BY group_name;


-- ---------------------------------------------------------------------
-- 4. Absolute difference in conversion (B - A), in percentage points
-- ---------------------------------------------------------------------
WITH rates AS (
    SELECT
        group_name,
        100.0 * SUM(purchased) / COUNT(*) AS conv
    FROM ab_test
    GROUP BY group_name
)
SELECT
    ROUND(MAX(CASE WHEN group_name = 'A' THEN conv END), 2) AS conv_a_pct,
    ROUND(MAX(CASE WHEN group_name = 'B' THEN conv END), 2) AS conv_b_pct,
    ROUND(
        MAX(CASE WHEN group_name = 'B' THEN conv END)
        - MAX(CASE WHEN group_name = 'A' THEN conv END), 2
    ) AS absolute_diff_pp
FROM rates;


-- ---------------------------------------------------------------------
-- 5. Relative lift = (Conv_B - Conv_A) / Conv_A * 100
-- ---------------------------------------------------------------------
WITH rates AS (
    SELECT
        group_name,
        100.0 * SUM(purchased) / COUNT(*) AS conv
    FROM ab_test
    GROUP BY group_name
),
pivoted AS (
    SELECT
        MAX(CASE WHEN group_name = 'A' THEN conv END) AS conv_a,
        MAX(CASE WHEN group_name = 'B' THEN conv END) AS conv_b
    FROM rates
)
SELECT
    ROUND(conv_a, 2)                             AS conv_a_pct,
    ROUND(conv_b, 2)                             AS conv_b_pct,
    ROUND(conv_b - conv_a, 2)                    AS absolute_diff_pp,
    ROUND(100.0 * (conv_b - conv_a) / conv_a, 2) AS relative_lift_pct
FROM pivoted;


-- ---------------------------------------------------------------------
-- 6. GUARDRAIL 1: complaint rate (denominator = purchasers, not all users)
-- ---------------------------------------------------------------------
SELECT
    group_name,
    offer,
    SUM(purchased) AS purchasers,
    SUM(complaint) AS complaints,
    ROUND(100.0 * SUM(complaint) / SUM(purchased), 2) AS complaint_rate_pct
FROM ab_test
GROUP BY group_name, offer
ORDER BY group_name;


-- ---------------------------------------------------------------------
-- 7. GUARDRAIL 2: return rate (denominator = purchasers)
-- ---------------------------------------------------------------------
SELECT
    group_name,
    offer,
    SUM(purchased) AS purchasers,
    SUM(returned)  AS returns,
    ROUND(100.0 * SUM(returned) / SUM(purchased), 2) AS return_rate_pct
FROM ab_test
GROUP BY group_name, offer
ORDER BY group_name;


-- ---------------------------------------------------------------------
-- 8. Orders, total order value and AOV (sanity check: every order = 800)
-- ---------------------------------------------------------------------
SELECT
    group_name,
    offer,
    SUM(purchased)   AS orders,
    SUM(order_value) AS total_order_value,
    ROUND(1.0 * SUM(order_value) / SUM(purchased), 2) AS aov
FROM ab_test
GROUP BY group_name, offer
ORDER BY group_name;


-- ---------------------------------------------------------------------
-- 9. FINAL EXPERIMENT SUMMARY: all metrics in one table
-- ---------------------------------------------------------------------
SELECT
    group_name,
    offer,
    COUNT(*)       AS users,
    SUM(purchased) AS purchasers,
    ROUND(100.0 * SUM(purchased) / COUNT(*), 2)        AS conversion_pct,
    SUM(complaint) AS complaints,
    ROUND(100.0 * SUM(complaint) / SUM(purchased), 2)  AS complaint_rate_pct,
    SUM(returned)  AS returns,
    ROUND(100.0 * SUM(returned) / SUM(purchased), 2)   AS return_rate_pct,
    SUM(order_value) AS total_order_value,
    ROUND(1.0 * SUM(order_value) / SUM(purchased), 2)  AS aov
FROM ab_test
GROUP BY group_name, offer
ORDER BY group_name;
