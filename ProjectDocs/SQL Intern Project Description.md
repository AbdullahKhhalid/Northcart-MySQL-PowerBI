# NorthCart E-Commerce Analytics — SQL Assessment Project

**Stack:** MySQL 8 + DBeaver  
**Database:** e-commerce practice DB (10 core tables + 2 backup/test copies)  
**Duration:** 2 weeks  
**Format:** 7 modules, 30 tasks. Each task has a business question, the exact output table we expect, and self-checks you can run to validate your own result before submitting.

---

## 1. The scenario

You have joined **NorthCart**, a mid-size online retailer, as the first data analyst. Nobody has ever reported on this database properly. Four stakeholders have asks:

| Stakeholder | What they need |
|---|---|
| **Finance** | Revenue by category and month, payment reconciliation, margin |
| **Marketing** | Customer segmentation (RFM), cohort retention, repeat-purchase behaviour |
| **Operations** | Carrier performance, supplier scorecard, return rates |
| **Engineering** | Data-quality checks, a reusable reporting view, an idempotent summary load, and a reconciliation of the customer backup tables |

Every task maps back to one of these. Treat the output tables as if they are going straight into a Power BI dashboard — column names, types and grain matter.

---

## 2. Ground rules (how we work)

These are graded. They matter more than getting a "right number".

1. **No `SELECT *`** in any submitted query. Name every column.
2. **Explicit joins only** (`JOIN ... ON`). No comma joins.
3. **CTEs over nested subqueries.** Name each CTE for what it *is* (`monthly_revenue`, not `t1`).
4. **Define "valid order" once, reuse everywhere.** After Module 1 you will know the real `status` values. Write the filter once in a comment block at the top of every script and apply it consistently.
5. **Never use `CURDATE()` for business logic.** Use a reference date: `(SELECT MAX(order_date) FROM orders)`. The dummy data is frozen; "today" is meaningless.
6. **Round only in the final SELECT**, never inside intermediate CTEs.
7. **Watch for fan-out.** If a metric looks too big after a join, you have multiplied rows. Aggregate first, then join.
8. **Every DDL/DML must be safe to run twice** (idempotent) and must never touch the original `customers` table.
9. **Comment the business rule**, not the SQL. `-- excludes cancelled orders and returned lines per Finance rule` is useful; `-- join products` is not.
10. **One task = one query** unless the task says otherwise. If you need a helper query to understand the data, keep it in an `exploration.sql` file, not in the deliverable.

---

## 3. Deliverables

Submit a folder:

```
northcart_sql_assessment/
  00_exploration.sql          -- scratch queries (not graded, but we look)
  01_profiling.sql
  02_core_reporting.sql
  03_time_intelligence.sql
  04_window_functions.sql
  05_data_quality.sql
  06_operations.sql
  07_engineering.sql
  outputs/                    -- one CSV per task, exported from DBeaver, named task_2_1.csv etc.
  FINDINGS.md                 -- 1–2 pages: what you learned about the data, every anomaly you found, what you'd fix
```

Each `.sql` file: one header comment (module, author, date, valid-order definition), then tasks in order, each preceded by `-- TASK x.y: <title>`.

---

## 4. Reading the expected outputs

For every task you get an **expected output table**: exact column names, in order, with a couple of *illustrative* rows. **The values shown are made up** — your numbers will differ. What must match: column names, column order, grain (one row per what?), sort order, and any rounding stated.

---

# MODULE 1 — Profiling & Data Dictionary
*Goal: understand the data before reporting on it. Engineering.*

### Task 1.1 — Row counts
One row per table, all 12 tables, in one result set.

| table_name | row_count |
|---|---|
| customers | 1200 |
| addresses | 1834 |
| ... | ... |

Sort: `row_count DESC`.

### Task 1.2 — Date coverage
For each date column below, report min, max, and how many rows have it populated: `orders.order_date`, `customers.registration_date`, `reviews.review_date`, `payments.payment_date`, `shipments.shipped_date`, `products.launch_date`.

