{{ config(tags=['check'], severity='error') }}

-- 【答え合わせ用テスト】行が返ったら失敗。
-- 上流（stg_customers）と行数・値が一致しているかも見る。
with expected as (
    select
        customer_id,
        first_name || ' ' || last_name as full_name
    from {{ ref('stg_customers') }}
),

actual as (
    select customer_id, full_name
    from {{ ref('customer_names') }}
)

select
    coalesce(a.customer_id, e.customer_id) as customer_id,
    a.full_name as actual_full_name,
    e.full_name as expected_full_name
from actual a
full outer join expected e on a.customer_id = e.customer_id
where a.customer_id is null
   or e.customer_id is null
   or a.full_name is distinct from e.full_name
