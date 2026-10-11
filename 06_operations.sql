-- Module: Module 6 - Operations, Author: Abdullah Khalid, Date: 14th September 2026 (Monday), Valid-Order Definition: orders.status not in ('Cancelled', 'Returned')


-- TASK 6.1: Carrier scorecard

with carrier_details as (
	select shipments.carrier as `carrier`, count(shipments.shipment_id) as `shipments`,
	sum(case when shipments.status = 'Delivered' then 1 else 0 end) as `delivered`,
	sum(case when shipments.status = 'In Transit' then 1 else 0 end) as `in_transit`,
	avg(datediff(actual_delivery, shipped_date)) as `avg_transit_days`,
	sum(case when actual_delivery > estimated_delivery then 1 else 0 end) as `late_deliveries`,
	avg(shipments.shipping_cost) as `avg_shipping_cost`
	from shipments
	group by carrier
),
timely_deliveries as (
	select carrier, shipments, delivered, in_transit, avg_transit_days, late_deliveries, (delivered - late_deliveries) / delivered * 100 as `on_time_pct`,
	avg_shipping_cost
	from carrier_details
)
select carrier, shipments, delivered, in_transit, round(avg_transit_days,1) as `avg_transit_days`, late_deliveries, round(on_time_pct,1) as `on_time_pct`,
round(avg_shipping_cost,2) as `avg_shipping_cost`
from timely_deliveries
order by on_time_pct desc;


-- TASK 6.2: Supplier scorecard

with supplier_info as (
	select suppliers.supplier_id as `supplier_id`, suppliers.supplier_name as `supplier_name`, suppliers.country as `country`,
	suppliers.rating as `supplier_rating`, count(distinct products.product_id) as `products`, sum(order_items.quantity) as `units_sold`,
	sum(total_amount_calculation.computed_total - total_amount_calculation.tax_amount) as `net_revenue`,
	sum(total_amount_calculation.computed_total - total_amount_calculation.tax_amount) - sum(order_items.quantity * products.cost) as `gross_margin`,
	sum(case when order_items.returned = 1 then 1 else 0 end) / count(order_items.order_item_id) * 100 as `return_rate_pct`
	from suppliers
	left join products
	on suppliers.supplier_id = products.supplier_id
	left join order_items
	on products.product_id = order_items.product_id
	left join total_amount_calculation
	on order_items.order_item_id = total_amount_calculation.order_item_id
	group by supplier_id, supplier_name, country, supplier_rating
),
product_ratings as (
	select supplier_id, avg(rating) as avg_product_rating
	from products
	group by supplier_id
)
select supplier_info.supplier_id, supplier_info.supplier_name, supplier_info.country, supplier_info.supplier_rating,
supplier_info.products, supplier_info.units_sold, round(supplier_info.net_revenue,2) as `net_revenue`, round(supplier_info.gross_margin,2) as `gross_margin`,
round(supplier_info.return_rate_pct,2) as `return_rate_pct`, round(product_ratings.avg_product_rating,2) as `avg_product_rating`
from supplier_info
left join product_ratings
on supplier_info.supplier_id = product_ratings.supplier_id;


-- TASK 6.3: High-return products

with product_categorisation as (
	select order_items.product_id as `product_id`, products.product_name as `product_name`, categories.category as `category`,
	products.price as `price`, products.cost as `cost`, (products.price - products.cost) / products.price * 100 as `margin_pct`,
	count(order_items.product_id) as `line_items`, sum(order_items.quantity) as `units`,
	sum(case when order_items.returned = 1 then 1 else 0 end) as `returned_lines`,
	sum(case when order_items.returned = 1 then 1 else 0 end) / count(order_items.product_id) * 100 as `return_rate_pct`,
	products.stock_quantity as `stock_quantity`
	from products
	join order_items
	on products.product_id = order_items.product_id
	join categories
	on products.category_id = categories.category_id
	group by order_items.product_id
),
product_threshold as (
	select product_id, product_name, category, price, cost, margin_pct, line_items, units, returned_lines,
	return_rate_pct, stock_quantity
	from product_categorisation
	where line_items >= 5 and return_rate_pct >= 20
	group by product_id
)
select product_id, product_name, category, price, cost, round(margin_pct,2) as `margin_pct`, line_items, units, returned_lines,
round(return_rate_pct,2) as `return_rate_pct`, stock_quantity
from product_threshold
order by return_rate_pct desc, units desc;


-- TASK 6.4: Review integrity

-- 6.4a — reviews flagged verified_purchase = 1 that cannot be backed by a purchase

with review_issues as (
	select reviews.review_id as `review_id`, reviews.customer_id as `customer_id`, reviews.product_id as `product_id`,
	reviews.order_id as `order_id`, reviews.rating as `rating`,
	case
		when orders.order_id is null or orders.customer_id != reviews.customer_id then 'ORDER_NOT_FOUND_FOR_CUSTOMER'
		when order_items.order_item_id is null then 'PRODUCT_NOT_IN_ORDER'
		when reviews.review_date < orders.order_date then 'REVIEW_BEFORE_ORDER'
	end as `issue`
	from reviews
	join products
	on reviews.product_id = products.product_id
	left join orders
	on reviews.order_id = orders.order_id
	left join order_items
	on reviews.order_id = order_items.order_id and reviews.product_id = order_items.product_id
	where reviews.verified_purchase = 1
)
select review_id, customer_id, product_id, order_id, rating, issue
from review_issues
where issue is not null;


-- 6.4b — verified vs unverified summary

with verified_unverified_summary as (
	select reviews.verified_purchase as `verified_purchase`, count(reviews.review_id) as `reviews`,
	avg(reviews.rating) as `avg_rating`, avg(reviews.helpful_votes) as `avg_helpful_votes`,
	sum(case when reviews.rating = 5 then 1 else 0 end) / count(reviews.rating) * 100 as `pct_5_star`
	from reviews
	group by verified_purchase
)
select verified_purchase, reviews, round(avg_rating,2) as `avg_rating`, round(avg_helpful_votes,2) as `avg_helpful_votes`,
round(pct_5_star,2) as `pct_5_star`
from verified_unverified_summary;


-- TASK 6.5: Catalog rating drift

with products_reviews_rating_drift as (
	select products.product_id as `product_id`, products.product_name as `product_name`,
	products.rating as `catalog_rating`, count(reviews.review_id) as `reviews`, avg(reviews.rating) as `review_avg`,
	products.rating - avg(reviews.rating) as `drift`
	from products
	join reviews
	on products.product_id = reviews.product_id
	group by product_id
	having count(reviews.review_id) >= 3 and abs(products.rating - avg(reviews.rating)) >= 0.5
)
select product_id, product_name, catalog_rating, reviews, round(review_avg,2) as `review_avg`, round(drift,2) as `drift`
from products_reviews_rating_drift
order by abs(drift) desc;
