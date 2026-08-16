# =============================================================================
#  dbt チュートリアル集
#
#    mk                       チュートリアル一覧
#    mk tutorial-01 start     起動して tutorial-01 の中に入る（start は省略可）
#    mk tutorial-01 exit      終了
#    mk tutorial-01 reset     その回を一からやり直し（確認を省くなら YES=1）
#
#  「主語（tutorial-01）」と「動詞（start/exit/reset）」を並べて渡す。
#  主語は tutorial-01 / 01 / 1 / ディレクトリ名 のどれでもよい。
#
#  ※ レシピ内にバッククォートを書かないこと（シェルが実行してしまう）
# =============================================================================

SHELL := /bin/bash
MAKEFLAGS += --no-print-directory
.DEFAULT_GOAL := help

ROOT_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
UV_IMAGE ?= ghcr.io/astral-sh/uv:python3.11-bookworm-slim

# --- 主語（チュートリアル）の解決 --------------------------------------------
TUTORIAL_DIRS := $(notdir $(wildcard $(ROOT_DIR)/tutorial-*))
# tutorial-01-first-model → 01
tut_num  = $(word 2,$(subst -, ,$(1)))
TUT_NUMS := $(foreach d,$(TUTORIAL_DIRS),$(call tut_num,$(d)))
# 受け付ける書き方: フルのディレクトリ名 / 01 / 1 / tutorial-01
TUT_GOALS := $(sort $(TUTORIAL_DIRS) $(TUT_NUMS) $(patsubst 0%,%,$(TUT_NUMS)) \
                    $(addprefix tutorial-,$(TUT_NUMS)))

tut_dir = $(strip $(foreach d,$(TUTORIAL_DIRS),\
            $(if $(filter $(1),$(d) $(call tut_num,$(d)) tutorial-$(call tut_num,$(d)) \
                               $(patsubst 0%,%,$(call tut_num,$(d)))),$(d))))

VERBS      := start exit reset ps logs build lock env help
GOAL_VERBS := $(filter $(VERBS),$(MAKECMDGOALS))
TUT_SPEC   := $(firstword $(filter-out $(VERBS),$(MAKECMDGOALS)))
TUT        ?= $(call tut_dir,$(TUT_SPEC))

YES  ?=      # 1 なら reset の確認プロンプトを省略
ARGS ?=

# その回が専用 compose を持っていればそれを使う（Airflow / Iceberg など重い回）
TUT_COMPOSE  := $(wildcard $(ROOT_DIR)/$(TUT)/docker-compose.yml)
COMPOSE_FILE := $(if $(TUT_COMPOSE),$(TUT_COMPOSE),$(ROOT_DIR)/docker-compose.yml)
COMPOSE       = docker compose --env-file $(ROOT_DIR)/.env -f $(COMPOSE_FILE)

TUT_NUM = $(call tut_num,$(TUT))

# 主語そのものはターゲットとしては何もしない（同名ディレクトリがあるので .PHONY 必須）。
# 動詞が付いていないときだけ start として扱う。
.PHONY: $(TUT_GOALS)
$(TUT_GOALS):
	@if [ -z "$(strip $(GOAL_VERBS))" ]; then $(MAKE) start TUT=$(call tut_dir,$@); fi

# =============================================================================
#  start / exit / reset
# =============================================================================

.PHONY: start
start: require-tut env work-dir ## 起動してチュートリアルの中に入る（例: mk tutorial-01 start）
	@$(COMPOSE) up -d --build --wait
	@printf '\n\033[36m── %s ──\033[0m\n' "$(TUT)"
	@printf 'いま /work/%s にいます。README.md にお題があります。\n' "$(TUT)"
	@printf '  cat README.md      お題を読む\n'
	@printf '  vi work/models/... 編集するのは work/ 配下だけ\n'
	@printf '  dbt run            モデルを作る\n'
	@printf '  ./check.sh         答え合わせ\n'
	@printf '  exit               シェルを抜ける（コンテナは動いたまま）\n\n'
	@$(COMPOSE) exec -w /work/$(TUT) dbt bash

# work/ は git 管理外。無ければ .skeleton から作る
.PHONY: work-dir
work-dir:
	@if [ ! -d "$(ROOT_DIR)/$(TUT)/work" ]; then \
		cp -a "$(ROOT_DIR)/$(TUT)/.skeleton" "$(ROOT_DIR)/$(TUT)/work"; \
		echo "✓ $(TUT)/work を作成しました（.skeleton から）"; \
	fi

.PHONY: exit
exit: ## 終了（DB のデータは残る）
	@$(COMPOSE) down

.PHONY: reset
reset: env ## 一からやり直し（主語なしなら環境全体。確認を省くなら YES=1）
ifeq ($(strip $(TUT)),)
	@echo "環境全体を作り直します（DB のデータも消えます）"
	@$(COMPOSE) down -v
	@$(COMPOSE) up -d --build --wait
	@echo "✓ 環境を作り直しました。mk <tutorial> start で始められます"
