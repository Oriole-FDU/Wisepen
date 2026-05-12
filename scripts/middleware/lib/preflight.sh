#!/usr/bin/env bash
# =============================================================================
# scripts/middleware/lib/preflight.sh
# -----------------------------------------------------------------------------
# 环境检查、ENV加载 与 弱密码扫描
# =============================================================================

# 弱密码扫描
# 扫描 .env 中以 _PASSWORD/_SECRET/_TOKEN/_KEY 结尾的值是否含弱密码
# root,admin,nacos,password,123456,test 或 含 'change-me'则认为弱密码
scan_weak_secrets() {
    local file="$1"
    python - "$file" <<'PY'
import os,re,sys
p=sys.argv[1]
weak=set('root admin nacos password 123456 test'.split())
suffix=re.compile(r'^(?P<k>[A-Z0-9_]+_(PASSWORD|SECRET|TOKEN|KEY))=(?P<v>.*)$')
hits=[]
with open(p,encoding='utf-8') as f:
    for ln in f:
        ln=ln.rstrip('\n')
        if not ln or ln.startswith('#'): continue
        m=suffix.match(ln)
        if not m: continue
        k,v=m.group('k'), m.group('v').strip()
        if 'change-me' in v.lower() or v.lower() in weak:
            hits.append((k,v))
for k,v in hits:
    print(f"{k}={v}")
sys.exit(1 if hits else 0)
PY
}

# 环境检查
check_environment() {
    # 检查 Docker 是否安装
    if ! command -v docker >/dev/null 2>&1; then
        err "找不到 docker；请先安装 Docker"; exit 1
    fi

    # 检查 Docker Compose v2 是否安装
    if ! docker compose version >/dev/null 2>&1; then
        err "找不到 docker compose v2；请升级 Docker"; exit 1
    fi
}

check_env_file() {
    # 检查 .env 文件是否存在
    if [ ! -f "$ENV_FILE" ]; then
        # 如果 .env 文件不存在，则复制 local-default.env 文件，如果 local-default.env 文件不存在，则报错并退出
        local default_env="$MIDDLEWARE_DIR/local-default.env"
        if [ ! -f "$default_env" ]; then
            err "缺少 $ENV_FILE 且 $default_env 不存在"
            err "请先执行 scripts/envs/init-envs.sh --random-secrets，或手动创建 .env"
            exit 1
        fi
        cp "$default_env" "$ENV_FILE"
        warn "$ENV_FILE 不存在；已自动复制 local-default.env（弱密码 root/admin/nacos）"
        warn "仅供 local 环境部署！server 环境请先执行 scripts/envs/init-envs.sh --random-secrets 或手填强值"
    fi
}