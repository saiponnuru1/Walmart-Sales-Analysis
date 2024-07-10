-- Creating the Database
CREATE DATABASE walmart_sales_data;

-- Creating the table with columns based on the information provided prior

CREATE TABLE sales(
	invoice_id VARCHAR(30) NOT NULL PRIMARY KEY,
	branch VARCHAR(5) NOT NULL,
    city VARCHAR(30) NOT NULL,
    customer_type VARCHAR(30) NOT NULL,
    gender VARCHAR(30) NOT NULL,
    product_line VARCHAR(100) NOT NULL,
    unit_price DEC(10, 2) NOT NULL,
    quantity INT NOT NULL,
    vat FLOAT(6, 4) NOT NULL,
    total_cost DEC(12, 4) NOT NULL, 
    date DATETIME NOT NULL,
    time TIME NOT NULL,
    payment_method VARCHAR(15) NOT NULL,
    cogs DECIMAL(10, 2) NOT NULL,
    gross_margin_percentage FLOAT(11, 9),
    gross_income DECIMAL(12, 4) NOT NULL,
    rating FLOAT(2, 1)
);

ALTER TABLE sales
CHANGE COLUMN total_cost total_sales DEC(12, 4);









-- ---------------------------------------------------------------------------------
-- ------------------------------- Feature Engineering Process----------------------
-- ---------------------------------------------------------------------------------

/*
1)
Creating a time_of_day of day column
Will be used for interesting business analytics
Will split it into morning, afternoon and evening

*/

SELECT time,
 CASE 
    WHEN `time` BETWEEN "00:00:00" AND "12:00:00" THEN "Morning"
	WHEN `time` BETWEEN "12:00:01" AND "16:00:00" THEN "Afternoon"
    ELSE "Evening"
 END AS time_of_date
FROM sales;
    
    
ALTER TABLE sales ADD COLUMN time_of_day VARCHAR(20);

UPDATE sales 
SET time_of_day = (
	CASE 
		WHEN `time` BETWEEN "00:00:00" AND "12:00:00" THEN "Morning"
		WHEN `time` BETWEEN "12:00:01" AND "16:00:00" THEN "Afternoon"
		ELSE "Evening"
	 END 
	);
    
-- ^^ need to un-tick safe update mode and restart connection
    
    
-- 2) Adding a day name column as day_name

SELECT date,
	DAYNAME(date) AS day_name
 FROM sales;
    
ALTER TABLE sales ADD COLUMN day_name VARCHAR(10);

UPDATE sales
   SET day_name = DAYNAME(date);

-- 3) Adding a month name column as month_name (note all data coincides with the first 3 months of the year

SELECT date,
	MONTHNAME(date)
FROM sales;


ALTER TABLE sales ADD COLUMN month_name VARCHAR(10);

UPDATE sales 
   SET month_name = MONTHNAME(date);


-- --------------------------------------------------------------------------------------------------------------
-- ---------------------------------- Business Questions---------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------

-- 1) How many unique product lines does the business have?--------------------------------------------------

SELECT COUNT(DISTINCT(product_line)) AS num_product_line
FROM sales;
-- Result: There are 6 unique product lines

-- 2) What is the most common payment method?----------------------------------------------------------------

SELECT payment_method, COUNT(*) AS num_payment_method
FROM sales
GROUP BY payment_method
ORDER BY num_payment_method DESC
LIMIT 1;
-- Result: Cash is the most commonly used payment method

-- 3) What is the most selling product line? -----------------------------------------------------------------
 
SELECT product_line, SUM(quantity) AS total_sold
FROM sales
GROUP BY product_line
ORDER BY total_sold DESC
LIMIT 1;
-- Result: Electronic Accessories sells the most with 961 sold


-- 4) What is the total revenue by month?------------------------------------------------------------------------
SELECT month_name, SUM(total_sales) as Monthly_Total_Revenue
FROM sales
GROUP BY month_name
ORDER BY Monthly_Total_Revenue DESC;
-- Result: January with 116291.8680, February revenue is 95727.3765, March revenue is 108867.1500


-- 5) What month had the largest Cost of Goods sold (COGS)---------------------------------------------------------
SELECT month_name, SUM(cogs) AS Cost_of_goods_sold
FROM sales
GROUP BY month_name
ORDER BY Cost_of_goods_sold DESC;
-- Result: Also January at 110754.16


