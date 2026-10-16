
-- =====================================================
-- OLIST E-COMMERCE DATA ANALYSIS
-- Database: olist_analysis
-- SQL: PostgreSQL
-- =====================================================


-- =====================================================
-- 1. ORDER STATUS ANALYSIS
-- Purpose: Count orders by status and understand order outcomes.
-- Skills: SELECT, GROUP BY, ORDER BY, COUNT
-- =====================================================

SELECT
    order_status,
    COUNT(*) AS order_count
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;


-- =====================================================
-- 2. CANCELLATION RATE
-- Purpose: Calculate the percentage of orders that were cancelled.
-- Skills: COUNT, subquery
-- =====================================================

SELECT
    COUNT(*) AS cancelled_orders,
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM orders),
        2
    ) AS cancellation_rate_pct
FROM orders
WHERE order_status = 'canceled';


-- =====================================================
-- 3. DELIVERY RATE
-- Purpose: Calculate the percentage of orders marked as delivered.
-- Skills: WHERE, COUNT, subquery
-- =====================================================

SELECT
    COUNT(*) AS delivered_orders,
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM orders),
        2
    ) AS delivery_rate_pct
FROM orders
WHERE order_status = 'delivered';


-- =====================================================
-- 4. ORDER STATUS PERCENTAGE
-- Purpose: Compare each order status as a share of all orders.
-- Skills: GROUP BY, aggregate functions, window function
-- =====================================================

SELECT
    order_status,
    COUNT(*) AS order_count,
    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS order_percentage
FROM orders
GROUP BY order_status
ORDER BY order_percentage DESC;


-- =====================================================
-- 5. DELIVERY PERFORMANCE
-- Purpose: Compare actual delivery dates with estimated dates.
-- Skills: CASE WHEN, aggregate functions
-- Note: Excludes orders without an actual customer delivery date.
-- =====================================================

SELECT
    CASE
        WHEN order_delivered_customer_date
             <= order_estimated_delivery_date
            THEN 'Early/On Time'
        ELSE 'Late'
    END AS delivery_performance,
    COUNT(*) AS order_count
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
GROUP BY
    CASE
        WHEN order_delivered_customer_date
             <= order_estimated_delivery_date
            THEN 'Early/On Time'
        ELSE 'Late'
    END
ORDER BY order_count DESC;



-- =====================================================
-- 6. UNIQUE CUSTOMER COUNT
-- Purpose: Count actual customers using customer_unique_id.
-- Skills: COUNT, DISTINCT
-- =====================================================

SELECT
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers;


-- =====================================================
-- 7. ONE-TIME VS REPEAT CUSTOMERS
-- Purpose: Classify customers based on the number of orders.
-- Skills: CTE, CASE WHEN, GROUP BY
-- =====================================================

WITH customer_order_counts AS (
    SELECT
        customer_unique_id,
        COUNT(DISTINCT customer_id) AS order_count
    FROM customers
    GROUP BY customer_unique_id
),
customer_types AS (
    SELECT
        customer_unique_id,
        order_count,
        CASE
            WHEN order_count > 1 THEN 'Repeat'
            ELSE 'One-time'
        END AS customer_type
    FROM customer_order_counts
)
SELECT
    customer_type,
    COUNT(*) AS customer_count
FROM customer_types
GROUP BY customer_type
ORDER BY customer_count DESC;


-- =====================================================
-- 8. REPEAT CUSTOMER RATE
-- Purpose: Calculate the percentage of customers who ordered
-- more than once during the observed period.
-- Skills: CTE, CASE WHEN, aggregate functions
-- =====================================================

WITH customer_order_counts AS (
    SELECT
        customer_unique_id,
        COUNT(DISTINCT customer_id) AS order_count
    FROM customers
    GROUP BY customer_unique_id
)
SELECT
    COUNT(*) AS total_customers,
    COUNT(*) FILTER (WHERE order_count > 1) AS repeat_customers,
    ROUND(
        COUNT(*) FILTER (WHERE order_count > 1) * 100.0
        / COUNT(*),
        2
    ) AS repeat_customer_rate_pct
FROM customer_order_counts;


