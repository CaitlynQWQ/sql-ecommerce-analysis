-- Use target database
USE mavenfuzzyfactory;

-- Step 1: Get the earliest pageview for each session（minimum pageview_id），Limit by date and channel
CREATE TEMPORARY TABLE first_pageviews AS
SELECT 
    wp.website_session_id,
    MIN(wp.website_pageview_id) AS min_pageview_id
FROM website_pageviews AS wp
LEFT JOIN website_sessions AS ws
    ON ws.website_session_id = wp.website_session_id
WHERE wp.created_at BETWEEN '2012-06-19' AND '2012-07-28'
  AND ws.utm_source = 'gsearch'
  AND ws.utm_campaign = 'nonbrand'
GROUP BY wp.website_session_id;

-- Step 2: 获取每个 session 的 landing page
CREATE TEMPORARY TABLE sessions_w_landing_page AS
SELECT 
    fp.website_session_id,
    wp.pageview_url AS landing_page
FROM first_pageviews AS fp
LEFT JOIN website_pageviews AS wp
    ON fp.min_pageview_id = wp.website_pageview_id
WHERE wp.pageview_url IN ('/home', '/lander-1');

-- Step 3: Count pageviews per session and identify bounce (viewed only one page) sessions
CREATE TEMPORARY TABLE bounced_sessions AS
SELECT 
    s.website_session_id,
    s.landing_page,
    COUNT(wp.website_pageview_id) AS count_of_pages_viewed
FROM sessions_w_landing_page AS s
LEFT JOIN website_pageviews AS wp
    ON s.website_session_id = wp.website_session_id
GROUP BY 
    s.website_session_id,
    s.landing_page
HAVING count_of_pages_viewed = 1;

-- Step 4: Aggregate bounce data and calculate bounce rate by landing page（bounce rate）
SELECT 
    s.landing_page,
    COUNT(DISTINCT s.website_session_id) AS total_sessions,
    COUNT(DISTINCT b.website_session_id) AS bounced_sessions,
    ROUND(COUNT(DISTINCT b.website_session_id) / COUNT(DISTINCT s.website_session_id) * 100, 2) AS bounce_rate_percent
FROM sessions_w_landing_page AS s
LEFT JOIN bounced_sessions AS b
    ON s.website_session_id = b.website_session_id
GROUP BY s.landing_page
ORDER BY bounce_rate_percent DESC;


-- FILE: section5.5.sql --

USE mavenfuzzyfactory;

-- Step 1: Find the earliest pageview_id per session and tag with week_start date
CREATE TEMPORARY TABLE first_pageviews AS
SELECT 
    wp.website_session_id,
    MIN(wp.website_pageview_id) AS min_pageview_id,
    DATE(DATE_SUB(MIN(wp.created_at), INTERVAL WEEKDAY(MIN(wp.created_at)) DAY)) AS week_start
FROM website_pageviews AS wp
INNER JOIN website_sessions AS ws
    ON ws.website_session_id = wp.website_session_id
    AND ws.utm_source = 'gsearch'
    AND ws.utm_campaign = 'nonbrand'
WHERE wp.created_at BETWEEN '2012-06-01' AND '2012-08-31'
GROUP BY wp.website_session_id;

-- Step 2: Extract the landing page (only keep /home and /lander-1), and carry the week_start information.
CREATE TEMPORARY TABLE sessions_w_landing_page AS
SELECT 
    f.website_session_id,
    wp.pageview_url AS landing_page,
    f.week_start
FROM first_pageviews AS f
LEFT JOIN website_pageviews AS wp
    ON f.min_pageview_id = wp.website_pageview_id
WHERE wp.pageview_url IN ('/home', '/lander-1');

-- Step 3: Count the number of pages viewed in each session, preserving the landing page and week start information.
CREATE TEMPORARY TABLE bounced_sessions AS
SELECT 
    s.website_session_id,
    s.landing_page,
    s.week_start,
    COUNT(wp.website_pageview_id) AS count_of_pages_viewed
FROM sessions_w_landing_page AS s
LEFT JOIN website_pageviews AS wp
    ON s.website_session_id = wp.website_session_id
GROUP BY s.website_session_id, s.landing_page, s.week_start
HAVING count_of_pages_viewed = 1;

-- Step 4: Aggregate analysis — compute bounce rate weekly and by landing page
SELECT 
    s.week_start,
    COUNT(DISTINCT s.website_session_id) AS total_sessions,
    COUNT(DISTINCT b.website_session_id) AS bounced_sessions,
    ROUND(COUNT(DISTINCT b.website_session_id) / COUNT(DISTINCT s.website_session_id) * 100, 2) AS bounce_rate_percent
