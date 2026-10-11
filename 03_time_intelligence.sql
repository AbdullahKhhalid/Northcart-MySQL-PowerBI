-- Module: Module 3 - Time Intelligence, Author: Abdullah Khalid, Date: 11th September 2026 (Friday), Valid-Order Definition: orders.status not in ('Cancelled', 'Returned')


-- TASK 3.1: Monthly revenue with MoM growth

with monthly_revenue as(
	select distinct(date_format(orders.order_date, '%Y-%m')) as `ym`, count(distinct orders.order_id) as `orders`,
	sum(total_amount_calculation.computed_total) as `revenue`
	from orders
	inner join order_items
	on orders.order_id = order_items.order_id
	join total_amount_calculation
	on total_amount_calculation.order_item_id = order_items.order_item_id
	join valid_order_rule
	on valid_order_rule.valid_orders = orders.order_id
	group by ym
),
mom_growth_calculation as (
	select ym, orders, revenue, lag(revenue) over (order by ym) as `prev_month_revenue`
	from monthly_revenue
)
select ym, orders, round(revenue,2) as `revenue`, prev_month_revenue, round((revenue - prev_month_revenue) / nullif(prev_month_revenue, 0) * 100,2) as `mom_growth_pct`
from mom_growth_calculation
order by ym desc;


-- TASK 3.2: Rolling 3-month average and cumulative revenue

with monthly_revenue as (
	select distinct(date_format(orders.order_date, '%Y-%m')) as `ym`, sum(total_amount_calculation.computed_total) as `revenue`
	from orders
	inner join order_items
	on orders.order_id = order_items.order_id
	join total_amount_calculation
	on total_amount_calculation.order_item_id = order_items.order_item_id
	join valid_order_rule
	on valid_order_rule.valid_orders = orders.order_id
	group by ym
)
select ym, round(revenue,2) as `revenue`, round(avg(revenue) over (order by ym rows between 2 preceding and current row), 2) as `rolling_3m_avg`,
round(sum(revenue) over (order by ym), 2) as `cumulative_revenue`
from monthly_revenue
order by ym desc;


-- TASK 3.3: Registration cohort retention

with cohort_calculation as (
	select customers.customer_id, date_format(customers.registration_date, '%Y-%m') as `cohort_month`,
	timestampdiff(month, date_format(customers.registration_date, '%Y-%m-01'),date_format(orders.order_date, '%Y-%m-01')) as `month_offset`
	from customers
	left join orders
	on customers.customer_id = orders.customer_id
	and orders.status not in ('Cancelled','Returned')
),
cohort_count as (
	select cohort_month, count(distinct(cohort_calculation.customer_id)) as `cohort_size`, count(distinct case when month_offset = 0 then customer_id end) as m0,
	count(distinct case when month_offset = 1 then customer_id end) as m1, count(distinct case when month_offset = 2 then customer_id end) as m2,
	count(distinct case when month_offset = 3 then customer_id end) as m3
	from cohort_calculation
	group by cohort_month
)
select cohort_month, cohort_size, m0, m1, m2, m3, round(m1/nullif(cohort_size, 0) * 100, 1) as `m1_retention_pct`
from cohort_count
order by cohort_month desc;


-- TASK 3.4: Day-of-week pattern

select dayname(orders.order_date) as `weekday`, count(distinct orders.order_id) as `orders`, round(sum(computed_total), 2) as `revenue`,
round(sum(total_amount_calculation.computed_total) / count(distinct orders.order_id), 2) as `avg_order_value`
from orders
join order_items
on orders.order_id = order_items.order_id
join total_amount_calculation
on total_amount_calculation.order_item_id = order_items.order_item_id
join valid_order_rule
on valid_order_rule.valid_orders = orders.order_id
group by dayname(orders.order_date)
order by field(weekday, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday');
