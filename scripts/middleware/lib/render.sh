#!/usr/bin/env bash
# =============================================================================
# scripts/middleware/lib/render.sh
# -----------------------------------------------------------------------------
# 模板渲染器
# 用于把模板文件里的占位符渲染为环境变量值
# =============================================================================

render_template() {
    local file="$1"
    python - "$file" <<'PY'
import os, re, sys
from pathlib import Path
src = Path(sys.argv[1])
text = src.read_text(encoding='utf-8')

# 处理 @if VAR ... @endif 跳段
# 先于 ${VAR} 替换以避免段内未配置的 ${VAR} 触发 missing 错误
# 如果环境变量有值，就保留中间内容；如果没有值或为空字符串，就删除整个块
js_if = re.compile(
    r'/\*\s*@if\s+([A-Z][A-Z0-9_]*)\s*\*/\s*\n?(.*?)/\*\s*@endif\s*\*/\s*\n?',
    re.DOTALL,
) # JS 注释风格
sql_if = re.compile(
    r'--\s*@if\s+([A-Z][A-Z0-9_]*)\s*\n(.*?)--\s*@endif\s*(?:\n|$)',
    re.DOTALL,
) # SQL 注释风格
def if_repl(m):
    var, body = m.group(1), m.group(2)
    val = os.environ.get(var, '')
    return body if val else ''
prev = None
while text != prev:
    prev = text
    text = js_if.sub(if_repl, text)
    text = sql_if.sub(if_repl, text)

# 反复展开 ${VAR} / ${VAR:default}（嵌套从内向外）
# 如果环境变量有值，就使用该值；如果没有值或为空字符串，就使用 default 值
# 如果 default 值也为空，就记录 missing 错误
pattern = re.compile(r'\$\{([A-Z][A-Z0-9_]*)(:([^${}]*))?\}')
missing = []
prev = None
while text != prev:
    prev = text
    def repl(m):
        var = m.group(1)
        default = m.group(3)
        val = os.environ.get(var)
        if val is not None and val != '':
            return val
        if default is not None:
            return default
        missing.append(var)
        return m.group(0)
    text = pattern.sub(repl, text)

if missing:
    print(f"MISSING-ERR {src.name}: 缺少环境变量：{sorted(set(missing))}", file=sys.stderr)
    sys.exit(3)

# 渲染后仍有 ${...}
# 意味着存在不符合 ${VAR} / ${VAR:default} 形式的占位
leftover = re.findall(r'\$\{[^}]*\}', text)
if leftover:
    print(f"LEFTOVER-ERR {src.name}: 渲染后仍有未解析占位：{sorted(set(leftover))}", file=sys.stderr)
    sys.exit(4)

sys.stdout.write(text)
PY
}

# 根据环境变量渲染模板
render_template_with_env() {
    local file="$1"
    shift || true
    (
        local env_file
        for env_file in "$@"; do
            [ -n "$env_file" ] && load_env_file "$env_file"
        done
        render_template "$file"
    )
}