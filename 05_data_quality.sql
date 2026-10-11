-- Module: Module 5 - Data Quality & Reconciliation, Author: Abdullah Khalid, Date: 12th September 2026 (Saturday), Valid-Order Definition: orders.status not in ('Cancelled', 'Returned')


-- TASK 5.1: Order header vs line items

with header_and_line_total as (
	select orders.order_id as `order_id`, orders.status as `status`, orders.total_amount as `header_total`,
	sum(total_amount_calculation.computed_total) as `line_total`, count(order_items.order_item_id) as `line_items`
	from orders
	left join order_items
	on orders.order_id = order_items.order_id
	left join total_amount_calculation
	on total_amount_calculation.order_item_id = order_items.order_item_id
	group by orders.order_id, orders.status, orders.total_amount
),
variance_calculation as (
	select order_id, status, header_total, line_total, header_total - line_total as `variance`, line_items
	from header_and_line_total
)
select order_id, status, header_total, round(line_total,2) as `line_total`, variance, line_items
from variance_calculation
where abs(header_total - line_total) > 0.01 or line_total is null
order by abs(variance) desc;


-- TASK 5.2: Payment reconciliation

with order_totals as (
	select orders.order_id, orders.status as `order_status`,
	sum(total_amount_calculation.computed_total) as `total_amount`
	from orders
	join valid_order_rule
	on valid_order_rule.valid_orders = orders.order_id
	join order_items
	on orders.order_id = order_items.order_id
	join total_amount_calculation
	on order_items.order_item_id = total_amount_calculation.order_item_id
	group by orders.order_id, orders.status
),
payment_totals as (
	select order_id,
	sum(case when status = 'Completed' then amount else 0 end) as `paid_amount`,
	sum(case when refunded = 1 then refund_amount else 0 end) as `refunded_amount`,
	count(payment_id) as `payment_rows`
	from payments
	group by order_id
),
combined as (
	select order_totals.order_id, order_totals.order_status, order_totals.total_amount,
	coalesce(payment_totals.paid_amount, 0) as `paid_amount`,
	coalesce(payment_totals.refunded_amount, 0) as `refunded_amount`,
	coalesce(payment_totals.payment_rows, 0) as `payment_rows`
	from order_totals
	left join payment_totals
	on order_totals.order_id = payment_totals.order_id
)
select order_id, order_status, total_amount, paid_amount, refunded_amount, payment_rows,
case
	when paid_amount = 0 then 'NO_PAYMENT'
	when paid_amount < total_amount then 'UNDERPAID'
	when paid_amount > total_amount then 'OVERPAID'
end as `recon_flag`
from combined
where paid_amount != total_amount
order by recon_flag, order_id;


-- TASK 5.3: Referential & logical integrity suite

select 'order_items.product_id -> products' as `check_name`, count(order_items.order_item_id) as `violations`
from order_items
left join products
on order_items.product_id = products.product_id
where products.product_id is null
union all
select 'orders.customer_id -> customers', count(orders.order_id)
from orders
left join customers
on orders.customer_id = customers.customer_id
where customers.customer_id is null
union all
select 'orders.address_id -> addresses', count(orders.order_id)
from orders
left join addresses
on orders.address_id = addresses.address_id
where addresses.address_id is null
union all
select 'order address belongs to a different customer', count(orders.order_id)
from orders
join addresses
on orders.address_id = addresses.address_id
where orders.customer_id != addresses.customer_id
union all
select 'reviews.order_id not owned by reviews.customer_id', count(reviews.review_id)
from reviews
join orders
on reviews.order_id = orders.order_id
where reviews.customer_id != orders.customer_id
union all
select 'reviews.product_id not in the reviewed order', count(reviews.review_id)
from reviews
left join order_items
on reviews.order_id = order_items.order_id
and reviews.product_id = order_items.product_id
where order_items.order_item_id is null
union all
select 'shipments delivered before shipped', count(shipments.shipment_id)
from shipments
where shipments.actual_delivery < shipments.shipped_date
union all
select 'payments dated before order_date', count(payments.payment_id)
from payments
join orders
on payments.order_id = orders.order_id
where payments.payment_date < orders.order_date
union all
select 'products priced below cost', count(products.product_id)
from products
where products.price < products.cost
union all
select 'products with stock_quantity < 0', count(products.product_id)
from products
where products.stock_quantity < 0
union all
select 'orders with total_amount <= 0', count(orders.order_id)
from orders
where orders.total_amount <= 0
union all
select 'valid orders with no shipment record', count(orders.order_id)
from orders
left join shipments
on orders.order_id = shipments.order_id
where orders.status not in ('Cancelled', 'Returned')
and shipments.shipment_id is null;


-- TASK 5.4: Customer backup reconciliation

