
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

CREATE DATABASE SalesEDA;
GO

USE SalesEDA;
GO

CREATE TABLE dbo.Sales (
    order_number        NVARCHAR(50) NOT NULL,
    order_date          DATE         NOT NULL,
    customer_name       NVARCHAR(50) NOT NULL,
    channel             NVARCHAR(50) NOT NULL,
    product_name        NVARCHAR(50) NOT NULL,
    quantity            INT          NOT NULL,
    unit_price          FLOAT        NOT NULL,
    revenue             FLOAT        NOT NULL,
    cost                FLOAT        NOT NULL,
    state               NVARCHAR(50) NOT NULL,
    state_name          NVARCHAR(50) NOT NULL,
    us_region           NVARCHAR(50) NOT NULL,
    lat                 FLOAT        NOT NULL,
    lon                 FLOAT        NOT NULL,
    budget              FLOAT        NULL,
    total_cost          FLOAT        NOT NULL,
    profit              FLOAT        NOT NULL,
    profit_margin_pct   FLOAT        NOT NULL,
    order_month_name    NVARCHAR(50) NOT NULL,
    month_no            INT          NOT NULL
);
GO

---- ----------------------------------------------------------------------------------------------------------------------------
---- LOAD DATA
---- ----------------------------------------------------------------------------------------------------------------------------

BULK INSERT dbo.Sales
FROM 'C:\Users\tamir\OneDrive\Desktop\Sales-Analysis-main MY\final\Cleaned Sales Performance Analysis.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\r\n',
    TABLOCK
);


---- ----------------------------------------------------------------------------------------------------------------------------
---- VALIDATION
---- ----------------------------------------------------------------------------------------------------------------------------

SELECT TOP 100 * FROM dbo.Sales;
SELECT COUNT(*)  AS total_rows
FROM dbo.Sales


/* ============================================================================================================================
   QUERY 1 : Monthly Sales Trend Over Time
   Goal    : Track revenue trends month-by-month to detect seasonality or sales spikes
   ============================================================================================================================ */


select Year,
       Month,
       Current_Month_Revenue,
       Previous_Month_Revenue,
       concat(round((Current_month_revenue - Previous_month_revenue)/ NULLIF (Previous_month_revenue,0)*100,2),'%') as Difference    
from (
select *,
       lag(current_month_revenue) over (order by year,month) as Previous_month_revenue 
from (
select Year(order_date) as Year,
       Month(order_date) as Month,
       round(sum(revenue)/1000000,1) as Current_month_revenue
from Sales
group by year(order_date),month(order_date))t)a 
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
    -Revenue peaks in May and August, indicating strong seasonal demand.
    -February is the weakest month, showing an early-year dip.
    -Sales recover after April, peak in mid-year, and remain stable in the final quarter.
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
    • Top 2 products dominate revenue, creating dependency risk.
    • Mid-tier products show strong growth potential.
    • Lower-tier products contribute less and require optimization.
*/


/* RECOMMENDATIONS

- Protect and prioritize top-performing products (26 & 25) through inventory planning and marketing focus.
- Invest in mid-tier products to scale them into top performers via pricing, bundling, and promotions.
- Evaluate low-performing products for optimization, repositioning, or potential discontinuation to improve portfolio efficiency.

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
    - Wholesale accounts for ~54% of total revenue, Distributor ~31%, and Export ~14.5%.
    - The heavy reliance on domestic bulk channels creates concentration risk.
    - To diversify, prioritise expanding export initiatives through targeted overseas marketing
      and strategic partner relationships.
*/
 





 
/* ============================================================================================================================
   QUERY 6 : Order Value (AOV) Distribution
   Goal    : Understand the spread of order values to identify typical spending levels and outliers
   ============================================================================================================================ */


select *,
       concat(round((cast(Total_orders as float)/sum(Total_orders) over ())*100,1),' %') as Contribution_To_TotalOrders
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
       ELSE 'Above 700k '
       END Order_Value_Category 
