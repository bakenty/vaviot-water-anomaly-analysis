WITH positive_days AS (
  SELECT anon_id, data, daily_m3,
    data - ROW_NUMBER() OVER (
      PARTITION BY anon_id ORDER BY data
    )::integer AS grp
  FROM vaviot.v_reading_deltas
  WHERE daily_m3 > 0 AND daily_m3 <= 5
),
streaks AS (
  SELECT anon_id,
    MIN(data) AS start_date,
    MAX(data) AS end_date,
    COUNT(*) AS days_count,
    ROUND(AVG(daily_m3), 3) AS avg_daily_m3
  FROM positive_days
  GROUP BY anon_id, grp
  HAVING COUNT(*) >= 30
)
SELECT
  COUNT(*) AS streaks_count,
  COUNT(DISTINCT anon_id) AS meters_count,
  MAX(days_count) AS longest_streak
FROM streaks;

WITH positive_days AS (
  SELECT anon_id, data, daily_m3,
    data - ROW_NUMBER() OVER (
      PARTITION BY anon_id ORDER BY data
    )::integer AS grp
  FROM vaviot.v_reading_deltas
  WHERE daily_m3 > 0 AND daily_m3 <= 5
),
streaks AS (
  SELECT anon_id,
    MIN(data) AS start_date,
    MAX(data) AS end_date,
    COUNT(*) AS days_count,
    MIN(daily_m3) AS min_daily_m3,
    ROUND(AVG(daily_m3), 3) AS avg_daily_m3
  FROM positive_days
  GROUP BY anon_id, grp
  HAVING COUNT(*) >= 30
)
SELECT
  COUNT(*) AS streaks_count,
  COUNT(DISTINCT anon_id) AS meters_count,
  COUNT(*) FILTER (WHERE min_daily_m3 >= 0.05) AS streaks_min_50l,
  COUNT(DISTINCT anon_id) FILTER (WHERE min_daily_m3 >= 0.05) AS meters_min_50l,
  COUNT(*) FILTER (WHERE min_daily_m3 >= 0.1) AS streaks_min_100l,
  COUNT(DISTINCT anon_id) FILTER (WHERE min_daily_m3 >= 0.1) AS meters_min_100l
FROM streaks;

WITH positive_days AS (
  SELECT anon_id, data, daily_m3,
    data - ROW_NUMBER() OVER (
      PARTITION BY anon_id ORDER BY data
    )::integer AS grp
  FROM vaviot.v_reading_deltas
  WHERE daily_m3 > 0 AND daily_m3 <= 5
),
streaks AS (
  SELECT anon_id,
    MIN(data) AS start_date,
    MAX(data) AS end_date,
    COUNT(*) AS days_count,
    MIN(daily_m3) AS min_daily_m3,
    ROUND(AVG(daily_m3), 3) AS avg_daily_m3
  FROM positive_days
  GROUP BY anon_id, grp
  HAVING COUNT(*) >= 30
)
SELECT
  anon_id,
  start_date,
  end_date,
  days_count,
  ROUND(min_daily_m3, 3) AS min_daily_m3,
  avg_daily_m3
FROM streaks
WHERE min_daily_m3 >= 0.1
ORDER BY days_count DESC, min_daily_m3 DESC
LIMIT 15;