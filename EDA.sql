
/* ============================================================================================================================
   PROJECT   : Sales Analysis 
   DATABASE  : SalesEDA
   TOOL      : SQL Server
   PURPOSE   : Data Analysis on cleaned sales data exported from Python
   ============================================================================================================================ 
*/





-- ----------------------------------------------------------------------------------------------------------------------------
-- SETUP : Create Database & Table
-- ----------------------------------------------------------------------------------------------------------------------------

create database SalesEDA;

CREATE TABLE Sales (
    order_number        VARCHAR(50)     NOT NULL,
    order_date          DATE            NOT NULL,
    customer_name       VARCHAR(100)    NOT NULL,
    channel             VARCHAR(50)     NOT NULL,
    product_name        VARCHAR(150)    NOT NULL,
    quantity            INT             NOT NULL,
    unit_price          DECIMAL(10,2)   NOT NULL,
    revenue             DECIMAL(12,2)   NOT NULL,
    cost                DECIMAL(12,2)   NOT NULL,
    total_cost          DECIMAL(12,2)   NOT NULL,
    profit              DECIMAL(12,2)   NOT NULL,
    profit_margin_pct   DECIMAL(5,2)    NOT NULL,
    budget              DECIMAL(12,2),            --Nullable :only exists for 2017
    state               VARCHAR(10)     NOT NULL,
    state_name          VARCHAR(50)     NOT NULL,
    us_region           VARCHAR(50)     NOT NULL,
    lat                 DECIMAL(9,6)    NOT NULL,
    lon                 DECIMAL(9,6)    NOT NULL,
    order_month_name    VARCHAR(15)     NOT NULL,
    order_month_num     INT             NOT NULL
);



-- ----------------------------------------------------------------------------------------------------------------------------
-- LOAD DATA
-- ----------------------------------------------------------------------------------------------------------------------------


Bulk insert Sales
from 'C:\SalesEDA.csv'
with (
    firstrow = 2,
    fieldterminator = ',',
    tablock
);

--Quick Check

select top 10 *  from Sales 





/* ============================================================================================================================
   QUERY 1 : Monthly Sales Trend Over Time
   Goal    : Track revenue trends month-by-month to detect seasonality or sales spikes
   ============================================================================================================================ */


select Year,
       Month,
       Previous_Month_Reveue,
       Current_Month_Revenue,
       concat(round((Current_month_revenue - previous_month_reveue)/current_month_revenue*100,2),'%') as Difference    
from (
select *,
       lag(current_month_revenue) over (order by year,month) as previous_month_reveue 
from (
select Year(order_date) as Year,
       Month(order_date) as Month,
       round(sum(revenue)/1000000,1) as Current_month_revenue
from Sales
group by year(order_date),  datename(month,order_date),month(order_date))t)a 
order by Year, Month


/*  INSIGHTS
    - Sales consistently cycle between $24M–$26M, with clear peaks in late spring / early summer (May–June)
      and troughs each January.
    - The overall trend remains stable, reflecting a reliable seasonal demand pattern.
    - The sharp revenue drop in early 2017 stands out as an outlier, warranting closer investigation
      into potential causes such as market disruptions or mistimed promotions.
*/






/* ============================================================================================================================
   QUERY 2 : Monthly Sales Trend (All Years Combined)
   Goal    : Highlight overall seasonality by aggregating sales across all years for each calendar month
   ============================================================================================================================ */


select datename(month,order_date) as Month ,
       round(sum(revenue)/1000000,2) as Total_Revenue
from Sales
group by datename(month,order_date)
order by Total_Revenue desc


/*  INSIGHTS
    - Across all years, January and Feburary are  strongest at roughly $124M and $114.7M.
    - Sales rebound in May and again around August (~$99M–$101M).
    - This pattern reveals a strong post-New Year surge, a spring dip, and a mid-summer bump
      repeating each calendar year.
*/
 




 
/* ============================================================================================================================
   QUERY 3 : Top 10 Products by Revenue
   Goal    : Identify the highest-grossing products to focus marketing and inventory efforts
   ============================================================================================================================ */


select top 10 product_name as Products ,
              round(sum(revenue)/1000000,2) as Total_Sales_Value
from Sales
group by product_name
order by Total_Sales_Value desc


/*  INSIGHTS
    - Products 26 and 25 pull ahead at $117.2M and $109.5M respectively.
    - There is a sharp drop to the $68M–$75M band for the next tier.
    - The bottom four products cluster around $57M, indicating similar growth constraints.
    - Focus growth pilots on the mid-tier and efficiency improvements on the lower earners.
*/
 





 
/* ============================================================================================================================
   QUERY 4 : Top 10 Products by Average Profit Margin
   Goal    : Compare average profitability across products to identify high-margin items
   ============================================================================================================================ */


select top 10 product_name as Product ,
       round(avg(profit_margin_pct),2) as Profit_Margin 
from Sales
group by product_name 
order by Profit_margin  desc


/*  INSIGHTS
    - Products 9 and 7 lead with the highest average profit margins (~40%).
    - All remaining products fall in a tight band between 35.5%–38.5%.
    - Applying margin optimization strategies from the top performers could help
      elevate overall product profitability.
*/
 
 




/* ============================================================================================================================
   QUERY 5 : Sales Distribution by Channel
   Goal    : Show the share of total revenue across channels to identify dominant sales routes
   ============================================================================================================================ */


