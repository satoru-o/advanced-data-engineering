#!/usr/bin/env bash
# 答え合わせ。コンテナ内で ./check.sh と打つ。
set -uo pipefail
cd "$(dirname "$0")"
source ../shared/check_lib.sh

SCHEMA=analytics_t02
TABLE=customer_names

echo "answer check: tutorial-02"

# 1) SQL に生テーブル名が直書きされていないこと
if grep -qiE 'from[[:space:]]+raw\.raw_customers' work/models/customer_names.sql; then
    fail "work/models/customer_names.sql に raw.raw_customers が直書きのまま残っている"
else
    pass "生テーブル名の直書きがない"
fi

# 2) source が定義され、モデルがそれに依存していること（manifest を見る）
dbt parse -q >/dev/null 2>&1
dep="$(manifest_py '
import json
m = json.load(open("target/manifest.json"))
srcs = [s["unique_id"] for s in m.get("sources", {}).values()]
node = next((v for v in m["nodes"].values() if v["name"] == "customer_names"), None)
deps = node["depends_on"]["nodes"] if node else []
print("SOURCES=%d" % len(srcs))
print("USES_SOURCE=%s" % ("yes" if any(d.startswith("source.") for d in deps) else "no"))
print("HAS_CUSTOMERS=%s" % ("yes" if any(s.endswith(".raw_customers") for s in srcs) else "no"))
')"

n_sources="$(sed -n 's/^SOURCES=//p' <<<"$dep")"
uses_source="$(sed -n 's/^USES_SOURCE=//p' <<<"$dep")"
has_customers="$(sed -n 's/^HAS_CUSTOMERS=//p' <<<"$dep")"

if [ -z "$n_sources" ]; then
    fail "dbt parse に失敗しました（YAML か SQL に文法エラーがあります。dbt parse で確認）"
    summary
fi

expect_eq "$has_customers" "yes" "raw_customers の source が定義されている"
expect_eq "$uses_source" "yes" "customer_names が source() 経由で参照している"

# 3) 出来上がりは tutorial-01 と同じであること
kind="$(relation_kind "$SCHEMA" "$TABLE")"
if [ -z "$kind" ]; then
    fail "$SCHEMA.$TABLE が存在しません（dbt run を実行してください）"
    summary
fi
expect_eq "$kind" "VIEW" "$SCHEMA.$TABLE が VIEW として存在する"
expect_eq "$(q "select count(*) from $SCHEMA.$TABLE")" "100" "100 行ある"
expect_eq "$(q "select full_name from $SCHEMA.$TABLE where customer_id = 1")" "Michael P." \
    "customer_id = 1 の full_name が 'Michael P.'"

if dbt test --select tag:check >/dev/null 2>&1; then
    pass "dbt test（値の検査）が通る"
else
    fail "dbt test が落ちています（詳細: dbt test --select tag:check）"
fi

summary
