{{ config(tags=['check'], severity='error') }}

-- 【答え合わせ用テスト】値が正しいかを検査する。
-- dbt の「特異テスト（singular test）」は "行が返ったら失敗" という約束。
-- ここでは full_name が「first_name + 半角スペース + last_name」になっていない行を探す。

select
    customer_id,
    first_name,
    last_name,
    full_name
from {{ ref('customer_names') }}
where
    customer_id is null
    or full_name is distinct from (first_name || ' ' || last_name)
