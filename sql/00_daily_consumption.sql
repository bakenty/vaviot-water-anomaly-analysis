-- Daily water consumption calculation
-- PostgreSQL 18
CREATE SCHEMA IF NOT EXISTS vaviot;

CREATE TABLE IF NOT EXISTS vaviot.pribory (
  anon_id text PRIMARY KEY,
  bs text,
  tip text,
  model text,
  mesyac_vypuska text
);

CREATE TABLE IF NOT EXISTS vaviot.pokazaniya (
  anon_id text,
  data date,
  pokazanie numeric,
  paketov_za_sutki integer
);

CREATE TABLE IF NOT EXISTS vaviot.sobytiya (
  anon_id text,
  data date,
  sobytie text
);

CREATE OR REPLACE VIEW vaviot.v_reading_deltas AS
WITH readings AS (
  SELECT
    anon_id,
    data,
    pokazanie,
    paketov_za_sutki,
    LAG(data) OVER (PARTITION BY anon_id ORDER BY data) AS prev_date,
    LAG(pokazanie) OVER (PARTITION BY anon_id ORDER BY data) AS prev_reading
  FROM vaviot.pokazaniya
),
deltas AS (
  SELECT *,
    data - prev_date AS days_gap,
    pokazanie - prev_reading AS delta_m3
  FROM readings
)
SELECT *,
  CASE WHEN days_gap = 1 THEN delta_m3 ELSE NULL END AS daily_m3
FROM deltas;