-- =====================================================
-- 9. CUSTOMER ORDER FREQUENCY
-- Purpose: See how many customers placed 1, 2, 3, or more orders.
-- Skills: CTE, GROUP BY, ORDER BY
-- =====================================================

WITH customer_order_counts AS (
    SELECT
        customer_unique_id,
        COUNT(DISTINCT customer_id) AS order_count
    FROM customers
    GROUP BY customer_unique_id
)
SELECT
    order_count,
    COUNT(*) AS customer_count
FROM customer_order_counts
GROUP BY order_count
ORDER BY order_count;



-- =====================================================
-- 10. REVENUE BY PRODUCT CATEGORY
-- Purpose: Identify the product categories contributing
-- the most delivered product revenue.
-- Skills: JOIN, GROUP BY, SUM, ORDER BY
-- Revenue excludes freight charges.
-- =====================================================

SELECT
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS product_category,
    ROUND(SUM(oi.price), 2) AS delivered_product_revenue
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )
ORDER BY delivered_product_revenue DESC;


-- =====================================================
-- 11. PRODUCT CATEGORY REVENUE SHARE
-- Purpose: Calculate each category's percentage of
-- total delivered product revenue.
-- Skills: CTE, JOIN, GROUP BY, window function
-- =====================================================

WITH category_revenue AS (
    SELECT
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS product_category,
        SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN orders o
        ON oi.order_id = o.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct
        ON p.product_category_name = ct.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        )
)
SELECT
    product_category,
    ROUND(revenue, 2) AS delivered_product_revenue,
    ROUND(
        revenue * 100.0 / SUM(revenue) OVER (),
        2
    ) AS revenue_share_pct
FROM category_revenue
ORDER BY revenue DESC;


-- =====================================================
-- 12. MONTHLY DELIVERED PRODUCT REVENUE
-- Purpose: Examine how delivered product revenue changes
-- from month to month.
-- Skills: DATE_TRUNC, JOIN, GROUP BY, SUM
-- =====================================================

SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp)::DATE
        AS purchase_month,
    ROUND(SUM(oi.price), 2) AS delivered_product_revenue
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY purchase_month;


-- =====================================================
-- 13. MONTHLY REVENUE WITH MONTH-OVER-MONTH CHANGE
-- Purpose: Compare monthly revenue with the previous month.
-- Skills: CTE, DATE_TRUNC, window function, LAG
-- =====================================================

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp)::DATE
            AS purchase_month,
        SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
),
monthly_comparison AS (
    SELECT
        purchase_month,
        revenue,
        LAG(revenue) OVER (ORDER BY purchase_month)
            AS previous_month_revenue
    FROM monthly_revenue
)
SELECT
    purchase_month,
    ROUND(revenue, 2) AS delivered_product_revenue,
    ROUND(previous_month_revenue, 2) AS previous_month_revenue,
    ROUND(
        (revenue - previous_month_revenue) * 100.0
        / NULLIF(previous_month_revenue, 0),
        2
    ) AS month_over_month_change_pct
FROM monthly_comparison
ORDER BY purchase_month;



-- =====================================================
-- 14. PAYMENT METHOD ANALYSIS
-- Purpose: Compare transaction counts and payment value
-- across payment methods.
-- Skills: GROUP BY, SUM, COUNT, window function
-- =====================================================

SELECT
    payment_type,
    COUNT(*) AS transaction_count,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(
        SUM(payment_value) * 100.0
        / SUM(SUM(payment_value)) OVER (),
        2
    ) AS payment_value_share_pct
FROM payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;


-- =====================================================
-- 15. SINGLE VS MULTIPLE INSTALLMENTS
-- Purpose: Compare average payment value by installment type.
-- Skills: CASE WHEN, GROUP BY, AVG
-- =====================================================

SELECT
    CASE
        WHEN payment_installments = 1 THEN 'Single installment'
        WHEN payment_installments > 1 THEN 'Multiple installments'
        ELSE 'Other or invalid'
    END AS installment_type,
    COUNT(*) AS payment_records,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM payments
