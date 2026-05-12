#!/usr/bin/env bash
# =============================================================================
# scripts/apps/build-and-deploy.sh
# -----------------------------------------------------------------------------
# 本地一键打包 + 部署微服务镜像（Jenkins 之外的脚本路径）。
#
# 流程：
#   1. 确保 wisepen-net 网络存在
#   2. 探测 cloud-infra_cloud-net：存在则在各子仓库的 docker-compose-app.yml 之上
#      叠加 docker-compose-app.legacy-net.yml overlay
#   3. 注册 APISIX 路由（调子仓库 wisepen-cloud-gateway-deploy/setup.sh）
#   4. 构建 Java（mvn package + 拷 *-biz/app.jar + 下载 OTel agent），起 wisepen-cloud apps
#   5. 构建 Python（uv 在 docker build 内），起 wisepen-cloud-ai apps
#   6. 构建 NodeJS（pnpm 在 docker build 内），起 wisepen-cloud-sidecar apps
#   7. 前端（wisepen-view）镜像化部署本轮不在脚本范围（用 IDE / pnpm dev 即可）
#
# 用法：
#   build-and-deploy.sh                      # 全套（gateway + java + python + nodejs）
#   build-and-deploy.sh --only gateway       # 只注册 APISIX 路由
#   build-and-deploy.sh --only java          # 只跑 Java（mvn + apps）
#   build-and-deploy.sh --only python        # 只跑 Python
#   build-and-deploy.sh --only nodejs        # 只跑 NodeJS sidecar
#   build-and-deploy.sh --skip-build         # 不编译，直接 docker compose up
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/deploy/middleware/.env"
CLOUD_DIR="$REPO_ROOT/wisepen-cloud"
AI_DIR="$REPO_ROOT/wisepen-cloud-ai"
SIDECAR_DIR="$REPO_ROOT/wisepen-cloud-sidecar"
GATEWAY_DIR="$REPO_ROOT/wisepen-cloud-gateway-deploy"

# ──────────────────────────────────────────────────────────────────────────────
# 装载公共库
# ──────────────────────────────────────────────────────────────────────────────
# shellcheck source=../middleware/lib/common.sh
. "$REPO_ROOT/scripts/middleware/lib/common.sh"
# shellcheck source=lib/preflight.sh
. "$SCRIPT_DIR/lib/preflight.sh"

ONLY=""
SKIP_BUILD=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --only)         ONLY="$2"; shift 2 ;;
        --only=*)       ONLY="${1#*=}"; shift ;;
        --skip-build)   SKIP_BUILD=1; shift ;;
        --help|-h)
            sed -n '/^# ====/,/^# ====/p' "$0" | sed 's/^# \{0,1\}//' | head -25
            exit 0 ;;
        *) echo "未知参数: $1" >&2; exit 1 ;;
    esac
done

say()  { printf '\033[36m[apps]\033[0m  %s\n' "$*"; }
warn() { printf '\033[33m[apps WARN]\033[0m  %s\n' "$*" >&2; }
err()  { printf '\033[31m[apps ERR ]\033[0m  %s\n' "$*" >&2; }
ok()   { printf '\033[32m[apps OK ]\033[0m  %s\n' "$*"; }

want() {
    [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]
}

# ──────────────────────────────────────────────────────────────────────────────
# 预检并加载环境变量
# ──────────────────────────────────────────────────────────────────────────────
# 检查 docker / docker compose 可用性
check_environment

#必须存在 .env 文件，否则拒绝启动
if [ ! -f "$ENV_FILE" ]; then
    err "$ENV_FILE 不存在，请先准备中间件环境（执行 scripts/middleware/init-up.sh local|server minimal|full）"
    exit 1
fi

# 加载环境变量
load_env

# ──────────────────────────────────────────────────────────────────────────────
# 构建微服务并启动
# ──────────────────────────────────────────────────────────────────────────────

