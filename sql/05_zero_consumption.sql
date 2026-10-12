SELECT
  COUNT(*) AS zero_days,
  COUNT(DISTINCT anon_id) AS zero_meters,
  COUNT(*) FILTER (WHERE paketov_za_sutki > 0) AS zero_days_with_packets,
  COUNT(DISTINCT anon_id) FILTER (WHERE paketov_za_sutki > 0) AS meters_with_packets
FROM vaviot.v_reading_deltas
WHERE daily_m3 = 0;

WITH zero_days AS (
  SELECT anon_id, data, paketov_za_sutki,
    data - ROW_NUMBER() OVER (
      PARTITION BY anon_id ORDER BY data
    )::integer AS grp
  FROM vaviot.v_reading_deltas
  WHERE daily_m3 = 0
    AND paketov_za_sutki > 0
),
streaks AS (
  SELECT anon_id,
    MIN(data) AS start_date,
    MAX(data) AS end_date,
    COUNT(*) AS days_count,
    SUM(paketov_za_sutki) AS total_packets
  FROM zero_days
  GROUP BY anon_id, grp
  HAVING COUNT(*) >= 7
)
SELECT
  COUNT(*) AS zero_streaks,
  COUNT(DISTINCT anon_id) AS zero_meters,
  MAX(days_count) AS longest_streak
FROM streaks;

WITH zero_days AS (
  SELECT anon_id, data, paketov_za_sutki,
    data - ROW_NUMBER() OVER (
      PARTITION BY anon_id ORDER BY data
    )::integer AS grp
  FROM vaviot.v_reading_deltas
  WHERE daily_m3 = 0
    AND paketov_za_sutki > 0
),
streaks AS (
  SELECT anon_id,
    MIN(data) AS start_date,
    MAX(data) AS end_date,
    COUNT(*) AS days_count,
    SUM(paketov_za_sutki) AS total_packets
  FROM zero_days
  GROUP BY anon_id, grp
  HAVING COUNT(*) >= 7
)
SELECT
  anon_id,
  start_date,
  end_date,
  days_count,
  total_packets
FROM streaks
ORDER BY days_count DESC, total_packets DESC
LIMIT 15;