from (
select order_number,
       round(sum(revenue),2) as total_purchase
from Sales
group by order_number)t)a)s
order by Total_orders desc


/*  INSIGHTS
    - ~83% of orders fall below $200k, confirming a volume-driven business model.
    - More than half of all orders (56.5%) are in the below-$100k bucket alone.
    - High-value orders above $400k represent just ~1% of total orders (99 orders),
      and nothing exceeded $600k.
    - The primary growth lever is moving customers from the below-$100k band
      into the $100k–$200k range through upselling and bundling strategies,
      which could meaningfully shift the revenue
*/
 




 
/* ============================================================================================================================
   QUERY 7 : Customer Revenue Ranking with Average & Median Benchmarks
   Goal    : Identify highest- and lowest-revenue customers and benchmark against average and median
   ============================================================================================================================ */


select Customer_name as Customer,
       Order_value_millions as Total_Order_Value,
       round(avg(order_value_Millions) over(),1) as Avg_Order_Value,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY order_value_millions) OVER () AS Median_Order_Value,
       Rank () over (order by Order_value_Millions desc) as rank
from (
 select  customer_name, 
        round(sum(revenue)/1000000 ,1) as Order_value_Millions, 
        count(order_number) as Total_orders
 from Sales group by customer_name)t
order by Order_value_Millions desc
  

/* INSIGHTS

- Aibox Company leads at ~$12.2M, followed closely by State Ltd (~$11.9M).
  The top 10 customers fall within a relatively tight $9.6M–$12.2M range, indicating a strong high-value cohort.
- At the lower end, revenue declines gradually to ~$3.9M, showing a long tail of lower-contributing customers rather than a sharp drop-off.
- Approximately 54% of customers fall below the average, while ~48% fall below the median,
  confirming a right-skewed distribution where a smaller group of high-value customers drives disproportionate revenue.
- Average and median order values (~$6.8M and ~$6.6M) remain consistent across customers,
  suggesting uniform transaction sizes and that revenue differences are primarily driven by order frequency.

*/

/* RECOMMENDATIONS

- Prioritize retention and relationship management for top-tier customers, as they contribute a significant share of revenue.
- Target mid-tier customers (~$7M–$9M) with upselling and engagement strategies to move them into the top-performing segment.
- Implement scalable campaigns to lift lower-tier customers toward the median, improving overall revenue distribution.
- Focus on increasing purchase frequency rather than order size, as order values are already consistent across customers.

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

/* INSIGHTS

- West region leads with ~$358M (~30% of total revenue), driven strongly by California alone (~$220.3M), making it the single largest contributor.
- South (~$321.7M) and Midwest (~$308.3M) form a strong second tier, indicating broad and consistent demand across multiple states.
- Northeast lags at ~$199.9M (~17% of total), highlighting a clear underperformance compared to other regions.
- California significantly outperforms all states, generating more than double the revenue of the next highest state (Illinois ~$107M).
- Illinois, Florida, and Texas form a strong second tier (~$80M–$107M), contributing substantial but notably lower revenue than California.
- Revenue distribution shows high regional concentration, with a few key states driving a large portion of total sales.

*/


/* RECOMMENDATIONS

- Sustain and protect West region performance, especially California, through focused account management and demand planning.
- Expand operations in Northeast through targeted marketing, partnerships, and regional sales strategies to close the revenue gap.
- Strengthen high-performing states (Illinois, Florida, Texas) to reduce dependency on California.
- Identify growth opportunities in mid-tier states to improve overall regional balance and reduce concentration risk.

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
 



/* ============================================================================================================================
   QUERY 10 : RFM Customer Segmentation
   Goal     : Classify customers by Recency, Frequency, and Monetary value to enable targeted marketing
   ============================================================================================================================ */

