#!/usr/bin/env bash
# 各チュートリアルの check.sh から source して使う共通ヘルパ。
# コンテナ内で動かす前提（psql の接続情報は環境変数から入っている）。

_FAILS=()

pass() { printf '  \033[32m✔\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✘\033[0m %s\n' "$1"; _FAILS+=("$1"); }

# SQL を 1 行の値として取り出す
q() { psql -Atqc "$1" 2>/dev/null; }

# リレーションの種別を返す: BASE TABLE / VIEW / なければ空
relation_kind() {
    q "select table_type from information_schema.tables
       where table_schema = '$1' and table_name = '$2'"
}

# 列名をカンマ区切り（アルファベット順）で返す
relation_columns() {
    q "select string_agg(column_name, ',' order by column_name)
       from information_schema.columns
       where table_schema = '$1' and table_name = '$2'"
}

expect_eq() { # expect_eq <実際> <期待> <説明>
    if [ "$1" = "$2" ]; then pass "$3"; else fail "$3（期待: $2 / 実際: ${1:-なし}）"; fi
}

# target/manifest.json を読む小道具（Python はコンテナに入っている）
manifest_py() { python3 -c "$1" 2>/dev/null; }

summary() {
    echo
    if [ ${#_FAILS[@]} -eq 0 ]; then
        printf '\033[32m✔ 正解です\033[0m\n'
        exit 0
    fi
    printf '\033[31m✘ まだ条件を満たしていません\033[0m\n'
    for f in "${_FAILS[@]}"; do printf '   - %s\n' "$f"; done
    printf '\nREADME.md の「受け入れ条件」を確認してください。\n'
    exit 1
}
