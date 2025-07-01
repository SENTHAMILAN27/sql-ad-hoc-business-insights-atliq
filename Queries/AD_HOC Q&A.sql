SELECT * FROM gdb023.fact_sales_monthly;

-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its
-- business in the APAC region.
	
 SELECT market,region,customer FROM 
 dim_CUSTOMER 
 where region = "APAC" and customer = "Atliq Exclusive";

/* 2. What is the percentage of unique product increase in 20	21 vs. 2020? 
	The final output contains these fields,
	unique_products_2020
	unique_products_2021
	percentage_chg  */	
-- ***********************************************
WITH poducts_2020 AS (
  SELECT COUNT(DISTINCT product_code) AS unique_products_2020
  FROM fact_sales_monthly
  WHERE fiscal_year = 2020
),
poducts_2021 AS (
  SELECT COUNT(DISTINCT product_code) AS unique_products_2021
  FROM fact_sales_monthly
  WHERE fiscal_year = 2021
)
SELECT 
  unique_products_2020,
  unique_products_2021,
  ROUND((unique_products_2021 - unique_products_2020) * 100.0 / unique_products_2020, 2) AS percentage_chg
FROM poducts_2020
JOIN poducts_2021
;


-- **********************************************************************************************************************************
/* 3. Provide a report with all the unique product counts for each segment and
sort them in descending order of product counts. The final output contains
2 fields,
segment
product_count */

select segment,count(product_code) as product_count
from dim_product
group by segment
order by product_count desc;

-- ***********************************************************************************************************

/* 4. Follow-up: Which segment had the most increase in unique products in
2021 vs 2020? The final output contains these fields,
segment
product_count_2020
product_count_2021
difference */ 


WITH Prod_cnt_2020 AS (
    SELECT 
        segment,
        COUNT(DISTINCT f.product_code) AS product_count_2020
    FROM 
        dim_product p
    JOIN 
        fact_sales_monthly f USING (product_code)
    WHERE 
        fiscal_year = 2020
    GROUP BY segment
),
Prod_cnt_2021 AS (
    SELECT 
        segment,
        COUNT(DISTINCT f.product_code) AS product_count_2021
    FROM 
        dim_product p
    JOIN 
        fact_sales_monthly f USING (product_code)
    WHERE 
        fiscal_year = 2021
    GROUP BY segment
)
SELECT
    segment,
    product_count_2021,
    product_count_2020,
    product_count_2021 - product_count_2020 AS difference
FROM 
    Prod_cnt_2020 c1
JOIN 
    Prod_cnt_2021 c2 USING (segment)
ORDER BY 
    difference DESC;

-- ************************************************************************************************++

/* 5.Get the products that have the highest and lowest manufacturing costs.
The final output should contain these fields,
product_code
product
manufacturing_cost */  

with hicost as 
(
select product_code , product, sum(manufacturing_cost ) as hmanufacturing_cost
from
dim_product p
join
 fact_manufacturing_cost mf
using (product_code)
group by product_code,product
order by hmanufacturing_cost desc 
limit 1 
),
locost as 
(
select product_code , product, sum(manufacturing_cost ) as lmanufacturing_cost
from
dim_product p
join
 fact_manufacturing_cost mf
using (product_code)
group by product_code,product
order by lmanufacturing_cost asc 
limit 1 
)
select 
h.product_code , h.product
lmanufacturing_cost,
hmanufacturing_cost
 from 
hicost h
cross join 
locost l
using (product_code);
-- * *************************************************************************************************

SET SESSION sql_mode = (SELECT REPLACE(@@sql_mode, 'ONLY_FULL_GROUP_BY', ''));

with manufacturing_cost as 
(
select product_code , product, sum(manufacturing_cost)  as manufacturing_cost
from
dim_product p
join
 fact_manufacturing_cost mf
using (product_code)
group by product_code,product
)
select product_code , product, manufacturing_cost
from 
manufacturing_cost
where manufacturing_cost = 
( select max(manufacturing_cost) from manufacturing_cost)
or	manufacturing_cost = 
( select min(manufacturing_cost) from manufacturing_cost);


-- ***********************************************************************************************************

/* 6. Generate a report which contains the top 5 customers who received an
average high pre_invoice_discount_pct for the fiscal year 2021 and in the
Indian market. The final output contains these fields,
customer_code
customer
average_discount_percentage */

select customer,customer_code,avg(pre_invoice_discount_pct) as avg_discount_pct
from 
fact_pre_invoice_deductions p
join dim_customer c
using(customer_code)
where market = "india" and fiscal_year= 2021
group by customer,customer_code
order by avg_discount_pct desc
limit 5 ;

-- ******************************************************************************************************************

/* 7.Get the complete report of the Gross sales amount for the customer “Atliq
Exclusive” for each month. This analysis helps to get an idea of low and
high-performing months and take strategic decisions.
The final report contains these columns:
Month
Year
Gross sales Amount  */

with GROSS_SALES as 
(
select 
	 customer_code ,
	 month(date_add(date, interval 4 month)) as months,
	 fiscal_year,
	 gross_price*sold_quantity as gross_sales 
from fact_sales_monthly
join fact_gross_price
using(product_code,fiscal_year)
where customer_code = "70002017" -- need to make it dynamic)
)
select 
	 customer_code ,
	 months,
	 fiscal_year,
	 round(sum(gross_sales),2) as Gross_Sales
	 from GROSS_SALES
group by customer_code, months,fiscal_year
order by fiscal_year, months;

-- *************************************************************************************************************

 /* 8.In which quarter of 2020, got the maximum total_sold_quantity? The final
output contains these fields sorted by the total_sold_quantity,
Quarter
total_sold_quantity*/ 

WITH qtr AS (
  SELECT  
    CEIL(MONTH(DATE_ADD(date, INTERVAL 4 MONTH)) / 3) AS Quarter,
    fiscal_year,
    SUM(sold_quantity) AS total_sold_quantity
  FROM fact_sales_monthly
  WHERE fiscal_year = 2020
  GROUP BY Quarter
)

SELECT Quarter, total_sold_quantity
FROM qtr
WHERE total_sold_quantity = (
  SELECT MAX(total_sold_quantity) FROM qtr
);

-- ********************************************************************************************************;

/* 9. Which channel helped to bring more gross sales in the fiscal year 2021
and the percentage of contribution? The final output contains these fields,
channel
gross_sales_mln
percentage */ 
    
    with cte1 as 
(
select 
	 channel,
	 round(sum(gross_price*sold_quantity )/1000000,2)as gross_sales_MLN
from fact_sales_monthly s
join fact_gross_price g
	using(product_code,fiscal_year)
join dim_customer c
	using (customer_code)
    where fiscal_year=2021
    group by channel 
    ),
     Pct as 
    (
    select *,
   round( gross_sales_MLN*100/(select sum(gross_sales_MLN) from cte1),2) As percentage_contribution
    from cte1
    )
select * from pct
order by percentage_contribution desc ;
    
    -- *********************************************************************************************************************
    
    
/* 10. Get the Top 3 products in each division that have a high
total_sold_quantity in the fiscal_year 2021? 
The final output contains these fields,
division
product_code
product
total_sold_quantity
rank_order */

with cte1 as
(
select division, product_code,product,
 sum(sold_quantity) as Total_sold_Qty,
 dense_rank() over (partition by division order by sum(sold_quantity) desc) As rnk
from fact_sales_monthly
join dim_product 
using(product_code)
group by division, product_code,product
order by Total_sold_Qty desc
)
select *
from cte1
where rnk<=3


