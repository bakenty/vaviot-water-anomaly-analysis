SELECT
  COUNT(*) AS magnet_events,
  COUNT(DISTINCT anon_id) AS magnet_meters
FROM vaviot.sobytiya
WHERE sobytie = 'магнит';

WITH magnet AS (
  SELECT DISTINCT anon_id, data
  FROM vaviot.sobytiya
  WHERE sobytie = 'магнит'
)
SELECT
  COUNT(*) AS negative_intervals,
  COUNT(DISTINCT d.anon_id) AS negative_meters,
  COUNT(*) FILTER (WHERE EXISTS (
    SELECT 1 FROM magnet m
    WHERE m.anon_id = d.anon_id
      AND m.data BETWEEN d.prev_date AND d.data
  )) AS intervals_with_magnet,
  COUNT(DISTINCT d.anon_id) FILTER (WHERE EXISTS (
    SELECT 1 FROM magnet m
    WHERE m.anon_id = d.anon_id
      AND m.data BETWEEN d.prev_date AND d.data
  )) AS meters_with_magnet
FROM vaviot.v_reading_deltas d
WHERE d.delta_m3 < -0.000000001;

WITH magnet_meters AS (
  SELECT DISTINCT anon_id
  FROM vaviot.sobytiya
  WHERE sobytie = 'магнит'
)
SELECT
  CASE WHEN m.anon_id IS NOT NULL THEN 'magnet'
       ELSE 'no_magnet' END AS meter_group,
  COUNT(*) AS intervals,
  COUNT(*) FILTER (
    WHERE d.delta_m3 < -0.000000001
  ) AS negative_intervals,
  COUNT(DISTINCT d.anon_id) AS meters,
  ROUND(
    100.0 * COUNT(*) FILTER (
      WHERE d.delta_m3 < -0.000000001
    ) / NULLIF(COUNT(*), 0), 3
  ) AS negative_pct
FROM vaviot.v_reading_deltas d
LEFT JOIN magnet_meters m ON m.anon_id = d.anon_id
WHERE d.prev_date IS NOT NULL
GROUP BY meter_group
ORDER BY meter_group;

WITH first_magnet AS (
  SELECT anon_id, MIN(data) AS magnet_date
  FROM vaviot.sobytiya
  WHERE sobytie = 'магнит'
  GROUP BY anon_id
),
periods AS (
  SELECT
    m.anon_id,
    m.magnet_date,
    COUNT(*) FILTER (
      WHERE d.data BETWEEN m.magnet_date - 14 AND m.magnet_date - 1
    ) AS before_days,
    COUNT(*) FILTER (
      WHERE d.data BETWEEN m.magnet_date + 1 AND m.magnet_date + 14
    ) AS after_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (
      ORDER BY d.daily_m3
    ) FILTER (
      WHERE d.data BETWEEN m.magnet_date - 14 AND m.magnet_date - 1
    ) AS median_before,
    PERCENTILE_CONT(0.5) WITHIN GROUP (
      ORDER BY d.daily_m3
    ) FILTER (
      WHERE d.data BETWEEN m.magnet_date + 1 AND m.magnet_date + 14
    ) AS median_after
  FROM first_magnet m
  JOIN vaviot.v_reading_deltas d
    ON d.anon_id = m.anon_id
   AND d.data BETWEEN m.magnet_date - 14 AND m.magnet_date + 14
   AND d.daily_m3 BETWEEN 0 AND 5
  GROUP BY m.anon_id, m.magnet_date
)
SELECT
  COUNT(*) AS total_magnet_meters,
  COUNT(*) FILTER (
    WHERE before_days = 14 AND after_days = 14
  ) AS meters_with_full_windows,
  COUNT(*) FILTER (
    WHERE before_days = 14
      AND after_days = 14
      AND median_before >= 0.1
  ) AS eligible_meters,
  COUNT(*) FILTER (
    WHERE before_days = 14
      AND after_days = 14
      AND median_before >= 0.1
      AND median_after <= median_before * 0.5
      AND median_before - median_after >= 0.1
  ) AS meters_with_drop
FROM periods;

WITH first_magnet AS (
  SELECT anon_id, MIN(data) AS magnet_date
  FROM vaviot.sobytiya
  WHERE sobytie = 'магнит'
  GROUP BY anon_id
),
periods AS (
  SELECT
    m.anon_id,
    m.magnet_date,
    COUNT(*) FILTER (
      WHERE d.data BETWEEN m.magnet_date - 14 AND m.magnet_date - 1
    ) AS before_days,
    COUNT(*) FILTER (
      WHERE d.data BETWEEN m.magnet_date + 1 AND m.magnet_date + 14
    ) AS after_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (
      ORDER BY d.daily_m3
    ) FILTER (
      WHERE d.data BETWEEN m.magnet_date - 14 AND m.magnet_date - 1
    ) AS median_before,
    PERCENTILE_CONT(0.5) WITHIN GROUP (
      ORDER BY d.daily_m3
    ) FILTER (
      WHERE d.data BETWEEN m.magnet_date + 1 AND m.magnet_date + 14
    ) AS median_after
  FROM first_magnet m
  JOIN vaviot.v_reading_deltas d
    ON d.anon_id = m.anon_id
   AND d.data BETWEEN m.magnet_date - 14 AND m.magnet_date + 14
   AND d.daily_m3 BETWEEN 0 AND 5
  GROUP BY m.anon_id, m.magnet_date
)
SELECT
  anon_id,
  magnet_date,
  ROUND(median_before::numeric, 3) AS median_before,
  ROUND(median_after::numeric, 3) AS median_after,
  ROUND(
    (100 * (median_after - median_before)
    / NULLIF(median_before, 0))::numeric, 1
  ) AS change_pct
FROM periods
WHERE before_days = 14
  AND after_days = 14
  AND median_before >= 0.1
  AND median_after <= median_before * 0.5
  AND median_before - median_after >= 0.1
ORDER BY change_pct
LIMIT 15;