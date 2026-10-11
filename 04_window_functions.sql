-- Module: Module 4 - Window Functions & Segmentation, Author: Abdullah Khalid, Date: 11th September 2026 (Friday), Valid-Order Definition: orders.status not in ('Cancelled', 'Returned')


-- TASK 4.1: Top 3 products per category by revenue

with ranked as (
	select categories.category as `category`, dense_rank() over (partition by category order by sum(total_amount_calculation.computed_total) desc) as `rnk`,
	products.product_id as `product_id`, products.product_name as `product_name`, sum(order_items.quantity) as `units`, sum(total_amount_calculation.computed_total) as `revenue`
	from products
	join categories
	on products.category_id = categories.category_id
	join order_items
	on products.product_id = order_items.product_id
	join total_amount_calculation
	on total_amount_calculation.order_item_id = order_items.order_item_id
	join valid_order_rule
	on valid_order_rule.valid_orders = order_items.order_id
	group by categories.category, products.product_id
)
select category, rnk, product_id, product_name, units, round(revenue, 2) as `revenue`
from ranked
where rnk <= 3
order by category, rnk;


-- TASK 4.2: RFM scoring and segments:

-- TASK 4.2a: one row per customer with ≥1 valid order

with customer_segregation as (
	select customers.customer_id as `customer_id`, datediff((select max(order_date) from orders), max(orders.order_date)) as `recency_days`,
	count(distinct orders.order_id) as `frequency`, sum(total_amount_calculation.computed_total) as `monetary`
	from customers
	join valid_order_rule
	on valid_order_rule.customer_id = customers.customer_id
	join orders
	on valid_order_rule.valid_orders = orders.order_id
	join order_items
	on orders.order_id = order_items.order_id
	join total_amount_calculation
	on total_amount_calculation.order_item_id = order_items.order_item_id
	group by customers.customer_id
),
rfm_calculation as (
	select customer_id, recency_days, frequency, monetary,
	ntile(5) over (order by recency_days desc) as `r_score`,
	ntile(5) over (order by frequency asc) as `f_score`,
	ntile(5) over (order by monetary asc) as `m_score`
	from customer_segregation
),
segment_calculation as (
	select customer_id, recency_days, frequency, monetary, r_score, f_score, m_score,
	case 
		when r_score >= 4 and f_score >= 4 and m_score >= 4 then 'Champion'
		when r_score >= 3 and f_score >= 3 then 'Loyal'
		when r_score >= 4 and f_score <= 2 then 'New/Promising'
		when r_score <= 2 and f_score >= 3 then 'At Risk'
		when r_score <= 2 and f_score <= 2 then 'Lost'
		else 'Needs Attention'
	end as `Segment`
	from rfm_calculation
)
select customer_id, recency_days, frequency, monetary, r_score, f_score, m_score, Segment
from segment_calculation;

-- TASK 4.2b: segment summary

with customer_segregation as (
	select customers.customer_id as `customer_id`, datediff((select max(order_date) from orders), max(orders.order_date)) as `recency_days`,
	count(distinct orders.order_id) as `frequency`, sum(total_amount_calculation.computed_total) as `monetary`
	from customers
	join valid_order_rule
	on valid_order_rule.customer_id = customers.customer_id
	join orders
	on valid_order_rule.valid_orders = orders.order_id
	join order_items
	on orders.order_id = order_items.order_id
	join total_amount_calculation
	on total_amount_calculation.order_item_id = order_items.order_item_id
	group by customers.customer_id
),
rfm_calculation as (
	select customer_id, recency_days, frequency, monetary,
	ntile(5) over (order by recency_days desc) as `r_score`,
	ntile(5) over (order by frequency asc) as `f_score`,
	ntile(5) over (order by monetary asc) as `m_score`
	from customer_segregation
),
segment_calculation as (
	select customer_id, recency_days, frequency, monetary, r_score, f_score, m_score,
	case 
		when r_score >= 4 and f_score >= 4 and m_score >= 4 then 'Champion'
		when r_score >= 3 and f_score >= 3 then 'Loyal'
		when r_score >= 4 and f_score <= 2 then 'New/Promising'
		when r_score <= 2 and f_score >= 3 then 'At Risk'
		when r_score <= 2 and f_score <= 2 then 'Lost'
		else 'Needs Attention'
	end as `Segment`
	from rfm_calculation
),
segment_summary as (
	select Segment, count(customer_id) as `customers`, count(customer_id) / (select count(*) from segment_calculation) * 100 as `pct_of_customers`,
	sum(monetary) as `total_monetary`, avg(monetary) as `avg_monetary`
	from segment_calculation
	group by Segment
)
select Segment, customers, round(pct_of_customers,1) as `pct_of_customers`, round(total_monetary,2) as `total_monetary`, round(avg_monetary,2) as `avg_monetary`
from segment_summary;


