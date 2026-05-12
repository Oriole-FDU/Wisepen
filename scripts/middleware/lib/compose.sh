#!/usr/bin/env bash
# =============================================================================
# scripts/middleware/lib/compose.sh
# -----------------------------------------------------------------------------
# 加载 Docker Compose 配置 与 准备宿主机数据目录
# =============================================================================

# 决定启动时要加载哪些 compose 文件
build_compose_files() {
    # 加载核心 compose 文件
    COMPOSE_FILES=( -f "$MIDDLEWARE_DIR/docker-compose.yml" )
    USE_JENKINS=0
    USE_OBSERVABILITY=0
    USE_SEARCH=0

    # 根据 MIDDLEWARE_STACK 判断是否启用 full 模式
    if [ "${MIDDLEWARE_STACK:-minimal}" = "full" ]; then
        COMPOSE_FILES+=( -f "$MIDDLEWARE_DIR/profiles/jenkins.yml" )
        COMPOSE_FILES+=( -f "$MIDDLEWARE_DIR/profiles/observability.yml" )
        COMPOSE_FILES+=( -f "$MIDDLEWARE_DIR/profiles/search.yml" )
        USE_JENKINS=1
        USE_OBSERVABILITY=1
        USE_SEARCH=1
    fi

    # 如果设置 WISEPEN_DATA_ROOT 会额外加载 profiles/bind-data.yml
    if [ -n "${WISEPEN_DATA_ROOT:-}" ]; then
        case "$WISEPEN_DATA_ROOT" in
            /*) ;;
            *)
                err "WISEPEN_DATA_ROOT 必须是绝对路径，当前值：$WISEPEN_DATA_ROOT"; exit 1 ;;
        esac
        COMPOSE_FILES+=( -f "$MIDDLEWARE_DIR/profiles/bind-data.yml" )
        # 启用 full 模式后还会按需加载对应的 bind-data overlay
        [ "$USE_JENKINS"       -eq 1 ] && COMPOSE_FILES+=( -f "$MIDDLEWARE_DIR/profiles/bind-data-jenkins.yml" )
        [ "$USE_OBSERVABILITY" -eq 1 ] && COMPOSE_FILES+=( -f "$MIDDLEWARE_DIR/profiles/bind-data-observability.yml" )
        [ "$USE_SEARCH"        -eq 1 ] && COMPOSE_FILES+=( -f "$MIDDLEWARE_DIR/profiles/bind-data-search.yml" )
    fi
}

# 准备数据目录，创建并设置权限
# 很多容器内部不是用 root 用户运行，而是用特定 UID/GID
# 如果宿主机目录归属不对，容器启动后可能无法写入数据目录
prepare_bind_data() {
    [ -z "${WISEPEN_DATA_ROOT:-}" ] && return 0

    say "bind-data: 在 $WISEPEN_DATA_ROOT 下创建并 chown 数据目录"

    declare -A OWNERS=(
        [mysql]="999:999"
        [redis]=""
        [mongo]="999:999"
        [nacos/logs]=""
        [nacos/data]=""
        [etcd]="1001:1001"
        [kafka]="1001:1001"
        [qdrant]=""
        [jod-fonts]=""
    )
    # 如果启用 Jenkins 则创建并设置相关目录的权限
    if [ "$USE_JENKINS" -eq 1 ]; then
        OWNERS[jenkins]="1000:1000"
    fi
    # 如果启用 Observability 则创建并设置相关目录的权限
    if [ "$USE_OBSERVABILITY" -eq 1 ]; then
        OWNERS[tempo]="10001:10001"
        OWNERS[loki]="10001:10001"
        OWNERS[prometheus]="65534:65534"
        OWNERS[grafana]="472:0"
    fi
    
    # 如果启用 Search 则创建并设置相关目录的权限
    if [ "$USE_SEARCH" -eq 1 ]; then
        OWNERS[elasticsearch/data]="1000:0"
        OWNERS[elasticsearch/plugins]="1000:0"
    fi

    
    for sub in "${!OWNERS[@]}"; do
        local dir="$WISEPEN_DATA_ROOT/$sub"
        mkdir -p "$dir"
        local owner="${OWNERS[$sub]}"
        if [ -n "$owner" ]; then
            if ! chown -R "$owner" "$dir" 2>/dev/null; then
                warn "chown $owner $dir 失败（权限不够？）；如该服务起不来请手动 sudo chown -R $owner $dir"
            fi
        fi
    done
}
