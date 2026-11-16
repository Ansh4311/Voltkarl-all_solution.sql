Select * from cdc_product_changes
select * from cdc_product_changes
Select * from dim_category
Select * from dim_customer
Select * from dim_employee
Select * from fact_orders

USE Voltkart;
SELECT 'dim_category' AS table_name, COUNT(*) AS rows FROM dim_category
UNION ALL SELECT 'dim_employee', COUNT(*) FROM dim_employee
UNION ALL SELECT 'dim_customer', COUNT(*) FROM dim_customer
UNION ALL SELECT 'dim_product', COUNT(*) FROM dim_product
UNION ALL SELECT 'fact_orders', COUNT(*) FROM fact_orders
UNION ALL SELECT 'fact_order_items', COUNT(*) FROM fact_order_items
UNION ALL SELECT 'stg_orders_incr', COUNT(*) FROM stg_orders_incr
UNION ALL SELECT 'cdc_product_changes', COUNT(*) FROM cdc_product_changes;

-- 1. Voltkart's commercial team wants a quick look at the biggest sales. Return the
   top 20 completed orders by value, with the customer and the sales rep behind each one.
   Required output: order_id, order_date, customer_name, sales_rep_name, order_total.

   Select TOP 20 order_id, order_status, customer_name,order_total,order_date,sales_rep_id
   from fact_orders fo
   inner join dim_customer dc on dc.customer_id = fo.customer_id
   inner join dim_employee de on de.employee_id = fo.sales_rep_id
   where lower(fo.order_status) = 'Completed'
   order by order_total DESC

-- 2. Marketing wants to re-engage people who registered but never bought. List the
    customers who have never placed an order. Required output: customer_id,customer_name, signup_date.
     
   Select dc.customer_name , dc.signup_date,dc.customer_id
   from dim_customer as dc 
   where NOT EXISTS (Select 1 
                    from fact_orders as fc
                    where fc.customer_id = dc.customer_id)
   
--3.Merchandising wants the stars of each category. For every category, return the
  top 3 products by completed revenue. Required output: category_name, product_name,
  total_revenue, revenue_rank.

 Select dc.category_name, dp.product_name, line_amount as total_revenue,
 RANK()over(partition by category_name ORDER BY line_amount DESC) as revenue_rank
 from dim_product as dp
 inner join dim_category dc on dc.category_id = dp.category_id
 inner join fact_order_items foi on foi.product_id = dp.product_id
 inner join fact_orders fo on fo.order_id = foi.order_id
 where lower(fo.order_status) = 'completed' 
                   
 

SELECT 
    category_name, product_name,  total_revenue,   revenue_rank
FROM (
    SELECT dc.category_name,  dp.product_name, 
        SUM(foi.line_amount) AS total_revenue,
        RANK() OVER (PARTITION BY dc.category_name ORDER BY SUM(foi.line_amount) DESC) AS revenue_rank
    FROM dim_product dp
    INNER JOIN dim_category dc ON dc.category_id = dp.category_id
    INNER JOIN fact_order_items foi ON foi.product_id = dp.product_id
    INNER JOIN fact_orders fo ON fo.order_id = foi.order_id
    WHERE LOWER(fo.order_status) = 'completed'
    GROUP BY dc.category_name, dp.product_name
) AS ranked_products
WHERE revenue_rank <= 3
ORDER BY category_name, revenue_rank;

--4. Finance wants the revenue trend with momentum. Produce monthly completed revenue with a cumulative 
   running total and the month-over-month %change. Required output: order_month (YYYY-MM), monthly_revenue,
   running_total,mom_pct_change.



SELECT order_month, monthly_revenue,
    SUM(monthly_revenue) OVER (ORDER BY order_month) AS running_total,
    CAST(
        (monthly_revenue - LAG(monthly_revenue, 1) OVER (ORDER BY order_month)) * 100.0 
        / NULLIF(LAG(monthly_revenue, 1) OVER (ORDER BY order_month), 0) 
        AS DECIMAL(5,2)
    ) AS mom_pct_change