WITH RFM_Base AS (
    SELECT
        customer_name,
        DATEDIFF(DAY, MAX(order_date), (SELECT MAX(order_date) FROM Sales))  AS Recency,
        COUNT(DISTINCT order_number)                                         AS Frequency,
        ROUND(SUM(revenue) / 1000, 2)                                        AS Monetary_K
    FROM Sales
    GROUP BY customer_name
),
RFM_Scores AS (
    SELECT *,
            CASE 
                when Recency =  0 then   5
                when Recency <= 2 then   4
                when Recency <= 5 then   3
                when Recency <= 9 then   2
                else 1
            END AS R_Score,
            NTILE(5) OVER (ORDER BY Frequency DESC) AS F_Score,
            NTILE(5) OVER (ORDER BY Monetary_K DESC) AS M_Score
    FROM RFM_Base
),
RFM_Combined AS (
    SELECT *,
        CAST(R_Score AS VARCHAR) + CAST(F_Score AS VARCHAR) + CAST(M_Score AS VARCHAR) AS RFM_Cell,
        (R_Score + F_Score + M_Score) AS RFM_Total
    FROM RFM_Scores
)
SELECT
    customer_name   AS Customer,
    Recency,
    Frequency,
    Monetary_K      AS Monetary_000s,
    R_Score,
    F_Score,
    M_Score,
    RFM_Cell,
    CASE
        when RFM_Total >= 13                 then  'Champion'
        when RFM_Total >= 11                 then  'Loyal Customer'
        when RFM_Total >= 4 and F_Score <= 2 then  'New Customer'
        when RFM_Total >= 9                  then  'Potential Loyalist'
        when  F_Score >= 4 and M_Score <= 2  then  'Needs Attention'
        else                                       'Developing'
    END AS Customer_Segment
FROM RFM_Combined
ORDER BY Customer;

/* INSIGHTS SUMMARY

- Champions represent the high-value customers with strong recency, high purchase frequency, and significant revenue contribution.
  They are critical to business success and should be prioritized through retention programs, loyalty rewards, and premium offerings.

- Loyal Customers form a stable and consistent revenue base, demonstrating strong repeat purchase behavior.
  These customers provide predictable revenue and can be strategically nurtured into Champions through cross-selling and personalized engagement.

- Potential Loyalists show good engagement levels with moderate-to-high activity, indicating strong future value potential.
  With targeted marketing and retention efforts, they can be converted into high-value segments.

- Developing customers represent a moderate engagement group with steady but not fully optimized contribution.
  These customers offer growth opportunities through improved engagement and upselling strategies.

- The dataset shows that customer retention is relatively strong and the business does not currently face significant churn issues.

- Overall, the customer base is healthy, with a strong concentration of active and repeat buyers.
  Revenue differences are primarily driven by purchase frequency rather than order value,
  highlighting opportunities to increase engagement rather than pricing.

*/


/* RECOMMENDATIONS

- Focus on retaining Champions and Loyal Customers, as they contribute the majority of revenue.

- Convert Potential Loyalists and Developing customers into higher-value segments through targeted campaigns and personalized offers.

- Increase purchase frequency across mid-tier customers to drive revenue growth.

- Implement proactive monitoring to identify early churn signals, even though current churn risk is low.

*/


/* ============================================================================================================================
   QUERY 11 : Customer Lifetime Value (CLV) Estimate
   Goal     : Estimate the long-run revenue value of each customer using average order value,
              purchase frequency, and customer lifespan
   ============================================================================================================================ */

