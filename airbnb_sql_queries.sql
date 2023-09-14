-- Start by exploring data. Looking at columns, data type and any formatting to consider.
SELECT *
FROM listings li;

SELECT *
FROM calendar cal;

SELECT *
FROM reviews rev

--Create a new cleaned listing table. Cleaning up listings data with only relevant columns.
--The price is a string with $ and , in it. We remove those using replace and convert to decimal. 
--We use SELECT DISTINCT TO remove any duplicates
--Use the where clause to remove all nulls. 
DROP TABLE IF EXISTS listings_cleaned;
CREATE TEMPORARY TABLE listings_cleaned AS(
  SELECT DISTINCT 
    id AS listing_id,
    description,
    room_type,
    bedrooms,
    amenities,
    neighbourhood_cleansed AS city,
    neighbourhood_group_cleansed AS county,
    latitude,
    longitude,
    CAST(REPLACE(REPLACE(price, '$', ''), ',', '') AS float) AS nightly_rate,
    review_scores_rating AS rating,
    host_id,
    host_is_superhost
  FROM listings li
  WHERE 
    id IS NOT NULL AND
    description IS NOT NULL AND
    room_type IS NOT NULL AND
    bedrooms IS NOT NULL AND
    amenities IS NOT NULL AND
    neighbourhood_cleansed IS NOT NULL AND
    neighbourhood_group_cleansed IS NOT NULL AND
    latitude IS NOT NULL AND
    longitude IS NOT NULL AND
    CAST(REPLACE(REPLACE(price, '$', ''), ',', '') AS float) IS NOT NULL AND
    review_scores_rating IS NOT NULL AND
    host_id IS NOT NULL AND
    host_is_superhost IS NOT NULL
);

-- Clean up calendar table. Remove nulls, duplicates and group by the listing id. We will be counting all nights they're not availble implying they were booked. 
DROP TABLE IF EXISTS calendar_cleaned;
CREATE TEMPORARY TABLE calendar_cleaned AS(
	SELECT DISTINCT listing_id, CAST(count(*) AS float) AS nights_booked
	FROM calendar cal
	WHERE available = 'f' AND listing_id IS NOT NULL AND available  IS NOT NULL
	GROUP BY listing_id 
);

--Clean up reviews Remove nulls, duplicates and group by the listing id. concatenated all reviews together and grouped by listing id. 
--Since reviews are really to guage guest sentiment and any keywords describing property, date of review was irrelevant.
DROP TABLE IF EXISTS reviews_cleaned;
CREATE TEMPORARY TABLE reviews_cleaned AS(
	SELECT DISTINCT listing_id, STRING_AGG("comments",',') AS reviews
	FROM reviews rev
	WHERE listing_id IS NOT NULL AND "comments"  IS NOT NULL
	GROUP BY listing_id 
);

-- Join all 3 tables together using listing id. This will be our main table to form queries from. 
CREATE TABLE listings_detailed AS(
	SELECT 
		lc.listing_id ,lc.room_type ,lc.bedrooms ,lc.amenities ,lc.city ,lc.county ,lc.latitude ,lc.longitude ,lc.nightly_rate ,calc.nights_booked,lc.nightly_rate *calc.nights_booked AS annual_rev,lc.rating,lc.host_id ,lc.host_is_superhost ,revs.reviews,
		CASE
			WHEN rating > 3 AND rating <=5 THEN 'Above Median'
			WHEN rating >= 0 AND rating < 3 THEN 'Below Median'
			ELSE 'Median Rating'
		END AS rating_group
	FROM listings_cleaned lc 
	INNER JOIN calendar_cleaned calc
		ON lc.listing_id = calc.listing_id 
	INNER JOIN reviews_cleaned revs
		ON revs.listing_id = lc.listing_id
	ORDER BY annual_rev DESC
);

--Data Analysis: 

--Question 1: Which listings make above average annual revenue? We will refer to these as great listings
-- Considerations: Our dataset includes the listings for the full province. It would not be fair to take the average revenue for the province to determine the list since more popular cities would skew the average.
-- Instead, we create a cte which calculates the average annual revenue by city and then use the city averages to compare individual listings to produce a fairer view of which properties perform above average. 
--We will create this into our table since we are looking for insights into what makes a listing above avg.

CREATE TABLE great_listings AS(
	WITH avg_rev_city AS(
		SELECT city, AVG(annual_rev) avg_rev
		FROM listings_detailed ld1 
		GROUP BY city
	)
	SELECT ld.*	
	FROM listings_detailed ld
	INNER JOIN avg_rev_city avgc
		ON ld.city = avgc.city
	WHERE annual_rev > avgc.avg_rev
	ORDER BY ld.annual_rev DESC
);

SELECT * 
FROM great_listings gl 
ORDER BY annual_rev DESC;


--Question 2: Which city has the most great listings?
SELECT city,count(*) AS number_of_listings, ROUND(AVG(annual_rev)::numeric, 2) AS average_annual_revenue
FROM great_listings gl 
GROUP BY city
ORDER BY number_of_listings DESC;

--What is the average guest rating great listing recieve?:
SELECT AVG(rating)
FROM great_listings gl;


--What is the average occupancy rate for great listings?
SELECT AVG((nights_booked/365) *100) AS occupany_rate
FROM great_listings gl 
ORDER BY occupany_rate DESC;

-- What is the distribution of great listings by bedrooms?
SELECT bedrooms,COUNT(*) AS number_of_listings
FROM great_listings gl
GROUP BY bedrooms
ORDER BY number_of_listings DESC;

--What is the percentage of listings are owned by superhosts? Does not seem to dominate in any way. 
SELECT 
    (CAST(
        (SELECT COUNT(host_is_superhost) FROM great_listings WHERE host_is_superhost = 't') AS float) / COUNT(host_is_superhost)) * 100 AS percentage_of_superhosts
FROM great_listings;

--What type of places are these listings?
SELECT room_type,COUNT(*) AS number_of_listings
FROM great_listings gl
GROUP BY room_type
ORDER BY number_of_listings DESC;

-- I would like to see which amenities are offered by these listings and their frequency. Also I would like to see what keywords occur most often in reviews for these places.
--Both these queries are better handled by python and the nltk module. Please look at the textual analysis python file to see the analysis. 