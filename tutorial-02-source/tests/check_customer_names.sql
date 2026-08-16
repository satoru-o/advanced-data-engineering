{{ config(tags=['check'], severity='error') }}

-- 【答え合わせ用テスト】行が返ったら失敗。
select
    customer_id,
    full_name
from {{ ref('customer_names') }}
where
    customer_id is null
    or full_name is distinct from (first_name || ' ' || last_name)
