SET search_path TO msha;

\copy dim_mine FROM 'data/processed/dim_mine.csv' WITH (FORMAT csv, HEADER true, NULL '');
\copy dim_date FROM 'data/processed/dim_date.csv' WITH (FORMAT csv, HEADER true, NULL '');
\copy fact_accidents FROM 'data/processed/fact_accidents.csv' WITH (FORMAT csv, HEADER true, NULL '');
\copy fact_mine_year FROM 'data/processed/fact_mine_year.csv' WITH (FORMAT csv, HEADER true, NULL '');