FROM sessions_w_landing_page AS s
LEFT JOIN bounced_sessions AS b
    ON s.website_session_id = b.website_session_id
GROUP BY s.week_start
ORDER BY s.week_start;


-- FILE: section5.6.sql --

USE mavenfuzzyfactory;
CREATE TEMPORARY TABLE session_level_flag
SELECT
	website_session_id,
    MAX(products_page) AS product_made_it,
    MAX(mrfuzzy_page) AS mrfuzzy_made_it,
    MAX(cart_page) AS cart_made_it,
    MAX(shipping_page) AS shipping_made_it,
    MAX(billing_page) AS billing_made_it,
    MAX(thank_page) AS thankyou_made_it
FROM (
	SELECT
		website_sessions.website_session_id,
		website_pageviews.pageview_url,
		-- website_pageviews.created_at AS pageview_created_at,
		CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS products_page,
		CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page,
		CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
		CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
		CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_page,
		CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thank_page
	FROM website_pageviews
	LEFT JOIN website_sessions
		ON website_sessions.website_session_id = website_pageviews.website_session_id
	WHERE website_sessions.created_at BETWEEN '2012-08-05' AND '2012-09-05'
		AND website_sessions.utm_source = 'gsearch'
        AND website_sessions.utm_campaign = 'nonbrand'
	ORDER BY
		website_sessions.website_session_id,
		website_pageviews.created_at
) AS session_level
GROUP BY website_session_id;

CREATE TEMPORARY TABLE count_flags AS
SELECT
  COUNT(*) AS total_sessions,
  COUNT(CASE WHEN product_made_it = 1 THEN 1 END) AS to_products,
  COUNT(CASE WHEN mrfuzzy_made_it = 1 THEN 1 END) AS to_mrfuzzy,
  COUNT(CASE WHEN cart_made_it = 1 THEN 1 END) AS to_cart,
  COUNT(CASE WHEN shipping_made_it = 1 THEN 1 END) AS to_shipping,
  COUNT(CASE WHEN billing_made_it = 1 THEN 1 END) AS to_billing,
  COUNT(CASE WHEN thankyou_made_it = 1 THEN 1 END) AS to_thankyou
FROM session_level_flag;

SELECT 
  ROUND(to_products / total_sessions * 100, 2) AS to_products_rate,
  ROUND(to_mrfuzzy / to_products * 100, 2) AS to_mrfuzzy_rate,
  ROUND(to_cart / to_mrfuzzy * 100, 2) AS to_cart_rate,
  ROUND(to_shipping / to_cart * 100, 2) AS to_shipping_rate,
  ROUND(to_billing / to_shipping * 100, 2) AS to_billing_rate,
  ROUND(to_thankyou / to_billing * 100, 2) AS to_thankyou_rate
FROM count_flags;


-- FILE: section5.7.sql --

SELECT 
  bill_version,
  COUNT(DISTINCT website_session_id) AS total_sessions,
  
  COUNT(DISTINCT CASE WHEN made_it_to_thankyou = 1 THEN website_session_id END) AS completed_sessions,
  COUNT(DISTINCT website_session_id) - COUNT(DISTINCT CASE WHEN made_it_to_thankyou = 1 THEN website_session_id END) /
	COUNT(DISTINCT website_session_id) AS bounce_rate_percent
FROM (
  -- Note：compare two different versions的billing pagejust need to从billing page阶段开始即可
  SELECT
    wp.website_session_id,
    CASE 
      WHEN wp.pageview_url = '/billing' THEN 1
      WHEN wp.pageview_url = '/billing-2' THEN 2
      ELSE NULL
    END AS bill_version,
    MAX(CASE WHEN wp2.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END) AS made_it_to_thankyou
  FROM website_pageviews AS wp
  LEFT JOIN website_pageviews AS wp2
    ON wp.website_session_id = wp2.website_session_id
  WHERE wp.pageview_url IN ('/billing', '/billing-2') AND wp.created_at <= '2012-11-10' AND wp.website_pageview_id >= '53550'
  GROUP BY wp.website_session_id, bill_version
) AS billing_funnel
WHERE bill_version IS NOT NULL
GROUP BY bill_version;


-- FILE: section5_demo.sql --