WITH Customer_Stats AS (
    SELECT
        customer_name,
        COUNT(DISTINCT order_number)                                                        AS Total_Orders,
        ROUND(SUM(revenue), 2)                                                              AS Total_Revenue,
        ROUND(SUM(revenue) / COUNT(DISTINCT order_number), 2)                               AS Avg_Order_Value,
        DATEDIFF(MONTH,
            MIN(order_date),
            MAX(order_date))                                                                AS Active_Months,
        ROUND(COUNT(DISTINCT order_number) * 1.0
              / NULLIF(DATEDIFF(MONTH, MIN(order_date), MAX(order_date)), 0), 2)            AS Orders_Per_Month
    FROM Sales
    GROUP BY customer_name
)
SELECT
    customer_name                                   AS Customer,
    Total_Orders,
    ROUND(Total_Revenue / 1000, 1)                  AS Total_Revenue_K,
    ROUND(Avg_Order_Value / 1000, 1)                AS Avg_Order_Value_K,
    Active_Months,
    Orders_Per_Month,
    -- Simple CLV projection: AOV x Orders per Month x 12 months forward
    ROUND((Avg_Order_Value * Orders_Per_Month * 12) / 1000, 1) AS Projected_Annual_CLV_K
FROM Customer_Stats
ORDER BY Projected_Annual_CLV_K DESC;

/* INSIGHTS
   - Customers with high purchase frequency (Orders_Per_Month) consistently
     generate higher CLV than one-time high spenders, highlighting the importance
     of repeat buying behavior.

   - High Active_Months indicates strong customer retention; however, customers
     with long tenure but lower CLV represent upsell and cross-sell opportunities.

   - Top CLV customers combine strong frequency and solid AOV, making them ideal
     targets for retention and loyalty programs.

   - Projected CLV can be used to define customer acquisition cost limits,
     ensuring marketing spend remains profitable.
*/




/* ============================================================================================================================
   QUERY 12 : Year-over-Year Revenue Growth by Product
   Goal     : Measure how each product's revenue grew or declined between years
   ============================================================================================================================ */

WITH Yearly_Product AS (
    SELECT
        product_name,
        YEAR(order_date)            AS Year,
        ROUND(SUM(revenue) / 1000, 1) AS Revenue_K
    FROM Sales
   
    GROUP BY product_name, YEAR(order_date)
),
YoY AS (
    SELECT *,
        LAG(Revenue_K) OVER (PARTITION BY product_name ORDER BY Year) AS Prev_Year_Revenue_K
    FROM Yearly_Product
)
SELECT
    product_name        AS Product,
    Year,
    Revenue_K,
    CASE
        WHEN Prev_Year_Revenue_K IS NULL THEN 'Base Year'
        ELSE CONCAT(
            ROUND((Revenue_K - Prev_Year_Revenue_K) / Prev_Year_Revenue_K * 100, 1),
            ' %'
        )
    END AS YoY_Growth
FROM YoY
ORDER BY product_name, Year;

/* INSIGHTS

- Revenue trends vary significantly across products, with several showing alternating growth and decline, indicating uneven demand patterns rather than consistent growth.

- Products such as Product 11 and Product 19 demonstrate relatively stable upward growth over multiple years, making them strong candidates for scaling and long-term investment.

- High-revenue products like Product 25 and Product 26 show gradual decline or stagnation over time, suggesting market maturity or possible saturation despite strong overall contribution.

- Some products (e.g., Product 15, Product 16, Product 28) show consistent or repeated negative YoY trends, indicating declining performance and potential need for strategic intervention.

- Products like Product 9 and Product 24 exhibit sharp growth spikes followed by declines, suggesting short-term drivers such as promotions or seasonal demand rather than sustainable growth.

- Overall, the product portfolio reflects a mix of growth-stage, mature, and declining products, requiring differentiated strategies for optimization.

*/

/* RECOMMENDATIONS

- Invest in consistently growing products (e.g., Product 11, Product 19) to maximize long-term revenue potential.

- Monitor and optimize mature products (e.g., Product 25, Product 26) through pricing, bundling, or innovation to prevent further decline.

- Reassess underperforming products with repeated negative growth to determine whether to reposition, improve, or phase out.

- Avoid over-reliance on products with volatile growth patterns by focusing on stable and predictable performers.

- Implement product-level performance tracking to identify early signals of decline or growth opportunities.

*/




