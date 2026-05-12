#!/usr/bin/env bash
# =============================================================================
# scripts/middleware/lib/seed.sh
# -----------------------------------------------------------------------------
# 数据库初始化文件 渲染 / 存盘（.rendered/mysql/ / .rendered/mongo/）
# Nacos 配置文件  渲染 / 存盘（.rendered/nacos/） / 导入Nacos
# =============================================================================

do_database_init() {
    local action="${1:-create}"
    case "$action" in
        check|create)
            render_db_seed "$action"
            ;;
        *)
            err "database-init action 无效: $action（应为 create | check）"
            return 1
            ;;
    esac
}

do_nacos_config_init() {
    local action="${1:?action required}" auto_import="${2:-0}"
    case "$action" in
        check)              render_nacos_seed "check" ;;
        create-if-missing)  nacos_config_apply "missing-only" "$auto_import" ;;
        override)           nacos_config_apply "all"          "$auto_import" ;;
        *)
            err "nacos-config-init action 无效: $action（应为 check | create-if-missing | override）"
            return 1
            ;;
    esac
}

# DB seed 渲染
render_db_seed() {
    local mode="${1:-create}"
    case "$mode" in
        check|create) ;;
        *) err "render_db_seed mode 无效: $mode（应为 create | check）"; return 1 ;;
    esac

    # 检查 python 是否存在
    if ! command -v python >/dev/null 2>&1; then
        err "render_db_seed 需要 python"; return 1
    fi

    # 检查业务配置文件是否存在
    if [ -f "$BUSINESS_ENV_FILE" ]; then
        say "render-db: 读取 $BUSINESS_ENV_FILE"
    else
        warn "render-db: 未找到 $BUSINESS_ENV_FILE"
        warn "  → 业务 *.tmpl 中所有 @if 块将被跳过（mysql/mongo 业务表为空 row）"
        warn "  → AI（chat-service）/ 文件存储（file-storage-service）相关功能可能降级"
        warn "  → 详情见 deploy/business/seed/README.md"
    fi

    # 渲染业务 *.tmpl 到内存数组
    # 内存数组用于存储渲染后的文件路径和内容
    local -a rel_paths=() contents=()
    local fail=0 sub src tmpl_out render_err rel
    for sub in mysql mongo; do

        # 扫描 $BUSINESS_SEED_DIR/mysql/*.tmpl 和 $BUSINESS_SEED_DIR/mongo/*.tmpl 
        # 目录下的所有 *.tmpl 文件
        local biz_dir="$BUSINESS_SEED_DIR/$sub"
        [ -d "$biz_dir" ] || continue # 如果目录不存在，则跳过

        shopt -s nullglob # 启用 nullglob 模式，允许使用 * 匹配空文件名
        for src in "$biz_dir"/*.tmpl; do
            [ -f "$src" ] || continue # 如果文件不存在，则跳过

            rel="$sub/$(basename "${src%.tmpl}")"
            render_err="$(mktemp 2>/dev/null || python -c 'import tempfile;f=tempfile.mkstemp()[1];print(f)')"
            if tmpl_out="$(render_template_with_env "$src" "$BUSINESS_ENV_FILE" 2>"$render_err")"; then
                rel_paths+=( "$rel" )
                contents+=( "$tmpl_out" )
                [ "$mode" = "check" ] && printf '  %-50s \033[32mrendered\033[0m\n' "$(basename "$src")"
            else
                printf '  %-50s \033[31mRENDER-FAIL\033[0m\n' "$(basename "$src")"
                sed 's/^/      /' "$render_err" >&2
                fail=$((fail + 1)) # 失败时累计失败数量
            fi
            rm -f "$render_err"
        done
        shopt -u nullglob # 禁用 nullglob 模式
    done

    if [ "$fail" -gt 0 ]; then
        err "render_db_seed 失败：${fail} 个 *.tmpl 渲染错误"
        return 1
    fi

    # check 阶段
    if [ "$mode" = "check" ]; then
        ok "render-db check 通过（${#rel_paths[@]} 条 *.tmpl 模板验证通过）"
        return 0
    fi

    # create 阶段
    # 清空输出目录
    local out_dir="$RENDERED_SEED_DIR"
    rm -rf "$out_dir/mysql" "$out_dir/mongo"
    mkdir -p "$out_dir/mysql" "$out_dir/mongo"

    # 复制中间件 seed 静态文件
    if [ -d "$MW_SEED_DIR/mysql" ]; then
        shopt -s nullglob
        for src in "$MW_SEED_DIR/mysql"/*.sql; do cp "$src" "$out_dir/mysql/"; done
        shopt -u nullglob
    fi
    if [ -d "$MW_SEED_DIR/mongo" ]; then
        shopt -s nullglob
        for src in "$MW_SEED_DIR/mongo"/*.js; do cp "$src" "$out_dir/mongo/"; done
        shopt -u nullglob
    fi

    # 复制业务静态文件
    for sub in mysql mongo; do
        local biz_dir="$BUSINESS_SEED_DIR/$sub"
        [ -d "$biz_dir" ] || continue
        shopt -s nullglob
        for src in "$biz_dir"/*.sql "$biz_dir"/*.js; do
            [ -f "$src" ] || continue
            cp "$src" "$out_dir/$sub/"
        done
        shopt -u nullglob
    done

    # 把内存里的模板结果落盘
    local i
    for ((i = 0; i < ${#rel_paths[@]}; i++)); do
        rel="${rel_paths[$i]}"
        printf '%s' "${contents[$i]}" > "$out_dir/$rel"
        printf '  %-50s \033[32mrendered\033[0m → %s\n' "$(basename "$rel")" "$rel"
    done

    ok "render-db 完成 → $RENDERED_SEED_DIR/{mysql,mongo}/"
}

# Nacos seed 渲染
render_nacos_seed() {
    local mode="${1:-create}"
    case "$mode" in
        check|create) ;;
        *) err "render_nacos_seed mode 无效: $mode（应为 create | check）"; return 1 ;;
    esac

    # 检查 python 是否存在
    if ! command -v python >/dev/null 2>&1; then
        err "render_nacos_seed 需要 python"; return 1
    fi

    # 检查业务配置文件是否存在
    if [ -f "$BUSINESS_ENV_FILE" ]; then
        say "render-nacos: 读取 $BUSINESS_ENV_FILE"
    else
        warn "render-nacos: 未找到 $BUSINESS_ENV_FILE"
        warn "  → Nacos yaml 中业务可选字段（OSS / LLM / Memory / SMTP 等）按 \${VAR:default} 取默认"
        warn "  → 相关业务功能可能降级"
        warn "  → 详情见 deploy/business/seed/README.md"
    fi

    # 渲染所有 *.yaml 到内存数组
    # 内存数组用于存储渲染后的文件路径和内容
    # 由 nacos_config_apply 后续消费
    NACOS_RENDERED_IDS=()
    NACOS_RENDERED_CONTENTS=()
    local fail=0 f data_id content render_err

    shopt -s nullglob # 启用 nullglob 模式，目录不存在或为空时 files 自动为空数组
    local files=( "$SEED_NACOS_DIR"/*.yaml )
    for f in "${files[@]}"; do
        data_id="$(basename "$f")"
        render_err="$(mktemp 2>/dev/null || python -c 'import tempfile;f=tempfile.mkstemp()[1];print(f)')"
        if content="$(render_template_with_env "$f" "$ENV_FILE" "$BUSINESS_ENV_FILE" 2>"$render_err")"; then
            NACOS_RENDERED_IDS+=( "$data_id" )
            NACOS_RENDERED_CONTENTS+=( "$content" )
            [ "$mode" = "check" ] && printf '  %-50s \033[32mrendered\033[0m\n' "$data_id"
        else
            printf '  %-50s \033[31mRENDER-FAIL\033[0m\n' "$data_id"
            sed 's/^/      /' "$render_err" >&2
            fail=$((fail + 1)) # 失败时累计失败数量
        fi
        rm -f "$render_err"
    done
    shopt -u nullglob # 禁用 nullglob 模式

    if [ "$fail" -gt 0 ]; then
        err "render_nacos_seed 失败：${fail} 个 dataId 模板渲染错误"
        return 1
    fi

    # check 阶段
    if [ "$mode" = "check" ]; then
        local n="${#NACOS_RENDERED_IDS[@]}"
        NACOS_RENDERED_IDS=()
        NACOS_RENDERED_CONTENTS=()
        ok "render-nacos check 通过（${n} 条 dataId 模板验证通过）"
        return 0
    fi
}

# 登录 Nacos 获取 token，用于后续的 Nacos 配置操作
nacos_login() {
    local user="$1" pass="$2" base="$3"
    curl -sf -X POST \
        --data-urlencode "username=$user" \
        --data-urlencode "password=$pass" \
        "$base/nacos/v1/auth/login" 2>/dev/null \
        | sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p'
}

# 检查 Nacos 配置是否存在
nacos_config_exists() {
    local base="$1" token="$2" data_id="$3"
    curl -sf -o /dev/null \
        "$base/nacos/v1/cs/configs?dataId=$data_id&group=DEFAULT_GROUP&accessToken=$token" 2>/dev/null
}

nacos_login_or_die() {
    local user="${NACOS_USERNAME:-nacos}"
    local pass="${NACOS_PASSWORD:?NACOS_PASSWORD must be set in .env}"
    local base="http://localhost:${WISEPEN_NACOS_HOST_PORT:-8848}"
    local token=""
    token="$(nacos_login "$user" "$pass" "$base" || true)"
    if [ -z "$token" ]; then
        err "Nacos 登录失败: user=$user"
        err "请确认 Nacos 已启动，并且控制台密码与 .env 的 NACOS_PASSWORD 一致"
        return 1
    fi
    printf '%s' "$token"
}

# 把单个 dataId POST 到 Nacos
nacos_push_one() {
    local base="$1" token="$2" data_id="$3" content="$4"
    local resp
    resp="$(curl -sf -X POST \
        --data-urlencode "dataId=$data_id" \
        --data-urlencode "group=DEFAULT_GROUP" \
        --data-urlencode "type=yaml" \
        --data-urlencode "content=$content" \
        "$base/nacos/v1/cs/configs?accessToken=$token" 2>/dev/null || echo FAIL)"
    printf '%s' "$resp"
    [ "$resp" = "true" ]
}

# 把渲染产物应用到 Nacos / 导出为文件
nacos_config_apply() {
    local scope="$1" auto_import="$2"
    render_nacos_seed "create" || return 1
    local token; token="$(nacos_login_or_die)" || return 1
    local base="http://localhost:${WISEPEN_NACOS_HOST_PORT:-8848}"

    # auto_import=0：导出模式
    if [ "$auto_import" -eq 0 ]; then
        # 清空输出目录
        local out_dir="$RENDERED_SEED_DIR/nacos"
        rm -rf "$out_dir"
        mkdir -p "$out_dir"
    fi

    local total="${#NACOS_RENDERED_IDS[@]}"
    local i data_id content resp
    local fail=0 skipped=0 pushed=0 exported=0

    for ((i = 0; i < total; i++)); do
        data_id="${NACOS_RENDERED_IDS[$i]}"
        content="${NACOS_RENDERED_CONTENTS[$i]}"

        # missing-only：dataId 已存在则 skip
        if [ "$scope" = "missing-only" ] && nacos_config_exists "$base" "$token" "$data_id"; then
            printf '  %-50s \033[33mskip(exists)\033[0m\n' "$data_id"
            skipped=$((skipped + 1))
            continue
        fi

        if [ "$auto_import" -eq 1 ]; then
            if resp="$(nacos_push_one "$base" "$token" "$data_id" "$content")"; then
                if [ "$scope" = "missing-only" ]; then
                    printf '  %-50s \033[32mcreated\033[0m\n' "$data_id"
                else
                    printf '  %-50s \033[32moverridden\033[0m\n' "$data_id"
                fi
                pushed=$((pushed + 1))
            else
                printf '  %-50s \033[31mFAIL\033[0m  %s\n' "$data_id" "$resp"
                fail=$((fail + 1))
            fi
        else
            # 导出到输出目录
            printf '%s' "$content" > "$out_dir/$data_id" # 将内容写入输出目录
            printf '  %-50s \033[36mexported\033[0m → %s\n' "$data_id" "$out_dir/$data_id"
            exported=$((exported + 1))
        fi
    done

    if [ "$fail" -gt 0 ]; then
        err "Nacos 配置导入失败: fail=${fail}, pushed=${pushed}, skipped=${skipped}, exported=${exported}"
        return 1
    fi

    if [ "$auto_import" -eq 1 ]; then
        ok "Nacos 配置导入完成: pushed=${pushed}, skipped=${skipped}"
    else
        ok "Nacos 配置已导出: exported=${exported}, skipped=${skipped}, dir=$out_dir"
    fi
}
