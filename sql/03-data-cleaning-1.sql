-- let's exclude columns tied to description & reviews
-- let's split the table into:
--	* product info: id, name, category, price, discount
-- 	* product ratings: id, rating, rating_count

-- 1. creating product_info_raw
BEGIN;
CREATE TABLE product_info_raw AS
SELECT product_id,
	   product_name,
	   category,
	   actual_price AS price,
	   discount_percentage AS discount
FROM sales_raw;

SELECT * FROM product_info_raw;
COMMIT;

-- 2. create product_info_stage -> to work on
BEGIN;
CREATE TABLE product_info_stage AS
SELECT * FROM product_info_raw;

SELECT * FROM product_info_stage;
COMMIT;

-- 3. cleaning product_info

-- 3.1 trim whitespace where it does not belong
BEGIN;
UPDATE product_info_stage
SET product_id = TRIM(product_id),
	price = TRIM(price),
	discount = TRIM(discount),
    category = TRIM(category)
RETURNING *;
COMMIT;

-- 3.2 remove unnecessary symbols
-- rupee sign in price
BEGIN;
UPDATE product_info_stage
SET price = TRIM(REPLACE(price, '₹', ''))
RETURNING price;
COMMIT;

-- comma in price
BEGIN;
UPDATE product_info_stage
SET price = TRIM(REPLACE(price, ',', ''))
RETURNING price;
COMMIT;

-- percentage sign in discount
BEGIN;
UPDATE product_info_stage
SET discount = TRIM(REPLACE(discount, '%', ''))
RETURNING *;
COMMIT;

-- splitting category -> first category (main), last category (subcategory)
-- create a column with main category
SELECT TRIM(REGEXP_REPLACE(category, '(^[^|]+).*', '\1')) AS main_category
FROM product_info_stage;

BEGIN;
ALTER TABLE product_info_stage
ADD COLUMN category_main TEXT;
SELECT * FROM product_info_stage;
COMMIT;

BEGIN;
UPDATE product_info_stage
SET category_main = TRIM(REGEXP_REPLACE(category, '(^[^|]+).*', '\1'))
RETURNING *;
COMMIT;

-- create a column with a subcategory
SELECT TRIM(REGEXP_REPLACE(category, '.*\|([^|]+)$', '\1')) AS subcategory
FROM product_info_stage;

BEGIN;
ALTER TABLE product_info_stage
ADD COLUMN subcategory TEXT;
COMMIT;

BEGIN;
UPDATE product_info_stage
SET subcategory = TRIM(REGEXP_REPLACE(category, '.*\|([^|]+)$', '\1'))
RETURNING *;
COMMIT;


-- 3.3 final trim (sanity check)
BEGIN;
UPDATE product_info_stage
SET product_id = TRIM(product_id),
	category = TRIM(category),
	price = TRIM(price),
	discount = TRIM(discount),
	category_main = TRIM(category_main),
	subcategory = TRIM(subcategory)
RETURNING *;
COMMIT;


-- 3.4 normalizing fake NULLs
BEGIN;
UPDATE product_info_stage
SET product_id = CASE
					WHEN TRIM(LOWER(product_id)) IN ('n/a', 'null', '') THEN NULL ELSE product_id
				 END,
	product_name = CASE
						WHEN TRIM(LOWER(product_name)) IN ('n/a', 'null', '') THEN NULL ELSE product_name
					END,
	category = CASE
					WHEN TRIM(LOWER(category)) IN ('n/a', 'null', '') THEN NULL ELSE category
				END,
	price = CASE
				WHEN TRIM(LOWER(price)) IN ('n/a', 'null', '') THEN NULL ELSE price
			END,
	discount = CASE
				WHEN TRIM(LOWER(discount)) IN ('n/a', 'null', '') THEN NULL ELSE discount
			END,
	category_main = CASE
				WHEN TRIM(LOWER(category_main)) IN ('n/a', 'null', '') THEN NULL ELSE category_main
			END,
	subcategory = CASE
				WHEN TRIM(LOWER(subcategory)) IN ('n/a', 'null', '') THEN NULL ELSE subcategory
			END
RETURNING *;
COMMIT;


-- 0 NULLs
SELECT COUNT(*) FROM product_info_stage
WHERE NULL IN (product_id, product_name, category, price, discount, category_main, subcategory);


-- 3.5 flagging impossible values

-- checking price for impossible values

-- other signs than digits present?
-- 0 rows
SELECT COUNT(price)
FROM product_info_stage
WHERE price ~ '[^0-9\.]';

-- any rows producing negative prices?
-- 0 rows
SELECT COUNT(price)
FROM product_info_stage
WHERE price::NUMERIC < 0;

