#!/usr/bin/env bash
# =============================================================================
# scripts/middleware/lib/ready.sh
# -----------------------------------------------------------------------------
# MySQL / Redis / MongoDB / Nacos 就绪检查
# Nacos 密码初始化
# =============================================================================

# 就绪检查
wait_for() {
    local name="$1" check_cmd="$2" max="${3:-90}" i=0
    printf '  %-32s ' "$name"
    while [ "$i" -lt "$max" ]; do
        if eval "$check_cmd" >/dev/null 2>&1; then
            printf '\033[32mready\033[0m\n'
            return 0
        fi
        i=$((i + 1))
        sleep 2
    done
    printf '\033[31mTIMEOUT\033[0m\n'
    err "$name 未在 $((max * 2)) 秒内就绪"
    return 1
}

# 等待 MySQL 就绪
wait_for_mysql() {
    wait_for "mysql"  "docker exec wisepen-mysql mysqladmin ping -h localhost -uroot -p\${WISEPEN_MYSQL_PASSWORD} --silent"
}

# 等待 Redis 就绪
wait_for_redis() {
    wait_for "redis"  "docker exec wisepen-redis redis-cli -a \${WISEPEN_REDIS_PASSWORD} --no-auth-warning ping | grep -q PONG"
}

# 等待 MongoDB 就绪
# mongo 容器在 docker-entrypoint-initdb.d 跑完之前不会接受外部认证；
# 这里 ping admin 库；返回 ok:1 即视为 mongod 已 ready 且 init JS 已跑完。
wait_for_mongo() {
    wait_for "mongo"  "docker exec wisepen-mongo mongosh --quiet -u \${WISEPEN_MONGO_USER:-root} -p \${WISEPEN_MONGO_PASSWORD} --authenticationDatabase admin --eval 'db.runCommand({ping:1}).ok' | grep -q 1"
}

# 等待 Nacos 就绪
wait_for_nacos() {
    wait_for "nacos"  "curl -sf http://localhost:\${WISEPEN_NACOS_HOST_PORT:-8848}/nacos/v1/console/health/readiness" 120
}

# Nacos 密码初始化
# Nacos v2.x 首次启动后控制台默认账号是 nacos/nacos（来自 00-nacos-schema.sql）。
# 业务侧 .env 中 NACOS_PASSWORD 是各服务用于登 Nacos 的密码，需要把控制台
# 的 nacos 用户密码改成它，否则 APISIX / 微服务连 Nacos 时鉴权失败
bootstrap_nacos_password() {
    local NACOS_BASE="http://localhost:${WISEPEN_NACOS_HOST_PORT:-8848}"
    local target_user="${NACOS_USERNAME:-nacos}"
    local target_pass="${NACOS_PASSWORD:?NACOS_PASSWORD must be set in .env}"
    local default_user="nacos"
    local default_pass="nacos"

    # 尝试期望密码
    if curl -sf -X POST \
            --data-urlencode "username=$target_user" \
            --data-urlencode "password=$target_pass" \
            "$NACOS_BASE/nacos/v1/auth/login" >/dev/null 2>&1; then
        ok "Nacos 密码已配置为 .env 期望值（无需初始化）"
        return 0
    fi

    # 退回默认账号
    say "Nacos 期望密码登失败；尝试默认账号 ${default_user}/${default_pass} 登录"
    local token
    token="$(curl -sf -X POST \
        --data-urlencode "username=$default_user" \
        --data-urlencode "password=$default_pass" \
        "$NACOS_BASE/nacos/v1/auth/login" 2>/dev/null \
        | sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p' || true)"

    if [ -z "$token" ]; then
        err "Nacos 既无法用 NACOS_PASSWORD 也无法用 ${default_user}/${default_pass} 登入。"
        err "已有数据卷中的 Nacos 密码未知，请手动处理后重试"
        return 1
    fi

    # PUT 更新密码
    if ! curl -sf -X PUT \
            --data-urlencode "username=$target_user" \
            --data-urlencode "newPassword=$target_pass" \
            "$NACOS_BASE/nacos/v1/auth/users?accessToken=$token" >/dev/null 2>&1; then
        err "PUT /nacos/v1/auth/users 失败，请检查 Nacos 日志"
        return 1
    fi

    # 验证新密码可用
    if curl -sf -X POST \
            --data-urlencode "username=$target_user" \
            --data-urlencode "password=$target_pass" \
            "$NACOS_BASE/nacos/v1/auth/login" >/dev/null 2>&1; then
        ok "Nacos 密码已配置为 .env 期望值"
    else
        err "其他错误，请检查 Nacos 日志"
        return 1
    fi
}
