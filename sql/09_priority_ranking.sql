WITH baseline AS (
  SELECT anon_id,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY daily_m3) AS median_m3,
    COUNT(*) AS valid_days
  FROM vaviot.v_reading_deltas
  WHERE daily_m3 >= 0
  GROUP BY anon_id
),
zero_days AS (
  SELECT anon_id, data,
    data - ROW_NUMBER() OVER (
      PARTITION BY anon_id ORDER BY data
    )::integer AS grp
  FROM vaviot.v_reading_deltas
  WHERE daily_m3 = 0 AND paketov_za_sutki > 0
),
zero_streaks AS (
  SELECT anon_id
  FROM zero_days
  GROUP BY anon_id, grp
  HAVING COUNT(*) >= 7
),
flags AS (
  SELECT d.anon_id,
    BOOL_OR(d.delta_m3 < -1) AS large_negative,
    BOOL_OR(
      d.daily_m3 > 5
      AND b.valid_days >= 30
      AND b.median_m3 > 0
      AND d.daily_m3 > b.median_m3 * 10
    ) AS spike,
    BOOL_OR(
      p.model LIKE '%D15%'
      AND d.daily_m3 > 72
    ) AS physical_limit
  FROM vaviot.v_reading_deltas d
  JOIN vaviot.pribory p ON p.anon_id = d.anon_id
  LEFT JOIN baseline b ON b.anon_id = d.anon_id
  GROUP BY d.anon_id
),
events AS (
  SELECT anon_id,
    BOOL_OR(sobytie = 'магнит') AS magnet,
    BOOL_OR(sobytie = 'сброс') AS reset_event
  FROM vaviot.sobytiya
  GROUP BY anon_id
)
SELECT
  p.anon_id,
  p.model,
  (CASE WHEN f.physical_limit THEN 3 ELSE 0 END +
   CASE WHEN f.large_negative THEN 2 ELSE 0 END +
   CASE WHEN f.spike THEN 2 ELSE 0 END +
   CASE WHEN z.anon_id IS NOT NULL THEN 1 ELSE 0 END +
   CASE WHEN COALESCE(e.magnet, FALSE) THEN 1 ELSE 0 END +
   CASE WHEN COALESCE(e.reset_event, FALSE) THEN 1 ELSE 0 END
  ) AS priority_score,
  f.physical_limit,
  f.large_negative,
  f.spike,
  (z.anon_id IS NOT NULL) AS zero_streak,
  COALESCE(e.magnet, FALSE) AS magnet,
  COALESCE(e.reset_event, FALSE) AS reset_event
FROM vaviot.pribory p
JOIN flags f ON f.anon_id = p.anon_id
LEFT JOIN (SELECT DISTINCT anon_id FROM zero_streaks) z ON z.anon_id = p.anon_id
LEFT JOIN events e ON e.anon_id = p.anon_id
ORDER BY priority_score DESC, p.anon_id
LIMIT 30;
/*Приоритизация приборов для технической проверки

Для определения приоритетных приборов разработана балльная система, учитывающая превышение расчётного физического предела, крупные отрицательные изменения, суточные всплески, длительные периоды нулевого расхода и зарегистрированные события.

В полученном списке 11 приборов набрали 8 баллов, ещё 19 приборов — 7 баллов.

Среди приборов с наивысшей оценкой: 1184793, 2569627, 3832684, 5359103 и 8190741. У них одновременно обнаружены крупные отрицательные изменения, аномальные положительные всплески, превышение расчётного предела и периоды нулевого потребления при поступающих пакетах.

Отдельного внимания заслуживают приборы 2491162, 2519659 и 2030325, у которых зафиксированы особенно крупные или повторяющиеся изменения накопительных показаний.

Рекомендуется начать с проверки исходных показаний, корректности декодирования регистра и истории передачи данных, а затем при необходимости провести техническую диагностику приборов.

Балльная система является предварительным инструментом приоритизации и не отражает вероятность неисправности.

SQL-расчёт рейтинга представлен в файле sql/09_priority_ranking.sql, результаты — в results/priority_meters.csv.
 */