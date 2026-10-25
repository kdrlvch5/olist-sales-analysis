-- =====================================================================
-- 03_data_checks.sql
-- Olist E-commerce: data quality checks before the analysis.
-- These checks use the FULL dataset (no period filter).
-- =====================================================================


-- 1. Period covered by the data
-- Result: 2016-09-04 -> 2018-10-17
select
min(order_purchase_timestamp) as first_order_date,
max(order_purchase_timestamp) as last_order_date
from orders;


-- 2. Orders by status + how many have a delivery date
-- Findings: 8 delivered orders have no delivery date,
--           6 canceled orders have a delivery date (anomaly)
select
order_status,
count(*) as total_orders,
count(order_delivered_customer_date) as orders_with_delivery_date
from orders
group by order_status
order by total_orders desc;


-- 3. Orders per month
-- Findings: 2016 is almost empty (Nov 2016 missing),
--           Sep-Oct 2018 are cut off -> analysis uses Jan 2017 - Aug 2018
select
date_trunc('month', order_purchase_timestamp)::date as month,
count(*) as orders
from orders
group by month
order by month asc;


-- 4. Prices and shipping cost
-- Findings: median price 74.99 vs average 120.65 (right-skewed),
--           max 6,735; 383 items with free shipping
select
min(price) as min_price,
max(price) as max_price,
round(percentile_cont(0.5) within group (order by price)::numeric, 2) as median_price,
round(avg(price), 2) as avg_price,
min(freight_value) as min_freight_value,
max(freight_value) as max_freight_value,
round(avg(freight_value), 2) as avg_freight_value,
sum(case when freight_value = 0 then 1 else 0 end) as items_with_free_freight
from order_items;


-- 5. Delivery time (delivered orders only)
-- Findings: 0 to 210 days, median 10, average 12.5, no negative values
with days as (
select
order_id,
order_delivered_customer_date::date - order_purchase_timestamp::date as delivery_days
from orders
where order_status = 'delivered' and order_delivered_customer_date is not null
)
select
min(delivery_days) as min_days,
round(avg(delivery_days), 1) as avg_days,
percentile_cont(0.5) within group (order by delivery_days) as median_delivery_days,
max(delivery_days) as max_days
from days;
