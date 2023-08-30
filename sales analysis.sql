# DATA EXPLORATION
SELECT * 
FROM customers;
# Has 3 columns: customer_code,customer_name,customer_type.

# Shows Distinct customer type
SELECT DISTINCT customer_type
FROM customers;
#There are two customer types: Brick & Motar and E-Commerce


#Shows ditinct product types
SELECT DISTINCT product_type
FROM products;
# There are two product types: Own Brand and Distribution.

/*There seems to be 2 records empty in the zone column for Ney York and Paris.
Since we are focusing our analysis on India we will exclude these two records*/
SELECT * 
FROM markets 
WHERE zone <> "";

#Shows all the records in the trancaction table 
SELECT *
FROM transactions;


SELECT COUNT(*)
FROM transactions;

SELECT *
FROM transactions
WHERE currency ="USD";
  
# Checking to see if all the currency is all in INR
SELECT DISTINCT currency
FROM transactions; 

/*There seem to be some records in currency column as USD. 
Further inspection show that sales_amount is the only column that needs to be normalized
We therfore need to normalize the  sales_amount column into INR.*/

#At the time of this project the converion rate on USD to INR is 82.75
SELECT 	product_code,
		customer_code,
        market_code,
        order_date,
        sales_qty,
		CASE WHEN currency ="INR" THEN sales_amount
			ELSE sales_amount*82.75 END AS norm_sales_amount,
            currency,profit_margin_percentage,profit_margin,
        cost_price
FROM transactions;

# Using this we create a view of this as a normalised transaction table 

# DATA ANALYSIS
/* We break up this analysis into 4 parts :
1.Customer analysis
2.Market analysis
3.Product analysis
4.Time based analysis
5.Cost analysis
6.Profitability analysis*/


#Creating a temporay table for customer_sales

CREATE TEMPORARY TABLE customer_sales(
SELECT n.customer_code,
		c.custmer_name,
        c.customer_type,
		n.sales_qty,
        n.norm_sales_amount,
        n.sales_qty * n.norm_sales_amount AS total_sales
FROM norm_transactions n
JOIN customers c
Using (customer_code));


#Finding the total sales for each customer type .
SELECT customer_type ,ROUND(sum(total_sales)/1000000,2) AS total_sales_mln
FROM customer_sales
GROUP BY customer_type
ORDER BY total_sales_mln DESC;


#Showing the total sales for each customer
SELECT custmer_name ,ROUND(SUM(total_sales)/1000000,2) AS total_sales_mln
FROM customer_sales
GROUP BY custmer_name
ORDER BY total_sales_mln DESC;

#Finding the top 3 customers of each customer type

SELECT * 
FROM	(SELECT 	customer_type,
		custmer_name, 
        ROUND(SUM(total_sales)/1000000,2) AS total_sales_mln,
        RANK() OVER (PARTITION BY customer_type ORDER BY SUM(total_sales) DESC) AS rankn
		FROM customer_sales
		GROUP BY customer_type,custmer_name) sb
WHERE sb.rankn<=3;        

#Finding the bottom 3 customers of each customer type


SELECT * 
FROM	(SELECT 	customer_type,
		custmer_name, 
        ROUND(SUM(total_sales)/1000000,2) AS total_sales_mln,
        RANK() OVER (PARTITION BY customer_type ORDER BY SUM(total_sales) ) AS rankn
		FROM customer_sales
		GROUP BY customer_type,custmer_name) sb
WHERE sb.rankn<=3;        


# Market analysis
CREATE TEMPORARY TABLE market_sales(
SELECT  m.markets_code,
		m.markets_name,
        m.zone,
		n.sales_qty,
        n.norm_sales_amount,
        n.sales_qty * n.norm_sales_amount AS total_sales
FROM norm_transactions n
JOIN markets m
on n.market_code= m.markets_code);

# Showing total sales of each zone
SELECT zone,ROUND(sum(total_sales/1000000),2) AS total_sales_mln
FROM market_sales
GROUP BY zone;

#Showing sales in each market

