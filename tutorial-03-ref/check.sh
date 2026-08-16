#!/usr/bin/env bash
# 答え合わせ。コンテナ内で ./check.sh と打つ。
set -uo pipefail
cd "$(dirname "$0")"
source ../shared/check_lib.sh

SCHEMA=analytics_t03

echo "answer check: tutorial-03"

# 1) 依存関係を manifest で確認（source 直参照ではなく ref であること）
dbt parse -q >/dev/null 2>&1
info="$(manifest_py '
import json
m = json.load(open("target/manifest.json"))
node = next((v for v in m["nodes"].values() if v["name"] == "customer_names"), None)
deps = node["depends_on"]["nodes"] if node else []
print("REFS_STG=%s" % ("yes" if any(d.endswith(".stg_customers") for d in deps) else "no"))
print("USES_SOURCE=%s" % ("yes" if any(d.startswith("source.") for d in deps) else "no"))
')"
refs_stg="$(sed -n 's/^REFS_STG=//p' <<<"$info")"
uses_source="$(sed -n 's/^USES_SOURCE=//p' <<<"$info")"

if [ -z "$refs_stg" ]; then
    fail "dbt parse に失敗しました（SQL に文法エラーがあります。dbt parse で確認）"
    summary
fi
expect_eq "$refs_stg" "yes" "customer_names が ref('stg_customers') を使っている"
expect_eq "$uses_source" "no" "customer_names は source を直接参照していない"

# 2) 2 つのモデルが両方できているか
for t in stg_customers customer_names; do
    kind="$(relation_kind "$SCHEMA" "$t")"
    if [ -z "$kind" ]; then
        fail "$SCHEMA.$t が存在しません（dbt run を実行してください）"
    else
        expect_eq "$kind" "VIEW" "$SCHEMA.$t が VIEW として存在する"
    fi
done

# 3) 中身
if [ -n "$(relation_kind "$SCHEMA" customer_names)" ]; then
    expect_eq "$(relation_columns "$SCHEMA" customer_names)" \
        "customer_id,first_name,full_name,last_name" "4 つの列がある"
    expect_eq "$(q "select count(*) from $SCHEMA.customer_names")" "100" "100 行ある"
    expect_eq "$(q "select full_name from $SCHEMA.customer_names where customer_id = 1")" \
        "Michael P." "customer_id = 1 の full_name が 'Michael P.'"

    if dbt test --select tag:check >/dev/null 2>&1; then
        pass "dbt test（値の検査）が通る"
    else
        fail "dbt test が落ちています（詳細: dbt test --select tag:check）"
    fi
fi

summary
