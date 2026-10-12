SELECT
  COUNT(*) AS total_days,
  ROUND(AVG(daily_m3), 3) AS avg_m3,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY daily_m3)::numeric, 3) AS median_m3,
  ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY daily_m3)::numeric, 3) AS p95_m3,
  ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY daily_m3)::numeric, 3) AS p99_m3,
  MAX(daily_m3) AS max_m3
FROM vaviot.v_reading_deltas
WHERE daily_m3 >= 0;

WITH baseline AS (
  SELECT anon_id,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY daily_m3) AS median_m3,
    COUNT(*) AS valid_days
  FROM vaviot.v_reading_deltas
  WHERE daily_m3 >= 0
  GROUP BY anon_id
)
SELECT
  COUNT(*) AS spike_days,
  COUNT(DISTINCT d.anon_id) AS spike_meters
FROM vaviot.v_reading_deltas d
JOIN baseline b ON d.anon_id = b.anon_id
WHERE d.daily_m3 > 5
  AND b.valid_days >= 30
  AND b.median_m3 > 0
  AND d.daily_m3 > b.median_m3 * 10;

WITH baseline AS (
  SELECT anon_id,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY daily_m3) AS median_m3,
    COUNT(*) AS valid_days
  FROM vaviot.v_reading_deltas
  WHERE daily_m3 >= 0
  GROUP BY anon_id
)
SELECT
  d.anon_id,
  d.data,
  ROUND(d.daily_m3, 3) AS daily_m3,
  ROUND(b.median_m3::numeric, 3) AS median_m3,
  ROUND((d.daily_m3 / b.median_m3)::numeric, 1) AS spike_ratio
FROM vaviot.v_reading_deltas d
JOIN baseline b ON d.anon_id = b.anon_id
WHERE d.daily_m3 > 5
  AND b.valid_days >= 30
  AND b.median_m3 > 0
  AND d.daily_m3 > b.median_m3 * 10
ORDER BY d.daily_m3 DESC
LIMIT 15;