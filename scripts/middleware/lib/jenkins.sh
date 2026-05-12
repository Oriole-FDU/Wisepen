#!/usr/bin/env bash
# =============================================================================
# scripts/middleware/lib/jenkins.sh
# -----------------------------------------------------------------------------
# Jenkins JCasC 热加载
# =============================================================================

do_reload_jenkins() {
    if ! docker ps --format '{{.Names}}' | grep -q '^wisepen-jenkins$'; then
        err "wisepen-jenkins 容器未运行"; exit 1
    fi
    load_env
    say "热加载 JCasC（POST /reload-configuration-as-code）"
    local jenkins_url="http://localhost:${JENKINS_HTTP_HOST_PORT:-8080}"
    local user="${JENKINS_ADMIN_USER:-admin}"
    local pass="${JENKINS_ADMIN_PASSWORD:?JENKINS_ADMIN_PASSWORD must be set in .env}"
    local crumb
    crumb="$(curl -sf -u "$user:$pass" \
        "$jenkins_url/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)" 2>/dev/null || true)"
    if [ -z "$crumb" ]; then
        err "无法获取 Jenkins crumb；请确认 admin 凭据正确并且 Jenkins 已 ready"
        exit 1
    fi
    if curl -sf -u "$user:$pass" -H "$crumb" -X POST \
            "$jenkins_url/configuration-as-code/reload" >/dev/null; then
        ok "JCasC reload 成功"
    else
        err "JCasC reload 失败（可能插件未就绪；试 docker logs wisepen-jenkins）"
        exit 1
    fi
}
