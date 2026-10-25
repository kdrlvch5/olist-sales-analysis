-- =====================================================================
-- 04_analysis.sql
-- Olist E-commerce: business questions.
--
-- Rules used in every query:
--   * period: Jan 2017 - Aug 2018 (complete months only)
--   * valid orders: all statuses except 'canceled' and 'unavailable'
--   * revenue = sum of item price (shipping excluded)
--   * customer = customer_unique_id (a real person)
--   * late = delivered after the estimated date, compared by day
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q1. Orders, revenue and average order value (AOV) by month
-- Result: fast growth in 2017, peak in Nov 2017 (7,421 orders),
--         plateau in 2018; AOV stable at about 125-153
-- ---------------------------------------------------------------------
with monthly_rev as (
select
date_trunc('month', o.order_purchase_timestamp)::date as month,
count(distinct o.order_id) as unique_orders,
round(sum(i.price), 2) as total_revenue
from orders o
join order_items i
on o.order_id = i.order_id
where o.order_status not in ('canceled', 'unavailable')
and o.order_purchase_timestamp >= '2017-01-01' and o.order_purchase_timestamp < '2018-09-01'
group by month
)
select
month, unique_orders, total_revenue,
round(total_revenue / nullif(unique_orders, 0), 0) as avg_order_revenue
from monthly_rev
order by month asc;


-- ---------------------------------------------------------------------
-- Q2a. Revenue by product category
-- LEFT JOIN keeps products without a category ('unknown': ~1.3% of revenue)
-- Result: health_beauty 1.25M, watches_gifts 1.19M, bed_bath_table 1.04M
-- ---------------------------------------------------------------------
select
coalesce(ct.product_category_name_english, 'unknown') as category,
count(distinct o.order_id) as unique_orders,
sum(i.price) as total_revenue
from orders o
join order_items i
on i.order_id = o.order_id
join products p
on p.product_id = i.product_id
left join category_translation ct
on p.product_category_name = ct.product_category_name
where o.order_status not in ('canceled', 'unavailable')
and o.order_purchase_timestamp >= '2017-01-01' and o.order_purchase_timestamp < '2018-09-01'
group by category
order by total_revenue desc;


-- ---------------------------------------------------------------------
-- Q2b. Revenue by customer state
-- Result: SP ~38% of revenue; SP + RJ + MG ~63%
-- ---------------------------------------------------------------------
select
c.customer_state as state,
count(distinct o.order_id) as unique_orders,
count(distinct c.customer_unique_id) as unique_customers,
sum(i.price) as total_revenue
from orders o
join order_items i
on o.order_id = i.order_id
join customers c
on o.customer_id = c.customer_id
where o.order_status not in ('canceled', 'unavailable')
and o.order_purchase_timestamp >= '2017-01-01' and o.order_purchase_timestamp < '2018-09-01'
group by state
order by total_revenue desc;


-- ---------------------------------------------------------------------
-- Q3a. Late deliveries: overall
-- Result: 6,531 of 96,203 delivered orders were late (6.79%)
-- ---------------------------------------------------------------------
select
count(order_id) as delivered_orders,
sum(case when order_delivered_customer_date::date > order_estimated_delivery_date::date then 1 else 0 end) as late_orders,
round(100.0 * sum(case when order_delivered_customer_date::date > order_estimated_delivery_date::date then 1 else 0 end)
/ count(order_id), 2) as late_pct
from orders
where order_status = 'delivered' and order_delivered_customer_date is not null
and order_purchase_timestamp >= '2017-01-01' and order_purchase_timestamp < '2018-09-01';


-- ---------------------------------------------------------------------
-- Q3b. Late deliveries by customer state (states with 500+ orders)
-- Result: worst MA 17.5%, CE 13.8%, BA 12.2%, RJ 12.1%; best PR 4.1%
-- ---------------------------------------------------------------------
select
c.customer_state as state,
count(o.order_id) as delivered_orders,
sum(case when o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date then 1 else 0 end) as late_orders,
round(100.0 * sum(case when o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date then 1 else 0 end)
/ count(o.order_id), 2) as late_pct
from orders o
join customers c
on o.customer_id = c.customer_id
where o.order_status = 'delivered' and o.order_delivered_customer_date is not null
and o.order_purchase_timestamp >= '2017-01-01' and o.order_purchase_timestamp < '2018-09-01'
group by c.customer_state
having count(o.order_id) > 500
order by late_pct desc;