SELECT zone,ROUND(sum(total_sales/1000000),2) AS total_sales_mln
FROM market_sales
GROUP BY zone 
ORDER BY total_sales_mln DESC;

# Showing the top 3 markets in each zone 
SELECT * 
FROM	(SELECT 	markets_name,
					zone, 
					ROUND(SUM(total_sales)/1000000,2) AS total_sales_mln,
					RANK() OVER (PARTITION BY zone ORDER BY SUM(total_sales) DESC) AS rankn
					FROM market_sales
					GROUP BY markets_name,zone) sb
WHERE sb.rankn<=3;  

# Showing the bottom 3 markets in each zone 
SELECT * 
FROM	(SELECT 	markets_name,
					zone, 
					ROUND(SUM(total_sales)/1000000,2) AS total_sales_mln,
					RANK() OVER (PARTITION BY zone ORDER BY SUM(total_sales)) AS rankn
					FROM market_sales
					GROUP BY markets_name,zone) sb
WHERE sb.rankn<=3;  

#product analysis.
# Showing total sales for each product_type
SELECT 	 p.product_type,
		 ROUND(SUM(n.sales_qty * n.norm_sales_amount)/1000000,2) AS total_sales_mln
FROM norm_transactions n
JOIN products p
on n.product_code= p.product_code
GROUP BY p.product_type;

#Time based analysis
#The inner query calculates the total_sales for each month per year.
#The full query finds the top 3 months with the most sales in each year

SELECT *
FROM   (
		SELECT 		d.year,
					d.month_name,
					ROUND(SUM(n.sales_qty * n.norm_sales_amount)/1000000,2) AS total_sales_mln,
					RANK() OVER(PARTITION BY d.year ORDER BY SUM(n.sales_qty * n.norm_sales_amount) DESC) as nrank
		FROM norm_transactions n
		JOIN date d
		on n.order_date= d.date
		GROUP BY d.month_name,d.year) AS Y
  WHERE  Y.nrank<=3;    


#Cost price analysis

# Shows Average cost price
SELECT ROUND(AVG(cost_price),2) AS average_cost_price
FROM norm_transactions;

#Shows the Distribution of cost price
SELECT 	ROUND(MIN(cost_price),2) AS MIN_cost_price,
		ROUND(MAX(cost_price),2) AS MAX_cost_price,
        COUNT(*) AS total_transactions
FROM norm_transactions;

#Average cost per product type

SELECT p.product_type,ROUND(AVG(cost_price),2) AS average_cost_price
FROM norm_transactions n
JOIN products p
ON n.product_code=p.product_code
Group BY p.product_type;

#cost price vs sales_qty
SELECT p.product_type,ROUND(AVG(cost_price),2) AS average_cost_price,SUM(sales_qty) AS total_sales_qty
FROM norm_transactions n
JOIN products p
ON n.product_code=p.product_code
Group BY p.product_type;

# profitability analysis

#the 5 most profitable markets 

SELECT 	m.zone,
		m.markets_name,
        ROUND(SUM(n.profit_margin_percentage),2) AS total_profit_margin_pct
FROM norm_transactions n
JOIN markets m 
ON n.market_code =m.markets_code
GROUP BY m.markets_name,m.zone
ORDER BY total_profit_margin_pct DESC
LIMIT 5;
  
  
#Finds the top 3 months  which the highest profit margin percentage
   SELECT 
    d.month_name,
    ROUND(SUM(n.profit_margin_percentage), 2) AS total_profit_margin_pct
FROM
    norm_transactions n
        JOIN
    date d ON n.order_date = d.date
GROUP BY d.month_name
ORDER BY total_profit_margin_pct DESC
LIMIT 3;
# Finds the 3 most profitable months in each year
SELECT *
FROM	(SELECT 	year,
					month_name,
					ROUND(SUM(n.profit_margin_percentage),2) AS total_profit_margin_pct,
					RANK() OVER(Partition BY d.year ORDER BY SUM(n.profit_margin_percentage) ) nrank
		FROM norm_transactions n
		JOIN date d
		ON n.order_date =d.date
		GROUP BY d.month_name,d.year
) Y
WHERE Y.nrank<=3;
    
    