with backup_rows as (
    select customersbackup_test.TestingID, customersbackup_test.customer_id,
           customersbackup_test.first_name, customersbackup_test.last_name,
           customersbackup_test.email, customersbackup_test.phone,
           customersbackup_test.date_of_birth, customersbackup_test.gender,
           customersbackup_test.city, customersbackup_test.state,
           customersbackup_test.country, customersbackup_test.registration_date
    from customersbackup_test
),
missing_in_backup as (
    select customers.customer_id, 'MISSING_IN_BACKUP' as diff_type, null as changed_columns
    from customers
    left join backup_rows
        on customers.customer_id = backup_rows.customer_id
    where backup_rows.customer_id is null
),
extra_in_backup as (
    select backup_rows.customer_id, 'EXTRA_IN_BACKUP' as diff_type, null as changed_columns
    from backup_rows
    left join customers
        on backup_rows.customer_id = customers.customer_id
    where customers.customer_id is null
),
changed_customers as (
    select customers.customer_id, 'CHANGED' as diff_type,
           concat(
               case when not (customers.first_name <=> backup_rows.first_name) then 'first_name,' else '' end,
               case when not (customers.last_name <=> backup_rows.last_name) then 'last_name,' else '' end,
               case when not (customers.email <=> backup_rows.email) then 'email,' else '' end,
               case when not (customers.phone <=> backup_rows.phone) then 'phone,' else '' end,
               case when not (customers.date_of_birth <=> backup_rows.date_of_birth) then 'date_of_birth,' else '' end,
               case when not (customers.gender <=> backup_rows.gender) then 'gender,' else '' end,
               case when not (customers.city <=> backup_rows.city) then 'city,' else '' end,
               case when not (customers.state <=> backup_rows.state) then 'state,' else '' end,
               case when not (customers.country <=> backup_rows.country) then 'country,' else '' end,
               case when not (customers.registration_date <=> backup_rows.registration_date) then 'registration_date' else '' end
           ) as changed_columns
    from customers
    join backup_rows
        on customers.customer_id = backup_rows.customer_id
    where not (
        customers.first_name <=> backup_rows.first_name
        and customers.last_name <=> backup_rows.last_name
        and customers.email <=> backup_rows.email
        and customers.phone <=> backup_rows.phone
        and customers.date_of_birth <=> backup_rows.date_of_birth
        and customers.gender <=> backup_rows.gender
        and customers.city <=> backup_rows.city
        and customers.state <=> backup_rows.state
        and customers.country <=> backup_rows.country
        and customers.registration_date <=> backup_rows.registration_date
    )
)
select customer_id, diff_type, changed_columns from missing_in_backup
union all
select customer_id, diff_type, changed_columns from extra_in_backup
union all
select customer_id, diff_type, changed_columns from changed_customers
order by diff_type, customer_id;


-- Customers with second backup table 'customersbackupno2_test'

with backup_rows as (
    select customersbackupno2_test.PersonID, customersbackupno2_test.customer_id,
           customersbackupno2_test.first_name, customersbackupno2_test.last_name,
           customersbackupno2_test.email, customersbackupno2_test.phone,
           customersbackupno2_test.date_of_birth, customersbackupno2_test.gender,
           customersbackupno2_test.city, customersbackupno2_test.state,
           customersbackupno2_test.country, customersbackupno2_test.registration_date
    from customersbackupno2_test
),
missing_in_backup as (
    select customers.customer_id, 'MISSING_IN_BACKUP' as diff_type, null as changed_columns
    from customers
    left join backup_rows
        on customers.customer_id = backup_rows.customer_id
    where backup_rows.customer_id is null
),
extra_in_backup as (
    select backup_rows.customer_id, 'EXTRA_IN_BACKUP' as diff_type, null as changed_columns
    from backup_rows
    left join customers
        on backup_rows.customer_id = customers.customer_id
    where customers.customer_id is null
),
changed_customers as (
    select customers.customer_id, 'CHANGED' as diff_type,
           concat(
               case when not (customers.first_name <=> backup_rows.first_name) then 'first_name,' else '' end,
               case when not (customers.last_name <=> backup_rows.last_name) then 'last_name,' else '' end,
               case when not (customers.email <=> backup_rows.email) then 'email,' else '' end,
               case when not (customers.phone <=> backup_rows.phone) then 'phone,' else '' end,
               case when not (customers.date_of_birth <=> backup_rows.date_of_birth) then 'date_of_birth,' else '' end,
               case when not (customers.gender <=> backup_rows.gender) then 'gender,' else '' end,
               case when not (customers.city <=> backup_rows.city) then 'city,' else '' end,
               case when not (customers.state <=> backup_rows.state) then 'state,' else '' end,
               case when not (customers.country <=> backup_rows.country) then 'country,' else '' end,
               case when not (customers.registration_date <=> backup_rows.registration_date) then 'registration_date' else '' end
           ) as changed_columns
    from customers
    join backup_rows
        on customers.customer_id = backup_rows.customer_id
    where not (
        customers.first_name <=> backup_rows.first_name
        and customers.last_name <=> backup_rows.last_name
        and customers.email <=> backup_rows.email
        and customers.phone <=> backup_rows.phone
        and customers.date_of_birth <=> backup_rows.date_of_birth
        and customers.gender <=> backup_rows.gender
        and customers.city <=> backup_rows.city
        and customers.state <=> backup_rows.state
        and customers.country <=> backup_rows.country
        and customers.registration_date <=> backup_rows.registration_date
    )
)
select customer_id, diff_type, changed_columns from missing_in_backup
union all
select customer_id, diff_type, changed_columns from extra_in_backup
union all
select customer_id, diff_type, changed_columns from changed_customers
order by diff_type, customer_id;


-- TASK 5.5: Duplicate customers

with duplicate_customer_email as (
	select lower(trim(email)) as `normalized_email`, count(*) as occurrences, group_concat(customer_id order by customer_id) as customer_ids,
	min(registration_date) as first_registered, max(registration_date) as last_registered
	from customers
	group by lower(trim(email))
	having count(*) > 1
)
select normalized_email, occurrences, customer_ids, first_registered, last_registered
from duplicate_customer_email;

-- Bonus task 5.5

with duplicate_customer_name_dob as (
	select lower(trim(first_name)) as `first_name`, lower(trim(last_name)) as `last_name`, date_of_birth,
	count(*) as occurrences, group_concat(customer_id order by customer_id) as customer_ids,
	min(registration_date) as first_registered, max(registration_date) as last_registered
	from customers
	group by lower(trim(first_name)), lower(trim(last_name)), date_of_birth
	having count(*) > 1
)
select first_name, last_name, date_of_birth, occurrences, customer_ids, first_registered, last_registered
from duplicate_customer_name_dob;
