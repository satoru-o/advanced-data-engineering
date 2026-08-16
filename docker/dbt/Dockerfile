# dbt 実行環境。Python 依存は uv（pyproject.toml + uv.lock）で管理する。
# ホストには何もインストールしない。
ARG UV_IMAGE=ghcr.io/astral-sh/uv:python3.11-bookworm-slim
FROM ${UV_IMAGE}

# git          : dbt deps で git 参照のパッケージを取る場合に必要
# postgresql-client : チュートリアルの答え合わせ（check.sh）から psql を使う
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# venv は /opt/venv に作り、PATH に通す。
# → コンテナ内では `uv run` を挟まずに素の `dbt` が使える。
ENV UV_PROJECT_ENVIRONMENT=/opt/venv \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:$PATH \
    DBT_PROFILES_DIR=/work/shared \
    HOME=/tmp \
    PYTHONUNBUFFERED=1

WORKDIR /work

# 依存だけを先に固める（uv.lock どおり = 再現可能）
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev \
    && dbt --version

# ログインシェル（bash -l）でも venv が見えるようにしておく
RUN printf 'export PATH=/opt/venv/bin:$PATH\n' > /etc/profile.d/10-venv.sh \
    && ln -s /opt/venv/bin/dbt /usr/local/bin/dbt

# ホストの UID で動かすため /etc/passwd に該当ユーザーがおらず、
# 既定のプロンプトが "I have no name!@..." になってしまうので上書きする
RUN printf "export PS1='\\[\\033[36m\\]dbt\\[\\033[0m\\]:\\w\\$ '\n" >> /etc/bash.bashrc

# 常駐させて `docker compose exec` で使う
CMD ["sleep", "infinity"]