USE mavenfuzzyfactory;
-- 该 session whetherWhether these pages were visited; 1 means visited。
CREATE TEMPORARY TABLE session_level_flag_demo
SELECT
    website_session_id,
    MAX(products_page) AS product_made_it, -- MAX() ： determine whether the user visited this page at least once用户whether“at least once”到达该页面。
    MAX(mrfuzzy_page) AS mrfuzzy_made_it,
    MAX(cart_page) AS cart_made_it
FROM (
		SELECT
		website_sessions.website_session_id,
		website_pageviews.pageview_url,
		website_pageviews.created_at AS pageview_created_at,
		CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS products_page,
		CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page,
		CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page
	FROM website_sessions
	LEFT JOIN website_pageviews
		ON website_sessions.website_session_id = website_pageviews.website_session_id
	WHERE website_sessions.created_at BETWEEN '2014-01-01' AND '2014-02-01'
	  AND website_pageviews.pageview_url IN ('/lander-2', '/products', '/the-original-mr-fuzzy', '/cart')
	ORDER BY
		website_sessions.website_session_id,
		website_pageviews.created_at
) AS pageview_level
GROUP BY website_session_id;

SELECT
    COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END) AS to_products,
    COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) AS to_mrfuzzy,
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS to_cart
FROM session_level_flag_demo;
-- 计算每一个界面之间的conversion rate
SELECT
    COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id END) AS to_products,
        COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id END) / 
        COUNT(DISTINCT website_session_id) AS to_products_rate,
    COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id END) AS to_mrfuzzy,
        COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id END) / 
        COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id END) AS to_mrfuzzy_rate,
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id END) AS to_cart,
        COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id END) / 
        COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id END) AS to_cart_rate
FROM session_level_flag_demo;



-- FILE: section5_demo00.sql --

USE mavenfuzzyfactory;

-- How many times each URL was viewed
SELECT
    pageview_url,
    COUNT(DISTINCT website_pageview_id) AS pvc
FROM website_pageviews
WHERE website_pageview_id < 1000
GROUP BY pageview_url
ORDER BY pvc DESC;

-- How many pageviews each session contains
SELECT 
    website_session_id,
    COUNT(DISTINCT website_pageview_id) AS pvc
FROM website_pageviews
WHERE website_pageview_id < 1000
GROUP BY website_session_id
ORDER BY pvc;

-- Each session may contain multiple pageviews and corresponding URLs
-- The URL associated with the earliest timestamp in each session is considered the landing page

-- Option 1: Subquery using created_at to identify the landing page
SELECT 
    website_session_id,
    created_at AS landing_time,
    pageview_url AS landing_page
FROM website_pageviews
WHERE website_pageview_id < 1000
  AND (website_session_id, created_at) IN (
        SELECT 
            website_session_id, 
            MIN(created_at)
        FROM website_pageviews
        WHERE website_pageview_id < 1000
        GROUP BY website_session_id
    );

-- Option 2: Use a temporary table
-- Identify the landing page using the smallest pageview_id within each session
CREATE TEMPORARY TABLE earliest_page AS
SELECT 
    website_session_id,
    MIN(website_pageview_id) AS min_pvid
FROM website_pageviews
WHERE website_pageview_id < 1000
GROUP BY website_session_id;

-- Join with the original table to get the landing page URL and count session hits per URL
SELECT
    COUNT(DISTINCT ep.website_session_id) AS hit_count, 
    wp.pageview_url AS landing_page
FROM earliest_page AS ep
LEFT JOIN website_pageviews AS wp 
    ON wp.website_pageview_id = ep.min_pvid
GROUP BY wp.pageview_url;

-- Bounce Rate = Number of sessions with only one pageview / Total number of sessions
-- Step-by-step:
-- 1. Identify landing pages of sessions with only one pageview
-- 2. Retrieve all sessions that landed on those pages
-- 3. Compute: (sessions with only one pageview) / (total sessions per landing page)

-- Step 1: Get the first pageview (landing page) for each session within a specific date range
CREATE TEMPORARY TABLE first_pageviews_demo AS
SELECT 
    wp.website_session_id,
    MIN(wp.website_pageview_id) AS min_pvid
FROM website_pageviews AS wp
INNER JOIN website_sessions AS ws
    ON ws.website_session_id = wp.website_session_id
    AND ws.created_at BETWEEN '2014-01-01' AND '2014-02-01'
GROUP BY wp.website_session_id;

