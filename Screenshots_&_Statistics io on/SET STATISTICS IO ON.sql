SET STATISTICS IO, TIME ON;
GO

--Original Slow Query 
SELECT o.customer_id, COUNT(*) AS orders_2024,
 (SELECT SUM(oi.line_amount)
 FROM fact_order_items oi
 JOIN fact_orders o2 ON o2.order_id = oi.order_id
 WHERE o2.customer_id = o.customer_id) AS lifetime_value
 FROM fact_orders o
 WHERE YEAR(o.order_date) = 2024
 GROUP BY o.customer_id;

 /* AFTER METRICS */

 SET STATISTICS IO, TIME ON;
GO

WITH CustomerLTV AS (
    SELECT 
        o.customer_id,
        SUM(oi.line_amount) AS lifetime_value
    FROM dbo.fact_orders AS o
    INNER JOIN dbo.fact_order_items AS oi 
        ON o.order_id = oi.order_id
    GROUP BY o.customer_id
),
Orders2024 AS (
    SELECT 
        customer_id,
        COUNT(*) AS orders_2024
    FROM dbo.fact_orders
    WHERE order_date >= '2024-01-01' 
      AND order_date < '2025-01-01'
    GROUP BY customer_id
)
SELECT 
    o24.customer_id,
    o24.orders_2024,
    ltv.lifetime_value
FROM Orders2024 AS o24
LEFT JOIN CustomerLTV AS ltv 
    ON o24.customer_id = ltv.customer_id
ORDER BY o24.customer_id;