**FINDINGS File:**



The **value order rule** for northcart\_db is **orders.status NOT IN ('Cancelled', 'Returned')**. This valid order rule counts anything thats a genuine transaction. Delivered, Shipped, and Processing all still count as valid business (revenue-generating) orders.



**Observation on task 1.4** **-** Returns all 0 after total\_customers column because the **dataset does not contain any empty (missing) records** or duplicate emails.



**Observation on task 1.5 -** Since all the rows of total\_ok column are equal to 1 meaning that the computed\_subtotal and tax amounts are within the **tolerance level of +-0.01** therefore, we can safely **use computed\_total or total\_amount as tax inclusive sales amount**. Furthermore from the second query, around **1986 rows** have subtotal **IS NOT EQUAL** TO quantity × unit\_price × (1 − discount%), meaning the stored subtotal itself is unreliable for margin/revenue calculation even though total\_amount is internally consistent.



**Observation on task 2.1 -** The sum of gross revenue from the main query is: **24,412,157.53** whereas the sum of the revenue WITHOUT any joins to categories table is: **24,412,157.26** . There is a small difference of **0.27**.  This figure can be explained by rounding of the revenue sums. As a result, no products were dropped because of missing category.



**Task 5.1 - Is the variance explained by orders.discount\_percent being applied at header level?** No, discount\_percent is not applied to orders.total\_amount. Header\_total ≈ line\_total regardless of discount\_percent's value, meaning the field is stored but unused. Dummy database issue.



**Task 5.3 - Two more checks are:** Orders with a negative or zero total\_amount and orders marked "Delivered" with no shipment record at all.



**Task 5.4 -** The first backup, **customersbackup\_test**, is more closer to live with only 10 records with changed values whereas the second backup, **customersbackupno2\_test**, has 153 changed rows.



**Task 5.5 -** Both lists **return empty** because there are no duplicates either by **email or name + dob** in the customers live table.



**Task 7.1 -** The results indicate that per-category figures show trivial rounding drift **(\~$0.01–0.02)** from intermediate rounding differences, but the **grand total reconciles exactly.**



**Task 7.3 -** The only issue returned in task 5.4 was **'CHANGED'**. MISSING\_IN\_BACKUP and EXTRA\_IN\_BACKUP were not returned because they did not exist. The **'CHANGED' value was returned 10 times** in task 5.4 but in this **task 7.3, only one 'CHANGED' customer\_id was returned**. The other 9 duplicates were removed from the customers\_scratch table.



**Task 7.4 -** The **(customer\_id, order\_date)** index helps MySQL **narrow down the data by customer first and then look at the relevant date range.** The order of the columns matters because MySQL **follows the order in which the columns are defined in the index when searching the data**. Before creating the index, MySQL **had to scan 11 rows** to get the results but after creating the composite index, the search **has been reduced to 3 rows** which means MySQL optimizer is preferring my newly created composite index on 'orders' table.







