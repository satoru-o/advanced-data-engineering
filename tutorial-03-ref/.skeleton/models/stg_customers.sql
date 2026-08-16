-- 用意ずみのモデル（このファイルは編集しない）。
-- source を 1:1 で整形するだけの層。

select
    id          as customer_id,
    first_name,
    last_name

from {{ source('jaffle_shop_raw', 'raw_customers') }}