-- TASK 4.3: Customer order timeline

with order_totals as (
    select order_items.order_id as order_id, sum(total_amount_calculation.computed_total) as order_total
    from order_items
    join total_amount_calculation
    on total_amount_calculation.order_item_id = order_items.order_item_id
    group by order_items.order_id
),
valid_customer_orders as (
    select customers.customer_id as `customer_id`, orders.order_id as `order_id`, orders.order_date as `order_date`,
    row_number() over (partition by customers.customer_id order by orders.order_date) as `order_seq`,
    order_totals.order_total as `total_amount`,
    sum(order_totals.order_total) over (partition by customers.customer_id order by orders.order_date rows between unbounded preceding and current row) as running_spend,
    datediff(orders.order_date, lag(orders.order_date) over (partition by customers.customer_id order by orders.order_date)) as `days_since_prev_order`,
    sum(order_totals.order_total) over (partition by customers.customer_id) as `lifetime_spending`
    from customers
    join valid_order_rule
    on valid_order_rule.customer_id = customers.customer_id
    join orders
    on valid_order_rule.valid_orders = orders.order_id
    join order_totals
    on order_totals.order_id = orders.order_id
),
lifetime_spending_pct_calculation as (
    select customer_id, order_id, order_date, order_seq, total_amount, running_spend, days_since_prev_order,
    total_amount / lifetime_spending * 100 as `pct_of_lifetime_spend`
    from valid_customer_orders
)
select customer_id, order_id, order_date, order_seq, total_amount, running_spend, days_since_prev_order, round(pct_of_lifetime_spend,2) as `pct_of_lifetime_spend`
from lifetime_spending_pct_calculation
order by customer_id, order_seq;


-- TASK 4.4: Does first purchase category predict repeat buying?

with customer_order_counts as (
	select orders.customer_id as customer_id,
	count(distinct orders.order_id) as total_orders
	from orders
	join valid_order_rule
	on valid_order_rule.valid_orders = orders.order_id
	group by orders.customer_id
),
purchase_group as (
	select categories.category_group as `first_purchase_group`, customers.customer_id,
	row_number() over (partition by customers.customer_id order by orders.order_date, orders.order_id) as `RowNumber`
	from customers
	join orders
	on customers.customer_id = orders.customer_id
	join order_items
	on orders.order_id = order_items.order_id
	join products
	on order_items.product_id = products.product_id
	join categories
	on products.category_id = categories.category_id
	join valid_order_rule
	on valid_order_rule.valid_orders = orders.order_id
),
first_purchase as (
	select purchase_group.first_purchase_group, purchase_group.customer_id, customer_order_counts.total_orders
	from purchase_group
	join customer_order_counts
	on customer_order_counts.customer_id = purchase_group.customer_id
	where purchase_group.RowNumber = 1
)
select first_purchase_group, count(customer_id) as customers, count(case when total_orders > 1 then 1 end) as repeat_customers,
round(count(case when total_orders > 1 then 1 end) / count(customer_id) * 100, 1) as repeat_rate_pct
from first_purchase
group by first_purchase_group
order by repeat_rate_pct desc;



