-- 1. create a RAW version of product_rating
BEGIN;
CREATE TABLE product_rating_raw AS
SELECT product_id,
	   rating,
	   rating_count
FROM sales_raw;

SELECT * FROM product_rating_raw;
COMMIT;

-- 2. validate

-- are there any invalid ratings?
-- 1
SELECT * 
FROM product_rating_raw
WHERE rating ~ '[^0-9\.]';

-- are there any invalid rating counts?
-- 0
SELECT *
FROM product_rating_raw
WHERE rating_count ~ '[^0-9,]';

-- we know from product_info that there are row duplicates
-- we will deal with them later

-- 3. create STAGING version of the table
BEGIN;
CREATE TABLE product_rating_stage AS
SELECT * FROM product_rating_raw;

SELECT * FROM product_rating_raw;
COMMIT;

-- 3.1 trim whitespace
BEGIN;
UPDATE product_rating_stage
SET product_id = TRIM(product_id),
	rating = TRIM(rating),
	rating_count = TRIM(rating_count)
RETURNING *;
COMMIT;

-- 3.2 remove unnecessary symbols
-- in rating there is a single row with a value '|'
BEGIN;
UPDATE product_rating_stage
SET rating = TRIM(REPLACE(rating, '|', ''));

SELECT * 
FROM product_rating_stage
WHERE rating ~ '[^0-9\.]';
COMMIT;

-- delete commas from rating_count
BEGIN;
UPDATE product_rating_stage
SET rating_count = TRIM(REPLACE(rating_count, ',', ''))
RETURNING *;
COMMIT;

-- 3.3 trim again (sanity check)
BEGIN;
UPDATE product_rating_stage
SET product_id = TRIM(product_id),
	rating = TRIM(rating),
	rating_count = TRIM(rating_count)
RETURNING *;
COMMIT;

-- 3.4 normalize fake NULLs
BEGIN;
UPDATE product_rating_stage
SET product_id = CASE WHEN TRIM(LOWER(product_id)) IN ('n/a', 'null', '') THEN NULL ELSE product_id END,
	rating = CASE WHEN TRIM(LOWER(rating)) IN ('n/a', 'null', '') THEN NULL ELSE rating END,
	rating_count = CASE WHEN TRIM(LOWER(rating_count)) IN ('n/a', 'null', '') THEN NULL ELSE rating_count END
RETURNING *;
COMMIT;

-- are there any NULLs?
-- 3 rows
SELECT *
FROM product_rating_stage
WHERE product_id IS NULL
   OR rating IS NULL
   OR rating_count IS NULL;

-- flagging NULLs
BEGIN;
ALTER TABLE product_rating_stage
ADD COLUMN null_row BOOLEAN DEFAULT FALSE;
COMMIT;

BEGIN;
WITH null_rows AS (
	SELECT ctid
	FROM product_rating_stage
	WHERE product_id IS NULL
   	OR rating IS NULL
   	OR rating_count IS NULL
)
UPDATE product_rating_stage pr
SET null_row = TRUE
FROM null_rows nr
WHERE pr.ctid = nr.ctid
RETURNING *;
COMMIT;

-- 3.5 impossible values

-- how many invalid ratings is there?
-- none
SELECT rating
FROM product_rating_stage
WHERE rating::NUMERIC NOT BETWEEN 0 AND 5;

-- what is the 99th and 1st percentile of rating count?
-- nothing seems too suspicious
WITH stats AS (
	SELECT PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY rating_count::BIGINT) AS p1,
		   PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY rating_count::BIGINT) AS p99
	FROM product_rating_stage
)
SELECT *
FROM product_rating_stage
CROSS JOIN stats
WHERE rating_count::BIGINT < p1
   OR rating_count::BIGINT > p99
ORDER BY rating_count::BIGINT;

-- 3.6 flag duplicates

-- whole rows duplicates to be flagged
WITH ranked AS (
	SELECT *,
		   ctid,
		   ROW_NUMBER() OVER(PARTITION BY product_id, rating, rating_count ORDER BY ctid) AS rnk
	FROM product_rating_stage
)
SELECT * FROM ranked
WHERE rnk > 1;

-- flag whole row duplicates
BEGIN;
ALTER TABLE product_rating_stage
ADD COLUMN row_duplicate BOOLEAN DEFAULT FALSE;
COMMIT;

BEGIN;
WITH ranked AS (
	SELECT ctid
	FROM (
	   	SELECT ctid,
		   	   ROW_NUMBER() OVER(PARTITION BY product_id, rating, rating_count ORDER BY ctid) AS rnk
		FROM product_rating_stage
	)
	WHERE rnk > 1
)
UPDATE product_rating_stage pr
SET row_duplicate = TRUE
FROM ranked r
WHERE pr.ctid = r.ctid
RETURNING *;
COMMIT;

-- product_id duplicate
SELECT product_id
FROM product_rating_stage
WHERE NOT row_duplicate
GROUP BY 1
HAVING COUNT(*) > 1;

-- flag id duplicate
BEGIN;
ALTER TABLE product_rating_stage
ADD COLUMN id_duplicate BOOLEAN DEFAULT FALSE;
COMMIT;

BEGIN;
WITH duplicates AS (
	SELECT product_id
	FROM product_rating_stage
	WHERE NOT row_duplicate
	GROUP BY product_id
	HAVING COUNT(product_id) > 1
)
UPDATE product_rating_stage pr
SET id_duplicate = TRUE
FROM duplicates d
WHERE d.product_id = pr.product_id
  AND NOT pr.row_duplicate
RETURNING *;
COMMIT;


-- cleaning is now over

-- 4. expose a clean table without flagged rows
BEGIN;
CREATE TABLE product_rating_clean AS
SELECT product_id, rating, rating_count
FROM product_rating_stage
WHERE NOT row_duplicate 
  AND NOT id_duplicate
  AND NOT null_row;
COMMIT;


-- 5. expose analytics table (final version)
BEGIN;
CREATE TABLE product_rating_analytics AS
SELECT product_id,
	   rating::NUMERIC(2,1),
	   rating_count::INT
FROM product_rating_clean;

SELECT * FROM product_rating_analytics;
COMMIT;

BEGIN;
ALTER TABLE product_rating_analytics
ADD CONSTRAINT rating_product_id_pk
PRIMARY KEY (product_id);
COMMIT;

BEGIN;
ALTER TABLE product_rating_analytics
ALTER COLUMN rating SET NOT NULL,
ALTER COLUMN rating_count SET NOT NULL;
COMMIT;

-- data is ready for analysis
