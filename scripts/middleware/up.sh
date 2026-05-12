#!/usr/bin/env bash
# =============================================================================
# scripts/middleware/up.sh
# -----------------------------------------------------------------------------
# 中间件日常启停入口
#
# 用法：
#   up.sh
#
# 相关入口：
#   scripts/middleware/init-up.sh <bind> <stack>  首次部署 / 完整重建
#   scripts/middleware/down.sh                    关停中间件
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

case "${1:-}" in
    --help|-h)
        sed -n '/^# ====/,/^# ====/p' "$0" | sed 's/^# \{0,1\}//' | head -30
        exit 0
        ;;
    "") ;;
    *)
        echo "up.sh 不接受参数；首次部署请用 init-up.sh <bind> <stack>" >&2
        exit 1
        ;;
esac

# ──────────────────────────────────────────────────────────────────────────────
# 装载公共库
# ──────────────────────────────────────────────────────────────────────────────
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/preflight.sh
. "$SCRIPT_DIR/lib/preflight.sh"
# shellcheck source=lib/compose.sh
. "$SCRIPT_DIR/lib/compose.sh"

# ──────────────────────────────────────────────────────────────────────────────
# 预检并加载环境变量
# ──────────────────────────────────────────────────────────────────────────────
check_environment
if [ ! -f "$ENV_FILE" ]; then
    err "$ENV_FILE 不存在；请先执行 scripts/middleware/init-up.sh <bind> <stack>"
    exit 1
fi
load_env
weak_output="$(scan_weak_secrets "$ENV_FILE" || true)"
if [ -n "$weak_output" ]; then
    if [ "${WISEPEN_BIND_ADDR:-127.0.0.1}" != "127.0.0.1" ]; then
        err ".env 含弱密码字段，server 环境有安全风险，启动已终止"
        printf '%s\n' "$weak_output" | sed 's/^/    /' >&2
        err "请执行 scripts/envs/init-envs.sh --random-secrets 生成强密码"
        exit 1
    else
        warn ".env 含弱密码字段（local 环境可以继续）"
        printf '%s\n' "$weak_output" | sed 's/^/    /'
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# 加载 Docker Compose 配置
# ─────────────────────────────────────────────────────────────────────────────
build_compose_files
compose=( --env-file "$ENV_FILE" "${COMPOSE_FILES[@]}" )

# ──────────────────────────────────────────────────────────────────────────────
# 执行启动
# ──────────────────────────────────────────────────────────────────────────────
say "启动服务"
( cd "$MIDDLEWARE_DIR" && docker compose "${compose[@]}" up -d )

export MIDDLEWARE_STACK="${MIDDLEWARE_STACK:-minimal}"

ok "中间件已启动"
say "  Nacos 控制台：     http://localhost:${WISEPEN_NACOS_HOST_PORT:-8848}/nacos"
say "  APISIX 入口：      http://localhost:${APISIX_HTTP_PORT:-9080}"
if [ "$MIDDLEWARE_STACK" = "full" ]; then
    say "  Jenkins：          http://localhost:${JENKINS_HTTP_HOST_PORT:-8080}"
fi
