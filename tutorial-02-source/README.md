# tutorial-02: source で生テーブルを宣言する

⏱ 5分 / 🎯 学ぶこと: **`source()` と `_sources.yml`**。生テーブル名を SQL に直書きしない理由。

## 準備

```bash
mk tutorial-02 start
```

`work/models/customer_names.sql` には tutorial-01 の答えがすでに入っている。動くが、`raw.raw_customers` が直書きされている。

## お題

1. `work/models/_sources.yml` に source を定義する
   - source の名前は **`jaffle_shop_raw`**
   - スキーマは `raw`
   - テーブルは最低限 `raw_customers`（余裕があれば `raw_orders` / `raw_payments` も）
2. `work/models/customer_names.sql` の `from raw.raw_customers` を `{{ source(...) }}` に書き換える
3. `dbt run`

確認に使えるコマンド:

```bash
dbt ls --resource-type source     # 定義した source が一覧に出る
dbt compile --select customer_names && cat target/compiled/tutorial_02/models/customer_names.sql
```

## 受け入れ条件

- `work/models/customer_names.sql` に `from raw.raw_customers` の直書きが残っていない
- `raw_customers` の source が定義されている
- `customer_names` が **source 経由** で参照している（dbt の依存関係に source が現れる）
- `analytics_t02.customer_names` が VIEW として存在し、100 行・`customer_id = 1` の `full_name` が `Michael P.`

## 答え合わせ

```bash
dbt run
./check.sh
```

やり直すときは `mk tutorial-02 reset`。

## 解答例

<details>
<summary>work/models/_sources.yml</summary>

```yaml
version: 2

sources:
  - name: jaffle_shop_raw
    description: "外部システムが Postgres の raw スキーマに入れた生データ"
    schema: raw
    tables:
      - name: raw_customers
      - name: raw_orders
      - name: raw_payments
```

</details>

<details>
<summary>work/models/customer_names.sql</summary>

```sql
select
    id                              as customer_id,
    first_name,
    last_name,
    first_name || ' ' || last_name  as full_name

from {{ source('jaffle_shop_raw', 'raw_customers') }}
```

</details>

## 解説

- `{{ source('jaffle_shop_raw', 'raw_customers') }}` は、コンパイル時に `"warehouse"."raw"."raw_customers"` に置き換わる。
  `target/compiled/...` を見ると実物が確認できる
- 直書きと違って、dbt が **依存関係を認識する**。`dbt ls --select source:jaffle_shop_raw+` で
  「この生テーブルを使っているモデル」が一覧できるようになる（影響範囲の調査ができる）
- スキーマ名やテーブル名が変わっても、直すのは `_sources.yml` の 1 か所だけで済む
- source には後から「鮮度チェック（freshness）」「テスト」「ドキュメント」を足していける。
  まず宣言しておくことが入口になる

## 次の一歩

モデル同士を繋ぐ `ref()` へ → **tutorial-03**
