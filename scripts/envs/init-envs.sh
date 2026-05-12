#!/usr/bin/env bash
# =============================================================================
# scripts/envs/init-envs.sh
# -----------------------------------------------------------------------------
# 在中间件部署完成后，根据 deploy/middleware/.env 生成各微服务的 .env，
# 归档到 deploy/envs/，并自动分发到对应子仓库实际位置。
#
# 输入：deploy/middleware/.env（中间件部署前由用户填好）
# 输出：
#   deploy/envs/wisepen-cloud.env                    →  wisepen-cloud/.env
#   deploy/envs/wisepen-chat-service.env             →  wisepen-cloud-ai/services/wisepen-chat-service/src/chat/.env
#   deploy/envs/wisepen-note-collab-service.env      →  wisepen-cloud-sidecar/wisepen-note-collab-service/.env
#   deploy/envs/wisepen-cloud-gateway-deploy.env     →  wisepen-cloud-gateway-deploy/.env
#
# 前端（wisepen-view）env 自动生成未实现；按其 .env.example 手动填即可
#
# 用法：
#   init-envs.sh                                # 生成 + 分发；已存在的 .env 跳过不覆盖
#   init-envs.sh --random-secrets               # 先基于 env.example 生成强随机
#                                                 deploy/middleware/.env，再继续生成并分发
#   init-envs.sh --force                        # 已存在的 .env 也覆盖
#   init-envs.sh --dry-run                      # 只打印差异，不写入
#   init-envs.sh --remote-host=team-dev:8848    # 覆盖 NACOS_SERVER_ADDR / 网关探测 host
#   init-envs.sh --no-distribute                # 仅写到 deploy/envs/，不分发到子仓库
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MIDDLEWARE_ENV="$REPO_ROOT/deploy/middleware/.env"
ENVS_DIR="$REPO_ROOT/deploy/envs"

# ──────────────────────────────────────────────────────────────────────────────
# 装载公共库
# ──────────────────────────────────────────────────────────────────────────────
# shellcheck source=../middleware/lib/common.sh
. "$REPO_ROOT/scripts/middleware/lib/common.sh"

FORCE=0
DRY_RUN=0
NO_DISTRIBUTE=0
REMOTE_HOST=""
RANDOM_SECRETS=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --random-secrets) RANDOM_SECRETS=1; shift ;;
        --force)         FORCE=1; shift ;;
        --dry-run)       DRY_RUN=1; shift ;;
        --no-distribute) NO_DISTRIBUTE=1; shift ;;
        --remote-host)   REMOTE_HOST="$2"; shift 2 ;;
        --remote-host=*) REMOTE_HOST="${1#*=}"; shift ;;
        --help|-h)
            sed -n '/^# ====/,/^# ====/p' "$0" | sed 's/^# \{0,1\}//' | head -25
            exit 0 ;;
        *) echo "未知参数: $1" >&2; exit 1 ;;
    esac
done

say()  { printf '\033[36m[envs]\033[0m  %s\n' "$*"; }
warn() { printf '\033[33m[envs WARN]\033[0m  %s\n' "$*" >&2; }
err()  { printf '\033[31m[envs ERR ]\033[0m  %s\n' "$*" >&2; }
ok()   { printf '\033[32m[envs OK ]\033[0m  %s\n' "$*"; }