| field | min_date | max_date | populated_rows |
|---|---|---|---|
| orders.order_date | 2023-01-03 | 2025-06-28 | 5400 |
| customers.registration_date | 2022-11-14 | 2025-06-20 | 1200 |

**Self-check:** `populated_rows` for `orders.order_date` should equal the orders row count from 1.1 (if it doesn't, note it in FINDINGS).

### Task 1.3 — Categorical value inventory
For each of `orders.status`, `payments.status`, `payments.payment_method`, `shipments.status`, `addresses.address_type`, `orders.shipping_method`: list every distinct value with its count. One result set.

| table_name | column_name | value | rows |
|---|---|---|---|
| orders | status | Delivered | 4102 |
| orders | status | Cancelled | 233 |

Sort: `table_name, column_name, rows DESC`.

**This task defines your "valid order" rule for the rest of the project.** State it explicitly in FINDINGS.

### Task 1.4 — Customer table health
Single-row summary.

| total_customers | missing_email | missing_phone | missing_dob | duplicate_emails | dob_after_registration |
|---|---|---|---|---|---|
| 1200 | 4 | 31 | 12 | 3 | 0 |

Treat empty strings as missing. `duplicate_emails` = number of *extra* rows sharing a normalised (lower-cased, trimmed) email.

### Task 1.5 — Decode the money columns
Take 10 order_items rows and prove (or disprove) the arithmetic: is `subtotal = quantity × unit_price × (1 − discount_percent/100)`? Is `total_amount = subtotal + tax_amount`?

| order_item_id | quantity | unit_price | discount_percent | subtotal | computed_subtotal | tax_amount | total_amount | computed_total | subtotal_ok | total_ok |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 2 | 49.99 | 0 | 99.98 | 99.98 | 8.00 | 107.98 | 107.98 | 1 | 1 |
| 2 | 1 | 120.00 | 10 | 108.00 | 108.00 | 8.64 | 116.64 | 116.64 | 1 | 1 |

Then add a second query: count of rows where `subtotal_ok = 0` and where `total_ok = 0` across the **whole** table (tolerance ±0.01). Write your conclusion in FINDINGS — is `total_amount` tax-inclusive? This decides how you compute revenue and margin later.

---

# MODULE 2 — Core Reporting
*Goal: joins and aggregation that Finance would sign off on.*

Unless stated otherwise: **valid orders only**, and **exclude returned line items** (`returned = 1`).

### Task 2.1 — Revenue by category
Grain: one row per `category_group` + `category`.

| category_group | category | orders | units | gross_revenue | revenue_per_unit |
|---|---|---|---|---|---|
| Electronics | Audio | 412 | 690 | 84210.55 | 122.04 |
| Home | Kitchen | 380 | 1120 | 61003.10 | 54.47 |

`gross_revenue` = sum of `order_items.total_amount`. Round to 2 dp. Sort: `gross_revenue DESC`.

**Self-check:** add a grand-total row (or a second query) — total must equal the sum of `order_items.total_amount` under the same filter with no joins to categories. If it doesn't, you have dropped products with a missing category. Report how many.

### Task 2.2 — Top 10 customers by lifetime spend

| customer_id | customer_name | country | orders | lifetime_spend | avg_order_value | first_order | last_order |
|---|---|---|---|---|---|---|---|
| 88 | Priya Nair | US | 14 | 4120.30 | 294.31 | 2023-02-11 | 2025-05-30 |

`lifetime_spend` from `orders.total_amount`. Exactly 10 rows.

### Task 2.3 — Order status funnel
All statuses (do **not** apply the valid-order filter here).

| status | orders | revenue | pct_of_orders |
|---|---|---|---|
| Delivered | 4102 | 612000.00 | 75.96 |
| Cancelled | 233 | 30110.00 | 4.31 |

**Self-check:** `pct_of_orders` sums to 100.00 (±0.05).

### Task 2.4 — Registered but never ordered
Customers with zero orders of any status.

| customer_id | first_name | last_name | email | registration_date | days_since_registration |
|---|---|---|---|---|---|
| 1043 | Ahmed | Khan | a.khan@example.com | 2025-03-02 | 118 |

`days_since_registration` is relative to the **reference date** (max order_date), not today. Sort: `registration_date`.

### Task 2.5 — Shipping method economics
Grain: one row per `shipping_method`.

| shipping_method | orders | avg_order_value | avg_discount_pct | avg_shipping_cost | pct_with_coupon |
|---|---|---|---|---|---|
| Express | 900 | 210.40 | 4.20 | 14.99 | 22.10 |

Join shipments with a LEFT JOIN — an order without a shipment row must still count.

---

# MODULE 3 — Time Intelligence
*Goal: monthly trends, growth, cohorts. Marketing + Finance.*

### Task 3.1 — Monthly revenue with MoM growth

| ym | orders | revenue | prev_month_revenue | mom_growth_pct |
|---|---|---|---|---|
| 2023-01 | 120 | 18400.00 | NULL | NULL |
| 2023-02 | 141 | 21900.00 | 18400.00 | 19.02 |

Use `LAG`. First month has NULLs, not zeros. Guard against divide-by-zero.

### Task 3.2 — Rolling 3-month average and cumulative revenue
Same monthly grain as 3.1.

| ym | revenue | rolling_3m_avg | cumulative_revenue |
|---|---|---|---|
| 2023-01 | 18400.00 | 18400.00 | 18400.00 |
| 2023-03 | 20100.00 | 20133.33 | 60400.00 |

Rolling window = current month and 2 preceding (`ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`).

### Task 3.3 — Registration cohort retention
Grain: one row per registration month. `m0..m3` = distinct customers from that cohort who placed a valid order 0, 1, 2, 3 months after their registration month.

| cohort_month | cohort_size | m0 | m1 | m2 | m3 | m1_retention_pct |
|---|---|---|---|---|---|---|
| 2023-01 | 45 | 30 | 12 | 9 | 7 | 26.7 |

Month offset = difference in **calendar months** between registration month and order month (use `TIMESTAMPDIFF(MONTH, ...)` on first-of-month dates). Cohorts with zero orders still appear.

### Task 3.4 — Day-of-week pattern
Grain: one row per weekday, Monday first.

| weekday | orders | revenue | avg_order_value |
|---|---|---|---|
| Monday | 780 | 118000.00 | 151.28 |

Sort by actual weekday order, not alphabetically.

---

# MODULE 4 — Window Functions & Segmentation
*Goal: ranking, running totals, RFM. Marketing.*

### Task 4.1 — Top 3 products per category by revenue
Ties share a rank (`DENSE_RANK`).

| category | rnk | product_id | product_name | units | revenue |
|---|---|---|---|---|---|
| Audio | 1 | 17 | Studio Headphones X | 210 | 25200.00 |
| Audio | 2 | 22 | Bluetooth Speaker Mini | 340 | 17000.00 |

Sort: `category, rnk`.

### Task 4.2 — RFM scoring and segments
Two outputs.

**4.2a** — one row per customer with ≥1 valid order:

| customer_id | recency_days | frequency | monetary | r_score | f_score | m_score | segment |
|---|---|---|---|---|---|---|---|
| 88 | 12 | 14 | 4120.30 | 5 | 5 | 5 | Champion |

Scores via `NTILE(5)`: 5 = best (most recent / most orders / highest spend). Segments:

| Rule | Segment |
|---|---|
| R≥4 and F≥4 and M≥4 | Champion |
| R≥3 and F≥3 | Loyal |
| R≥4 and F≤2 | New / Promising |
| R≤2 and F≥3 | At Risk |
| R≤2 and F≤2 | Lost |
| otherwise | Needs Attention |

Evaluate rules top to bottom.

**4.2b** — segment summary:

| segment | customers | pct_of_customers | total_monetary | avg_monetary |
|---|---|---|---|---|
| Champion | 96 | 9.6 | 240300.00 | 2503.13 |

### Task 4.3 — Customer order timeline
Grain: one row per valid order.

| customer_id | order_id | order_date | order_seq | total_amount | running_spend | days_since_prev_order | pct_of_lifetime_spend |
|---|---|---|---|---|---|---|---|
| 88 | 1201 | 2023-02-11 | 1 | 140.00 | 140.00 | NULL | 3.40 |
| 88 | 1877 | 2023-04-02 | 2 | 310.00 | 450.00 | 50 | 7.52 |

Sort: `customer_id, order_seq`.

### Task 4.4 — Does first purchase category predict repeat buying?
Grain: one row per `category_group` of the customer's **very first line item**.

| first_purchase_group | customers | repeat_customers | repeat_rate_pct |
|---|---|---|---|
| Electronics | 310 | 201 | 64.8 |

"Repeat" = more than one valid order in total. Sort: `repeat_rate_pct DESC`.

---

# MODULE 5 — Data Quality & Reconciliation
*Goal: find what's broken. Engineering + Finance. This is the module we care most about.*

Every anomaly you surface here goes into FINDINGS with a one-line hypothesis of the cause.

### Task 5.1 — Order header vs line items
Orders where `orders.total_amount` ≠ sum of `order_items.total_amount` (tolerance ±0.01). Include orders with **no** line items.

| order_id | status | header_total | line_total | variance | line_items |
|---|---|---|---|---|---|
| 3310 | Delivered | 250.00 | 275.00 | -25.00 | 3 |
| 4402 | Pending | 90.00 | NULL | 90.00 | 0 |

Sort: `ABS(variance) DESC`. Then answer in FINDINGS: is the variance explained by `orders.discount_percent` being applied at header level? Show the query you used to test that.

### Task 5.2 — Payment reconciliation
One row per order that is **not** cleanly paid.

| order_id | order_status | total_amount | paid_amount | refunded_amount | payment_rows | recon_flag |
|---|---|---|---|---|---|---|
| 512 | Delivered | 180.00 | 0.00 | 0.00 | 0 | NO_PAYMENT |
| 977 | Delivered | 180.00 | 360.00 | 0.00 | 2 | OVERPAID |

`paid_amount` counts only successful payments (use the status value you found in 1.3). Flags: `NO_PAYMENT`, `UNDERPAID`, `OVERPAID`. Sort: `recon_flag, order_id`.

### Task 5.3 — Referential & logical integrity suite
One query, one row per check, all checks in one result set. Minimum checks:

| check_name | violations |
|---|---|
| order_items.product_id -> products | 0 |
| orders.customer_id -> customers | 0 |
| orders.address_id -> addresses | 2 |
| order address belongs to a different customer | 5 |
| reviews.order_id not owned by reviews.customer_id | 3 |
| reviews.product_id not in the reviewed order | 8 |
| shipments delivered before shipped | 0 |
| payments dated before order_date | 1 |
| products priced below cost | 4 |
| products with stock_quantity < 0 | 0 |

Add at least two checks of your own.

### Task 5.4 — Customer backup reconciliation
Compare `customers` (live) against `customersbackup_test`. First check whether the backup has duplicate `customer_id`s (it has a surrogate `TestingID` key, so it can). Then produce:

| customer_id | diff_type | changed_columns |
|---|---|---|
| 1188 | MISSING_IN_BACKUP | NULL |
| 9001 | EXTRA_IN_BACKUP | NULL |
| 402 | CHANGED | email,phone |

`CHANGED` compares all business columns (names, email, phone, dob, gender, city, state, country, registration_date) using NULL-safe comparison. MySQL has no `FULL OUTER JOIN` — show how you got both sides. Sort: `diff_type, customer_id`.

Repeat for `customersbackupno2_test` (same query, different table) and note in FINDINGS which backup is closer to live.

### Task 5.5 — Duplicate customers
Same person registered more than once, by normalised email.

| normalized_email | occurrences | customer_ids | first_registered | last_registered |
|---|---|---|---|---|
| jane.doe@example.com | 2 | 41,1187 | 2023-01-09 | 2025-04-12 |

Bonus: a second version matching on `first_name + last_name + date_of_birth` and compare the two lists.

---

# MODULE 6 — Operations
*Goal: carrier, supplier, product and review performance.*

### Task 6.1 — Carrier scorecard

| carrier | shipments | delivered | in_transit | avg_transit_days | late_deliveries | on_time_pct | avg_shipping_cost |
|---|---|---|---|---|---|---|---|
| FastShip | 1400 | 1350 | 50 | 3.4 | 120 | 91.1 | 9.80 |

"Late" = `actual_delivery > estimated_delivery`. `on_time_pct` uses delivered shipments as the denominator. Sort: `on_time_pct DESC`.

### Task 6.2 — Supplier scorecard
Grain: one row per supplier, **including suppliers with no sales**.

| supplier_id | supplier_name | country | supplier_rating | products | units_sold | net_revenue | gross_margin | return_rate_pct | avg_product_rating |
|---|---|---|---|---|---|---|---|---|---|
| 3 | Orion Goods | DE | 4.5 | 18 | 2200 | 145000.00 | 51200.00 | 3.1 | 4.2 |

`net_revenue` = line `total_amount − tax_amount` (adjust if 1.5 proved otherwise). `gross_margin` = `net_revenue − quantity × product.cost`. `avg_product_rating` must be the average across the supplier's **products**, not across order lines — this is the fan-out trap from the ground rules.

### Task 6.3 — High-return products
Products with ≥5 line items and return rate ≥ 20% (make both thresholds easy to change).

| product_id | product_name | category | price | cost | margin_pct | line_items | units | returned_lines | return_rate_pct | stock_quantity |
|---|---|---|---|---|---|---|---|---|---|---|
| 61 | Desk Lamp Pro | Lighting | 39.99 | 22.00 | 45.0 | 40 | 55 | 11 | 27.5 | 120 |

Sort: `return_rate_pct DESC, units DESC`.

### Task 6.4 — Review integrity
**6.4a** — reviews flagged `verified_purchase = 1` that cannot be backed by a purchase:

| review_id | customer_id | product_id | order_id | rating | issue |
|---|---|---|---|---|---|
| 703 | 15 | 88 | 2901 | 5 | PRODUCT_NOT_IN_ORDER |

Issues: `ORDER_NOT_FOUND_FOR_CUSTOMER`, `PRODUCT_NOT_IN_ORDER`, `REVIEW_BEFORE_ORDER`.

**6.4b** — verified vs unverified summary:

| verified_purchase | reviews | avg_rating | avg_helpful_votes | pct_5_star |
|---|---|---|---|---|
| 1 | 2100 | 4.21 | 3.4 | 48.2 |
| 0 | 640 | 3.60 | 1.1 | 30.5 |

### Task 6.5 — Catalog rating drift
Products whose stored `products.rating` differs from the average of their reviews by ≥ 0.5, with ≥ 3 reviews.

| product_id | product_name | catalog_rating | reviews | review_avg | drift |
|---|---|---|---|---|---|
| 17 | Studio Headphones X | 4.8 | 42 | 4.10 | 0.70 |

Sort: `ABS(drift) DESC`.

---

# MODULE 7 — Engineering
*Goal: build reusable, idempotent objects. Everything here must be safe to re-run.*

### Task 7.1 — Reporting view `v_order_facts`
One row per order line, denormalised with everything a dashboard needs:

`order_item_id, order_id, order_date, order_month, order_status, shipping_method, coupon_code, customer_id, customer_country, customer_state, registration_date, product_id, product_name, brand, unit_cost, category_id, category, category_group, supplier_id, supplier_name, quantity, unit_price, line_discount_pct, subtotal, tax_amount, line_total, returned`

Use `CREATE OR REPLACE VIEW`. Then **re-run Task 2.1 against the view** and show both results match exactly (paste both grand totals in FINDINGS).

### Task 7.2 — Daily sales summary table with idempotent load
Create `daily_sales_summary(sales_date PK, orders, units, gross_revenue, returned_units, loaded_at)` and write a load statement using `INSERT ... ON DUPLICATE KEY UPDATE`. Run it twice; prove the row count and totals do not change.

Expected shape:

| sales_date | orders | units | gross_revenue | returned_units | loaded_at |
|---|---|---|---|---|---|
| 2023-01-03 | 6 | 11 | 812.40 | 0 | 2026-09-09 10:14:02 |

### Task 7.3 — Safe backfill from backup
1. `CREATE TABLE customers_scratch LIKE customers` and copy live data into it.
2. Upsert from `customersbackup_test` into `customers_scratch`, de-duplicating the backup by `customer_id` first (keep highest `TestingID`).
3. Wrap it in a transaction.
4. Re-run your 5.4 diff **against `customers_scratch`** and show `MISSING_IN_BACKUP` and `CHANGED` are now 0 (`EXTRA_IN_BACKUP` should also be 0 after the upsert — explain why).

**Never write to `customers`.**

### Task 7.4 — Query plan & indexing
Take this query:

```sql
SELECT order_id, order_date, total_amount
FROM orders
WHERE customer_id = <pick a busy customer>
  AND order_date BETWEEN '2024-01-01' AND '2024-12-31';
```

Run `EXPLAIN`, record `type`, `key`, `rows`. Propose and create one composite index. Re-run `EXPLAIN`. Report:

| query | before_type | before_key | before_rows | index_created | after_type | after_key | after_rows |
|---|---|---|---|---|---|---|---|
| orders by customer+date | ALL | NULL | 5400 | idx_orders_customer_date (customer_id, order_date) | range | idx_orders_customer_date | 14 |

Explain in FINDINGS why the column order in the index matters.

### Task 7.5 — Capstone: `v_customer_360`
One row per customer (including customers with no orders), ready to be dropped into Power BI.

| customer_id | customer_name | email | gender | age | city | state | country | registration_date | addresses | orders | lifetime_spend | avg_order_value | first_order | last_order | days_since_last_order | favourite_category_group | reviews | avg_review_rating | return_rate_pct | lifecycle_status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 88 | Priya Nair | ... | F | 34 | Austin | TX | US | 2023-01-20 | 2 | 14 | 4120.30 | 294.31 | 2023-02-11 | 2025-05-30 | 29 | Electronics | 6 | 4.5 | 2.1 | Active |
| 1043 | Ahmed Khan | ... | M | 27 | ... | ... | ... | 2025-03-02 | 1 | 0 | 0.00 | NULL | NULL | NULL | NULL | NULL | 0 | NULL | NULL | Never purchased |

`lifecycle_status` (relative to reference date): `Never purchased`; `Active` ≤ 90 days since last order; `Lapsing` 91–180; `Churned` > 180. `favourite_category_group` = the group with the highest spend for that customer.

**Self-checks:** row count = customers row count; sum of `lifetime_spend` = total valid-order revenue from 2.2's underlying data; `orders = 0` count = row count of 2.4.

---

## 5. Grading rubric (100 points)

| Area | Points | What we look at |
|---|---|---|
| Correctness | 35 | Output shape matches spec, self-checks pass, numbers reconcile across tasks |
| Query craft | 20 | Ground rules followed; CTE naming; no fan-out; NULL handling; sort order |
| Data-quality findings | 20 | Module 5 anomalies found, quantified, and given a plausible cause |
| Engineering | 15 | Module 7 objects are idempotent, safe, and verified |
| FINDINGS.md | 10 | Clear, honest, prioritised. "I couldn't explain X" is fine; silence is not |

**Automatic deductions:** `SELECT *` in a deliverable (−5 each), any write to `customers` (−15), `CURDATE()` in business logic (−3 each).

## 6. Check-in schedule

- **Day 3:** Modules 1–2 done. 15-minute review — mainly to lock the valid-order definition and money-column semantics before you build on them.
- **Day 7:** Modules 3–5.
- **Day 10:** Modules 6–7 + FINDINGS draft.
- **Day 12:** Walkthrough. You present `v_customer_360` and your top 5 data-quality findings as if to the COO.
