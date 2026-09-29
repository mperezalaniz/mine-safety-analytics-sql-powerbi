-- ============================================================
-- MSHA Mine Safety Analytics — Analysis Queries
-- Star schema: dim_mine, dim_date, fact_accidents, fact_mine_year
-- ============================================================
SET search_path TO msha;

-- 1. NATIONAL YEARLY TREND: incidence & fatality rate per 200,000 hours
WITH acc_yr AS (
    SELECT d.year,
           COUNT(*)                                   AS total_accidents,
           COUNT(*) FILTER (WHERE a.is_fatality)       AS fatalities,
           SUM(a.days_lost)                            AS total_days_lost
    FROM fact_accidents a
    JOIN dim_date d ON d.date_key = a.accident_date
    WHERE d.year BETWEEN 2005 AND 2025
    GROUP BY d.year
),
hrs_yr AS (
    SELECT year, SUM(annual_hours) AS total_hours
    FROM fact_mine_year
    WHERE year BETWEEN 2005 AND 2025
    GROUP BY year
)
SELECT a.year, a.total_accidents, a.fatalities, h.total_hours,
       ROUND(a.total_accidents / h.total_hours::numeric * 200000, 2) AS incidence_rate_200k,
       ROUND(a.fatalities      / h.total_hours::numeric * 200000, 4) AS fatality_rate_200k
FROM acc_yr a JOIN hrs_yr h ON a.year = h.year
ORDER BY a.year;


-- 2. COAL vs METAL/NON-METAL comparison
WITH acc_cm AS (
    SELECT d.year, a.coal_metal_ind, COUNT(*) AS accidents
    FROM fact_accidents a JOIN dim_date d ON d.date_key = a.accident_date
    WHERE d.year BETWEEN 2005 AND 2025
    GROUP BY d.year, a.coal_metal_ind
),
hrs_cm AS (
    SELECT year, coal_metal_ind, SUM(annual_hours) AS total_hours
    FROM fact_mine_year
    WHERE year BETWEEN 2005 AND 2025
    GROUP BY year, coal_metal_ind
)
SELECT a.year, a.coal_metal_ind, a.accidents, h.total_hours,
       ROUND(a.accidents / h.total_hours::numeric * 200000, 2) AS incidence_rate_200k
FROM acc_cm a JOIN hrs_cm h ON a.year=h.year AND a.coal_metal_ind=h.coal_metal_ind
ORDER BY a.year, a.coal_metal_ind;


-- 3. BY STATE — accident count and exposure-adjusted rate
WITH acc_state AS (
    SELECT m.state, COUNT(*) AS accidents, COUNT(*) FILTER (WHERE a.is_fatality) AS fatalities
    FROM fact_accidents a
    JOIN dim_mine m ON m.mine_id = a.mine_id
    JOIN dim_date d ON d.date_key = a.accident_date
    WHERE d.year BETWEEN 2005 AND 2025
    GROUP BY m.state
),
hrs_state AS (
    SELECT m.state, SUM(fy.annual_hours) AS total_hours
    FROM fact_mine_year fy JOIN dim_mine m ON m.mine_id = fy.mine_id
    WHERE fy.year BETWEEN 2005 AND 2025
    GROUP BY m.state
)
SELECT a.state, a.accidents, a.fatalities, h.total_hours,
       ROUND(a.accidents / NULLIF(h.total_hours,0)::numeric * 200000, 2) AS incidence_rate_200k
FROM acc_state a JOIN hrs_state h ON a.state = h.state
ORDER BY a.accidents DESC;


-- 4. TOP ACCIDENT CLASSIFICATIONS
SELECT classification, COUNT(*) AS accidents
FROM fact_accidents
GROUP BY classification
ORDER BY accidents DESC
LIMIT 15;


-- 5. TOP INJURED BODY PARTS
SELECT body_part, COUNT(*) AS accidents
FROM fact_accidents
WHERE body_part <> 'NO VALUE FOUND'
GROUP BY body_part
ORDER BY accidents DESC
LIMIT 15;


-- 6. EXPERIENCE BANDS vs ACCIDENTS & SEVERITY
SELECT
    CASE
        WHEN total_experience < 0.5  THEN '<6m'
        WHEN total_experience < 1    THEN '6m-1y'
        WHEN total_experience < 2    THEN '1-2y'
        WHEN total_experience < 5    THEN '2-5y'
        WHEN total_experience < 10   THEN '5-10y'
        WHEN total_experience < 20   THEN '10-20y'
        ELSE '20y+'
    END AS experience_band,
    COUNT(*)                                     AS accidents,
    COUNT(*) FILTER (WHERE is_fatality)           AS fatalities,
    ROUND(AVG(days_lost)::numeric, 1)             AS avg_days_lost
FROM fact_accidents
WHERE total_experience IS NOT NULL
GROUP BY 1
ORDER BY MIN(total_experience);


-- 7. RISKIEST MINES BY REALIZED INCIDENCE RATE (min. exposure threshold)
WITH mine_hours AS (
    SELECT mine_id, SUM(annual_hours) AS total_hours
    FROM fact_mine_year GROUP BY mine_id
),
mine_acc AS (
    SELECT mine_id, COUNT(*) AS accidents, COUNT(*) FILTER (WHERE is_fatality) AS fatalities
    FROM fact_accidents GROUP BY mine_id
)
SELECT m.mine_name, m.state, m.mine_type, ma.accidents, ma.fatalities, mh.total_hours,
       ROUND(ma.accidents / mh.total_hours::numeric * 200000, 2) AS incidence_rate_200k
FROM mine_acc ma
JOIN mine_hours mh ON mh.mine_id = ma.mine_id
JOIN dim_mine m ON m.mine_id = ma.mine_id
WHERE mh.total_hours >= 500000
ORDER BY incidence_rate_200k DESC
LIMIT 30;


-- 8. DATA QUALITY CHECK — orphaned fact rows (should return 0)
SELECT
    (SELECT COUNT(*) FROM fact_accidents a LEFT JOIN dim_mine m ON m.mine_id=a.mine_id WHERE m.mine_id IS NULL) AS orphan_accidents,
    (SELECT COUNT(*) FROM fact_mine_year f LEFT JOIN dim_mine m ON m.mine_id=f.mine_id WHERE m.mine_id IS NULL) AS orphan_mine_years,
    (SELECT COUNT(*) FROM fact_accidents WHERE document_no IS NULL) AS null_keys;