-- 6) What product line had the largest revenue?------------------------------------------------------------------------
SELECT product_line, SUM(total_sales) AS total_revenue
FROM sales
GROUP BY product_line
ORDER BY total_revenue DESC
LIMIT 1;
-- Result: Food and Beverages at 56144.8440

-- 7) What is the city with the largest revenue?------------------------------------------------------------------------
SELECT city, SUM(total_sales) AS total_revenue
FROM sales
GROUP BY city
ORDER BY total_revenue DESC
LIMIT 1;
-- Result: Naypyitaw at 110490.7755

/*
8) Fetch each product line and add a column to those product line showing "Good",
 "Bad". Good if its greater than average sales
*/
-- We can do this on an individual product basis as follows:


WITH avg_sales_cte AS (
    SELECT AVG(total_sales) AS avg_sales
    FROM sales
)
SELECT 
    product_line, total_sales, avg_sales_cte.avg_sales AS avg_sales,
    CASE
        WHEN total_sales < avg_sales_cte.avg_sales THEN 'bad'
        WHEN total_sales >= avg_sales_cte.avg_sales THEN 'good'
    END AS rating
FROM 
    sales, avg_sales_cte
GROUP BY 
    product_line, total_sales, avg_sales_cte.avg_sales;


-- Or by aggregating by product line to give the overall rating
SELECT product_line, total_sales, avg_sales,
    CASE
        WHEN total_sales < avg_sales THEN 'bad'
        WHEN total_sales >= avg_sales THEN 'good'
    END AS rating
FROM (
    SELECT product_line, SUM(total_sales) AS total_sales,
            AVG(SUM(total_sales)) OVER () AS avg_sales
    FROM 
        sales
    GROUP BY 
        product_line
) AS subquery;


-- 9) Which branch sold more products than average product sold?

SELECT branch, AVG(quantity) as avg_branch 
FROM sales
GROUP BY branch
HAVING avg_branch > (SELECT AVG(quantity) as avg_qty FROM sales);
-- Result: Only branch C


/*I MADE THESE QUESTIONS UP:
10) What is the total revenue generated by each branch for each month? What can we interpret from these findings?
*/

SELECT branch, month_name, SUM(total_sales) OVER(PARTITION BY branch, month_name) AS total_revenue
  FROM sales
ORDER BY branch, total_revenue DESC;
/* Result: Branch A made over 38,000 in January, just under 30,000 in February and over 37,000 in March.
Branch B made little over 37,000 in January, just over 33,000 in February and little over 34,000 in March.
Branch C made over 40,000 in January, just under 33,000 in February, and little over than 37,000 in Match.
January is the popular month in all 3 branches and February is the worst performing month for all branches. It is difficult to attribute a reason for the fluctuation in the revenue of each branch. It could be an issue with marketing strategy in February, it may be a one-time occurrence; would need data from other months in the financial year to develop more clear insight as to why.
*/	

/*
11) Which branch has the highest average transaction amount? By how much does each branch's average differ from than the average across all 3 branches?
*/

SELECT branch, AVG(total_sales) OVER() AS overall_avg_transaction_amount , AVG(total_sales) OVER(PARTITION BY branch) AS branch_avg_transaction_amount, (AVG(total_sales) OVER(PARTITION BY branch))-(AVG(total_sales) OVER()) AS difference
  FROM sales
 ORDER BY branch_avg_transaction_amount DESC;
 
-- Result: Branch C has the highest average transaction amount, with it being over 337. Branch C's average is more than 15 above the overall average. Branch B's average is over 4 below the overall average and branch C's average is over 10 below the overall average. Thus, there is clearly disparity in how much the average consumer spends across the three branches.
  
/*
13) Find the top X gross profit margins for the product lines by branch and by month. CANNOT SEEM TO ANSWER!
*/

SELECT branch, product_line, month_name, SUM(total_sales) OVER(PARTITION BY branch, product_line, month_name) AS product_revenue, SUM(cogs) OVER(PARTITION BY branch, product_line, month_name) AS product_cogs, (SUM(total_sales) OVER(PARTITION BY branch, product_line, month_name)-SUM(cogs) OVER(PARTITION BY branch, product_line, month_name))/(SUM(total_sales) OVER(PARTITION BY branch, product_line, month_name))*100 AS product_line_gpm
  FROM sales
 ORDER BY branch, product_revenue DESC;
 

