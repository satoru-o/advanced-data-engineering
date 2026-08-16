#!/usr/bin/env bash
# 答え合わせ。コンテナ内で ./check.sh と打つ。
set -uo pipefail
cd "$(dirname "$0")"
source ../shared/check_lib.sh

SCHEMA=analytics_t01
TABLE=customer_names

echo "answer check: tutorial-01"

# 1) モデルが作られているか（dbt run したか）
kind="$(relation_kind "$SCHEMA" "$TABLE")"
if [ -z "$kind" ]; then
    fail "$SCHEMA.$TABLE が存在しません（まず dbt run を実行してください）"
    summary
fi
expect_eq "$kind" "VIEW" "$SCHEMA.$TABLE が VIEW として存在する"

# 2) 列がそろっているか
cols="$(relation_columns "$SCHEMA" "$TABLE")"
expect_eq "$cols" "customer_id,first_name,full_name,last_name" "4 つの列がある"

# 3) 行数
if [ "$cols" = "customer_id,first_name,full_name,last_name" ]; then
    rows="$(q "select count(*) from $SCHEMA.$TABLE")"
    expect_eq "$rows" "100" "100 行ある"

    sample="$(q "select full_name from $SCHEMA.$TABLE where customer_id = 1")"
    expect_eq "$sample" "Michael P." "customer_id = 1 の full_name が 'Michael P.'"

    # 4) 値の検査は dbt のテストに任せる（tests/check_customer_names.sql）
    if dbt test --select tag:check >/dev/null 2>&1; then
        pass "dbt test（full_name の組み立て）が通る"
    else
        fail "dbt test が落ちています（詳細: dbt test --select tag:check）"
    fi
fi

summary
