-- main categories:
SELECT DISTINCT category
FROM product_info_analytics;

-- number of subcategories
SELECT category, COUNT(DISTINCT subcategory)
FROM product_info_analytics
GROUP BY category
ORDER BY 2 DESC;

-- price and discount in this dataset
SELECT ROUND(AVG(price), 2) AS avg_price,
	   MIN(price) AS min_price,
	   MAX(price) AS max_price
FROM product_info_analytics;

SELECT ROUND(AVG(discount), 2) AS avg_discount,
	   MIN(discount) AS min_discount,
	   MAX(discount) AS max_discount
FROM product_info_analytics;

-- price in different categories
SELECT category,
	   COUNT(product_id),
	   MIN(price),
	   MAX(price),
	   ROUND(AVG(price))
FROM product_info_analytics
GROUP BY category
ORDER BY 4 DESC;

-- ratings in different categories
SELECT category,
	   ROUND(AVG(rating), 2) AS avg_rating,
	   ROUND(AVG(rating_count), 2) AS avg_rating_count
FROM product_info_analytics
JOIN product_rating_analytics USING (product_id)
GROUP BY category
ORDER BY 2 DESC, 3 DESC;

-- top 10 rated subcategories
SELECT subcategory,
	   ROUND(AVG(rating), 2) AS avg_rating,
	   ROUND(AVG(rating_count), 2) AS avg_rating_count
FROM product_info_analytics
JOIN product_rating_analytics USING (product_id)
GROUP BY subcategory
ORDER BY 2 DESC, 3 DESC
LIMIT 10;

-- top 10 rated products where rating > 4.5 and rating count > 10000
SELECT product_name,
	   rating,
	   rating_count
FROM product_info_analytics
JOIN product_rating_analytics USING (product_id)
WHERE rating > 4.5
  AND rating_count > 10000
ORDER BY rating_count DESC
LIMIT 10;