FROM (
    SELECT 
        CONVERT(CHAR(7), order_date, 126) AS order_month,
        SUM(order_total) AS monthly_revenue
    FROM fact_orders
    WHERE LOWER(order_status) = 'completed'
    GROUP BY CONVERT(CHAR(7), order_date, 126)
) AS monthly_data
ORDER BY order_month;

--5.The CRM team wants to size up the customer base by value. Split customers into
four quartiles by lifetime completed spend, and for each quartile report how many
customers fall in it and their average spend. Required output: spend_quartile,
customer_count, avg_lifetime_spend.


Select * from fact_orders

SELECT 
    spend_quartile,
    COUNT(customer_id) AS customer_count,
    AVG(total_spend) AS avg_lifetime_spend
FROM (
    SELECT customer_id,
        SUM(order_total) AS total_spend,
        NTILE(4) OVER (ORDER BY SUM(order_total) ASC) AS spend_quartile
    FROM fact_orders
    WHERE LOWER(order_status) = 'completed'
    GROUP BY customer_id
) AS customer_quartiles
GROUP BY spend_quartile
ORDER BY spend_quartile;

--6.The catalogue team needs to see everything under a part of the tree. Using a
    recursive query, list all categories in the subtree rooted at 'Computers' at any depth, with
    how deep each sits and a readable path from Computers. Required output: category_id,
    category_name, depth_level, category_path.

Select * from dim_category

WITH CategorySubtreeCTE AS (
    -- Anchor Member: Find the root node 'Computers'
    SELECT 
        category_id,
        parent_category_id,
        category_name,
        1 AS depth_level, -- Start at depth 1 for 'Computers'
        CAST(category_name AS VARCHAR(MAX)) AS category_path
    FROM dbo.dim_category
    WHERE category_name = 'Computers' -- Anchor condition starting from 'Computers'

    UNION ALL

    -- Recursive Member: Join the table back to the CTE to find sub-categories
    SELECT 
        c.category_id,
        c.parent_category_id,
        c.category_name,
        cte.depth_level + 1, -- Increment depth level by 1 for each child level
        CAST(cte.category_path + ' -> ' + c.category_name AS VARCHAR(MAX))
    FROM dbo.dim_category c
    INNER JOIN CategorySubtreeCTE cte 
        ON c.parent_category_id = cte.category_id -- Matching child's parent_id to parent's category_id
)
-- Final Select matching the required output columns
SELECT 
    category_id,
    category_name,
    depth_level,
    category_path
FROM CategorySubtreeCTE
ORDER BY category_path;


Select * from dim_category
Select * from dim_customer
Select * from dim_employee
Select * from fact_orders

--7.Sales leadership wants performance rolled up the org chart. For every employee
compute the total completed order value generated by their whole team — that is,
themselves plus everyone reporting under them at any depth. A Sales Rep's team is just
themselves; a manager's is their entire subtree. Required output: employee_id,
employee_name, role, team_total_revenue.

select * from dim_employee
select * from fact_orders

WITH OrgHierarchy AS (
    -- Anchor Member: Start with every employee as part of their own team (self-reference)
    SELECT 
        employee_id AS ancestor_id,
        employee_id AS descendant_id
    FROM dbo.dim_employee

    UNION ALL

    -- Recursive Member: Find all employees who report to the current descendant at any depth
    SELECT 
        oh.ancestor_id,
        e.employee_id AS descendant_id
    FROM dbo.dim_employee e
    INNER JOIN OrgHierarchy oh 
        ON e.manager_id = oh.descendant_id
)
-- Final Select: Group by each employee and sum the completed order totals of their entire team
SELECT 
    e.employee_id,
    e.employee_name,
    e.role,
    COALESCE(SUM(o.order_total), 0) AS team_total_revenue
FROM dbo.dim_employee e
LEFT JOIN OrgHierarchy oh 
    ON e.employee_id = oh.ancestor_id
LEFT JOIN dbo.fact_orders o 
    ON oh.descendant_id = o.sales_rep_id 
    AND o.order_status = 'Completed'
