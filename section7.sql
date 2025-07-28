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
    -- IS NOT NULL 的判断，其实是用来识别是否成功 LEFT JOIN 到订单行，而不是检查订单表中某列是不是空。
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
-- 可以把 "organic search" 理解成： 没有被广告“砸钱”的搜索流量，是用户主动搜索点进来的，是一种“自然产生”的网站访问方式。
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

