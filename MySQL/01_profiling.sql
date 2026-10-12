-- Module: Module 1 - Profiling & Data Dictionary, Author: Abdullah Khalid, Date: 9th September 2026 (Wednesday), Valid-Order Definition: orders.status not in ('Cancelled', 'Returned')


-- TASK 1.1: Row Counts

select 'customers' as `table_name`, count(customer_id) as `row_count`
from customers
union all
select 'addresses', count(address_id)
from addresses
union all
select 'categories', count(category_id)
from categories
union all
select 'customersbackup_test', count(customer_id)
from customersbackup_test
union all
select 'customersbackupno2_test', count(customer_id)
from customersbackupno2_test
union all
select 'order_items', count(order_item_id)
from order_items
union all
select 'orders', count(order_id)
from orders
union all
select 'payments', count(payment_id)
from payments
union all
select 'products', count(product_id)
from products
union all
select 'reviews', count(review_id)
from reviews
union all
select 'shipments', count(shipment_id)
from shipments
union all
select 'suppliers', count(supplier_id)
from suppliers
order by `row_count` desc;


-- TASK 1.2: Date coverage

select 'orders.order_date' as `field`, min(orders.order_date) as `min_date`, max(orders.order_date) as `max_date`, count(orders.order_date) as `populated_rows`
from orders
union all
select 'customers.registration_date', min(customers.registration_date), max(customers.registration_date), count(customers.registration_date)
from customers
union all
select 'reviews.review_date', min(reviews.review_date), max(reviews.review_date), count(reviews.review_date)
from reviews
union all
select 'payments.payment_date', min(payments.payment_date), max(payments.payment_date), count(payments.payment_date)
from payments
union all
select 'shipments.shipped_date', min(shipments.shipped_date), max(shipments.shipped_date), count(shipments.shipped_date)
from shipments
union all
select 'products.launch_date', min(products.launch_date), max(products.launch_date), count(products.launch_date)
from products;


-- TASK 1.3: Categorical value inventory

select 'orders' as `table_name`, 'status' as `column_name`, orders.status as `value`, count(orders.status) as `rows`
from orders
group by orders.status
union all
select 'payments', 'status', payments.status, count(payments.status)
from payments
group by payments.status
union all
select 'payments', 'payment_method', payments.payment_method, count(payments.payment_method)
from payments
group by payment_method
union all
select 'shipments', 'status', shipments.status, count(shipments.status)
from shipments
group by shipments.status
union all
select 'addresses', 'address_type', addresses.address_type, count(addresses.address_type)
from addresses
group by addresses.address_type
union all
select 'orders', 'shipping_method', orders.shipping_method, count(orders.shipping_method)
from orders
group by orders.shipping_method
order by `table_name`, `column_name`, `rows` desc;


-- TASK 1.4: Customer table health

with duplicate_groups as (
    select lower(trim(email)) as email, count(*) - 1 as extra_rows
    from customers
    where email is not null and trim(email) <> ''
    group by lower(trim(email))
    having count(*) > 1
),
duplicate_emails_calculation as (
    select coalesce(sum(extra_rows), 0) as duplicate_emails
    from duplicate_groups
),
remaining_columns as (
	select count(customer_id) as `total_customers`, sum(email is null or trim(email) = '') as `missing_email`,
	sum(phone is null or trim(phone) = '') as `missing_phone`, sum(date_of_birth is null) as `missing_dob`,
	sum(case
		when customers.date_of_birth > registration_date then 1
		else 0
		end) as `dob_after_registration`
	from customers
)
select remaining_columns.total_customers, remaining_columns.missing_email, remaining_columns.missing_phone, remaining_columns.missing_dob,
duplicate_emails_calculation.duplicate_emails, remaining_columns.dob_after_registration
from remaining_columns
cross join duplicate_emails_calculation;


-- TASK 1.5: Decode the money columns

with subtotal_calculation as (
	select order_items.order_item_id as `order_item_id`, order_items.quantity as `quantity`, order_items.unit_price as `unit_price`,
	order_items.discount_percent as `discount_percent`, order_items.subtotal as `subtotal`, (quantity * unit_price * (1 - discount_percent / 100)) as `computed_subtotal`,
	order_items.tax_amount as `tax_amount`, order_items.total_amount as `total_amount`
	from order_items
),
total_calculation as (
	select order_item_id, quantity, unit_price, discount_percent, subtotal, computed_subtotal, tax_amount, total_amount,
	(subtotal_calculation.computed_subtotal + tax_amount) as `computed_total`
	from subtotal_calculation
)
select order_item_id, quantity, unit_price, discount_percent, subtotal, computed_subtotal, tax_amount, total_amount, computed_total,
case 
	when abs(subtotal - computed_subtotal) <= 0.01 then 1
	else 0
end as `subtotal_ok`,
case
	when abs(total_amount - computed_total) <= 0.01 then 1
	else 0
end as `total_ok`
from total_calculation
limit 10;

-- second query of task 1.5
select
    sum(case when abs(subtotal - computed_subtotal) > 0.01 then 1 else 0 end) as subtotal_mismatches,
    sum(case when abs(total_amount - computed_total) > 0.01 then 1 else 0 end) as total_mismatches
from total_calculation;
