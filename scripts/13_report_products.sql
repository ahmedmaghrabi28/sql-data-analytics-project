/*
===============================================================================
Product Report
===============================================================================
Purpose:
    - This report consolidates key product metrics and behaviors.

Highlights:
    1. Gathers essential fields such as product name, category, subcategory, and cost.
    2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
    3. Aggregates product-level metrics:
        - total orders
        - total sales
        - total quantity sold
        - total customers (unique)
        - lifespan (in months)
    4. Calculates valuable KPIs:
        - recency (months since last sale)
        - average order revenue (AOR)
        - average monthly revenue
===============================================================================
*/
IF OBJECT_ID('gold.report_products', 'V') IS NOT NULL
    DROP VIEW gold.report_products;
GO

CREATE VIEW gold.report_products AS

WITH base_query AS(
/*------------------------------------------------------------------------------
1) Base Query: Retrieves core columns from tables
------------------------------------------------------------------------------*/
SELECT 
    f.customer_key,
    f.order_number,
    f.product_key,
    f.order_date,
    f.sales_amount,
    f.quantity,
    p.product_name,
    p.category,
    p.subcategory,
    p.product_number,
    p.cost
FROM gold.fact_sales AS F
LEFT JOIN gold.dim_products AS p
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL)
 
 ,product_aggregations AS(
 /*------------------------------------------------------------------------------
2) Product Aggregations: Summarizes key metrics at the Product level
------------------------------------------------------------------------------*/
SELECT
    product_key,
    product_number,
    product_name,
    category,
    subcategory,
    cost,
    COUNT(DISTINCT order_number) AS total_orders,
    SUM(sales_amount) AS total_sales,
    SUM(quantity) AS total_quantity,
    COUNT(DISTINCT customer_key) AS total_customers,
	MAX(order_date) AS last_order_date,
    DATEDIFF(MONTH,MIN(order_date),MAX(order_date)) AS lifespan,
    ROUND(AVG(CAST(sales_amount AS FLOAT)/NULLIF(quantity,0)),1) AS avg_selling_price
FROM base_query
GROUP BY 
    product_key,
    product_name,
    product_number,
    category,
    subcategory,
    cost)

SELECT 
    product_key,
    product_name,
    product_number,
    category,
    subcategory,
    cost,
    total_sales,
    CASE
        WHEN total_sales > 50000 THEN 'High-Performers'
        WHEN total_sales >= 10000 THEN 'Mid-Range'
        ELSE 'Low-Performers'
    END AS product_segment,
    last_order_date,
    lifespan,
    DATEDIFF(MONTH,last_order_date,GETDATE()) AS recency,
   total_orders,
   total_quantity,
   total_customers,
    avg_selling_price,
	-- Compute average order revenue (AOR)
    CASE
        WHEN total_orders = 0 THEN 0
        ELSE total_sales/total_orders
    END AS avg_order_revenue,
   -- Compute avg monthly revenue
   CASE
       WHEN lifespan = 0 THEN total_sales
       ELSE total_sales/lifespan
    END AS avg_monthly_revenue
FROM product_aggregations;