-- --------------------------------------------------------------------------------------------------------------------------------------------------
-- ----------------------------------------------------- Sales Questions-----------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------------------------------------



-- 1) Number of sales made in each time of the day per weekday---------------------------------------------

SELECT time_of_day, COUNT(*) AS sales_count
FROM sales
WHERE day_name NOT IN ('Saturday', 'Sunday')
GROUP BY time_of_day
ORDER BY sales_count DESC;
-- Result: Evening: 290, Afternoon: 269, Morning: 140


-- 2) Which of the customer types brings the most revenue?---------------------------------------------------

SELECT customer_type, SUM(total_sales) AS totalsales
FROM sales
GROUP BY customer_type
ORDER BY totalsales DESC;
-- Result: Member: 163625.1015 , Normal: 157261.2930 so Member.

-- 3) Which city has the largest tax percent/ VAT (Value Added Tax)? ----------------------------------------

SELECT city, AVG(VAT) AS VAT
FROM sales
GROUP BY city
ORDER BY VAT DESC;
-- Result: Naypyitaw

-- 4) Which customer type pays the most in VAT

SELECT customer_type ,AVG(VAT) AS VAT
FROM sales
GROUP BY customer_type
ORDER BY VAT DESC;
-- Result: Member by a small amount


/* I MADE THIS QUESTION UP
 5) What are the peak sales hours across different branches and how 
 can they be leveraged for targeted promotions?
 What other insights can we gather?

*/

CREATE TEMPORARY TABLE branch_hourly_sale AS
SELECT branch, HOUR(time) AS hour, SUM(total_sales) AS total_sales_by_hour
FROM sales
GROUP BY branch, hour;


SELECT branch, hour, total_sales_by_hour
FROM branch_hourly_sale
WHERE (branch, total_sales_by_hour) IN (
    SELECT branch, MAX(total_sales_by_hour)
    FROM (
        SELECT branch, HOUR(time) AS hour, SUM(total_sales) AS total_sales_by_hour
        FROM sales
        GROUP BY branch, hour
    ) AS inner_hourly_sales
    GROUP BY branch
)
ORDER BY branch, hour;





/* Result:
	Branch A has most sales from 11am-12pm
    Branch B has most sales from 7pm-8pm
    Branch C has most sales from 7pm-8pm
    Branch B has the highest total_sales_by_hour
    
    It could mean those who typically shop at B and C do so after work, and therefore 
    should target working age people more with promotions
    With branch A, perhaps lots of sales come from retirees, young people etc 
    so promotions could target these people
    
*/

-- 6) I MADE THIS MYSELF: What days of the week prove to give the most amount of sales at the different branches?
CREATE TEMPORARY TABLE  branch_day_sale AS
SELECT branch, day_name, SUM(total_sales) AS total_sales_on
FROM sales
GROUP BY branch, day_name
ORDER BY total_sales_on DESC;

SELECT branch, day_name , total_sales_on
FROM branch_day_sale
WHERE (branch, total_sales_on) IN (
    SELECT branch, MAX(total_sales_on)
    FROM (
        SELECT branch, day_name, SUM(total_sales) AS total_sales_on
        FROM sales
        GROUP BY branch, day_name
    ) AS inner_day_sales
    GROUP BY branch
)
ORDER BY branch, day_name;

/* Result:
	Branch A: Sunday
    Branch B: Saturday
    Branch C: Saturday
*/

/* I MADE THESE QUESTIONS UP:
7)How does the average transaction amount vary by time of day? 
*/
SELECT time_of_day, AVG(total_sales) OVER(PARTITION BY time_of_day) AS time_of_day_avg
  FROM sales
 ORDER BY time_of_day_avg;
 
-- Result: Evenings have the lowest average transaction amount, with just over 320 whereas afternoons have the highest average, being over 325.


-- --------------------------------------------------------------------------------------------------------------------------------------------------
-- ----------------------------------------------------- Customer Questions-----------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------------------------------------