select Channel,
       Revenue as Total_Revenue,
       concat(round((revenue/total_revenue*100),2),' %')  as Contribution
from (
select distinct
        Channel,
        round(sum(revenue) over (partition by channel)/1000000,1)as Revenue,
        round(sum(revenue) over()/1000000,1)as total_revenue
from Sales)t


/*  INSIGHTS
    - Wholesale accounts for ~54% of total revenue, Distributor ~31%, and Export ~15%.
    - The heavy reliance on domestic bulk channels creates concentration risk.
    - To diversify, prioritise expanding export initiatives through targeted overseas marketing
      and strategic partner relationships.
*/
 





 
/* ============================================================================================================================
   QUERY 6 : Order Value (AOV) Distribution
   Goal    : Understand the spread of order values to identify typical spending levels and outliers
   ============================================================================================================================ */


select *,
       concat(round((cast(Total_orders as float)/sum(Total_orders) over ())*100,1),' %') as Contribution_To_Revenue
from (
select distinct Order_Value_Category,
       count(Order_Value_Category) over (partition by Order_Value_category ) as Total_orders
from (
select order_number,
       concat(round(total_purchase/1000,1),' k') as Revenue , 
       CASE
            WHEN total_purchase >= 100000 AND total_purchase < 200000 THEN '100k to 200k'
            WHEN total_purchase >= 200000 AND total_purchase < 400000 THEN '200k to 400k'
            WHEN total_purchase >= 400000 AND total_purchase < 600000 THEN '400k to 600k'
            WHEN total_purchase >= 600000 AND total_purchase < 700000 THEN '600k to 700k'
            when total_purchase <100000 then 'Below 100k'
       ELSE 'Above 800k '
       END Order_Value_Category 
from (
select order_number,
       round(sum(revenue),2) as total_purchase
from Sales
group by order_number)t)a)s
order by Total_orders desc


/*  INSIGHTS
    - 83% of orders fall below $200k, confirming a volume-driven business model.
    - More than half of all orders (54.7%) are in the below-$100k bucket alone.
    - High-value orders above $400k represent just 1.2% of total orders (129 orders),
      and nothing exceeded $600k — indicating no enterprise-level accounts exist yet.
    - The primary growth lever is moving customers from the below-$100k band
      into the $100k–$200k range through upselling and bundling strategies,
      which could meaningfully shift the revenue mix without needing new customer acquisition.
*/
 




 
/* ============================================================================================================================
   QUERY 7 : Customer Revenue Ranking with Average & Median Benchmarks
   Goal    : Identify highest- and lowest-revenue customers and benchmark against average and median
   ============================================================================================================================ */


select Customer_name as Customer,
       Order_value_millions as Total_Order_Value,
       round(avg(order_value_Millions) over(),1) as Avg_Order_Value,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY order_value_millions) OVER () AS Median_Order_Value
from (
 select  customer_name, 
        round(sum(revenue)/1000000 ,1) as Order_value_Millions, 
        count(order_number) as Total_orders
 from Sales group by customer_name)t
order by Order_value_Millions desc


/*  INSIGHTS
    - Aibox Company leads at $12.6M, followed by State Ltd at $12.2M; the 10th-ranked customer
      still contributes $9.9M — a tight $10M–$12M top tier.
    - At the bottom, Johnson Ltd sits at ~$4M.
    - ~54% of customers fall below the average, but only ~48% fall below the median,
      confirming a right-skewed distribution driven by a small number of high-value accounts.
    - Action: prioritise retention and upselling for the top tier; launch targeted campaigns
      to lift the lower-revenue cohort toward the median.
*/
 





 
/* ============================================================================================================================
   QUERY 8 : Total Sales by State & US Region
   Goal    : Visualise geographic distribution to identify high- and low-performing states
             and compare performance across US regions
   ============================================================================================================================ */


select distinct State_Name as States,
       round(sum(revenue) over(partition by state_name)/1000000 ,1) as Total_State_Revenue,
       us_region as Region,
        round(sum(revenue) over(partition by us_region)/1000000 ,1) as  Total_Region_Revenue
from Sales
order by Total_State_Revenue desc


/*  INSIGHTS
    - West dominates with ~$372M (~30% of total), underscoring its market leadership.
    - South and Midwest each contribute over $320M and $335M respectively, indicating strong consistent demand.
    - Northeast trails at ~$210M (~17% of total), signalling the clearest opportunity for targeted investment.
    - California leads all states at ~$229M — more than twice the next-highest state.
    - Illinois, Florida, and Texas form a solid second tier at $110M-$85M
    - Action: close the Northeast gap with local promotions and partnerships while sustaining
      momentum in the West and South.
*/
 




 
/* ============================================================================================================================
   QUERY 9 : Average Profit Margin by Channel
   Goal    : Compare profitability across sales channels to identify the most efficient routes
   ============================================================================================================================ */


select Channel,
       concat(round(avg(profit_margin_pct),1),' %') as AVG_Profit_Margin
from Sales
group by channel


/*  INSIGHTS
    - Export leads with a 37.93% average margin, followed by Distributor (37.6%) and
      Wholesale (37.1%).
    - The spread of less than 1% confirms consistently strong profitability across all channels.
    - Since Export delivers the highest margin but only ~15% of revenue, pushing export volume
      represents the highest-return growth opportunity.
*/
 