# random-secrets 
# 基于 env.example 生成强随机 middleware/.env
generate_random_middleware_env() {
    local example="$REPO_ROOT/deploy/middleware/env.example"
    [ -f "$example" ] || { err "缺少 $example"; exit 1; }
    if [ -f "$MIDDLEWARE_ENV" ]; then
        err "$MIDDLEWARE_ENV 已存在；--random-secrets 不覆盖已有环境"
        err "如需重新生成：删除现有 .env 后重跑；或编辑现有 .env 后去掉 --random-secrets"
        exit 1
    fi
    command -v openssl >/dev/null 2>&1 || { err "--random-secrets 需要 openssl"; exit 1; }
    command -v python  >/dev/null 2>&1 || { err "--random-secrets 需要 python（用于安全替换 .env 字段）"; exit 1; }

    cp "$example" "$MIDDLEWARE_ENV"

    local hex_keys=(
        WISEPEN_MYSQL_PASSWORD WISEPEN_REDIS_PASSWORD WISEPEN_MONGO_PASSWORD
        ETCD_ROOT_PASSWORD APISIX_ADMIN_KEY APISIX_DASHBOARD_PASSWORD APISIX_DASHBOARD_SECRET
        KAFKA_UI_PASSWORD WISEPEN_QDRANT_API_KEY FROM_SOURCE_SECRET
        JENKINS_ADMIN_PASSWORD JENKINS_SCM_CRED_TOKEN JENKINS_NACOS_PASSWORD
        NACOS_PASSWORD GRAFANA_ADMIN_PASSWORD ES_ELASTIC_PASSWORD
    )
    local nacos_password
    nacos_password="$(gen_hex)"
    local k
    for k in "${hex_keys[@]}"; do
        if [ "$k" = "NACOS_PASSWORD" ] || [ "$k" = "JENKINS_NACOS_PASSWORD" ]; then
            replace_kv "$MIDDLEWARE_ENV" "$k" "$nacos_password"
        else
            replace_kv "$MIDDLEWARE_ENV" "$k" "$(gen_hex)"
        fi
    done
    replace_kv "$MIDDLEWARE_ENV" "NACOS_AUTH_TOKEN" "$(gen_b64)"

    ok "已生成强随机 deploy/middleware/.env"
    say "保存以下凭据备用（仅本次输出）："
    grep -E '^(WISEPEN_(MYSQL|REDIS|MONGO|QDRANT)|ETCD_ROOT|APISIX_(ADMIN_KEY|DASHBOARD_(PASSWORD|SECRET))|NACOS_(AUTH_TOKEN|PASSWORD)|JENKINS_(ADMIN|SCM_CRED|NACOS)|GRAFANA_ADMIN|ES_ELASTIC|KAFKA_UI|FROM_SOURCE)' "$MIDDLEWARE_ENV" \
        | sed 's/^/    /'
}

if [ "$RANDOM_SECRETS" -eq 1 ]; then
    generate_random_middleware_env
elif [ ! -f "$MIDDLEWARE_ENV" ]; then
    err "找不到 $MIDDLEWARE_ENV"
    err "请先 cp deploy/middleware/env.example deploy/middleware/.env 并填好凭证"
    err "或者用 scripts/envs/init-envs.sh --random-secrets 自动生成强密码 .env"
    exit 1
fi

# 加载中间件 .env
load_env

# 解析连接 host
# 本地 = localhost
# 远端 = --remote-host 或 WISEPEN_PUBLIC_HOST
if [ -n "$REMOTE_HOST" ]; then
    NACOS_ADDR="$REMOTE_HOST"
    GATEWAY_HOST="${REMOTE_HOST%:*}"
    say "使用 --remote-host：$REMOTE_HOST（团队成员场景）"
else
    if [ "${WISEPEN_BIND_ADDR:-127.0.0.1}" = "0.0.0.0" ]; then
        NACOS_ADDR="localhost:${WISEPEN_NACOS_HOST_PORT:-8848}"
        GATEWAY_HOST="localhost"
    else
        NACOS_ADDR="localhost:${WISEPEN_NACOS_HOST_PORT:-8848}"
        GATEWAY_HOST="localhost"
    fi
fi

