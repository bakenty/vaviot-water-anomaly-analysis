CREATE OR REPLACE VIEW vaviot.v_level_changes AS
WITH valid AS (
  SELECT anon_id, data, daily_m3
  FROM vaviot.v_reading_deltas
  WHERE daily_m3 BETWEEN 0 AND 5
),
windows AS (
  SELECT
    a.anon_id,
    a.data AS change_date,
    COUNT(*) FILTER (
      WHERE b.data BETWEEN a.data - 14 AND a.data - 1
    ) AS before_days,
    COUNT(*) FILTER (
      WHERE b.data BETWEEN a.data AND a.data + 13
    ) AS after_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (
      ORDER BY b.daily_m3
    ) FILTER (
      WHERE b.data BETWEEN a.data - 14 AND a.data - 1
    ) AS median_before,
    PERCENTILE_CONT(0.5) WITHIN GROUP (
      ORDER BY b.daily_m3
    ) FILTER (
      WHERE b.data BETWEEN a.data AND a.data + 13
    ) AS median_after
  FROM valid a
  JOIN valid b ON b.anon_id = a.anon_id
    AND b.data BETWEEN a.data - 14 AND a.data + 13
  GROUP BY a.anon_id, a.data
),
candidates AS (
  SELECT *,
    CASE
      WHEN median_after > median_before THEN 'increase'
      ELSE 'decrease'
    END AS direction
  FROM windows
  WHERE before_days = 14
    AND after_days = 14
    AND ABS(median_after - median_before) >= 0.1
    AND (
      median_after >= GREATEST(median_before, 0.01) * 2
      OR median_before >= GREATEST(median_after, 0.01) * 2
    )
)
SELECT
  c.anon_id,
  c.change_date,
  c.direction,
  ROUND(c.median_before::numeric, 3) AS median_before,
  ROUND(c.median_after::numeric, 3) AS median_after,
  COUNT(*) FILTER (
    WHERE (
      c.direction = 'increase'
      AND v.daily_m3 > (c.median_before + c.median_after) / 2
    ) OR (
      c.direction = 'decrease'
      AND v.daily_m3 < (c.median_before + c.median_after) / 2
    )
  ) AS stable_days
FROM candidates c
JOIN valid v ON v.anon_id = c.anon_id
  AND v.data BETWEEN c.change_date AND c.change_date + 13
GROUP BY
  c.anon_id, c.change_date, c.direction,
  c.median_before, c.median_after
HAVING COUNT(*) FILTER (
  WHERE (
    c.direction = 'increase'
    AND v.daily_m3 > (c.median_before + c.median_after) / 2
  ) OR (
    c.direction = 'decrease'
    AND v.daily_m3 < (c.median_before + c.median_after) / 2
  )
) >= 10;

SELECT
  COUNT(*) AS change_windows,
  COUNT(DISTINCT anon_id) AS change_meters,
  COUNT(DISTINCT anon_id) FILTER (
    WHERE direction = 'increase'
  ) AS increase_meters,
  COUNT(DISTINCT anon_id) FILTER (
    WHERE direction = 'decrease'
  ) AS decrease_meters
FROM vaviot.v_level_changes;

SELECT *
FROM vaviot.v_level_changes
ORDER BY ABS(median_after - median_before) DESC
LIMIT 15;