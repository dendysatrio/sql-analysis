--Problem Statement 
--As a Data Analyst at Revogrocers, your role is to explore the company's grocery dataset and generate insights that support business improvement. The stakeholders need a clear understanding of product performance, purchasing patterns, category profitability and customer behavior.

-- 1. Which product category generates the highest revenue after discount?

  SELECT
    categories.categoryname,
    SUM (products.price*sales.Quantity * (1 - sales.Discount)) AS revenue_after_discount
 
  FROM `fsda-sql-01.grocery_dataset.sales` AS sales
    JOIN `fsda-sql-01.grocery_dataset.products` AS products
      ON sales.ProductID = products.productid
    JOIN `fsda-sql-01.grocery_dataset.categories` AS categories
      ON products.categoryid = categories.categoryid

  GROUP BY categories.categoryname
  ORDER BY revenue_after_discount DESC;

-- 2.What is the relationship between revenue and total units sold per category?
  SELECT
    categories.categoryname,
    SUM (sales.Quantity) AS total_units_sold,
    SUM (products.price*sales.Quantity * (1 - sales.Discount)) AS revenue_after_discount
    
  FROM `fsda-sql-01.grocery_dataset.sales` AS sales
    JOIN `fsda-sql-01.grocery_dataset.products` AS products
     ON  sales.ProductID = products.productid
    JOIN `fsda-sql-01.grocery_dataset.categories` AS categories
     ON  products.categoryid = categories.categoryid

  GROUP BY categories.categoryname
  ORDER BY revenue_after_discount DESC;

-- 3.How does revenue relate to the number of unique customers in each category?

  SELECT
    categories.categoryname,
    COUNT (DISTINCT sales.customerid) AS unique_customers,
    SUM (products.price * sales.Quantity * (1 - sales.Discount)) AS revenue_after_discount
    
  FROM  `fsda-sql-01.grocery_dataset.sales` AS sales
    JOIN  `fsda-sql-01.grocery_dataset.products` AS products
      ON  sales.ProductID = products.productid
    JOIN  `fsda-sql-01.grocery_dataset.categories` AS categories
      ON  products.categoryid = categories.categoryid

  GROUP BY categories.categoryname
  ORDER BY revenue_after_discount DESC;

-- 4.What is the average price per unit across product categories?

  SELECT 
    categories.categoryname,
    AVG(products.price) AS avg_price_per_unit,
    COUNT (products.productid) AS product_count

  FROM  `fsda-sql-01.grocery_dataset.products` AS products
    JOIN`fsda-sql-01.grocery_dataset.categories` AS categories
      ON products.CategoryID = categories.CategoryID
  
  GROUP BY categories.categoryname
  ORDER BY avg_price_per_unit DESC;

-- 5.How does the average price correlate with the number of buyers?

  WITH avg_price AS 
  (
  SELECT
    products.categoryid,
    AVG(products.price) AS avg_price_per_unit      
  FROM  `fsda-sql-01.grocery_dataset.products` AS products
  WHERE products.categoryid IS NOT NULL
  GROUP BY products.categoryid
  ),
  unique_buyers AS
  (
  SELECT
    products.categoryid,
    COUNT(DISTINCT sales.CustomerID) AS unique_customers
  FROM `fsda-sql-01.grocery_dataset.sales` AS sales
    JOIN  fsda-sql-01.grocery_dataset.products AS products
     ON sales.ProductID = products.productid
  WHERE products.categoryid IS NOT NULL
  GROUP BY products.categoryid
  )
  SELECT
    categories.categoryname,
    avg_price.avg_price_per_unit,
    unique_buyers.unique_customerS
  FROM avg_price
    LEFT JOIN unique_buyers
      ON avg_price.categoryid = unique_buyers.categoryid
    JOIN `fsda-sql-01.grocery_dataset.categories` AS categories
      ON avg_price.categoryid = categories.categoryid

  ORDER BY avg_price_per_unit DESC;