# 写文件辅助
# 如果 dry-run 就只打印控制台，否则落盘
write_file() {
    local dst="$1"
    local content="$2"

    if [ -f "$dst" ] && [ "$FORCE" -eq 0 ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            say "DRY  skip (exists): $dst"
        else
            warn "跳过：$dst 已存在（--force 可覆盖）"
        fi
        return 0
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        say "DRY  write: $dst"
        printf '%s\n' "$content" | sed 's/^/      | /'
        return 0
    fi

    mkdir -p "$(dirname "$dst")"
    printf '%s\n' "$content" > "$dst"
    ok "wrote $dst"
}

# 分发归档文件至子仓库实际位置
distribute() {
    local src="$1" dst="$2"
    if [ "$NO_DISTRIBUTE" -eq 1 ]; then
        say "--no-distribute：跳过 $dst"
        return 0
    fi
    if [ ! -f "$src" ]; then
        warn "源不存在，跳过分发：$src"
        return 0
    fi
    if [ -f "$dst" ] && [ "$FORCE" -eq 0 ]; then
        warn "跳过分发：$dst 已存在（--force 可覆盖）"
        return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        say "DRY  distribute: $src → $dst"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    ok "distributed → $dst"
}

# ──────────────────────────────────────────────────────────────────────────────
# 生成各子仓库 .env 内容
# ──────────────────────────────────────────────────────────────────────────────

# Java 微服务共享 .env
WISEPEN_CLOUD_ENV_CONTENT="# Auto-generated by scripts/envs/init-envs.sh from deploy/middleware/.env
# Do not edit; rerun init-envs.sh after changing middleware/.env

# Nacos
NACOS_SERVER_ADDR=$NACOS_ADDR
NACOS_USERNAME=${NACOS_USERNAME:-nacos}
NACOS_PASSWORD=${NACOS_PASSWORD}

# Spring profile（本机起服务保持 dev；容器/Jenkins 部署时由 docker compose 覆盖为 prod）
SPRING_PROFILES_ACTIVE=dev

# OpenTelemetry Java Agent（本机开发默认关闭遥测）
OTEL_SDK_DISABLED=true
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_EXPORTER_OTLP_ENDPOINT=http://${GATEWAY_HOST}:${OTEL_HTTP_HOST_PORT:-4318}
"

# Python 微服务 .env
WISEPEN_AI_ENV_CONTENT="# Auto-generated by scripts/envs/init-envs.sh from deploy/middleware/.env
# Do not edit; rerun init-envs.sh after changing middleware/.env

# Nacos
NACOS_SERVER_ADDR=$NACOS_ADDR
NACOS_USERNAME=${NACOS_USERNAME:-nacos}
NACOS_PASSWORD=${NACOS_PASSWORD}

# Profile（本机开发为 dev；容器化为 prod 在 compose 注入）
PROFILE=dev
"

# NodeJS 微服务 .env
WISEPEN_SIDECAR_ENV_CONTENT="# Auto-generated by scripts/envs/init-envs.sh from deploy/middleware/.env
# Do not edit; rerun init-envs.sh after changing middleware/.env

# Nacos
NACOS_SERVER_ADDR=$NACOS_ADDR
NACOS_USERNAME=${NACOS_USERNAME:-nacos}
NACOS_PASSWORD=${NACOS_PASSWORD}

# Profile（本机开发为 dev；容器化为 prod 在 compose 注入）
PROFILE=dev
"

# Gateway 部署 .env
WISEPEN_GATEWAY_ENV_CONTENT="# Auto-generated by scripts/envs/init-envs.sh from deploy/middleware/.env
# Do not edit; rerun init-envs.sh after changing middleware/.env

# APISIX Admin
APISIX_ADMIN_HOST=$GATEWAY_HOST
APISIX_ADMIN_PORT=${APISIX_ADMIN_HOST_PORT:-9180}
APISIX_ADMIN_KEY=${APISIX_ADMIN_KEY}

# Redis（auth.lua 用）
REDIS_AUTH_PASSWORD=${WISEPEN_REDIS_PASSWORD}

# 服务间安全 token（与 wisepen-cloud / wisepen-cloud-sidecar 共用）
FROM_SOURCE_SECRET=${FROM_SOURCE_SECRET}
"

# 落盘归档并分发
mkdir -p "$ENVS_DIR"

write_file "$ENVS_DIR/wisepen-cloud.env"                "$WISEPEN_CLOUD_ENV_CONTENT"
distribute "$ENVS_DIR/wisepen-cloud.env"                "$REPO_ROOT/wisepen-cloud/.env"

write_file "$ENVS_DIR/wisepen-chat-service.env"         "$WISEPEN_AI_ENV_CONTENT"
distribute "$ENVS_DIR/wisepen-chat-service.env"         "$REPO_ROOT/wisepen-cloud-ai/services/wisepen-chat-service/src/chat/.env"

write_file "$ENVS_DIR/wisepen-note-collab-service.env"  "$WISEPEN_SIDECAR_ENV_CONTENT"
distribute "$ENVS_DIR/wisepen-note-collab-service.env"  "$REPO_ROOT/wisepen-cloud-sidecar/wisepen-note-collab-service/.env"

write_file "$ENVS_DIR/wisepen-cloud-gateway-deploy.env" "$WISEPEN_GATEWAY_ENV_CONTENT"
distribute "$ENVS_DIR/wisepen-cloud-gateway-deploy.env" "$REPO_ROOT/wisepen-cloud-gateway-deploy/.env"

# 前端环境
warn "前端（wisepen-view）env 自动生成本轮未实现，请按其 .env.example 手动填"

if [ "$DRY_RUN" -eq 1 ]; then
    warn "DRY-RUN：以上操作并未真正执行"
fi

ok "完成"