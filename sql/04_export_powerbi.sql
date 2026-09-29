-- ============================================================
-- MSHA Mine Safety Analytics — Exports for Power BI
-- Each query produces one table of the Power BI semantic model.
-- Run with: psql -f sql/04_export_powerbi.sql  (writes to data/powerbi/)
-- ============================================================
SET search_path TO msha;

-- 1. National yearly trend -> tbl_trend_national
\copy (WITH acc AS (SELECT d.year, COUNT(*) AS total_accidents, COUNT(*) FILTER (WHERE a.is_fatality) AS fatalities, SUM(a.days_lost) AS total_days_lost FROM fact_accidents a JOIN dim_date d ON d.date_key = a.accident_date WHERE d.year BETWEEN 2005 AND 2025 GROUP BY d.year), hrs AS (SELECT year, SUM(annual_hours) AS total_hours FROM fact_mine_year WHERE year BETWEEN 2005 AND 2025 GROUP BY year) SELECT a.year, a.total_accidents, a.fatalities, a.total_days_lost, h.total_hours, ROUND(a.total_accidents / h.total_hours::numeric * 200000, 2) AS incidence_rate_200k, ROUND(a.fatalities / h.total_hours::numeric * 200000, 4) AS fatality_rate_200k FROM acc a JOIN hrs h USING (year) ORDER BY a.year) TO 'data/powerbi/trend_national_yearly.csv' WITH CSV HEADER

-- 2. Coal vs Metal/Non-Metal -> tbl_trend_coal_metal
\copy (WITH acc AS (SELECT d.year, a.coal_metal_ind, COUNT(*) AS accidents FROM fact_accidents a JOIN dim_date d ON d.date_key = a.accident_date WHERE d.year BETWEEN 2005 AND 2025 GROUP BY 1,2), hrs AS (SELECT year, c_m AS coal_metal_ind, SUM(annual_hours) AS total_hours FROM (SELECT year, annual_hours, coal_metal_ind AS c_m FROM fact_mine_year WHERE year BETWEEN 2005 AND 2025) x GROUP BY 1,2) SELECT a.year, CASE a.coal_metal_ind WHEN 'C' THEN 'Coal' ELSE 'Metal/Non-Metal' END AS commodity, a.accidents, h.total_hours, ROUND(a.accidents / h.total_hours::numeric * 200000, 2) AS incidence_rate_200k FROM acc a JOIN hrs h ON h.year = a.year AND h.coal_metal_ind = a.coal_metal_ind ORDER BY 1,2) TO 'data/powerbi/trend_coal_vs_metal.csv' WITH CSV HEADER

-- 3. By state -> tbl_by_state
\copy (WITH acc AS (SELECT m.state, COUNT(*) AS accidents, COUNT(*) FILTER (WHERE a.is_fatality) AS fatalities FROM fact_accidents a JOIN dim_mine m USING (mine_id) JOIN dim_date d ON d.date_key = a.accident_date WHERE d.year BETWEEN 2005 AND 2025 GROUP BY m.state), hrs AS (SELECT m.state, SUM(f.annual_hours) AS total_hours FROM fact_mine_year f JOIN dim_mine m USING (mine_id) WHERE f.year BETWEEN 2005 AND 2025 GROUP BY m.state) SELECT a.state, a.accidents, a.fatalities, h.total_hours, ROUND(a.accidents / NULLIF(h.total_hours,0)::numeric * 200000, 2) AS incidence_rate_200k FROM acc a JOIN hrs h USING (state) ORDER BY a.accidents DESC) TO 'data/powerbi/by_state.csv' WITH CSV HEADER

-- 4. Top accident classifications -> tbl_top_classification
\copy (SELECT classification, COUNT(*) AS accidents, COUNT(*) FILTER (WHERE is_fatality) AS fatalities, ROUND(AVG(days_lost)::numeric, 1) AS avg_days_lost FROM fact_accidents GROUP BY classification ORDER BY accidents DESC LIMIT 15) TO 'data/powerbi/top_classification.csv' WITH CSV HEADER

-- 5. Top injured body parts -> tbl_top_body_part
\copy (SELECT body_part, COUNT(*) AS accidents FROM fact_accidents WHERE body_part <> 'NO VALUE FOUND' GROUP BY body_part ORDER BY accidents DESC LIMIT 15) TO 'data/powerbi/top_body_part.csv' WITH CSV HEADER

-- 6. Experience bands -> tbl_experience_bands
\copy (SELECT CASE WHEN total_experience < 0.5 THEN '<6m' WHEN total_experience < 1 THEN '6m-1y' WHEN total_experience < 2 THEN '1-2y' WHEN total_experience < 5 THEN '2-5y' WHEN total_experience < 10 THEN '5-10y' WHEN total_experience < 20 THEN '10-20y' ELSE '20y+' END AS experience_band, ROUND(MIN(total_experience), 2) AS band_order, COUNT(*) AS accidents, COUNT(*) FILTER (WHERE is_fatality) AS fatalities, ROUND(AVG(days_lost)::numeric, 1) AS avg_days_lost FROM fact_accidents WHERE total_experience IS NOT NULL GROUP BY 1 ORDER BY MIN(total_experience)) TO 'data/powerbi/experience_bands.csv' WITH CSV HEADER

-- 7. Riskiest mines (>= 500,000 exposure hours) -> tbl_riskiest_mines
\copy (WITH mh AS (SELECT mine_id, SUM(annual_hours) AS total_hours FROM fact_mine_year GROUP BY mine_id), ma AS (SELECT mine_id, COUNT(*) AS accidents, COUNT(*) FILTER (WHERE is_fatality) AS fatalities FROM fact_accidents GROUP BY mine_id) SELECT m.mine_name, m.state, m.mine_type, CASE m.coal_metal_ind WHEN 'C' THEN 'Coal' ELSE 'Metal/Non-Metal' END AS commodity, ma.accidents, ma.fatalities, mh.total_hours, ROUND(ma.accidents / mh.total_hours::numeric * 200000, 2) AS incidence_rate_200k FROM ma JOIN mh USING (mine_id) JOIN dim_mine m USING (mine_id) WHERE mh.total_hours >= 500000 ORDER BY incidence_rate_200k DESC LIMIT 50) TO 'data/powerbi/riskiest_mines.csv' WITH CSV HEADER
