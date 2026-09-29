"""ETL: MSHA raw files -> star-schema CSVs (dim_mine, dim_date, fact_accidents, fact_mine_year).
Usage: python etl/etl.py <folder_with_Mines.txt_Accidents.txt_MinesProdYearly.txt>
"""
import pandas as pd
import numpy as np
import os
import sys

SRC = sys.argv[1] if len(sys.argv) > 1 else "data/raw"   # MSHA pipe-delimited .txt files
OUT = "data/processed"
os.makedirs(OUT, exist_ok=True)

def load(name):
    df = pd.read_csv(os.path.join(SRC, name), sep="|", dtype=str, quotechar='"',
                      low_memory=False, encoding='latin-1', on_bad_lines='skip')
    df.columns = [c.strip() for c in df.columns]
    return df

print("Loading Mines...")
mines = load("Mines.txt")
print("Loading MinesProdYearly...")
prod = load("MinesProdYearly.txt")
print("Loading Accidents...")
acc = load("Accidents.txt")

# ---------- DIM_MINE ----------
dim_mine = mines[[
    'MINE_ID','CURRENT_MINE_NAME','COAL_METAL_IND','CURRENT_MINE_TYPE','CURRENT_MINE_STATUS',
    'STATE','FIPS_CNTY_NM','DISTRICT','PRIMARY_SIC','COMPANY_TYPE','NO_EMPLOYEES'
]].copy()
dim_mine.columns = ['mine_id','mine_name','coal_metal_ind','mine_type','mine_status',
                     'state','county_name','district','primary_commodity','company_type','no_employees']
dim_mine['no_employees'] = pd.to_numeric(dim_mine['no_employees'], errors='coerce')
dim_mine = dim_mine.drop_duplicates('mine_id')
dim_mine.to_csv(os.path.join(OUT,'dim_mine.csv'), index=False)
print("dim_mine:", dim_mine.shape)

# ---------- FACT_ACCIDENTS ----------
fact_acc = acc[[
    'DOCUMENT_NO','MINE_ID','ACCIDENT_DT','COAL_METAL_IND','DEGREE_INJURY','CLASSIFICATION',
    'ACCIDENT_TYPE','INJURY_SOURCE','NATURE_INJURY','INJ_BODY_PART','OCCUPATION','ACTIVITY',
    'NO_INJURIES','DAYS_LOST','DAYS_RESTRICT','TOT_EXPER','MINE_EXPER'
]].copy()
fact_acc.columns = ['document_no','mine_id','accident_date','coal_metal_ind','degree_injury','classification',
                     'accident_type','injury_source','nature_injury','body_part','occupation','activity',
                     'no_injuries','days_lost','days_restrict','total_experience','mine_experience']

fact_acc['accident_date'] = pd.to_datetime(fact_acc['accident_date'], format='%m/%d/%Y', errors='coerce')
fact_acc['no_injuries'] = pd.to_numeric(fact_acc['no_injuries'], errors='coerce')
fact_acc['days_lost'] = pd.to_numeric(fact_acc['days_lost'], errors='coerce')
fact_acc['days_restrict'] = pd.to_numeric(fact_acc['days_restrict'], errors='coerce')
fact_acc['total_experience'] = pd.to_numeric(fact_acc['total_experience'], errors='coerce')
fact_acc['mine_experience'] = pd.to_numeric(fact_acc['mine_experience'], errors='coerce')
fact_acc['is_fatality'] = fact_acc['degree_injury'] == 'FATALITY'
fact_acc['is_severe'] = fact_acc['degree_injury'].isin(['FATALITY','PERM TOT OR PERM PRTL DISABLTY'])

# drop rows with no date or duplicate document_no (data quality step)
before = len(fact_acc)
fact_acc = fact_acc.dropna(subset=['accident_date','document_no'])
fact_acc = fact_acc.drop_duplicates('document_no')
print(f"fact_accidents: {before} -> {len(fact_acc)} after cleaning")

# keep only mine_ids that exist in dim_mine (referential integrity)
fact_acc = fact_acc[fact_acc['mine_id'].isin(dim_mine['mine_id'])]
print("fact_accidents after mine_id filter:", fact_acc.shape)
fact_acc.to_csv(os.path.join(OUT,'fact_accidents.csv'), index=False)

# ---------- DIM_DATE (built from accident dates range) ----------
dmin = fact_acc['accident_date'].min()
dmax = fact_acc['accident_date'].max()
all_dates = pd.date_range(dmin, dmax, freq='D')
dim_date = pd.DataFrame({'date_key': all_dates})
dim_date['year'] = dim_date['date_key'].dt.year
dim_date['quarter'] = dim_date['date_key'].dt.quarter
dim_date['month'] = dim_date['date_key'].dt.month
dim_date['month_name'] = dim_date['date_key'].dt.month_name()
dim_date['day'] = dim_date['date_key'].dt.day
dim_date['day_of_week'] = dim_date['date_key'].dt.day_name()
dim_date['fiscal_year'] = np.where(dim_date['month']>=10, dim_date['year']+1, dim_date['year'])
dim_date.to_csv(os.path.join(OUT,'dim_date.csv'), index=False)
print("dim_date:", dim_date.shape, dmin, dmax)

# ---------- FACT_MINE_YEAR ----------
fact_my = prod[['MINE_ID','CALENDAR_YR','SUBUNIT_DESC','C_M_IND','ANNUAL_HRS','ANNUAL_COAL_PROD','AVG_ANNUAL_EMPL','AVG_EMPLOYEE_HOURS']].copy()
fact_my.columns = ['mine_id','year','subunit','coal_metal_ind','annual_hours','annual_coal_prod','avg_employees','avg_employee_hours']
fact_my['year'] = pd.to_numeric(fact_my['year'], errors='coerce')
fact_my['annual_hours'] = pd.to_numeric(fact_my['annual_hours'], errors='coerce')
fact_my['annual_coal_prod'] = pd.to_numeric(fact_my['annual_coal_prod'], errors='coerce')
fact_my['avg_employees'] = pd.to_numeric(fact_my['avg_employees'], errors='coerce')
fact_my['avg_employee_hours'] = pd.to_numeric(fact_my['avg_employee_hours'], errors='coerce')
fact_my = fact_my.dropna(subset=['mine_id','year'])
fact_my = fact_my[fact_my['mine_id'].isin(dim_mine['mine_id'])]
fact_my.to_csv(os.path.join(OUT,'fact_mine_year.csv'), index=False)
print("fact_mine_year:", fact_my.shape)

print("ETL DONE")
