-- tutorial-01 で書いたモデル。動くけれど、生テーブル名が直書きされている。
-- TODO: raw.raw_customers を source() 参照に置き換える。

select
    id                              as customer_id,
    first_name,
    last_name,
    first_name || ' ' || last_name  as full_name

from raw.raw_customers