-- Step 2: Associate each session with its landing page URL
CREATE TEMPORARY TABLE sessions_with_landing_page AS
SELECT
    fpd.website_session_id,
    wp.pageview_url AS landing_page
FROM first_pageviews_demo AS fpd
LEFT JOIN website_pageviews AS wp
    ON wp.website_pageview_id = fpd.min_pvid;

-- Step 3: Count how many pageviews each session had;
-- Filter to keep only sessions that viewed exactly one page (i.e., bounced sessions)
CREATE TEMPORARY TABLE bounced_sessions AS
SELECT 
    swlp.website_session_id,
    swlp.landing_page,
    COUNT(wp.website_pageview_id) AS count_of_pages_viewed
FROM sessions_with_landing_page AS swlp
LEFT JOIN website_pageviews AS wp
    ON wp.website_session_id = swlp.website_session_id
GROUP BY swlp.website_session_id, swlp.landing_page
HAVING count_of_pages_viewed = 1;

-- Final Output: Calculate total sessions, bounced sessions, and bounce rate for each landing page
SELECT 
    swlp.landing_page,
    COUNT(DISTINCT swlp.website_session_id) AS sessions,
    COUNT(DISTINCT bs.website_session_id) AS bounced_sessions,
    ROUND(
        COUNT(DISTINCT bs.website_session_id) * 1.0 / COUNT(DISTINCT swlp.website_session_id), 
        4
    ) AS bounce_rate
FROM sessions_with_landing_page AS swlp
LEFT JOIN bounced_sessions AS bs
    ON swlp.website_session_id = bs.website_session_id
GROUP BY swlp.landing_page
ORDER BY sessions DESC;



-- Build and Test Conversion Funnel



-- FILE: section7.sql --

/*
Analyze Channel Portfolios
*/
USE mavenfuzzyfactory;

SELECT website_sessions.utm_content,
COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
COUNT(DISTINCT orders.order_id) AS ords,
COUNT(DISTINCT orders.order_id) / COUNT(DISTINCT website_sessions.website_session_id) AS coversion_rate
FROM website_sessions
LEFT JOIN orders ON orders.website_session_id = website_sessions.website_session_id
GROUP BY 1
ORDER BY sessions;

-- Practice 1
SELECT 
-- yearweek(created_at) as yrwk,
MIN(DATE(created_at)) as week_start_date,
COUNT(distinct website_session_id) as total_sessions,
COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' THEN website_session_id ELSE NULL END) AS gsearch,
COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' THEN website_session_id ELSE NULL END) AS bsearch
FROM website_sessions
WHERE created_at > '2012-08-22'
	AND created_at < '2012-11-29'
    AND utm_campaign = 'nonbrand'
GROUP BY yearweek(created_at);

-- Practice 2
SELECT utm_source,
COUNT(DISTINCT website_sessions.website_session_id) as web,
COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN website_session_id ELSE NULL END) AS mobile_session,
COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN website_session_id ELSE NULL END) / COUNT(DISTINCT website_sessions.website_session_id) AS pct_mobile
FROM website_sessions
WHERE created_at > '2012-08-22'
	AND created_at < '2012-11-30'
    AND utm_campaign = 'nonbrand'
GROUP BY utm_source;

-- Practice 3
SELECT 
    ws.device_type,
    ws.utm_source,
    COUNT(DISTINCT o.order_id) AS order_count,
    COUNT(DISTINCT ws.website_session_id) AS sessions,
    COUNT(DISTINCT o.order_id) / COUNT(DISTINCT ws.website_session_id) AS cvr
FROM website_sessions AS ws
LEFT JOIN orders AS o 
    ON o.website_session_id = ws.website_session_id
WHERE ws.created_at BETWEEN '2012-08-22' AND '2012-09-18' AND utm_campaign = 'nonbrand'
GROUP BY ws.device_type, ws.utm_source;

SELECT 
    ws.device_type,
    ws.utm_source,
    COUNT(DISTINCT CASE WHEN o.website_session_id IS NOT NULL THEN ws.website_session_id END) AS order_count,
    -- IS NOT NULL 的判断，actually is用来识别whether成功 LEFT JOIN 到订单行，而不是检查订单表中某列是不是空。
    COUNT(DISTINCT ws.website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN o.website_session_id IS NOT NULL THEN ws.website_session_id END) * 1.0 
        / COUNT(DISTINCT ws.website_session_id) AS cvr
FROM website_sessions AS ws
LEFT JOIN orders AS o 
    ON o.website_session_id = ws.website_session_id
