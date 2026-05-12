#!/usr/bin/env bash
# =============================================================================
# scripts/middleware/init-up.sh
# -----------------------------------------------------------------------------
# 中间件首次部署/完整重建入口
#
# 用法：
#   init-up.sh <bind> <stack>
#
# 参数：
#   bind:
#     local   写入 WISEPEN_BIND_ADDR=127.0.0.1，仅允许本机访问
#     server  写入 WISEPEN_BIND_ADDR=0.0.0.0，对外暴露；若检测到弱密码则拒绝启动
#
#   stack:
#     minimal 启动核心中间件：mysql、redis、mongo、nacos、apisix、kafka、qdrant、jodconverter
#             以及 docker-compose.yml 中声明的依赖服务，例如 etcd、apisix-dashboard、kafka-ui
#     full    在 minimal 基础上追加 jenkins、observability、search 等扩展服务
#
#
# 执行流程
# 1. 渲染数据库初始化文件到 deploy/middleware/seed/.rendered/{mysql,mongo}
# 2. 启动 MySQL 与 MongoDB，并等待 Ready
# 2-1. [自动] MySQL 加载 deploy/middleware/seed/.rendered/mysql/* 目录下的 SQL 文件
# 2-2. [自动] MongoDB 加载 deploy/middleware/seed/.rendered/mongo/* 目录下的 JS 文件
# 3. 启动 Nacos、Redis、etcd、Kafka、Kafka UI、Qdrant、JodConverter，并等待 Redis / Nacos ready
# 4. 设置 Nacos 密码（使用 nacos/nacos 尝试登陆 Nacos 并将密码设置为 .env NACOS_PASSWORD）
# 5. 渲染 Nacos 配置并导入 Nacos
# 6. 启动剩余服务，包括 APISIX、Dashboard，以及 full 模式下的 Jenkins / observability / search
#
# 相关入口：
#   scripts/envs/init-envs.sh --random-secrets   生成强随机 deploy/middleware/.env
#   scripts/middleware/up.sh                     日常启动/重启中间件
#   scripts/middleware/down.sh                   关停中间件
#   scripts/middleware/seed.sh                   单独执行 database-init 或 nacos-config-init
#   scripts/middleware/jenkins.sh reload         热加载 Jenkins JCasC
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ──────────────────────────────────────────────────────────────────────────────
# 打印帮助信息
# ──────────────────────────────────────────────────────────────────────────────
usage() {
    sed -n '/^# ====/,/^# ====/p' "$0" | sed 's/^# \{0,1\}//' | head -40
}

# ──────────────────────────────────────────────────────────────────────────────
# 参数解析
# ──────────────────────────────────────────────────────────────────────────────
if [ "$#" -lt 2 ]; then
    usage
    exit 1
fi

BIND="$1"
STACK="$2"
shift 2 || true

if [ "$#" -gt 0 ]; then
    echo "init-up.sh 只接受 2 个固定位置参数：bind ∈ {local,server}, stack ∈ {minimal,full}" >&2
    echo "多余参数：$*" >&2
    usage
    exit 1
fi

case "$BIND" in
    local)   BIND_ADDR="127.0.0.1" ;;
    server)  BIND_ADDR="0.0.0.0"   ;;
    --help|-h) usage; exit 0 ;;
    *) echo "未知 bind: $BIND（应为 local 或 server）" >&2; usage; exit 1 ;;
esac

case "$STACK" in
    minimal|full) ;;
    *) echo "未知 stack: $STACK（应为 minimal 或 full）" >&2; usage; exit 1 ;;
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
# shellcheck source=lib/ready.sh
. "$SCRIPT_DIR/lib/ready.sh"
# shellcheck source=lib/render.sh
. "$SCRIPT_DIR/lib/render.sh"
# shellcheck source=lib/seed.sh
. "$SCRIPT_DIR/lib/seed.sh"

# ──────────────────────────────────────────────────────────────────────────────
# 预检并加载环境变量
# ──────────────────────────────────────────────────────────────────────────────
# server 环境下必须使用强密码，必须存在 .env 文件，否则拒绝启动
if [ ! -f "$ENV_FILE" ] && [ "$BIND" = "server" ]; then
    err "$ENV_FILE 不存在，server 环境不能使用 local-default.env（弱密码），启动已终止"
    err "请执行 scripts/envs/init-envs.sh --random-secrets 生成强密码，或手动新建 .env 并填入强密码后重试"
    exit 1
