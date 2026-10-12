# NorthCart E-Commerce Analytics

MySQL and Power BI project completed during my data analyst internship. NorthCart is a fictional online retailer, and the dataset is synthetic (AI-generated). I acted as the company's first data analyst, answering business questions from Finance, Marketing, Operations and Engineering.

## Overview
- **Stack:** MySQL 8, DBeaver, Power BI
- **Scope:** 7 modules, 30 tasks, each with a business question, expected output and self-checks
- **Database:** 10 core tables (orders, order_items, products, customers, payments, shipments, suppliers and others) plus backup/test copies

## MySQL Skills Demonstrated
Multi-table joins, CTEs, window functions, views, subqueries (EXISTS / ANY / ALL), CASE logic, UNION, aggregation with GROUP BY / HAVING, RFM segmentation, cohort retention analysis, data cleaning and quality checks, idempotent scripts, etc.

## What I Built
- **Finance:** revenue by category and month, payment reconciliation, margin
- **Marketing:** RFM segmentation, cohort retention, repeat-purchase behaviour
- **Operations:** carrier performance, supplier scorecard, return rates
- **Engineering:** data-quality checks, a reusable reporting view, an idempotent summary load, reconciliation of customer backup tables

## Power BI Reports
1. **Initial report:** my first Power BI report. It worked, but it had too many pages and unnecessary visuals, gridlines inside the bar/column charts, no page navigation or filter reset, and a conclusion page of large text cards.
2. **Refined report:** rebuilt to fix those issues, with fewer visuals and pages, cleaner charts, page navigation and a filter reset button.

Both reports are included as .pbix files with PDF exports.

## Repository Structure
- `/MySQL` – MySQL scripts
- `/PowerBI` – .pbix files and PDF exports
- '/ProjectDocs' - FINDINGS document and database relationship diagram

## Query Standards
Explicit joins, named CTEs, no `SELECT *`, a single "valid order" definition, a fixed reference date instead of `CURDATE()`, rounding only in the final SELECT, and idempotent scripts that never modify the original `customers` table.

## Key Findings
See the FINDINGS document for the full data-quality and business findings.