/* ============================================================================================================================
   QUERY 13 : 3-Month Rolling Average Revenue and Running Average Monthly
   Goal     : Smooth out month-to-month noise to reveal the underlying revenue trend
   ============================================================================================================================ */

WITH Monthly AS (
    SELECT
        YEAR(order_date)               AS Year,
        MONTH(order_date)              AS Month,
        DATENAME(MONTH, order_date)    AS Month_Name,
        ROUND(SUM(revenue) / 1000000, 2) AS Revenue_M
    FROM Sales
    GROUP BY YEAR(order_date), MONTH(order_date), DATENAME(MONTH, order_date)
)
SELECT
    Year,
    Month,
    Month_Name,
    Revenue_M,
    round(avg(Revenue_M) over (Partition by Year  order by year ,month rows between unbounded preceding and current row),2) as Running_Avg,
    ROUND(AVG(Revenue_M) OVER (ORDER BY Year, Month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2) AS Rolling_3M_Avg_M
FROM Monthly
ORDER BY Year, Month;

/* INSIGHTS

- Revenue remains highly stable across the entire period, fluctuating within a narrow band (~$23M–$26M), 
  indicating a mature and predictable business model with low volatility.

- A clear seasonal pattern is observed: revenue tends to dip early in the year (February–April), peak in May, slightly soften in June–July, 
  and rebound again around August, followed by stable performance toward year-end.

- The rolling 3-month average smooths short-term fluctuations and confirms the absence of any significant upward or downward trend, reinforcing the stability of the business.

- A noticeable dip in early 2017 (especially February) indicates short-term demand fluctuation, but the quick recovery suggests strong business resilience.

- Overall, the business shows consistent performance with cyclical seasonal patterns rather than sustained growth,
  indicating that revenue optimization must come from efficiency, pricing, or customer strategies rather than organic demand expansion.

*/


/* RECOMMENDATIONS

- Focus on increasing Average Order Value (AOV) and customer frequency, as organic revenue growth is limited in a stable demand environment.

- Strengthen performance during low-demand months (Feb–Apr) through targeted promotions and campaigns.

- Capitalize on peak periods (May and August) with inventory planning and marketing push to maximize revenue.

- Use rolling average trends for more accurate forecasting and operational planning.

*/



/* ============================================================================================================================
   QUERY 14 : Channel × Product Profitability Matrix
   Goal     : Identify which channel-product combinations are most and least profitable
   ============================================================================================================================ */

SELECT
    channel                                     AS Channel,
    product_name                                AS Product,
    ROUND(SUM(revenue) / 1000, 1)               AS Revenue_K,
    ROUND(SUM(profit) / 1000, 1)                AS Profit_K,
    ROUND(AVG(profit_margin_pct), 2)            AS Avg_Margin_Pct,
    RANK() OVER (
        PARTITION BY channel
        ORDER BY AVG(profit_margin_pct) DESC
    )                                           AS Margin_Rank_In_Channel
FROM Sales
GROUP BY channel, product_name
ORDER BY Channel, Margin_Rank_In_Channel

/* INSIGHTS

- Export channel delivers the highest profit margins, with several products exceeding 40% (peaking at ~46%), 
  indicating strong pricing power and premium positioning compared to other channels.

- Distributor channel maintains relatively consistent margins (~36%–40%) across most products,
 reflecting stable and balanced profitability with lower volatility.

- Wholesale channel generates the highest revenue volumes but operates at comparatively lower margins (~35%–38%), 
  confirming a high-volume, low-margin business model.

- Certain products (e.g., Product 9, Product 19, Product 1) consistently perform well across multiple channels, 
  indicating strong and diversified demand.

- Margin variation across products within each channel highlights opportunities for pricing optimization, cost control, and product-level strategy improvements.

- Overall, the channel strategy reflects a trade-off between volume (Wholesale) and profitability (Export),
  with Distributor acting as a balanced middle layer.

*/

/* RECOMMENDATIONS

- Expand Export channel for high-margin products to maximize profitability and improve overall margin mix.

- Use Wholesale channel to drive volume while optimizing pricing and costs to prevent margin erosion.

- Maintain Distributor channel as a stable revenue base while identifying high-margin products for scaling.

- Focus on cross-channel top-performing products to maximize both volume and profitability.

- Reassess low-margin products within each channel for pricing adjustments, cost reduction, or repositioning.

*/


/* ============================================================================================================================
   QUERY 15 : Profit Margin by State & Region
   Goal     : Geographic profitability view to complement the revenue map in Query 8
   ============================================================================================================================ */

SELECT
    state_name      AS State,
    us_region       AS Region,
    ROUND(SUM(revenue)  / 1000000, 2)   AS Revenue_M,
    ROUND(SUM(profit)   / 1000000, 2)   AS Profit_M,
    ROUND(AVG(profit_margin_pct), 2)    AS Avg_Margin_Pct,
    RANK() OVER (ORDER BY AVG(profit_margin_pct) DESC) AS Margin_Rank
FROM Sales
GROUP BY state_name, us_region
ORDER BY Avg_Margin_Pct DESC;

/* INSIGHTS
   - Profit margins are highly consistent across states (~35%–40%), indicating
     standardized pricing and cost structures across regions.

   - High-revenue states (e.g., California, Texas, Illinois) drive the majority
     of total profit despite slightly lower margin ranks, highlighting the
     importance of volume over margin.

   - Top margin states (e.g., Montana, Nebraska) are lower in revenue, suggesting
     niche efficiency but limited overall business impact.

   - Minimal margin variation across regions (West, Midwest, South, Northeast)
     indicates balanced regional performance without major profitability gaps.

   - Focus should be on scaling high-revenue states while improving margins in
     lower-performing regions for overall profitability growth.
*/


/* ============================================================================================================================
   QUERY 16 : Revenue Pivot Table — Month × Year
   Goal     : Create a cross-tab of monthly revenue across all years for at-a-glance seasonality
   ============================================================================================================================ */

SELECT
    month_no                                 AS Month_Num,
    order_month_name                                AS Month,
    ROUND(SUM(CASE WHEN YEAR(order_date) = 2014 THEN revenue ELSE 0 END) / 1000000, 2) AS [2014_M],
    ROUND(SUM(CASE WHEN YEAR(order_date) = 2015 THEN revenue ELSE 0 END) / 1000000, 2) AS [2015_M],
    ROUND(SUM(CASE WHEN YEAR(order_date) = 2016 THEN revenue ELSE 0 END) / 1000000, 2) AS [2016_M],
    ROUND(SUM(CASE WHEN YEAR(order_date) = 2017 THEN revenue ELSE 0 END) / 1000000, 2) AS [2017_M],
    ROUND(SUM(revenue) / 1000000, 2)               AS All_Years_Total_M
FROM Sales
GROUP BY month_no, order_month_name
ORDER BY month_no;



/* INSIGHTS

- Revenue shows a clear seasonal pattern, with peak performance in May (~$102.27M) and August (~$101.95M),
  followed closely by strong year-end months (October–December ~ $100M–$101M).

- February consistently records the lowest revenue (~$91.3M), indicating a recurring early-year demand dip.

- Revenue remains stable across months (~$23M–$26M per month), reflecting a mature and predictable business with low volatility.

- A cyclical trend is observed: dip in February–April, peak in May, slight moderation in June–July, rebound in August,
  and stable performance through Q4.

- Year-end months (Oct–Dec) maintain consistently high performance, making them critical for maximizing annual revenue.

*/

/* RECOMMENDATIONS

- Focus on boosting performance during low-demand months (February–April) through targeted promotions and campaigns.

- Capitalize on peak periods (May, August, and Q4) with strong inventory planning and marketing efforts.

- Use seasonal trends for accurate forecasting and demand planning.

- Optimize pricing and promotions during stable months to increase average order value.

*/



/* ============================================================================================================================
   QUERY 17 : Cost Efficiency by Product — Revenue-to-Cost Ratio
   Goal     : Identify which products deliver the most revenue per dollar of cost
   ============================================================================================================================ */

SELECT
    product_name                                        AS Product,
    ROUND(SUM(revenue)    / 1000000, 2)                 AS Revenue_M,
    ROUND(SUM(total_cost) / 1000000, 2)                 AS Total_Cost_M,
    ROUND(SUM(revenue) / NULLIF(SUM(total_cost), 0), 3) AS Revenue_Per_Cost_Dollar,
    ROUND(AVG(profit_margin_pct), 2)                    AS Avg_Margin_Pct,
    RANK() OVER (ORDER BY SUM(revenue) / NULLIF(SUM(total_cost), 0) DESC) AS Efficiency_Rank
FROM Sales
GROUP BY product_name
ORDER BY Efficiency_Rank;

/* INSIGHTS
   - Top-performing products (e.g., Product 9, Product 30, Product 28) generate
     the highest revenue per cost dollar, indicating superior cost efficiency.

   - Efficiency variation across products is relatively narrow (~1.52–1.67),
     suggesting a generally optimized cost structure across the portfolio.

   - High-revenue products (e.g., Product 25, Product 26, Product 1) maintain
     strong efficiency, making them key contributors to both scale and profitability.

   - Lower-ranked products (e.g., Product 12, Product 14, Product 2) show weaker
     cost efficiency, highlighting opportunities for cost optimization or pricing adjustments.

   - Overall, combining high efficiency with high revenue identifies the most
     strategic products for growth and investment focus.
*/

/* ============================================================================================================================
   QUERY 18 : ABC Product Classification (Pareto Analysis)
   Goal     : Classify products into A (top 70%), B (next 20%), C (bottom 10%) by revenue contribution
   ============================================================================================================================ */
 
WITH Product_Revenue AS (
    SELECT
        product_name,
        ROUND(SUM(revenue) / 1000000, 2) AS Revenue_M
    FROM Sales
    GROUP BY product_name
),
Running_Total AS (
    SELECT *,
        SUM(Revenue_M) OVER (ORDER BY Revenue_M DESC) AS Cumulative_Revenue,
        SUM(Revenue_M) OVER ()                         AS Grand_Total
    FROM Product_Revenue
)
SELECT
    product_name                                            AS Product,
    Revenue_M,
    ROUND(Cumulative_Revenue / Grand_Total * 100, 1)        AS Cumulative_Pct,
    CASE
        WHEN Cumulative_Revenue / Grand_Total <= 0.70 THEN 'A — Core'
        WHEN Cumulative_Revenue / Grand_Total <= 0.90 THEN 'B — Support'
        ELSE                                               'C — Review'
    END AS ABC_Class
FROM Running_Total
ORDER BY Revenue_M DESC;

/* INSIGHTS

- A-class products contribute approximately ~70% of total revenue, confirming that a relatively small group of products drives the majority of business performance.

- B-class products contribute the next ~20% of revenue, acting as stable support contributors with strong potential to scale into higher-value products.

- C-class products contribute the remaining ~10% of revenue, indicating limited impact on overall performance and highlighting opportunities for optimization.

- Revenue distribution is highly concentrated in top-performing products, creating dependency risk on A-class items for overall business success.

- The distribution follows a Pareto-like pattern (~70/20/10), slightly more balanced than the traditional 80/20 rule, indicating a moderately diversified product portfolio.

*/

/* RECOMMENDATIONS

- Prioritize A-class products for inventory management, demand forecasting, and marketing investment to protect core revenue.

- Focus on scaling B-class products through pricing strategies, bundling, and targeted promotions to increase their contribution.

- Evaluate C-class products for cost optimization, repositioning, or potential discontinuation to improve portfolio efficiency.

- Reduce dependency risk by diversifying revenue across more products rather than relying heavily on top performers.

*/