-- ---------------------------------------------------------------------
-- Q3c. Late deliveries by month
-- Result: waves in Nov 2017 (12.4%), Feb 2018 (14.1%), Mar 2018 (19.0%)
-- ---------------------------------------------------------------------
select
date_trunc('month', order_purchase_timestamp)::date as month,
count(order_id) as delivered_orders,
sum(case when order_delivered_customer_date::date > order_estimated_delivery_date::date then 1 else 0 end) as late_orders,
round(100.0 * sum(case when order_delivered_customer_date::date > order_estimated_delivery_date::date then 1 else 0 end)
/ count(order_id), 2) as late_pct
from orders
where order_status = 'delivered' and order_delivered_customer_date is not null
and order_purchase_timestamp >= '2017-01-01' and order_purchase_timestamp < '2018-09-01'
group by month
order by month asc;


-- ---------------------------------------------------------------------
-- Q4a. Review scores: late vs on-time orders
-- Result: late 2.27 avg / 62.4% low scores; on-time 4.29 / 9.3%
-- ---------------------------------------------------------------------
select
case
    when o.order_delivered_customer_date::date <= o.order_estimated_delivery_date::date
        then 'on-time' else 'late' end as delivery,
count(r.review_id) as total_reviews,
round(avg(r.review_score), 2) as avg_score,
round(100.0 * sum(case when r.review_score = 1 or r.review_score = 2 then 1 else 0 end)
/ count(r.review_id), 2) as pct_low_score
from orders o
join order_reviews r
on o.order_id = r.order_id
where o.order_status = 'delivered' and o.order_delivered_customer_date is not null
and o.order_purchase_timestamp >= '2017-01-01' and o.order_purchase_timestamp < '2018-09-01'
group by delivery;


-- ---------------------------------------------------------------------
-- Q4b. Review scores by number of days late
-- Result: 4.29 (on time) -> 3.29 (1-3 days) -> 2.10 (4-7) -> 1.70 (8+)
-- ---------------------------------------------------------------------
with delivery_range as (
select
o.order_id,
r.review_score as score,
o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date as delay_days
from orders o
join order_reviews r
on o.order_id = r.order_id
where o.order_status = 'delivered' and o.order_delivered_customer_date is not null
and o.order_purchase_timestamp >= '2017-01-01' and o.order_purchase_timestamp < '2018-09-01'
)
select
case when delay_days <= 0 then '1. on time'
     when delay_days >= 1 and delay_days <= 3 then '2. 1-3 days'
     when delay_days >= 4 and delay_days <= 7 then '3. 4-7 days'
     when delay_days >= 8 then '4. 8+ days' end as days_late,
count(score) as total_reviews,
round(avg(score), 2) as avg_score,
round(100.0 * sum(case when score = 1 or score = 2 then 1 else 0 end)
/ count(score), 2) as pct_low_score
from delivery_range
group by days_late
order by days_late asc;


-- ---------------------------------------------------------------------
-- Q5. Customers by number of orders
-- Result: 96.96% of customers bought only once
-- ---------------------------------------------------------------------
with order_p_customers as (
select
c.customer_unique_id as customer,
count(distinct o.order_id) as orders_count
from orders o
join customers c
on o.customer_id = c.customer_id
where o.order_status not in ('canceled', 'unavailable')
and o.order_purchase_timestamp >= '2017-01-01' and o.order_purchase_timestamp < '2018-09-01'
group by customer
)
select
orders_count,
count(*) as customers,
round(100.0 * count(*) / sum(count(*)) over (), 2) as pct_customers
from order_p_customers
group by orders_count
order by orders_count;


-- ---------------------------------------------------------------------
-- Bonus. Do customers whose FIRST order was late come back less often?
-- Result: late first order 2.51% returned vs on-time 3.06%
--         (two-proportion z-test p ~ 0.01, but a small absolute effect)
-- ---------------------------------------------------------------------
with cte1 as (
select
c.customer_unique_id as customer,
o.order_id,
o.order_purchase_timestamp,
o.order_delivered_customer_date,
o.order_estimated_delivery_date,
o.order_status,
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
case when order_delivered_customer_date::date <= order_estimated_delivery_date::date
     then 'on-time' else 'late' end as first_order_delivery,
count(customer) as total_customers,
sum(case when total_orders > 1 then 1 else 0 end) as returned_customers,
round(100.0 * sum(case when total_orders > 1 then 1 else 0 end) / count(*), 2) as pct_returned
from cte1
where order_number = 1 and order_status = 'delivered' and order_delivered_customer_date is not null
group by first_order_delivery;
