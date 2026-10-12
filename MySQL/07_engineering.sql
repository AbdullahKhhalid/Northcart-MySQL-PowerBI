-- Module: Module 7 - Engineering, Author: Abdullah Khalid, Date: 15th September 2026 (Tuesday), Valid-Order Definition: orders.status not in ('Cancelled', 'Returned')


-- TASK 7.1: Reporting view v_order_facts

create or replace view v_order_facts as
select order_items.order_item_id as `order_item_id`,
	orders.order_id as `order_id`,
	orders.order_date as `order_date`,
	date_format(orders.order_date, '%Y-%m') as `order_month`,
	orders.status as `order_status`,
	orders.shipping_method as `shipping_method`,
	orders.coupon_code as `coupon_code`,
	customers.customer_id as `customer_id`,
	customers.country as `customer_country`,
	customers.state as `customer_state`,
	customers.registration_date as `registration_date`,
	products.product_id as `product_id`,
	products.product_name as `product_name`,
	products.brand as `brand`,
	products.cost as `unit_cost`,
	categories.category_id as `category_id`,
	categories.category as `category`,
	categories.category_group as `category_group`,
	suppliers.supplier_id as `supplier_id`,
	suppliers.supplier_name as `supplier_name`,
	order_items.quantity as `quantity`,
	order_items.unit_price as `unit_price`,
	order_items.discount_percent as `line_discount_pct`,
	order_items.subtotal as `subtotal`,
	order_items.tax_amount as `tax_amount`,
	order_items.total_amount as `line_total`,
	order_items.returned as `returned`
from orders
join customers
on orders.customer_id = customers.customer_id
join order_items
on orders.order_id = order_items.order_id
join products
on order_items.product_id = products.product_id
join categories
on products.category_id = categories.category_id
join suppliers
on products.supplier_id = suppliers.supplier_id;

select category_group, category, count(distinct order_id) as `orders`,
sum(quantity) as `units`, round(sum(line_total),2) as `gross_revenue`,
round(sum(line_total) / sum(quantity),2) as `revenue_per_unit`
from v_order_facts
join valid_order_rule
on valid_order_rule.valid_orders = v_order_facts.order_id
where returned = 0
group by category_group, category
order by gross_revenue desc;

select round(sum(line_total),2) as `grand_total_row`
from v_order_facts
join valid_order_rule
on valid_order_rule.valid_orders = v_order_facts.order_id
where returned = 0;


-- TASK 7.2: Daily sales summary table with idempotent load

create table if not exists daily_sales_summary (
    sales_date date primary key,
    orders int,
    units int,
    gross_revenue decimal(12,2),
    returned_units int,
    loaded_at timestamp
);

insert into daily_sales_summary (sales_date, orders, units, gross_revenue, returned_units, loaded_at)
select v_order_facts.order_date as `sales_date`,
    count(distinct case when v_order_facts.returned = 0 then v_order_facts.order_id end) as `orders`,
    sum(case when v_order_facts.returned = 0 then v_order_facts.quantity else 0 end) as `units`,
    round(sum(case when v_order_facts.returned = 0 then v_order_facts.line_total else 0 end), 2) as `gross_revenue`,
    sum(case when v_order_facts.returned = 1 then v_order_facts.quantity else 0 end) as `returned_units`,
    now() as `loaded_at`
from v_order_facts
join valid_order_rule
on valid_order_rule.valid_orders = v_order_facts.order_id
group by v_order_facts.order_date
on duplicate key update
    orders = values(orders),
    units = values(units),
    gross_revenue = values(gross_revenue),
    returned_units = values(returned_units),
    loaded_at = values(loaded_at);

select sales_date, orders, units, gross_revenue, returned_units, loaded_at
from daily_sales_summary
order by sales_date;


-- TASK 7.3: Safe backfill from backup

create table if not exists customers_scratch like customers;

insert into customers_scratch
select customer_id, first_name, last_name, email, phone, date_of_birth, gender,
city, state, country, registration_date
from customers;

start transaction;

insert into customers_scratch (customer_id, first_name, last_name, email, phone, date_of_birth, gender,
city, state, country, registration_date)
with backup_deduplication as (
	select customersbackup_test.customer_id, customersbackup_test.first_name, customersbackup_test.last_name, customersbackup_test.email,
	customersbackup_test.phone, customersbackup_test.date_of_birth, customersbackup_test.gender, customersbackup_test.city,
	customersbackup_test.state, customersbackup_test.country, customersbackup_test.registration_date,
	row_number() over (partition by customer_id order by TestingID desc) as `row_no`
	from customersbackup_test
)
select customer_id, first_name, last_name, email, phone, date_of_birth, gender,
city, state, country, registration_date
from backup_deduplication
where row_no = 1
on duplicate key update
	first_name = values(first_name),
	last_name = values(last_name),
	email = values(email),
	phone = values(phone),
	date_of_birth = values(date_of_birth),
	gender = values(gender),
	city = values(city),
	state = values(state),
	country = values(country),
	registration_date = values(registration_date)

