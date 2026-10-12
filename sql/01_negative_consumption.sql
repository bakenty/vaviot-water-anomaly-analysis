SELECT
  COUNT(*) FILTER (WHERE delta_m3 < 0) AS negative_intervals,
  COUNT(DISTINCT anon_id) FILTER (WHERE delta_m3 < 0) AS negative_meters,
  COUNT(*) FILTER (WHERE daily_m3 < 0) AS negative_daily_intervals,
  COUNT(DISTINCT anon_id) FILTER (WHERE daily_m3 < 0) AS negative_daily_meters
FROM vaviot.v_reading_deltas;

SELECT
  anon_id,
  COUNT(*) AS negative_count,
  MIN(delta_m3) AS largest_drop_m3,
  MIN(data) AS first_date,
  MAX(data) AS last_date
FROM vaviot.v_reading_deltas
WHERE delta_m3 < 0
GROUP BY anon_id
ORDER BY negative_count DESC, largest_drop_m3 ASC
LIMIT 20;

SELECT
  COUNT(*) AS negative_intervals,
  COUNT(DISTINCT d.anon_id) AS negative_meters,
  COUNT(*) FILTER (WHERE EXISTS (
    SELECT 1 FROM vaviot.sobytiya s
    WHERE s.anon_id = d.anon_id
      AND s.sobytie = 'сброс'
      AND s.data BETWEEN d.prev_date AND d.data
  )) AS intervals_with_reset,
  COUNT(DISTINCT d.anon_id) FILTER (WHERE EXISTS (
    SELECT 1 FROM vaviot.sobytiya s
    WHERE s.anon_id = d.anon_id
      AND s.sobytie = 'сброс'
      AND s.data BETWEEN d.prev_date AND d.data
  )) AS meters_with_reset
FROM vaviot.v_reading_deltas d
WHERE d.delta_m3 < 0;

WITH jumps AS (
  SELECT d.anon_id, p.model, d.delta_m3,
    ROUND(ABS(d.delta_m3) / 327.68) AS multiple
  FROM vaviot.v_reading_deltas d
  JOIN vaviot.pribory p ON p.anon_id = d.anon_id
  WHERE d.delta_m3 <> 0
)
SELECT
  model,
  CASE WHEN delta_m3 < 0 THEN 'negative' ELSE 'positive' END AS direction,
  COUNT(*) AS intervals,
  COUNT(DISTINCT anon_id) AS meters
FROM jumps
WHERE multiple BETWEEN 1 AND 20
  AND ABS(ABS(delta_m3) - multiple * 327.68) <= 0.5
GROUP BY model, direction
ORDER BY model, direction;