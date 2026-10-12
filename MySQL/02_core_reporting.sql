-- Module: Module 2 - Core Reporting, Author: Abdullah Khalid, Date: 10th September 2026 (Thursday), Valid-Order Definition: orders.status not in ('Cancelled', 'Returned')


-- TASK 2.1: Revenue by category

select categories.category_group as `category_group`, categories.category as `category`, count(distinct order_items.order_id) as `orders`,
sum(order_items.quantity) as `units`, round(sum(total_amount_calculation.computed_total),2) as `gross_revenue`,
round(sum(total_amount_calculation.computed_total) / sum(order_items.quantity),2) as `revenue_per_unit`
from categories
join products
on categories.category_id = products.category_id
join order_items
on products.product_id = order_items.product_id
join valid_order_rule
on valid_order_rule.valid_orders = order_items.order_id
join total_amount_calculation
on total_amount_calculation.order_item_id = order_items.order_item_id
where order_items.returned = 0
group by category_group, category
order by `gross_revenue` desc;

-- Second query of task 2.1

select round(sum(order_items.total_amount),2) as `grand_total_row`
from order_items
join valid_order_rule
on valid_order_rule.valid_orders = order_items.order_id
where order_items.returned = 0;


-- TASK 2.2: Top 10 customers by lifetime spend

select customers.customer_id as `customer_id`, concat(customers.first_name, ' ', customers.last_name) as `customer_name`, customers.country as `country`,
count(orders.order_id) as `orders`, round(sum(orders.total_amount),2) as `lifetime_spend`, round(avg(orders.total_amount),2) as `avg_order_value`,
min(orders.order_date) as `first_order`, max(orders.order_date) as `last_order`
from customers
join orders
on customers.customer_id = orders.customer_id
join valid_order_rule
on valid_order_rule.valid_orders = orders.order_id
group by customers.customer_id
order by lifetime_spend desc
limit 10;


-- TASK 2.3: Order status funnel

select orders.status as `status`, count(distinct orders.order_id) as `orders`, round(sum(total_amount_calculation.computed_total), 2) as `revenue`,
round((count(distinct orders.order_id) / sum(count(distinct orders.order_id)) over ()) * 100, 2) as `pct_of_orders`
from orders
join order_items
on orders.order_id = order_items.order_id
join total_amount_calculation
on total_amount_calculation.order_item_id = order_items.order_item_id
group by orders.status
order by orders desc;


-- TASK 2.4: Registered but never ordered

select customers.customer_id as `customer_id`, customers.first_name as `first_name`, customers.last_name as `last_name`, customers.email as `email`,
customers.registration_date as `registration_date`, datediff((select max(order_date) from orders), customers.registration_date) as `days_since_registration`
from customers
left join orders
on customers.customer_id = orders.customer_id
where orders.customer_id is null
order by registration_date;


-- TASK 2.5: Shipping method economics

select orders.shipping_method as `shipping_method`, count(orders.order_id) as `orders`, round(avg(orders.total_amount),2) as `avg_order_value`,
round(avg(orders.discount_percent),2) as `avg_discount_pct`, round(avg(shipments.shipping_cost),2) as `avg_shipping_cost`,
round(count(orders.coupon_code) / count(orders.order_id) * 100,2) as `pct_with_coupon`
from orders
join valid_order_rule
on valid_order_rule.valid_orders = orders.order_id
left join shipments
on orders.order_id = shipments.order_id
group by orders.shipping_method;