WHERE ws.created_at BETWEEN '2012-08-22' AND '2012-09-18' AND utm_campaign = 'nonbrand'
GROUP BY ws.device_type, ws.utm_source;

-- Pratice 4
SELECT 
MIN(DATE(created_at)) as week_start_date,
COUNT(distinct website_session_id) as total_sessions,
COUNT(DISTINCT CASE WHEN device_type = 'mobile' AND utm_source = 'gsearch' THEN website_session_id ELSE NULL END) AS gm_session,
COUNT(DISTINCT CASE WHEN device_type = 'mobile' AND utm_source = 'bsearch' THEN website_session_id ELSE NULL END) AS bm_session,
COUNT(DISTINCT CASE WHEN device_type = 'desktop' AND utm_source = 'bsearch' THEN website_session_id ELSE NULL END) AS bd_session,
COUNT(DISTINCT CASE WHEN device_type = 'desktop' AND utm_source = 'gsearch' THEN website_session_id ELSE NULL END) AS bd_session
FROM website_sessions
WHERE utm_campaign = 'nonbrand' AND created_at < '2012-11-04'
GROUP BY yearweek(created_at);


-- Practice 5
-- can be understood as "organic search" understand as： 没有被广告“砸钱”的搜索流量，是用户主动搜索点进来的，是一种“自然产生”的网站访问方式。
SELECT DISTINCT 
	utm_source,
    utm_campaign,
    http_referer
FROM website_sessions
WHERE created_at < '2012-12-23';

SELECT DISTINCT
  CASE
    WHEN utm_source IS NULL AND http_referer IN ('https://www.gsearch.com', 'https://www.bsearch.com') THEN 'organic_search'
    WHEN utm_campaign = 'nonbrand' THEN 'paid_nonbrand'
    WHEN utm_campaign = 'brand' THEN 'paid_brand'
    WHEN utm_source IS NULL AND http_referer IS NULL THEN 'direct_type_in'
  END AS channel_group,
  utm_source,
  utm_campaign,
  http_referer
FROM website_sessions
WHERE created_at < '2012-12-23';

-- FILE: mid-course.sql --

-- Mid-Course Project Question
-- 1. Gsearch seems to be the biggest driver of our business.
-- Could you pull monthly trends for gsearch sessions and orders so that we can showcase the growth there?
USE mavenfuzzyfactory;
SELECT 
    COUNT(DISTINCT ws.website_session_id) AS session_count,
    COUNT(DISTINCT o.order_id) AS order_count,
    COUNT(DISTINCT o.order_id) / COUNT(DISTINCT ws.website_session_id) * 100 AS cvr,
    DATE_FORMAT(ws.created_at, '%Y-%m') AS years_months
FROM website_sessions AS ws
LEFT JOIN orders AS o
    ON o.website_session_id = ws.website_session_id
WHERE ws.utm_source = 'gsearch'
GROUP BY years_months
ORDER BY years_months;

-- 2. Next, it would be great to see a similar monthly trend for Gsearch,
-- but this time splitting out nonbrand and brand campaigns separately.
-- I am wondering if brand is picking up at all. If so, this is a good story to tell.
SELECT 
	DATE_FORMAT(ws.created_at, '%Y-%m') AS years_months,
    ws.utm_campaign,
    COUNT(DISTINCT ws.website_session_id) AS session_count,
    COUNT(DISTINCT o.order_id) AS order_count,
    COUNT(DISTINCT o.order_id) / COUNT(DISTINCT ws.website_session_id) * 100 AS cvr
FROM website_sessions AS ws
LEFT JOIN orders AS o
    ON o.website_session_id = ws.website_session_id
WHERE ws.utm_source = 'gsearch'
GROUP BY years_months, ws.utm_campaign
ORDER BY years_months;

-- 3. While we’re on Gsearch, could you dive into nonbrand, and pull monthly sessions and orders split by device type?
-- I want to flex our analytical muscles a little and show the board we really know our traffic sources.
SELECT 
    DATE_FORMAT(ws.created_at, '%Y-%m') AS years_months,
    ws.device_type,
    COUNT(DISTINCT ws.website_session_id) AS session_count,
    COUNT(DISTINCT o.order_id) AS order_count,
    ROUND(COUNT(DISTINCT o.order_id) / COUNT(DISTINCT ws.website_session_id) * 100, 2) AS cvr_percent
FROM website_sessions AS ws 
LEFT JOIN orders AS o
    ON ws.website_session_id = o.website_session_id
