-- Module: Exploration File, Author: Abdullah Khalid, Date: 9th September 2026 (Wednesday), Valid-Order Definition: None

-- created a new database
create database Northcart_DB;

-- checking data after migration
SELECT COUNT(*) AS address_count
FROM addresses;

-- checking for null values in order_date
select * from orders
where orders.order_date is null;

SELECT order_date, COUNT(*)
FROM orders
GROUP BY order_date
HAVING COUNT(*) > 1;

-- task 1.4 stuck
with duplicate_emails_calculation as(
	select sum(email) as `duplicate_emails`
	from customers
	group by lower(trim(customers.email))
	having count(*) > 1
),
remaining_columns as (select count(customer_id) as `total_customers`, sum(email = '') as `missing_email`,
sum(phone = '') as `missing_phone`, sum(date_of_birth is null) as `missing_dob`,
sum(case
	when customers.date_of_birth > registration_date then 1
	else 0
end) as `dob_after_registration`
from customers)
select *
from remaining_columns
cross join duplicate_emails_calculation;

-- Creating a view for computed_total from module 1 so I can use it in later modules.
create view total_amount_calculation as
with subtotal_calculation as (
	select order_items.order_item_id as `order_item_id`, order_items.quantity as `quantity`, order_items.unit_price as `unit_price`,
order_items.discount_percent as `discount_percent`, order_items.subtotal as `subtotal`, (quantity * unit_price * (1 - discount_percent / 100)) as `computed_subtotal`,
order_items.tax_amount as `tax_amount`, order_items.total_amount as `total_amount`
	from order_items
),
total_calculation as (
	select subtotal_calculation.*, (subtotal_calculation.computed_subtotal + tax_amount) as `computed_total`
	from subtotal_calculation
)
select *
from total_amount_calculation;

-- Creating a view for valid order rule.
create or replace view valid_order_rule as
select orders.order_id as `valid_orders`, orders.customer_id as `customer_id`, orders.address_id as `address_id`, orders.order_date as `order_date`
from orders
where orders.status not in ('Cancelled', 'Returned');
select *
from valid_order_rule

drop view if exists valid_order_rule;

-- task 2.1 checking table records/rows after joins || select * from total_amount_calculation
select *
from categories
join products
on categories.category_id = products.category_id
left join order_items
on products.product_id = order_items.product_id;

-- task 2.5 checking rows after left join
select *
from orders
left join shipments
on orders.order_id = shipments.order_id;

-- task 3.4 checking whether revenue is being doubled because of joins
SELECT
    order_item_id,
    COUNT(*) AS count_rows
FROM total_amount_calculation
GROUP BY order_item_id
HAVING COUNT(*) > 1;

SELECT
    COUNT(*) AS joined_rows,
    COUNT(DISTINCT order_items.order_item_id) AS unique_items
FROM orders
JOIN order_items
    ON orders.order_id = order_items.order_id
JOIN total_amount_calculation
    ON total_amount_calculation.order_item_id = order_items.order_item_id;


-- task 4.1 join check

select *
from products
join categories
on products.category_id = categories.category_id;

-- task 5.1 Theory testing whether variance is explained by orders.discount_percent being applied at header level?

-- ========================================

select order_id, status, header_total, line_total, discount_percent,
       round(line_total * (1 - discount_percent/100), 2) as expected_header_after_discount,
       header_total - round(line_total * (1 - discount_percent/100), 2) as remaining_variance
from (
    select orders.order_id, orders.status, orders.total_amount as header_total,
           orders.discount_percent,
           round(sum(total_amount_calculation.computed_total),2) as line_total
    from orders
    left join order_items on orders.order_id = order_items.order_id
    left join total_amount_calculation on total_amount_calculation.order_item_id = order_items.order_item_id
    group by orders.order_id, orders.status, orders.total_amount, orders.discount_percent
) t
where abs(header_total - line_total) > 0.01


-- ===============================================================

select order_id, status, header_total, line_total, discount_percent,
       line_total - header_total as raw_diff,
       round(line_total * (1 - discount_percent/100), 2) as after_discount,
       round(line_total * (discount_percent/100), 2) as discount_amount_only
from (
    select orders.order_id, orders.status, orders.total_amount as header_total,
           orders.discount_percent,
           round(sum(total_amount_calculation.computed_total),2) as line_total
    from orders
    left join order_items on orders.order_id = order_items.order_id
    left join total_amount_calculation on total_amount_calculation.order_item_id = order_items.order_item_id
    where orders.order_id = 616
    group by orders.order_id, orders.status, orders.total_amount, orders.discount_percent
) t

-- Task 5.4 - checking duplicates

with duplicate_customers as (
	select customer_id, count(customersbackup_test.customer_id)
	from customersbackup_test
	group by customersbackup_test.customer_id
	having count(*) > 1
)
select *
from duplicate_customers;


-- task 6.2

select order_items.order_item_id
from suppliers
left join products
on suppliers.supplier_id = products.supplier_id
left join order_items
on products.product_id = order_items.product_id
left join total_amount_calculation
on order_items.order_item_id = total_amount_calculation.order_item_id
where supplier_name = 'Vertex Exports'


-- task 7.4 - getting the customer with the most orders

select orders.customer_id, count(*) as order_count
from orders
group by orders.customer_id
order by order_count desc
limit 1;








-- ===========================================================================================================================================




create or replace view total_amount_calculation as
with subtotal_calculation as (
	select order_items.order_item_id as `order_item_id`, order_items.quantity as `quantity`, order_items.unit_price as `unit_price`,
order_items.discount_percent as `discount_percent`, order_items.subtotal as `subtotal`, (quantity * unit_price * (1 - discount_percent / 100)) as `computed_subtotal`,
order_items.tax_amount as `tax_amount`, order_items.total_amount as `total_amount`, order_items.order_id as `order_id`, order_items.returned as `returned`
	from order_items
	inner join valid_order_rule on valid_order_rule.valid_orders = order_items.order_id
),
total_calculation as (
	select subtotal_calculation.*, (subtotal_calculation.computed_subtotal + tax_amount) as `computed_total`
	from subtotal_calculation
)

select *
from total_amount_calculation



select count(distinct customers.customer_id)
from valid_order_rule
join customers
on customers.customer_id = valid_order_rule.customer_id




select distinct(customers.country)
from customers


select count(distinct(order_item_id))
from order_items

select distinct(order_date)
from orders;

select *
from valid_order_rule

select count(distinct(order_item_id))
from total_amount_calculation


create or replace view WithoutReturns as (
	select valid_order_rule.valid_orders as `valid_orders`
	from valid_order_rule
	left join order_items on valid_order_rule.valid_orders = order_items.order_id
	where order_items.returned = 0
	group by valid_order_rule.valid_orders
)
select *
from WithoutReturns;


DROP VIEW IF EXISTS WithoutReturns;


SELECT 
    SUM(quantity * unit_price) AS expected_gross_revenue
FROM order_items
INNER JOIN valid_order_rule ON valid_order_rule.valid_orders = order_items.order_id
WHERE order_items.returned = 0;



select *
from categories