# 各子仓库 compose 中均用 ${DOCKER_REGISTRY}/wisepencloud-*:${APP_VERSION}；
# 本机 build-and-deploy 时 DOCKER_REGISTRY 默认 'local'，APP_VERSION 默认 'latest'。
export DOCKER_REGISTRY="${DOCKER_REGISTRY:-local}"
export APP_VERSION="${APP_VERSION:-latest}"

# 探测 wisepen-net 网络 与 cloud-infra_cloud-net 网络（旧网络）
ensure_networks() {
    say "确保 wisepen-net 存在（不存在则 create）"
    if ! docker network inspect wisepen-net >/dev/null 2>&1; then
        docker network create wisepen-net >/dev/null
        ok "已创建 wisepen-net"
    else
        ok "wisepen-net 已存在"
    fi

    # 老网络仅探测，不创建
    if docker network inspect cloud-infra_cloud-net >/dev/null 2>&1; then
        ok "探测到 cloud-infra_cloud-net；将启用 legacy-net overlay"
        LEGACY_NET_PRESENT=1
    else
        say "未探测到 cloud-infra_cloud-net；不启用 legacy-net overlay（新机器零污染）"
        LEGACY_NET_PRESENT=0
    fi
}

# 动态生成 Docker Compose 参数
# 根据当前子仓库路径，拼出需要传给 docker compose 的 -f xxx.yml 参数列表
subrepo_compose_args() {
    local dir="$1"
    local args=( -f "$dir/docker-compose-app.yml" )
    if [ "$LEGACY_NET_PRESENT" -eq 1 ] && [ -f "$dir/docker-compose-app.legacy-net.yml" ]; then
        args+=( -f "$dir/docker-compose-app.legacy-net.yml" )
    fi
    printf '%s\n' "${args[@]}"
}

# 部署 APISIX 路由（调用子仓库 wisepen-cloud-gateway-deploy/setup.sh）
do_gateway() {
    if [ ! -d "$GATEWAY_DIR" ]; then
        err "找不到 $GATEWAY_DIR — 请先 git submodule update --init"
        exit 1
    fi
    say "注册 APISIX 路由（调 $GATEWAY_DIR/setup.sh）"
    export APISIX_ADMIN_HOST="${APISIX_ADMIN_HOST:-localhost}"
    export APISIX_ADMIN_PORT="${APISIX_ADMIN_HOST_PORT:-9180}"
    export APISIX_ADMIN_KEY="${APISIX_ADMIN_KEY:?APISIX_ADMIN_KEY must be set in middleware .env}"
    export REDIS_AUTH_PASSWORD="${WISEPEN_REDIS_PASSWORD:?WISEPEN_REDIS_PASSWORD must be set in middleware .env}"
    export FROM_SOURCE_SECRET="${FROM_SOURCE_SECRET:?FROM_SOURCE_SECRET must be set in middleware .env}"

    if ! curl -sf --max-time 5 -H "X-API-KEY: $APISIX_ADMIN_KEY" \
            "http://$APISIX_ADMIN_HOST:$APISIX_ADMIN_PORT/apisix/admin/routes" >/dev/null; then
        err "APISIX Admin API 不可达：http://$APISIX_ADMIN_HOST:$APISIX_ADMIN_PORT"
        err "请先 scripts/middleware/up.sh，确认 APISIX_ADMIN_KEY 与中间件 .env 一致"
        exit 1
    fi

    ( cd "$GATEWAY_DIR" && bash setup.sh )
    ok "APISIX 路由已写入"
}

