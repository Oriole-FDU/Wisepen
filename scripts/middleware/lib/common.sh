#!/usr/bin/env bash
# =============================================================================
# scripts/middleware/lib/common.sh
# -----------------------------------------------------------------------------
# 路径常量、日志输出、随机值生成、.env 字段替换、.env 安全加载
# 被入口脚本最先 source；其余 lib/*.sh 都依赖它
# =============================================================================

# 路径（由 up.sh 入口在 source 前导出 SCRIPT_DIR / REPO_ROOT）
MIDDLEWARE_DIR="$REPO_ROOT/deploy/middleware"
BUSINESS_DIR="$REPO_ROOT/deploy/business"

ENV_FILE="$MIDDLEWARE_DIR/.env"
BUSINESS_ENV_FILE="$BUSINESS_DIR/seed/business.env"

MW_SEED_DIR="$MIDDLEWARE_DIR/seed"
BUSINESS_SEED_DIR="$BUSINESS_DIR/seed"

RENDERED_SEED_DIR="$MW_SEED_DIR/.rendered"

# 颜色输出
say()  { printf '\033[36m[mw]\033[0m  %s\n' "$*"; }
warn() { printf '\033[33m[mw WARN]\033[0m  %s\n' "$*" >&2; }
err()  { printf '\033[31m[mw ERR ]\033[0m  %s\n' "$*" >&2; }
ok()   { printf '\033[32m[mw OK ]\033[0m  %s\n' "$*"; }

# 强随机值生成
# Base64 32 字节（>32 字符的 base64，符合 Nacos 要求）
gen_b64()  { openssl rand -base64 32 | tr -d '\n'; }
# 16 字节的十六进制（32 个 hex 字符），普通密码用
gen_hex()  { openssl rand -hex 16; }

# 在文件中替换 KEY=... 为 KEY=新值（保留原有注释/空行；仅 = 号分割的简单赋值）
# 用 python 兜底，避免 sed 在 macOS / Windows Git Bash 的反斜杠/转义差异
replace_kv() {
    local file="$1" key="$2" value="$3"
    python -c "
import re,sys,io
p=sys.argv[1]; k=sys.argv[2]; v=sys.argv[3]
with io.open(p,'r',encoding='utf-8') as f: s=f.read()
s=re.sub(r'(?m)^'+re.escape(k)+r'=.*$', k+'='+v, s)
with io.open(p,'w',encoding='utf-8',newline='\n') as f: f.write(s)
" "$file" "$key" "$value"
}

# 加载 .env 到当前 shell
# 用自写 parser 而非 `set -a; . .env`：兼容 docker-compose 风格 .env 中的
# 空格、引号、$ 等字面值，避免 Bash source 误解析
load_env_file() {
    local file="$1"
    [ -f "$file" ] || return 0
    local line key value
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        [[ "$line" =~ ^[[:space:]]*$ ]]   && continue
        [[ "$line" =~ ^[[:space:]]*\# ]]  && continue
        if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            # 去掉值两端的成对引号（双引号 / 单引号），不做变量展开。
            value="${value#"${value%%[![:space:]]*}"}"
            value="${value%"${value##*[![:space:]]}"}"
            if [[ "$value" =~ ^\"(.*)\"[[:space:]]*(#.*)?$ ]]; then
                value="${BASH_REMATCH[1]}"
            elif [[ "$value" =~ ^\'(.*)\'[[:space:]]*(#.*)?$ ]]; then
                value="${BASH_REMATCH[1]}"
            else
                if [[ "$value" =~ ^[[:space:]]*#.*$ ]]; then
                    value=""
                elif [[ "$value" =~ ^(.*[^[:space:]])[[:space:]]+#.*$ ]]; then
                    value="${BASH_REMATCH[1]}"
                fi
                value="${value#"${value%%[![:space:]]*}"}"
                value="${value%"${value##*[![:space:]]}"}"
            fi
            export "$key=$value"
        fi
    done < "$file"
}

load_env() {
    load_env_file "$ENV_FILE"
}