WHERE ws.utm_source = 'gsearch'
  AND ws.utm_campaign = 'nonbrand'
GROUP BY years_months, ws.device_type
ORDER BY years_months, ws.device_type;

-- 4. I’m worried that one of our more pessimistic board members may be concerned about the large % of traffic from Gsearch.
-- Can you pull monthly trends for Gsearch, alongside monthly trends for each of our other channels?
SELECT 
    DATE_FORMAT(ws.created_at, '%Y-%m') AS years_months,
    ws.utm_source AS channel_type,
    COUNT(DISTINCT ws.website_session_id) AS session_count,
    COUNT(DISTINCT o.order_id) AS order_count,
    ROUND(COUNT(DISTINCT o.order_id) / COUNT(DISTINCT ws.website_session_id) * 100, 2) AS cvr_percent
FROM website_sessions AS ws
LEFT JOIN orders AS o
    ON ws.website_session_id = o.website_session_id
GROUP BY years_months, channel_type
ORDER BY years_months, channel_type;

-- 5. I’d like to tell the story of our website performance improvements over the course of the first 8 months.
-- Could you pull session to order conversion rates, by month?
SELECT 
    DATE_FORMAT(ws.created_at, '%Y-%m') AS years_months,
	COUNT(DISTINCT ws.website_session_id) AS session_count,
    COUNT(DISTINCT o.order_id) AS order_count,
    ROUND(COUNT(DISTINCT o.order_id) / COUNT(DISTINCT ws.website_session_id) * 100, 2) AS cvr_percent
FROM website_sessions AS ws
LEFT JOIN orders AS o
    ON ws.website_session_id = o.website_session_id
WHERE ws.created_at BETWEEN '2012-03-01' AND '2012-11-30'
GROUP BY years_months
ORDER BY years_months;

-- 6. For the gsearch lander test, please estimate the revenue that test earned us
-- (Hint: Look at the increase in CVR from the test (Jun 19 – Jul 28),
-- CVR by landing page during test (based on first pageview)
SELECT
    wp.pageview_url AS landing_page,
    COUNT(DISTINCT ws.website_session_id) AS sessions,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(COUNT(DISTINCT o.order_id) / COUNT(DISTINCT ws.website_session_id) * 100, 2) AS cvr_percent
FROM website_sessions AS ws
JOIN (
    SELECT website_session_id, pageview_url
    FROM website_pageviews
    WHERE website_pageview_id IN (
        SELECT MIN(website_pageview_id)
        FROM website_pageviews
        WHERE created_at BETWEEN '2012-06-19' AND '2012-07-28'
        GROUP BY website_session_id
    )
) AS wp
    ON ws.website_session_id = wp.website_session_id
LEFT JOIN orders AS o
    ON ws.website_session_id = o.website_session_id
WHERE ws.utm_source = 'gsearch'
  AND ws.utm_campaign = 'nonbrand'
GROUP BY wp.pageview_url;

-- 7. For the landing page test you analyzed previously,
-- it would be great to show a full conversion funnel from each of the two pages to orders.
-- You can use the same period you analyzed last time (Jun 19 – Jul 28).

SELECT
	website_session_id,
    MAX(products_page) AS product_made_it,
    MAX(mrfuzzy_page) AS mrfuzzy_made_it,
    MAX(cart_page) AS cart_made_it,
    MAX(shipping_page) AS shipping_made_it,
    MAX(billing_page) AS billing_made_it,
    MAX(thank_page) AS thankyou_made_it
FROM (
	SELECT
		website_sessions.website_session_id,
		website_pageviews.pageview_url,
		-- website_pageviews.created_at AS pageview_created_at,
		CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS products_page,
		CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page,
		CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
		CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
		CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_page,
		CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thank_page
	FROM website_pageviews
	LEFT JOIN website_sessions
		ON website_sessions.website_session_id = website_pageviews.website_session_id
	WHERE website_sessions.created_at BETWEEN '2012-06-19' AND '2012-07-28'
		AND website_sessions.utm_source = 'gsearch'
        AND website_sessions.utm_campaign = 'nonbrand'
	ORDER BY
		website_sessions.website_session_id,
		website_pageviews.created_at
) AS session_level
GROUP BY website_session_id;

/*
8.I’d love for you to quantify the impact of our billing test, as well.
Please analyze the lift generated from the test (Sep 10 – Nov 10), in terms of revenue per billing page session,
and then pull the number of billing page sessions in the past month to understand monthly impact.
*/

