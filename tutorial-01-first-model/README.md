# tutorial-01: はじめてのモデル

⏱ 5分 / 🎯 学ぶこと: **dbt のモデル＝「SELECT 文にファイル名で名前を付けたもの」**。`dbt run` が何をするのか。

## 準備

ホストで:

```bash
mk tutorial-01 start
```

コンテナの `/work/tutorial-01-first-model` に入った状態でシェルが開く。以降のコマンドはその中で打つ。

ディレクトリの見かた:

| | |
|---|---|
| `work/` | **編集していいのはここだけ。** git 管理外で、`mk ... reset` で初期状態に戻る |
| `README.md` / `tests/` / `check.sh` / `dbt_project.yml` | 読むためのもの（お題と受け入れ条件の定義） |
| `target/` / `logs/` | `dbt` が実行時に作る。中身を覗くと勉強になる |

生データを覗いてみる:

```bash
psql -c "select * from raw.raw_customers limit 5"
```

## お題

`work/models/customer_names.sql` を編集して、顧客の氏名一覧を返すモデルを作る。

- 元データは `raw.raw_customers`（テーブル名は SQL に直書きしてよい。source 化は tutorial-02 でやる）
- 返す列は `customer_id` / `first_name` / `last_name` / `full_name` の 4 つ
- `full_name` は「名 + 半角スペース + 姓」（例: `Michael P.`）
- 書けたら `dbt run`

ファイルはホスト側のエディタで編集しても、コンテナ内の `vi` で編集してもよい（同じファイル）。

## 受け入れ条件

- `analytics_t01.customer_names` が **VIEW** として存在する
- 列は `customer_id` / `first_name` / `last_name` / `full_name` の 4 つ
- 行数が **100**
- `customer_id = 1` の `full_name` が `Michael P.`
- `customer_id` に NULL がなく、全行で `full_name = first_name || ' ' || last_name`

## 答え合わせ

```bash
dbt run
./check.sh
```

`✔ 正解です` が出れば完了。`mk tutorial-01 exit` で環境を止められる。
やり直したいときは `mk tutorial-01 reset`（書きかけのファイルは破棄され、最初の状態に戻る）。

## 解答例

<details>
<summary>work/models/customer_names.sql（クリックで開く）</summary>

```sql
select
    id                              as customer_id,
    first_name,
    last_name,
    first_name || ' ' || last_name  as full_name

from raw.raw_customers
```

</details>

## 解説

- モデルを置く場所は `dbt_project.yml` の `model-paths` で決まる（この教材では `work/models`）。
  そこに置いた `.sql` ファイル 1 個 = モデル 1 個で、**ファイル名がそのままリレーション名**になる
  （`customer_names.sql` → `customer_names`）
- ファイルの中身は `SELECT` 文だけ。`CREATE VIEW` は書かない。dbt が
  `create view analytics_t01.customer_names as (あなたの SELECT)` を組み立てて実行する
- 実際に発行された SQL は `target/run/tutorial_01/models/customer_names.sql` に残る。見てみると分かりやすい
  ```bash
  cat target/run/tutorial_01/models/customer_names.sql
  ```
- 書き込み先が `analytics_t01` なのは `dbt_project.yml` の `+schema: t01` のため。
  既定スキーマ `analytics` の後ろに付く（回ごとに成果物が混ざらないようにしている）
- 何も指定しないとマテリアライゼーションは **view**。テーブルにする方法は後の回で扱う

## 次の一歩

`raw.raw_customers` を直書きしたのが心残りなら → **tutorial-02（source）**
