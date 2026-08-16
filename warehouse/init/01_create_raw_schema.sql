-- Postgres 初回起動時（pgdata が空のとき）に自動実行される初期化スクリプト。
--
-- dbt の source() を体験するために、「外部システムが raw スキーマにデータを
-- 入れてくれている」状態を再現する。CSV は ./postgres/init/data/ 配下を
-- /docker-entrypoint-initdb.d/data/ として bind mount している。
--
-- _loaded_at 列は dbt の `source freshness` 用（loaded_at_field）。

CREATE SCHEMA IF NOT EXISTS raw;

-- ---------------------------------------------------------------- customers
CREATE TABLE raw.raw_customers (
    id          integer,
    first_name  varchar(50),
    last_name   varchar(50),
    _loaded_at  timestamptz NOT NULL DEFAULT now()
);

COPY raw.raw_customers (id, first_name, last_name)
    FROM '/docker-entrypoint-initdb.d/data/raw_customers.csv'
    WITH (FORMAT csv, HEADER true);

-- ------------------------------------------------------------------ orders
CREATE TABLE raw.raw_orders (
    id          integer,
    user_id     integer,
    order_date  date,
    status      varchar(50),
    _loaded_at  timestamptz NOT NULL DEFAULT now()
);

COPY raw.raw_orders (id, user_id, order_date, status)
    FROM '/docker-entrypoint-initdb.d/data/raw_orders.csv'
    WITH (FORMAT csv, HEADER true);

-- ---------------------------------------------------------------- payments
-- amount はセント単位（dbt 側のマクロ cents_to_dollars でドルに変換する）
CREATE TABLE raw.raw_payments (
    id              integer,
    order_id        integer,
    payment_method  varchar(50),
    amount          integer,
    _loaded_at      timestamptz NOT NULL DEFAULT now()
);

COPY raw.raw_payments (id, order_id, payment_method, amount)
    FROM '/docker-entrypoint-initdb.d/data/raw_payments.csv'
    WITH (FORMAT csv, HEADER true);

-- dbt が作る各スキーマの所有者になれるよう明示的に権限を渡しておく
-- （POSTGRES_USER と dbt の接続ユーザーは同一なので実質的な保険）
GRANT USAGE ON SCHEMA raw TO CURRENT_USER;
