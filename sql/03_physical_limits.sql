SELECT
  p.model,
  COUNT(DISTINCT d.anon_id) AS meters,
  ROUND(MAX(d.daily_m3), 3) AS max_daily_m3,
  COUNT(*) FILTER (WHERE d.daily_m3 > 100) AS days_over_100,
  COUNT(DISTINCT d.anon_id) FILTER (WHERE d.daily_m3 > 100) AS meters_over_100
FROM vaviot.v_reading_deltas d
JOIN vaviot.pribory p ON p.anon_id = d.anon_id
WHERE d.daily_m3 >= 0
GROUP BY p.model
ORDER BY max_daily_m3 DESC;

SELECT
  COUNT(*) AS impossible_days,
  COUNT(DISTINCT d.anon_id) AS impossible_meters,
  ROUND(MAX(d.daily_m3), 3) AS max_daily_m3
FROM vaviot.v_reading_deltas d
JOIN vaviot.pribory p ON p.anon_id = d.anon_id
WHERE p.model LIKE '%D15%'
  AND d.daily_m3 > 72;

SELECT
  d.anon_id,
  p.model,
  d.data,
  ROUND(d.daily_m3, 3) AS daily_m3,
  ROUND(d.daily_m3 / 72, 1) AS times_over_limit
FROM vaviot.v_reading_deltas d
JOIN vaviot.pribory p ON p.anon_id = d.anon_id
WHERE p.model LIKE '%D15%'
  AND d.daily_m3 > 72
ORDER BY d.daily_m3 DESC
LIMIT 15;