fi

# 检查 docker / docker compose 可用性
check_environment
# [Local模式] 检查 .env 文件是否存在（若不存在则使用使用 local-default.env）
check_env_file

# 扫描 .env 中的弱密码
weak_output="$(scan_weak_secrets "$ENV_FILE" || true)"
if [ -n "$weak_output" ]; then
    if [ "$BIND" = "server" ]; then
        err ".env 含弱密码字段，server 环境有安全风险，启动已终止"
        printf '%s\n' "$weak_output" | sed 's/^/    /' >&2
        err "请执行 scripts/envs/init-envs.sh --random-secrets 生成强密码，或手动新建 .env 并填入强密码后重试"
        exit 1
    else
        warn ".env 含弱密码字段，local 环境可以继续启动"
        printf '%s\n' "$weak_output" | sed 's/^/    /'
    fi
fi

# 加载环境变量
load_env

# ──────────────────────────────────────────────────────────────────────────────
# 回写配置
# ──────────────────────────────────────────────────────────────────────────────
# 将 bind_addr 持久化到 .env
current_bind="${WISEPEN_BIND_ADDR:-127.0.0.1}"
if [ "$current_bind" != "$BIND_ADDR" ]; then
    say "WISEPEN_BIND_ADDR：$current_bind → $BIND_ADDR（写回 .env）"
    replace_kv "$ENV_FILE" "WISEPEN_BIND_ADDR" "$BIND_ADDR"
fi
export WISEPEN_BIND_ADDR="$BIND_ADDR"

# 将 stack 持久化到 .env
current_stack="${MIDDLEWARE_STACK:-minimal}"
if [ "$current_stack" != "$STACK" ]; then
    say "MIDDLEWARE_STACK：$current_stack → $STACK（写回 .env）"
    replace_kv "$ENV_FILE" "MIDDLEWARE_STACK" "$STACK"
fi
export MIDDLEWARE_STACK="$STACK"

# ──────────────────────────────────────────────────────────────────────────────
# 加载 Docker Compose 配置并准备宿主机数据目录
# ─────────────────────────────────────────────────────────────────────────────
build_compose_files
prepare_bind_data

compose=( --env-file "$ENV_FILE" "${COMPOSE_FILES[@]}" )

# ──────────────────────────────────────────────────────────────────────────────
# 执行初始化与启动流程
# ──────────────────────────────────────────────────────────────────────────────

say "[1/6] 渲染数据库初始化文件到 $RENDERED_SEED_DIR/{mysql,mongo}"
do_database_init "create"

say "[2/6] 启动 MySQL 与 MongoDB，并等待 Ready"
say "首次启动时将自动加载 $RENDERED_SEED_DIR/{mysql,mongo} 目录下的 SQL/JS 文件（docker-entrypoint-initdb.d）"
( cd "$MIDDLEWARE_DIR" && docker compose "${compose[@]}" up -d --build mysql mongo )
wait_for_mysql
wait_for_mongo

say "[3/6] 启动 Nacos、Redis、etcd、Kafka、Kafka UI、Qdrant、JodConverter，并等待 Redis / Nacos ready"
( cd "$MIDDLEWARE_DIR" && docker compose "${compose[@]}" up -d --build \
    nacos redis etcd kafka kafka-ui qdrant jodconverter )
wait_for_redis
wait_for_nacos

say "[4/6] 设置 Nacos 密码"
bootstrap_nacos_password

say "[5/6] 渲染 Nacos 配置 yaml 并导入 Nacos 配置"
do_nacos_config_init "create-if-missing" 1

say "[6/6] 启动剩余服务"
( cd "$MIDDLEWARE_DIR" && docker compose "${compose[@]}" up -d --build )

ok "中间件已就绪。日常重启用：scripts/middleware/up.sh（无参数）"
say "  生成各微服务 .env：scripts/envs/init-envs.sh"
say "  Nacos 控制台：     http://localhost:${WISEPEN_NACOS_HOST_PORT:-8848}/nacos"
say "  APISIX 入口：      http://localhost:${APISIX_HTTP_PORT:-9080}"
if [ "$STACK" = "full" ]; then
    say "  Jenkins：          http://localhost:${JENKINS_HTTP_HOST_PORT:-8080}"
fi