commit;

with backup_rows as (
    select customers_scratch.customer_id,
           customers_scratch.first_name, customers_scratch.last_name,
           customers_scratch.email, customers_scratch.phone,
           customers_scratch.date_of_birth, customers_scratch.gender,
           customers_scratch.city, customers_scratch.state,
           customers_scratch.country, customers_scratch.registration_date
    from customers_scratch
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


-- TASK 7.4: Query plan & indexing

explain
select order_id, order_date, total_amount
from orders
where customer_id = 2 and order_date between '2024-01-01' and '2024-12-31';

create index idx_orders_customer_date
on orders (customer_id, order_date);


-- TASK 7.5: Capstone

with customer_details as (
    select customers.customer_id as `customer_id`, concat(customers.first_name, ' ', customers.last_name) as `customer_name`, customers.email as `email`,
    case when customers.gender = 'Male' then 'M' when customers.gender = 'Female' then 'F'end as `gender`,
    timestampdiff(year, customers.date_of_birth, now()) as `age`, customers.city as `city`, customers.state as `state`,
    customers.country as `country`, customers.registration_date as `registration_date`,
    (select count(addresses.address_id) from addresses where addresses.customer_id = customers.customer_id) as `addresses`,
    count(distinct case when valid_order_rule.valid_orders is not null then orders.order_id end) as `orders`,
    sum(case when valid_order_rule.valid_orders is not null then total_amount_calculation.computed_total end) as `lifetime_spend`,
    (select avg(orders.total_amount) from orders left join valid_order_rule on valid_order_rule.valid_orders = orders.order_id
    where orders.customer_id = customers.customer_id and valid_order_rule.valid_orders is not null) as `avg_order_value`,
    min(case when valid_order_rule.valid_orders is not null then orders.order_date end) as `first_order`,
    max(case when valid_order_rule.valid_orders is not null then orders.order_date end) as `last_order`,
    datediff((select max(orders.order_date) from orders), max(orders.order_date)) as `days_since_last_order`,
    sum(case when order_items.returned = 1 then 1 else 0 end) / count(order_items.order_item_id) * 100 as `return_rate_pct`
    from customers
    left join orders on customers.customer_id = orders.customer_id
    left join order_items on orders.order_id = order_items.order_id
    left join products on order_items.product_id = products.product_id
    left join categories on products.category_id = categories.category_id
    left join total_amount_calculation on order_items.order_item_id = total_amount_calculation.order_item_id
    left join valid_order_rule on valid_order_rule.valid_orders = orders.order_id
    group by customer_id
),
fav_category_group as (
	select orders.customer_id, categories.category_group,
	row_number() over (partition by orders.customer_id order by sum(total_amount_calculation.computed_total) desc) as `rank`
    from orders
    left join order_items on orders.order_id = order_items.order_id
    left join products on order_items.product_id = products.product_id
    left join categories on products.category_id = categories.category_id
    left join total_amount_calculation on order_items.order_item_id = total_amount_calculation.order_item_id
    left join valid_order_rule on valid_order_rule.valid_orders = orders.order_id
    where valid_order_rule.valid_orders is not null
    group by orders.customer_id, categories.category_group
),
review_details as (
	select reviews.customer_id, count(reviews.review_id) as `reviews`, avg(reviews.rating) as `avg_review_rating`
	from reviews
	group by reviews.customer_id
)
select customer_details.customer_id, customer_details.customer_name, customer_details.email, customer_details.gender, customer_details.age,
customer_details.city, customer_details.state, customer_details.country, customer_details.registration_date, customer_details.addresses, customer_details.orders,
round(customer_details.lifetime_spend,2) as `lifetime_spend`, round(customer_details.avg_order_value,2) as `avg_order_value`,
customer_details.first_order, customer_details.last_order, customer_details.days_since_last_order,
fav_category_group.category_group as `favourite_category_group`, review_details.reviews as `reviews`,
round(review_details.avg_review_rating, 1) as `avg_review_rating`, round(customer_details.return_rate_pct,1) as `return_rate_pct`,
case 
	when customer_details.days_since_last_order <= 90 then 'Active'
	when customer_details.days_since_last_order between 91 and 180 then 'Lapsing'
	when customer_details.days_since_last_order > 180 then 'Churned'
	when customer_details.days_since_last_order is null then 'Never purchased'
end as `lifecycle_status`
from customer_details
left join fav_category_group on customer_details.customer_id = fav_category_group.customer_id and fav_category_group.`rank` = 1
left join review_details on customer_details.customer_id = review_details.customer_id;
