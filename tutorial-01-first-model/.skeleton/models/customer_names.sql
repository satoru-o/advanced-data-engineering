-- TODO: ここを書き換えるのがこの回のお題です。
--
-- raw.raw_customers から、次の 4 列を返す SELECT を書いてください。
--   customer_id / first_name / last_name / full_name
--
-- 生データの中身を見たいときは、コンテナ内で:
--   psql -c "select * from raw.raw_customers limit 5"

select
    null as customer_id
