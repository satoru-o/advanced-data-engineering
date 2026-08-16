# tutorial-03: ref でモデルを繋ぐ

⏱ 5分 / 🎯 学ぶこと: **`ref()` と DAG**。実行順を dbt に決めさせる。

## 準備

```bash
mk tutorial-03 start
```

`work/models/stg_customers.sql` は用意ずみ（source を整形しただけのモデル。編集しない）。

## お題

1. `work/models/customer_names.sql` を、**`stg_customers` の上に**組み立てる
   - 返す列は `customer_id` / `first_name` / `last_name` / `full_name`
   - source を直接見にいかず、`{{ ref('stg_customers') }}` を使う
2. `dbt run` して、実行ログで **stg_customers → customer_names の順**に動くことを確認する
3. 系譜を眺めてみる

```bash
dbt ls --select +customer_names          # customer_names の上流をすべて表示
dbt run --select stg_customers+          # stg_customers と、その下流だけを実行
```

## 受け入れ条件

- `customer_names` が `ref('stg_customers')` を使っている（dbt の依存関係にモデルが現れる）
- `customer_names` が source を**直接**参照していない
- `analytics_t03` に `stg_customers` と `customer_names` の両方が VIEW として存在する
- `customer_names` は 4 列・100 行、`customer_id = 1` の `full_name` が `Michael P.`
- 上流 `stg_customers` と全行で値が一致する

## 答え合わせ

```bash
dbt run
./check.sh
```

やり直すときは `mk tutorial-03 reset`。

## 解答例

<details>
<summary>work/models/customer_names.sql</summary>

```sql
select
    customer_id,
    first_name,
    last_name,
    first_name || ' ' || last_name as full_name

from {{ ref('stg_customers') }}
```

</details>

## 解説

- `ref()` は「他のモデルを参照する」だけの関数ではない。**参照した瞬間に依存関係（DAG）ができる**。
  dbt はこの DAG を見て実行順を決め、並列に流せるところは並列に流す
- だから `dbt run` に順番を指定するオプションは無い。順番はコードから導かれる
- `+` を付けた選択（`+model` = 上流も、`model+` = 下流も）は、この DAG があるから成立する。
  「このモデルを直したら何が壊れるか」を機械的に辿れるのが利点
- ハードコードで `analytics_t03.stg_customers` と書いても同じ VIEW は作れるが、
  dbt からは無関係のリレーションに見える → 実行順は保証されず、影響範囲も追えない
- 生成された SQL を見ると、`ref()` が実テーブル名に展開されているのが分かる
  ```bash
  cat target/compiled/tutorial_03/models/customer_names.sql
  ```

## 次の一歩

view ではなく table にしたい / 差分だけ更新したい → **マテリアライゼーションの回（未実装）**