-- 1) How many unique customer types does the data have?---------------------------------------------
SELECT COUNT(DISTINCT(customer_type)) AS num_customer_types
  FROM sales;
-- Result: There are 2 types

-- 2) How many unique payment methods does the data have?---------------------------------------------------
SELECT COUNT(DISTINCT(payment_method)) AS num_payment_methods
  FROM sales;
-- Result: There are 3 types

-- 3) What is the most common customer type?-----------------------------------------------------------------
SELECT customer_type, COUNT(*) OVER(PARTITION BY customer_type) AS num_people_in_type
  FROM sales;
-- Result: There are 499 customers who are customer type 'Member' and 496 customers who are customer type 'Normal', so 'Member' is the most common customer type

-- 4)Which customer type buys the most?----------------------------------------------------------------------
SELECT customer_type, SUM(total_sales) OVER(PARTITION BY customer_type) AS group_expenditure 
  FROM sales
 ORDER BY group_expenditure DESC;
-- Result: Customers of customer type 'Member' spent over 163,000 combined, whereas those of customer type 'Normal' spent around 157,000 combined. Therefore, customer type 'Member' buys the most.

/* I MADE THESE QUESTIONS UP: 
5)What is the average transaction amount per customer type?
*/
SELECT customer_type, AVG(total_sales) OVER(PARTITION BY customer_type)
  FROM sales;
-- Result: Members spend nearly 328 on average, normal customers spend around 317 on average.


/*
6)What is the average rating given by customers for each product? What are the prices of each product? How does product rating and price compare to the average rating and price for product line? Thus make an inference.
*/
CREATE TEMPORARY TABLE product_ratings_and_prices AS
SELECT product_line, unit_price, AVG(unit_price) OVER(PARTITION BY product_line) AS average_price, (unit_price - AVG(unit_price) OVER(PARTITION BY product_line)) AS price_difference, AVG(rating) OVER(PARTITION BY product_line, unit_price) AS average_product_rating, AVG(rating) OVER(PARTITION BY product_line) AS average_product_line_rating, (AVG(rating) OVER(PARTITION BY product_line, unit_price) - AVG(rating) OVER(PARTITION BY product_line)) AS product_rating_difference
  FROM sales;

-- Decided to run each select statement one at a time
SELECT COUNT(*) AS low_price_good_rating
  FROM product_ratings_and_prices 
WHERE price_difference<0 AND product_rating_difference>0;

SELECT COUNT(*) AS low_price_bad_rating
  FROM product_ratings_and_prices 
WHERE price_difference<0 AND product_rating_difference<0;

SELECT COUNT(*) AS high_price_good_rating
  FROM product_ratings_and_prices 
WHERE price_difference>0 AND product_rating_difference>0;

SELECT COUNT(*) AS high_price_bad_rating
  FROM product_ratings_and_prices 
WHERE price_difference>0 AND product_rating_difference<0;

/* Result: There are 257 instances of low price and good rating, 244 instances of low price and bad rating, 
242 instances of high price and good rating, 252 instances of high price and bad rating. In the solution, low price means below average for that product line, 
and the opposite for high price. Good rating means when the product's average is above the average rating of the product line, and the opposite for bad rating.
For products of low price there are over 5% more cases of good rating than bad rating. For products of high price there are over 4% more cases of bad rating than good rating. 
These could be things for management to consider when deciding product mix; it seems as if customers receive greater utility from cheaper products. However, in pure numbers the
 distribution of instances is fairly even across the 4 cases. Hence, it may be a case of removing or improving products in both price categories.


/*
8)What is the average transaction amount for each payment method? What payment method was used for the smallest transaction? 
What was the largest transaction for this method? What payment method was used for the largest transaction?
*/

SELECT payment_method, AVG(total_sales) OVER(PARTITION BY payment_method) AS method_avg, MIN(total_sales) OVER(PARTITION BY payment_method) AS method_min, MAX(total_sales) OVER(PARTITION BY payment_method) AS method_max
  FROM sales;

/* Result: Cash has an average of just over 326, credit card has an average of over 324, Ewallet has an average of little over 316 so cash has the highest average.
Cash was used for the smallest transaction, and its largest transaction is the lowest amongst the 3 methods' highest by a distance.
Credit card was used for the largest transaction.
*/


  