else
	@if [ ! -d "$(ROOT_DIR)/$(TUT)/.skeleton" ]; then \
		echo "✘ $(TUT)/.skeleton がありません（初期状態を復元できません）"; exit 1; fi
	@if [ "$(YES)" != "1" ]; then \
		echo "$(TUT) を初期状態に戻します:"; \
		echo "  - スキーマ analytics_t$(TUT_NUM)% を削除"; \
		echo "  - work/ を破棄して .skeleton から作り直し（書きかけは消えます）"; \
		echo "  - target/ logs/ dbt_packages/ を削除"; \
		read -r -p "続けますか? [y/N] " ans; \
		case "$$ans" in [yY]*) ;; *) echo "中止しました"; exit 1;; esac; \
	fi
	@$(COMPOSE) up -d --wait >/dev/null
	@$(COMPOSE) exec -T dbt bash -c '\
		for s in $$(psql -Atc "select nspname from pg_namespace where nspname like '"'"'analytics_t$(TUT_NUM)%'"'"'"); do \
			psql -q -c "drop schema if exists \"$$s\" cascade"; echo "  drop schema $$s"; \
		done' || true
	@rm -rf "$(ROOT_DIR)/$(TUT)/work" "$(ROOT_DIR)/$(TUT)/target" \
	        "$(ROOT_DIR)/$(TUT)/logs" "$(ROOT_DIR)/$(TUT)/dbt_packages"
	@cp -a "$(ROOT_DIR)/$(TUT)/.skeleton" "$(ROOT_DIR)/$(TUT)/work"
	@echo "✓ $(TUT)/work を初期状態に戻しました"
endif

# =============================================================================
#  補助
# =============================================================================

.PHONY: ps
ps: ## コンテナの状態
	@$(COMPOSE) ps

.PHONY: logs
logs: ## ログを追う
	@$(COMPOSE) logs -f --tail=100 $(ARGS)

.PHONY: build
build: env ## dbt イメージを作り直す
	@$(COMPOSE) build

.PHONY: lock
lock: ## pyproject.toml を変えたら実行（コンテナ内で uv lock）
	@docker run --rm -v "$(ROOT_DIR)":/w -w /w -e HOME=/tmp -e UV_LINK_MODE=copy \
		--user "$$(id -u):$$(id -g)" $(UV_IMAGE) uv lock
	@echo "✓ uv.lock を更新しました。mk build でイメージを作り直してください"

.PHONY: require-tut
require-tut:
	@if [ -z "$(strip $(TUT))" ]; then \
		if [ -n "$(strip $(TUT_SPEC))" ]; then \
			echo "✘ '$(TUT_SPEC)' に対応するチュートリアルがありません"; \
		else \
			echo "✘ チュートリアルを指定してください（例: mk tutorial-01 start）"; \
		fi; \
		$(MAKE) --no-print-directory list; exit 1; \
	fi

# .env が無ければホストの UID/GID と MTU を見て作る
.PHONY: env
env: ## .env を（無ければ）作る
	@if [ ! -f "$(ROOT_DIR)/.env" ]; then \
		iface=$$(ip route show default 2>/dev/null | awk '{print $$5}' | head -1); \
		mtu=$$(ip -o link show $$iface 2>/dev/null | grep -o 'mtu [0-9]*' | awk '{print $$2}'); \
		mtu=$${mtu:-1500}; \
		sed -e "s/^HOST_UID=.*/HOST_UID=$$(id -u)/" \
		    -e "s/^HOST_GID=.*/HOST_GID=$$(id -g)/" \
		    -e "s/^DOCKER_NETWORK_MTU=.*/DOCKER_NETWORK_MTU=$$mtu/" \
		    "$(ROOT_DIR)/.env.example" > "$(ROOT_DIR)/.env"; \
		echo "✓ .env を作成 (UID=$$(id -u) GID=$$(id -g) MTU=$$mtu)"; \
	fi

.PHONY: list
list:
	@printf '\033[1mチュートリアル\033[0m\n'
	@for d in $(sort $(TUTORIAL_DIRS)); do \
		title=$$(head -1 "$(ROOT_DIR)/$$d/README.md" 2>/dev/null | sed -e 's/^# *//'); \
		printf '  \033[36m%-28s\033[0m %s\n' "$$d" "$$title"; \
	done

.PHONY: help
help: ## このヘルプ
	@printf '\033[1mdbt チュートリアル集\033[0m\n\n'
	@printf '  \033[36mmk <tutorial> start\033[0m   起動して、その回のディレクトリに入る（start は省略可）\n'
	@printf '  \033[36mmk <tutorial> exit\033[0m    終了（DB のデータは残る）\n'
	@printf '  \033[36mmk <tutorial> reset\033[0m   その回を一からやり直し（確認を省くなら YES=1）\n\n'
	@printf '  例)  mk tutorial-01 start  /  mk 01 start  /  mk 1  /  mk 01 reset YES=1\n\n'
	@$(MAKE) --no-print-directory list
	@printf '\n  その他: mk ps / mk logs / mk build / mk lock / mk reset（環境全体を作り直し）\n'

# 知らないターゲットを叩いたときの案内（Makefile 自身の再作成は抑止する）
Makefile: ;
%::
	@echo "✘ '$@' は知らないコマンドです"
	@$(MAKE) --no-print-directory help
	@exit 1