-- how do outliers look like?
-- nothing suspicious, prices looking adequate for edge percentiles
WITH stats AS (
	SELECT PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY price::NUMERIC) AS p1,
		   PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY price::NUMERIC) AS p99
	FROM product_info_stage
)
SELECT product_name, price, p1, p99
FROM product_info_stage
CROSS JOIN stats
WHERE price::NUMERIC < stats.p1 
   OR price::NUMERIC > stats.p99
ORDER BY price::NUMERIC;

-- nothing suspicious in price, no flag needed


-- checking discounts for impossible values

-- other values than digits in the rows?
-- 0 rows
SELECT COUNT(discount)
FROM product_info_stage
WHERE discount ~ '[^0-9]';

-- are values within the 0-100 range?
-- 0 rows
SELECT COUNT(discount)
FROM product_info_stage
WHERE discount::NUMERIC < 0
	OR discount::NUMERIC > 100;

-- nothing suspicious in discount, no flag needed


-- 3.6 FLAGGING DUPLICATES

-- how many rows are to be excluded (pure duplicates), leaving only single occurance of each row?
-- 110
WITH ranked AS (
	SELECT ctid,
		   *,
		   ROW_NUMBER() OVER (
				PARTITION BY product_id, product_name, category, price, discount, category_main, subcategory
				ORDER BY ctid
		   ) AS rnk
	FROM product_info_stage
)
SELECT COUNT(*) FROM ranked
WHERE rnk > 1;


-- flag duplicate rows to be excluded
BEGIN;
ALTER TABLE product_info_stage
ADD COLUMN row_duplicate BOOLEAN DEFAULT FALSE;

SELECT row_duplicate FROM product_info_stage;
COMMIT;


BEGIN;
WITH ids AS (
	SELECT ctid
	FROM (
		SELECT ctid,
			   ROW_NUMBER() OVER (
					PARTITION BY product_id, product_name, category, price, discount, category_main, subcategory
					ORDER BY ctid
			   ) AS rnk
		FROM product_info_stage
	)
	WHERE rnk > 1
)
UPDATE product_info_stage p
SET row_duplicate = TRUE
FROM ids
WHERE p.ctid = ids.ctid
RETURNING *;
COMMIT;


-- are there any product_id duplicates (not row duplicates)?
-- 4 product_ids
SELECT product_id
FROM product_info_stage
WHERE NOT row_duplicate
GROUP BY product_id
HAVING COUNT(*) > 1;

-- flag IDs duplication
BEGIN;
ALTER TABLE product_info_stage
ADD COLUMN product_id_duplicate BOOLEAN DEFAULT FALSE;

SELECT product_id_duplicate FROM product_info_stage;
COMMIT;

BEGIN;
WITH duplicate_ids AS (
	SELECT product_id
	FROM product_info_stage
	WHERE NOT row_duplicate
	  AND product_id IS NOT NULL
	GROUP BY 1
	HAVING COUNT(*) > 1
)
UPDATE product_info_stage pi
SET product_id_duplicate = TRUE
FROM duplicate_ids di
WHERE pi.product_id = di.product_id
  AND NOT pi.row_duplicate
RETURNING *;
COMMIT;

-- cleaning is now OVER
-- 4. expose a CLEAN table
BEGIN;
CREATE TABLE product_info_clean AS
SELECT product_id,
	   product_name,
	   category_main AS category,
	   subcategory,
	   price,
	   discount
FROM product_info_stage
WHERE NOT row_duplicate
  AND NOT product_id_duplicate;

SELECT * FROM product_info_clean;
COMMIT;


-- 5. expose an ANALYTICS version of the table
BEGIN;
CREATE TABLE product_info_analytics AS
SELECT product_id,
	   product_name,
	   category,
	   subcategory,
	   price::NUMERIC(10,2),
	   ((discount::NUMERIC) / 100)::NUMERIC(5,4) AS discount
FROM product_info_clean;

SELECT * FROM product_info_analytics;
COMMIT;

-- add constraints
BEGIN;
ALTER TABLE product_info_analytics
ADD CONSTRAINT product_id_pk
PRIMARY KEY (product_id);

ALTER TABLE product_info_analytics
ADD CONSTRAINT discount_check
CHECK (discount BETWEEN 0 AND 1);
COMMIT;

BEGIN;
ALTER TABLE product_info_analytics
ALTER COLUMN category SET NOT NULL,
ALTER COLUMN subcategory SET NOT NULL,
ALTER COLUMN price SET NOT NULL,
ALTER COLUMN discount SET NOT NULL;
COMMIT;

-- PRODUCT INFO IS READY FOR ANALYSIS