-- 6.What is the percentage contribution of each category to total revenue?

  SELECT
   category_totals.categoryname,
   category_totals.category_revenue,
   SUM (category_totals.category_revenue) OVER () AS total_revenue,
   ROUND(category_totals.category_revenue / SUM(category_totals.category_revenue) OVER () * 100,2
  ) AS percentage_contribution
  FROM(
     SELECT 
      categories.categoryid,
      categories.categoryname,
      SUM (products.price * sales.Quantity * (1 - sales.Discount)) AS category_revenue
      FROM`fsda-sql-01.grocery_dataset.sales` AS sales
      JOIN `fsda-sql-01.grocery_dataset.products` AS products
      ON sales.ProductID = products.productid
      JOIN `fsda-sql-01.grocery_dataset.categories` AS categories
      ON products.categoryid = categories.categoryid
      GROUP BY  categories.categoryid,categories.categoryname
    ) AS category_totals

  ORDER BY  percentage_contribution DESC;


-- 7.Which category has the highest repeat purchase rate?

  WITH purchases_per_customer_per_category AS 
  (
  SELECT
    products.categoryid,
    sales.CustomerID AS customer_id,

    COUNT(
      DISTINCT COALESCE(
        sales.TransactionNumber,
        CONCAT('txn_', CAST(sales.SalesID AS STRING)) 
      )
    ) AS purchase_count

  FROM `fsda-sql-01.grocery_dataset.sales` AS sales
  JOIN `fsda-sql-01.grocery_dataset.products` AS products
    ON sales.ProductID = products.productid
  
  WHERE sales.CustomerID IS NOT NULL
    AND products.categoryid IS NOT NULL
  GROUP BY products.categoryid, sales.CustomerID
  ),
  repeat_flag_per_customer_category AS 
  (
  SELECT
    categoryid,
    customer_id,
    purchase_count,
    CASE WHEN purchase_count > 1 THEN 1 ELSE 0 END AS is_repeat_buyer
    FROM purchases_per_customer_per_category
  ),
  category_repeat_summary AS 
  (
  SELECT
    categoryid,
    COUNT(DISTINCT customer_id) AS total_buyers,
    SUM(is_repeat_buyer) AS repeat_buyers
  FROM repeat_flag_per_customer_category
  GROUP BY categoryid
  )
  SELECT
    categories.categoryname,
    category_repeat_summary.total_buyers,
    category_repeat_summary.repeat_buyers,
    ROUND(
    (category_repeat_summary.repeat_buyers / category_repeat_summary.total_buyers) * 100,2
  ) AS repeat_rate_percent

  FROM category_repeat_summary
  JOIN `fsda-sql-01.grocery_dataset.categories` AS categories
    ON category_repeat_summary.categoryid = categories.categoryid

  ORDER BY repeat_rate_percent DESC;

-- 8.What is the overall business performance summary based on these metrics?
-- 9.Which user has the highest total purchase value, and what does their transaction trend look like using a window function?

  WITH top_customer AS 
  (
  SELECT
    sales.CustomerID AS customerid,
    SUM(
        COALESCE(products.price, 0) 
        * COALESCE(sales.Quantity, 0) 
        * (1 - COALESCE(sales.Discount, 0))
    ) AS total_spend
  FROM `fsda-sql-01.grocery_dataset.sales` AS sales
  JOIN `fsda-sql-01.grocery_dataset.products` AS products
    ON sales.ProductID = products.productid
  WHERE sales.CustomerID IS NOT NULL
  GROUP BY sales.CustomerID
  ORDER BY total_spend DESC
  LIMIT 1
  ),
  daily_revenue AS 
  (
  SELECT
    DATE(sales.SalesDate) AS sales_date,
    SUM(
        COALESCE(products.price, 0) 
        * COALESCE(sales.Quantity, 0) 
        * (1 - COALESCE(sales.Discount, 0))
    ) AS revenue_on_day
  FROM `fsda-sql-01.grocery_dataset.sales` AS sales
  JOIN `fsda-sql-01.grocery_dataset.products` AS products
    ON sales.ProductID = products.productid
  WHERE sales.CustomerID = (SELECT customerid FROM top_customer)
    AND DATE(sales.SalesDate) IS NOT NULL  
  GROUP BY DATE(sales.SalesDate)
  )
  SELECT
    sales_date,
    revenue_on_day,
    SUM(revenue_on_day) OVER (ORDER BY sales_date) AS cumulative_revenue
  FROM daily_revenue
  ORDER BY sales_date;