GROUP BY 
    e.employee_id,
    e.employee_name,
    e.role
ORDER BY 
    team_total_revenue DESC;

--8.The platform team is moving off nightly full reloads. You've been handed today's
batch in stg_orders_incr. Write a single MERGE that performs an incremental load into
fact_orders: update orders that changed, insert ones that are new. Acceptance criteria: one
MERGE statement; matched orders are updated (status and total) and new orders inserted;
include a verification query showing the fact_orders row count before versus after and a
sample of updated rows. 

 select * from fact_orders
 select * from stg_orders_incr


 /* =====================================================
   STEP 1: VERIFY ROW COUNT BEFORE MERGE
===================================================== */
SELECT 'Before Merge' AS status, COUNT(*) AS row_count 
FROM dbo.fact_orders;


/* =====================================================
   STEP 2: PERFORM INCREMENTAL MERGE INTO fact_orders
===================================================== */
MERGE INTO dbo.fact_orders AS tgt
USING dbo.stg_orders_incr AS src
ON tgt.order_id = src.order_id

WHEN MATCHED AND (
       ISNULL(tgt.order_status, '') <> ISNULL(src.order_status, '')
    OR ISNULL(tgt.order_total, 0) <> ISNULL(src.order_total, 0)
)
THEN UPDATE SET
    tgt.order_date   = src.order_date,
    tgt.customer_id  = src.customer_id,
    tgt.sales_rep_id = src.sales_rep_id,
    tgt.order_status = src.order_status,
    tgt.order_total  = src.order_total

WHEN NOT MATCHED BY TARGET THEN
INSERT (order_id, order_date, customer_id, sales_rep_id, order_status, order_total)
VALUES (src.order_id, src.order_date, src.customer_id, src.sales_rep_id, src.order_status, src.order_total);


/* =====================================================
   STEP 3: VERIFY RESULTS & ROW COUNT AFTER MERGE
===================================================== */
SELECT 'After Merge' AS status, COUNT(*) AS row_count 
FROM dbo.fact_orders;

-- Sample of updated or inserted rows to verify results
SELECT  *
FROM dbo.fact_orders
ORDER BY order_id;








/* =====================================================
   STEP 3: MERGE STAGING INTO DIM TABLE
===================================================== */
MERGE INTO fact_orders AS fos
USING stg_orders_incr AS soi
ON fos.order_id = soi.order_id

WHEN MATCHED AND (
       ISNULL(fos.order_date,'') <> ISNULL(soi.order_date,'')
    OR ISNULL(fos.customer_id,'') <> ISNULL(soi.customer_id,'')
	OR ISNULL(fos.sales_rep_id,'') <> ISNULL(soi.sales_rep_id,'')
	OR ISNULL(fos.order_status,'') <> ISNULL(soi.order_status,'')
	or ISNULL(fos.order_total,'') <> ISNULL(soi.order_total,'')
)
THEN UPDATE SET
    fos.order_date = soi.order_date,
    fos.customer_id = soi.customer_id,
	fos.sales_rep_id = soi.sales_rep_id,
	fos.order_status = soi.order_status,
	fos.order_total = soi.order_total,
    fos.UpdatedAt = SYSUTCDATETIME()

WHEN NOT MATCHED BY TARGET THEN
INSERT (order_id, order_date, customer_id, sales_rep_id, order_status, order_total,UpdatedAt)
VALUES (soi.order_id, soi.order_date, soi.customer_id, soi.sales_rep_id, 
soi.order_status, soi.order_total,SYSUTCDATETIME());


/* =====================================================
   STEP 4: VERIFY RESULTS
===================================================== */

SELECT *
FROM fact_orders
ORDER BY order_id;

--9.The catalogue source now emits a change feed (cdc_product_changes) with
operation codes. Apply it to dim_product in a single MERGE that honours the codes: I inserts
a new product, U updates an existing one, D deletes it. Acceptance criteria: one MERGE
handling all three operations; include a verification query showing inserted, updated, and
deleted products.

 
select * from dim_product
select * from cdc_product_changes