WHERE payment_installments IS NOT NULL
GROUP BY
    CASE
        WHEN payment_installments = 1 THEN 'Single installment'
        WHEN payment_installments > 1 THEN 'Multiple installments'
        ELSE 'Other or invalid'
    END
ORDER BY average_payment_value DESC;


-- =====================================================
-- 16. TOP 10 SELLERS BY DELIVERED PRODUCT REVENUE
-- Purpose: Identify sellers generating the most
-- delivered product revenue.
-- Skills: JOIN, GROUP BY, SUM, ORDER BY, LIMIT
-- Revenue excludes freight charges.
-- =====================================================

SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(SUM(oi.price), 2) AS delivered_product_revenue
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
JOIN sellers s
    ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
GROUP BY
    s.seller_id,
    s.seller_city,
    s.seller_state
ORDER BY delivered_product_revenue DESC
LIMIT 10;


-- =====================================================
-- 17. SELLER SHIPPING PERFORMANCE
-- Purpose: Compare seller shipping timeliness against
-- the shipping deadline recorded for each order item.
-- Skills: JOIN, CASE WHEN, aggregate functions
-- Note: Uses carrier handoff date as a shipping proxy.
-- =====================================================

SELECT
    CASE
        WHEN o.order_delivered_carrier_date IS NULL
            THEN 'Unknown'
        WHEN o.order_delivered_carrier_date <= oi.shipping_limit_date
            THEN 'On Time'
        ELSE 'Late'
    END AS shipping_performance,
    COUNT(*) AS order_item_count,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS item_share_pct
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
GROUP BY
    CASE
        WHEN o.order_delivered_carrier_date IS NULL
            THEN 'Unknown'
        WHEN o.order_delivered_carrier_date <= oi.shipping_limit_date
            THEN 'On Time'
        ELSE 'Late'
    END
ORDER BY order_item_count DESC;



-- =====================================================
-- 18. CUSTOMER DISTRIBUTION BY STATE
-- Purpose: Identify states with the largest customer base.
-- Skills: JOIN, GROUP BY, COUNT, ORDER BY
-- =====================================================

SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers
FROM customers c
GROUP BY c.customer_state
ORDER BY unique_customers DESC
LIMIT 10;


-- =====================================================
-- 19. CUSTOMER SHARE BY STATE
-- Purpose: Calculate each state's percentage of all
-- unique customers.
-- Skills: CTE, aggregation, window function
-- =====================================================

WITH state_customers AS (
    SELECT
        customer_state,
        COUNT(DISTINCT customer_unique_id) AS customer_count
    FROM customers
    GROUP BY customer_state
)
SELECT
    customer_state,
    customer_count,
    ROUND(
        customer_count * 100.0 / SUM(customer_count) OVER (),
        2
    ) AS customer_share_pct
FROM state_customers
ORDER BY customer_count DESC;


-- =====================================================
-- 20. CUSTOMER REVIEW SCORE DISTRIBUTION
-- Purpose: Understand how customers rated their orders.
-- Skills: GROUP BY, COUNT, aggregate functions
-- =====================================================

SELECT
    review_score,
    COUNT(*) AS review_count,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS review_share_pct
FROM reviews
WHERE review_score BETWEEN 1 AND 5
GROUP BY review_score
ORDER BY review_score DESC;


-- =====================================================
-- 21. AVERAGE REVIEW SCORE BY DELIVERY PERFORMANCE
-- Purpose: Compare ratings for early/on-time and late
-- delivered orders.
-- Skills: JOIN, CASE WHEN, AVG, GROUP BY
-- Note: This shows association, not causation.
-- =====================================================

SELECT
    CASE
        WHEN o.order_delivered_customer_date
             <= o.order_estimated_delivery_date
            THEN 'Early/On Time'
        ELSE 'Late'
    END AS delivery_performance,
    COUNT(*) AS delivered_orders,
    ROUND(AVG(r.review_score), 2) AS average_review_score
FROM orders o
JOIN reviews r
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
  AND r.review_score BETWEEN 1 AND 5
GROUP BY
    CASE
        WHEN o.order_delivered_customer_date
             <= o.order_estimated_delivery_date
            THEN 'Early/On Time'
        ELSE 'Late'
    END
ORDER BY average_review_score DESC;
