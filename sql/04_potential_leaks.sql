WITH valid_days AS (
  SELECT anon_id, data, daily_m3,
    data - ROW_NUMBER() OVER (
      PARTITION BY anon_id ORDER BY data
    )::integer AS grp
  FROM vaviot.v_reading_deltas
  WHERE daily_m3 BETWEEN 0.1 AND 5
),
streaks AS (
  SELECT anon_id,
    MIN(data) AS start_date,
    MAX(data) AS end_date,
    COUNT(*) AS days_count,
    MIN(daily_m3) AS min_daily_m3,
    ROUND(AVG(daily_m3), 3) AS avg_daily_m3
  FROM valid_days
  GROUP BY anon_id, grp
  HAVING COUNT(*) >= 30
)
SELECT
  COUNT(*) AS leak_periods,
  COUNT(DISTINCT anon_id) AS leak_meters,
  MAX(days_count) AS longest_period
FROM streaks;

WITH valid_days AS (
  SELECT anon_id, data, daily_m3,
    data - ROW_NUMBER() OVER (
      PARTITION BY anon_id ORDER BY data
    )::integer AS grp
  FROM vaviot.v_reading_deltas
  WHERE daily_m3 BETWEEN 0.1 AND 5
),
streaks AS (
  SELECT anon_id,
    MIN(data) AS start_date,
    MAX(data) AS end_date,
    COUNT(*) AS days_count,
    MIN(daily_m3) AS min_daily_m3,
    ROUND(AVG(daily_m3), 3) AS avg_daily_m3
  FROM valid_days
  GROUP BY anon_id, grp
  HAVING COUNT(*) >= 30
)
SELECT
  anon_id, start_date, end_date,
  days_count, min_daily_m3, avg_daily_m3
FROM streaks
ORDER BY days_count DESC, min_daily_m3 DESC
LIMIT 20;