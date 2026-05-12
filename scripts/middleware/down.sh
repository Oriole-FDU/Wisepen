#!/usr/bin/env bash
# =============================================================================
# scripts/middleware/down.sh
# -----------------------------------------------------------------------------
# 关闭中间件（默认保留数据卷）
#
# 用法：
#   down.sh                 # 关闭所有中间件
#   down.sh --volumes       # 清理存储卷（危险！）
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MIDDLEWARE_DIR="$REPO_ROOT/deploy/middleware"
ENV_FILE="$MIDDLEWARE_DIR/.env"

REMOVE_DATA=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --volumes|-v) REMOVE_DATA=1; shift ;;
        --help|-h)
            sed -n '/^# ====/,/^# ====/p' "$0" | sed 's/^# \{0,1\}//' | head -10
            exit 0 ;;
        *) echo "未知参数: $1" >&2; exit 1 ;;
    esac
done

say()  { printf '\033[36m[mw-down]\033[0m  %s\n' "$*"; }
warn() { printf '\033[33m[mw-down WARN]\033[0m  %s\n' "$*" >&2; }
ok()   { printf '\033[32m[mw-down OK ]\033[0m  %s\n' "$*"; }

COMPOSE_ARGS=( -f "$MIDDLEWARE_DIR/docker-compose.yml"
               -f "$MIDDLEWARE_DIR/profiles/jenkins.yml"
               -f "$MIDDLEWARE_DIR/profiles/observability.yml"
               -f "$MIDDLEWARE_DIR/profiles/search.yml" )

say "docker compose down"
if [ -f "$ENV_FILE" ]; then
    ( cd "$MIDDLEWARE_DIR" && docker compose --env-file "$ENV_FILE" "${COMPOSE_ARGS[@]}" down --remove-orphans )
else
    ( cd "$MIDDLEWARE_DIR" && docker compose "${COMPOSE_ARGS[@]}" down --remove-orphans )
fi

if [ "$REMOVE_DATA" -eq 1 ]; then
    DATA_DIR="$MIDDLEWARE_DIR/data"
    warn "即将删除 $DATA_DIR/*  （MySQL/Redis/Mongo/Nacos/Kafka/Qdrant/Jenkins 等所有数据）"
    printf '继续吗？[y/N]: '
    read -r reply
    case "$reply" in
        [yY]|[yY][eE][sS])
            rm -rf "$DATA_DIR"/*
            ok "存储卷已清空"
            ;;
        *) warn "用户取消存储卷删除" ;;
    esac
fi

ok "完成"