# 部署 Java 微服务（调用子仓库 wisepen-cloud/mvnw 或 mvn 编译）
do_java() {
    if [ ! -d "$CLOUD_DIR" ]; then
        err "找不到 $CLOUD_DIR — 请先 git submodule update --init"
        exit 1
    fi

    if [ "$SKIP_BUILD" -eq 0 ]; then
        say "Maven 编译 wisepen-cloud（约 3-10 分钟）"
        if [ -x "$CLOUD_DIR/mvnw" ]; then
            ( cd "$CLOUD_DIR" && ./mvnw -DskipTests clean package )
        elif command -v mvn >/dev/null 2>&1; then
            ( cd "$CLOUD_DIR" && mvn -DskipTests clean package )
        else
            err "找不到 mvn 也找不到 mvnw；请安装 Maven 3.9+"
            exit 1
        fi

        say "拷贝 *-biz/target/*.jar → *-biz/app.jar"
        for biz_dir in "$CLOUD_DIR"/wisepen-*-service/wisepen-*-biz; do
            [ -d "$biz_dir/target" ] || continue
            local_name="$(basename "$biz_dir")"
            jar_file=""
            max_size=0
            while IFS= read -r f; do
                sz=$(wc -c <"$f" | tr -d ' ')
                if [ "$sz" -gt "$max_size" ]; then
                    max_size=$sz
                    jar_file="$f"
                fi
            done < <(find "$biz_dir/target" -maxdepth 1 -name "*.jar" ! -name "*-original.jar" 2>/dev/null)
            if [ -z "$jar_file" ]; then
                warn "  $local_name 找不到可执行 jar，跳过"
                continue
            fi
            cp "$jar_file" "$biz_dir/app.jar"
            say "  $local_name -> $(basename "$jar_file")"
        done

        AGENT="$CLOUD_DIR/opentelemetry-javaagent.jar"
        if [ ! -f "$AGENT" ]; then
            say "下载 opentelemetry-javaagent.jar"
            curl -fL -o "$AGENT" \
                https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar
        fi
    fi

    say "启动 wisepen-cloud apps"
    mapfile -t COMPOSE_ARGS < <(subrepo_compose_args "$CLOUD_DIR")
    ( cd "$CLOUD_DIR" && docker compose --env-file "$ENV_FILE" "${COMPOSE_ARGS[@]}" up -d --build )
    ok "启动 wisepen-cloud apps 完成"
}

# 部署 Python 微服务（调用子仓库 wisepen-cloud-ai 构建）
do_python() {
    if [ ! -d "$AI_DIR" ]; then
        err "找不到 $AI_DIR — 请先 git submodule update --init"
        exit 1
    fi
    say "启动 wisepen-cloud-ai apps（docker build 内部 uv sync）"
    mapfile -t COMPOSE_ARGS < <(subrepo_compose_args "$AI_DIR")
    ( cd "$AI_DIR" && docker compose --env-file "$ENV_FILE" "${COMPOSE_ARGS[@]}" up -d --build )
    ok "启动 wisepen-cloud-ai apps 完成"
}

# 部署 NodeJS 微服务（调用子仓库 wisepen-cloud-sidecar 构建）
do_nodejs() {
    if [ ! -d "$SIDECAR_DIR" ]; then
        err "找不到 $SIDECAR_DIR — 请先 git submodule update --init"
        exit 1
    fi

    say "启动 wisepen-cloud-sidecar apps（docker build 内部 pnpm install/build）"
    mapfile -t COMPOSE_ARGS < <(subrepo_compose_args "$SIDECAR_DIR")
    ( cd "$SIDECAR_DIR" && docker compose --env-file "$ENV_FILE" "${COMPOSE_ARGS[@]}" up -d --build --remove-orphans )
    ok "启动 wisepen-cloud-sidecar apps 完成"
}

# 前端部署（占位）
do_view_warn() {
    warn "前端（wisepen-view）镜像化部署暂不可用，请手动部署"
}

# ───── 主流程 ─────
ensure_networks

if want gateway; then do_gateway; fi
if want java;    then do_java;    fi
if want python;  then do_python;  fi
if want nodejs;  then do_nodejs;  fi
if [ -z "$ONLY" ]; then do_view_warn; fi

ok "完成"
