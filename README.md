# dbt チュートリアル集（ローカル Docker 完結）

1 本 5 分の小ネタで dbt を覚えるための練習場。**お題 → 自分で実装 → 答え合わせ** を繰り返す。

- ホストに入れるのは **Docker / Docker Compose / make だけ**。dbt も Python も uv もコンテナの中
- dbt コマンドは**コンテナの中で自分で打つ**（`mk` はコンテナの出し入れだけ担当）
- ファイルはホストに bind mount されているので、好きなエディタで編集できる

## はじめかた

```bash
mk tutorial-01 start
```

`mk` は「リポジトリのルートの Makefile を叩く」ためのシェル関数（`~/.bash_aliases` で定義済み）:

```bash
mk() { make -C "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" "$@"; }
```

この関数が無い環境では `make -C <リポジトリのルート> tutorial-01 start` と等価。

初回は Docker イメージのビルドで少し待つ。起動すると **そのチュートリアルのディレクトリに入った状態**の
シェルが開くので、あとはその中で:

```bash
cat README.md          # お題を読む
vi work/models/....sql # 実装する（ホスト側のエディタでもよい）
dbt run                # 動かす
./check.sh             # 答え合わせ → ✔ / ✘
exit                   # シェルを抜ける（コンテナは動いたまま）
```

### チュートリアルの構成

```
tutorial-NN-xxx/
├── README.md        お題・受け入れ条件・解答例（読む）
├── check.sh         答え合わせ（読む）
├── dbt_project.yml  この回の dbt プロジェクト設定（読む）
├── tests/           受け入れテスト＝仕様書（読む）
├── .skeleton/       work/ の初期状態（git 管理下）
└── work/            ★ 編集していいのはここだけ（git 管理外）
```

`work/` は git 管理外で、無ければ `mk ... start` が `.skeleton/` から作る。
`mk ... reset` すると丸ごと作り直されるので、失敗しても気楽に潰せる。

## mk のコマンド

| コマンド | やること |
|---|---|
| `mk` | チュートリアル一覧 |
| `mk tutorial-01 start` | 環境を起動して、その回のディレクトリに入る（`start` は省略可、`mk 01` / `mk 1` でもよい） |
| `mk tutorial-01 exit` | 終了（DB のデータは残る） |
| `mk tutorial-01 reset` | その回を**一からやり直し**（スキーマを消し、書きかけのファイルを初期状態に戻す。確認を省くなら `YES=1` を付ける） |

「主語（`tutorial-01`）＋ 動詞（`start` / `exit` / `reset`）」を並べて渡す。主語は
`tutorial-01` / `01` / `1` / ディレクトリ名フル のどれでもよい。

その他: `mk ps` / `mk logs` / `mk build`（イメージ再ビルド）/ `mk lock`（依存更新）/ `mk reset`（環境全体を作り直し）

## チュートリアル一覧

| # | タイトル | 学ぶこと | 状態 |
|---|---|---|---|
| 01 | [はじめてのモデル](tutorial-01-first-model/) | モデル＝ SELECT に名前を付けたもの。`dbt run` が発行する SQL | ✅ |
| 02 | [source で生テーブルを宣言する](tutorial-02-source/) | `source()` と `_sources.yml`、依存関係の可視化 | ✅ |
| 03 | [ref でモデルを繋ぐ](tutorial-03-ref/) | `ref()` と DAG、実行順と `--select` | ✅ |
| 04 | マテリアライゼーション | view / table / ephemeral の使い分け | ⬜ 未実装 |
| 05 | incremental モデル | `is_incremental()` と差分更新 | ⬜ |
| 06 | seed | CSV マスタの取り込み | ⬜ |
| 07 | 汎用テスト | `unique` / `not_null` / `accepted_values` / `relationships` | ⬜ |
| 08 | 特異テスト | SQL で書く単発テスト | ⬜ |
| 09 | カスタム汎用テスト | 自分でテストを作る | ⬜ |
| 10 | Jinja 入門 | 変数・条件分岐・ループ | ⬜ |
| 11 | マクロ | 引数付きマクロ、組み込みマクロの上書き | ⬜ |
| 12 | パッケージ | `dbt deps` と `dbt_utils` | ⬜ |
| 13 | dbt-expectations | 踏み込んだデータ品質テスト | ⬜ |
| 14 | snapshot | SCD Type 2 で履歴を残す | ⬜ |
| 15 | source freshness | 鮮度チェック | ⬜ |
| 16 | docs | `dbt docs generate` と系譜グラフ | ⬜ |
| 17 | hooks | pre-hook / post-hook / on-run-end | ⬜ |
| 18 | CI | GitHub Actions を act でローカル実行 | ⬜ |
| 19 | Airflow + Cosmos | dbt を DAG として動かす | ⬜ |
| 20 | DuckDB + MinIO + Iceberg | レイクハウス構成 | ⬜ |

## 仕組み

| | 中身 |
|---|---|
| コンテナ | `postgres`（DWH 代わり）と `dbt`（dbt CLI の置き場。常駐） |
| 生データ | 初回起動時に `warehouse/init/` の SQL と CSV で `raw` スキーマへ投入（jaffle_shop: 顧客 100 / 注文 99 / 支払 113 行） |
| 依存管理 | `pyproject.toml` + `uv.lock`（uv）。イメージビルド時に `/opt/venv` へ `uv sync --frozen` |
| bind mount | リポジトリ全体 → コンテナの `/work`。`tutorial-NN/target/` などの生成物もホストから見える |
| 接続設定 | `shared/profiles.yml` 1 個を全チュートリアルで共有（値は環境変数経由） |
| 書き込み先 | 回ごとに分離。tutorial-NN は `analytics_tNN` スキーマに作られる |
| 答え合わせ | 各回の `check.sh`。データの検証は dbt のテスト（`tests/check_*.sql`）、構造の検証は psql と `target/manifest.json` |

## 困ったら

| 症状 | 対処 |
|---|---|
| 生成物が root 所有になる | `.env` の `HOST_UID` / `HOST_GID` がホストの `id -u` / `id -g` と違う。直して `mk 01 start` |
| ネットワーク越しの取得がタイムアウトする | `.env` の `DOCKER_NETWORK_MTU` をホストの `ip link show` の値に合わせる（WSL2 は 1420） |
| ポート 55432 が埋まっている | `.env` の `POSTGRES_HOST_PORT` を変更 |
| 全部おかしくなった | `mk reset`（環境全体を作り直し。生データから再構築される） |
| 依存を変えたい | `pyproject.toml` を編集 → `mk lock` → `mk build` |
