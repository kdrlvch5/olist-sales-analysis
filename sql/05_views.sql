-- =====================================================================
-- 05_views.sql
-- Olist E-commerce: views for the Power BI model
-- (3 dimensions + 3 facts). All business rules are applied here once:
--   * period Jan 2017 - Aug 2018, without 'canceled' / 'unavailable'
--   * English category names, 'unknown' if missing
--   * customer = real person (customer_unique_id)
--   * delivery status and delay days
-- Each view was exported to CSV (UTF-8) in the exports/ folder.
-- =====================================================================


-- ---------------------------------------------------------------------
-- dim_products: one row = one product (32,951 rows)
-- ---------------------------------------------------------------------
create or replace view dim_products as
select
pr.product_id,
coalesce(c.product_category_name_english, 'unknown') as product_category
from products pr
left join category_translation c
on pr.product_category_name = c.product_category_name;


-- ---------------------------------------------------------------------
-- dim_sellers: one row = one seller (3,095 rows)
-- ---------------------------------------------------------------------
create or replace view dim_sellers as
select
seller_id,
seller_state,
seller_city
from sellers;


-- ---------------------------------------------------------------------
-- dim_customers: one row = one real customer (94,707 rows)
-- State and city are taken from the customer's FIRST order.
-- ---------------------------------------------------------------------
create or replace view dim_customers as
with cte1 as (
select
    c.customer_unique_id,
    c.customer_state,
    c.customer_city,
    o.order_purchase_timestamp,
    row_number() over (
        partition by c.customer_unique_id
        order by o.order_purchase_timestamp asc
        ) as order_number,
    count(o.order_id) over (
        partition by c.customer_unique_id
        ) as total_orders
from orders o
join customers c
on o.customer_id = c.customer_id
where o.order_status not in ('canceled', 'unavailable')
and o.order_purchase_timestamp >= '2017-01-01' and o.order_purchase_timestamp < '2018-09-01'
)
select
case when total_orders > 1 then 'repeat' else 'one-time' end as customer_type,
    customer_unique_id,
    customer_state,
    customer_city,
    order_purchase_timestamp::date as first_order_date,
    total_orders
from cte1
where order_number = 1;


-- ---------------------------------------------------------------------
-- fact_order_items: one row = one item in an order
-- Check: sum(price) = 13,449,529.68; distinct orders = 97,905
-- ---------------------------------------------------------------------
create or replace view fact_order_items as
select
    i.order_id,
    i.order_item_id,
    i.product_id,
    i.price,
    i.freight_value,
    i.seller_id,
    c.customer_unique_id,
    o.order_purchase_timestamp::date as order_date
from order_items i
join orders o
on o.order_id = i.order_id
join customers c
on c.customer_id = o.customer_id
where o.order_status not in ('canceled', 'unavailable')
and o.order_purchase_timestamp >= '2017-01-01' and o.order_purchase_timestamp < '2018-09-01';


-- ---------------------------------------------------------------------
-- fact_orders: one row = one order (97,910 rows)
-- Check: 'late' = 6,531; 'late' + 'on-time' = 96,203
-- ---------------------------------------------------------------------
create or replace view fact_orders as
select
    o.order_id,
    c.customer_unique_id,
    o.order_purchase_timestamp::date as order_date,
    o.order_status,
    o.order_delivered_customer_date::date as delivery_date,
    o.order_estimated_delivery_date::date as estimated_delivery_date,
    o.order_delivered_customer_date::date - o.order_purchase_timestamp::date as delivery_days,
    o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date as delay_days,
    case
        when o.order_delivered_customer_date is null then 'not delivered'
        when o.order_delivered_customer_date::date <= o.order_estimated_delivery_date::date then 'on-time'
        else 'late'
    end as delivery_status
from orders o
join customers c
on o.customer_id = c.customer_id
where o.order_status not in ('canceled', 'unavailable')
and o.order_purchase_timestamp >= '2017-01-01' and o.order_purchase_timestamp < '2018-09-01';


-- ---------------------------------------------------------------------
-- fact_reviews: one row = one review for one order
-- ---------------------------------------------------------------------
create or replace view fact_reviews as
select
    r.review_id,
    o.order_id,
    r.review_score,
    r.review_creation_date::date as review_date
from order_reviews r
join orders o
on r.order_id = o.order_id
where o.order_status not in ('canceled', 'unavailable')
and o.order_purchase_timestamp >= '2017-01-01' and o.order_purchase_timestamp < '2018-09-01';


-- ---------------------------------------------------------------------
-- Check: views work together (expected: late 2.27, on-time 4.29,
-- not delivered 1.83 - same as Q4a in 04_analysis.sql)
-- ---------------------------------------------------------------------
select
o.delivery_status,
round(avg(r.review_score), 2) as avg_score
from fact_reviews r
join fact_orders o
on r.order_id = o.order_id
group by o.delivery_status;