/* =====================================================
   STEP 1: PERFORM SINGLE MERGE FOR INSERT, UPDATE, DELETE
===================================================== */
MERGE INTO dbo.dim_product AS tgt
USING dbo.cdc_product_changes AS src
ON tgt.product_id = src.product_id

-- 1. UPDATE OPERATION
WHEN MATCHED AND src.operation = 'U' THEN
UPDATE SET
    tgt.product_name = src.product_name,
    tgt.category_id  = src.category_id,
    tgt.unit_price   = src.unit_price,
    tgt.unit_cost    = src.unit_cost,
    tgt.launch_date  = src.launch_date

-- 2. DELETE OPERATION
WHEN MATCHED AND src.operation = 'D' THEN
DELETE

-- 3. INSERT OPERATION
WHEN NOT MATCHED BY TARGET AND src.operation = 'I' THEN
INSERT (product_id, product_name, category_id, unit_price, unit_cost, launch_date)
VALUES (src.product_id, src.product_name, src.category_id, src.unit_price, src.unit_cost, src.launch_date);


/* =====================================================
   STEP 2: VERIFICATION QUERY
===================================================== */
-- View final state of dim_product to verify results
SELECT *
FROM dbo.dim_product
ORDER BY product_id;

--10.A report is slow. Here is the query analysts are running:
 SELECT o.customer_id, COUNT(*) AS orders_2024,
 (SELECT SUM(oi.line_amount)
 FROM fact_order_items oi
 JOIN fact_orders o2 ON o2.order_id = oi.order_id
 WHERE o2.customer_id = o.customer_id) AS lifetime_value
 FROM fact_orders o
 WHERE YEAR(o.order_date) = 2024
 GROUP BY o.customer_id;
Turn on SET STATISTICS IO, TIME ON and "Include Actual Execution Plan", run it, then make
it fast: explain what the plan is doing, rewrite the query, and add an index that helps. Required
output: the rewritten query, the CREATE INDEX statement(s), and a short note giving the
logical reads before versus after and why the plan changed.

 

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
select * from fact_orders
select * from fact_order_items

--11. (Bonus) The retention team wants loyalty streaks. For each customer, find the
longest run of consecutive calendar months in which they placed at least one completed
order. Required output: customer_id, customer_name, longest_streak_months.

 select * from fact_orders 
 select * from dim_customer

 WITH CustomerMonths AS (
    -- 1. Get distinct year-month periods per customer for 'Completed' orders
    SELECT DISTINCT
        customer_id,
        YEAR(order_date) * 12 + MONTH(order_date) AS month_index
    FROM dbo.fact_orders
    WHERE order_status = 'Completed'
),
StreakGroups AS (
    -- 2. Subtract ROW_NUMBER() from the continuous month_index.
    -- Consecutive months will produce the exact same 'island_id'
    SELECT 
        customer_id,
        month_index,
        month_index - ROW_NUMBER() OVER (
            PARTITION BY customer_id 
            ORDER BY month_index
        ) AS island_id
    FROM CustomerMonths
),
StreakLengths AS (
    -- 3. Count the length of each consecutive monthly streak per customer
    SELECT 
        customer_id,
        island_id,
        COUNT(*) AS streak_months
    FROM StreakGroups
    GROUP BY customer_id, island_id
),
MaxStreaks AS (
    -- 4. Find the longest streak for each customer
    SELECT 
        customer_id,
        MAX(streak_months) AS longest_streak_months
    FROM StreakLengths
    GROUP BY customer_id
)
SELECT 
    c.customer_id,
    c.customer_name, -- Replace with c.EmailAddress or c.first_name + ' ' + c.last_name if needed
    ISNULL(m.longest_streak_months, 0) AS longest_streak_months
FROM dbo.dim_customer AS c
LEFT JOIN MaxStreaks AS m 
    ON c.customer_id = m.customer_id
ORDER BY longest_streak_months DESC, c.customer_id;