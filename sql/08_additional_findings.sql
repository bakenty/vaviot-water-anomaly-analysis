--- 1. Повторяющиеся скачки около 327.68 м³
WITH jumps AS (
  SELECT d.anon_id, p.model, d.delta_m3,
    ROUND(ABS(d.delta_m3) / 327.68) AS multiple
  FROM vaviot.v_reading_deltas d
  JOIN vaviot.pribory p ON p.anon_id = d.anon_id
  WHERE d.delta_m3 <> 0
)
SELECT
  CASE WHEN delta_m3 < 0 THEN 'negative' ELSE 'positive' END AS direction,
  COUNT(*) AS intervals,
  COUNT(DISTINCT anon_id) AS meters
FROM jumps
WHERE multiple BETWEEN 1 AND 20
  AND ABS(ABS(delta_m3) - multiple * 327.68) <= 0.5
GROUP BY direction
ORDER BY direction;
---2. Скопление экстремальных скачков в одни даты
SELECT
  data,
  COUNT(*) AS extreme_intervals,
  COUNT(DISTINCT anon_id) AS meters,
  ROUND(MAX(daily_m3), 3) AS max_daily_m3
FROM vaviot.v_reading_deltas
WHERE daily_m3 > 100
GROUP BY data
HAVING COUNT(DISTINCT anon_id) >= 2
ORDER BY meters DESC, data
LIMIT 20;
---3. Концентрация аномалий по моделям
WITH meter_flags AS (
  SELECT
    anon_id,
    BOOL_OR(delta_m3 < 0) AS has_negative
  FROM vaviot.v_reading_deltas
  GROUP BY anon_id
)
SELECT
  COALESCE(NULLIF(TRIM(p.model), ''), 'unknown') AS model,
  COUNT(*) AS total_meters,
  COUNT(*) FILTER (WHERE f.has_negative) AS negative_meters,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE f.has_negative)
    / NULLIF(COUNT(*), 0), 2
  ) AS negative_pct
FROM vaviot.pribory p
LEFT JOIN meter_flags f ON p.anon_id = f.anon_id
GROUP BY COALESCE(NULLIF(TRIM(p.model), ''), 'unknown')
ORDER BY negative_pct DESC;