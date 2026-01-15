-- delete the first row which contains headers
SELECT *
FROM sales_raw
WHERE product_id = 'product_id';

BEGIN;
DELETE FROM sales_raw
WHERE product_id = 'product_id'
RETURNING *;
COMMIT;

-- how many rows are there?
-- 1465
SELECT COUNT(*) FROM sales_raw;

-- are there any ID NULLs?
-- 0
SELECT COUNT(*) - COUNT(product_id) AS product_id_nulls 
FROM sales_raw;

-- are there any IDs duplicated?
-- 114
SELECT COUNT(product_id) - COUNT(DISTINCT product_id) AS product_id_duplicates
FROM sales_raw;

-- are product names also duplicated?
-- 128
SELECT COUNT(*) - COUNT(DISTINCT product_name)
FROM sales_raw;

-- how many product categories are there?
-- 211
SELECT COUNT(DISTINCT category)
FROM sales_raw;

-- how many ID variations are there?
-- 1 -> string of length 10
SELECT LENGTH(product_id)
FROM product_rating_raw
GROUP BY 1;
