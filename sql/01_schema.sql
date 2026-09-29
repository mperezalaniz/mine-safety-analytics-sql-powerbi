-- ============================================================
-- MSHA Mine Safety Analytics — Star Schema
-- Source: MSHA Open Government Data (msha.gov)
-- Author: Emiliano Pérez Alaniz
-- ============================================================

DROP SCHEMA IF EXISTS msha CASCADE;
CREATE SCHEMA msha;
SET search_path TO msha;

-- ---------- DIMENSION: MINE ----------
CREATE TABLE dim_mine (
    mine_id             VARCHAR(7)  PRIMARY KEY,
    mine_name           VARCHAR(100),
    coal_metal_ind      CHAR(1),            -- 'C' Coal / 'M' Metal-NonMetal
    mine_type           VARCHAR(20),        -- Surface / Underground / Facility
    mine_status         VARCHAR(50),
    state               VARCHAR(2),
    county_name         VARCHAR(80),
    district            VARCHAR(3),
    primary_commodity   VARCHAR(150),
    company_type        VARCHAR(80),
    no_employees        NUMERIC
);

-- ---------- DIMENSION: DATE ----------
CREATE TABLE dim_date (
    date_key        DATE PRIMARY KEY,
    year             INT,
    quarter          INT,
    month            INT,
    month_name       VARCHAR(12),
    day              INT,
    day_of_week      VARCHAR(12),
    fiscal_year      INT           -- MSHA fiscal year: Oct 1 – Sep 30
);

-- ---------- FACT: ACCIDENTS (grain = one reported accident) ----------
CREATE TABLE fact_accidents (
    document_no      VARCHAR(12) PRIMARY KEY,
    mine_id           VARCHAR(7) REFERENCES dim_mine(mine_id),
    accident_date     DATE REFERENCES dim_date(date_key),
    coal_metal_ind    CHAR(1),
    degree_injury     VARCHAR(60),
    classification    VARCHAR(60),
    accident_type     VARCHAR(80),
    injury_source     VARCHAR(60),
    nature_injury     VARCHAR(60),
    body_part         VARCHAR(80),
    occupation        VARCHAR(200),
    activity          VARCHAR(80),
    no_injuries       NUMERIC,
    days_lost         NUMERIC,
    days_restrict     NUMERIC,
    total_experience  NUMERIC(5,2),
    mine_experience   NUMERIC(5,2),
    is_fatality       BOOLEAN,
    is_severe         BOOLEAN        -- fatality OR permanent disability
);

-- ---------- FACT: MINE-YEAR EXPOSURE (grain = mine + year + subunit) ----------
CREATE TABLE fact_mine_year (
    mine_id           VARCHAR(7) REFERENCES dim_mine(mine_id),
    year               INT,
    subunit            VARCHAR(32),
    coal_metal_ind     CHAR(1),
    annual_hours       NUMERIC,
    annual_coal_prod   NUMERIC,
    avg_employees      NUMERIC(9,1),
    avg_employee_hours NUMERIC(9,1)
);

CREATE INDEX idx_fact_acc_mine   ON fact_accidents(mine_id);
CREATE INDEX idx_fact_acc_date   ON fact_accidents(accident_date);
CREATE INDEX idx_fact_acc_degree ON fact_accidents(degree_injury);
CREATE INDEX idx_fact_my_mine    ON fact_mine_year(mine_id);
CREATE INDEX idx_fact_my_year    ON fact_mine_year(year);
