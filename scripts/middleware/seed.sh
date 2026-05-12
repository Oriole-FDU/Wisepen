#!/usr/bin/env bash
# =============================================================================
# scripts/middleware/seed.sh
# -----------------------------------------------------------------------------
# 中间件种子初始化入口
# 用于 MySQL/Mongo 初始化产物渲染、Nacos 配置渲染/导出/导入
#
# 用法：
#   seed.sh database-init
#   seed.sh database-init --check
#   seed.sh nacos-config-init --check
#   seed.sh nacos-config-init --create-if-missing [--auto-import]
#   seed.sh nacos-config-init --override [--auto-import]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ──────────────────────────────────────────────────────────────────────────────
# 装载公共库
# ──────────────────────────────────────────────────────────────────────────────
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/preflight.sh
. "$SCRIPT_DIR/lib/preflight.sh"
# shellcheck source=lib/render.sh
. "$SCRIPT_DIR/lib/render.sh"
# shellcheck source=lib/seed.sh
. "$SCRIPT_DIR/lib/seed.sh"

# ──────────────────────────────────────────────────────────────────────────────
# 打印帮助信息
# ──────────────────────────────────────────────────────────────────────────────
usage() {
    sed -n '/^# ====/,/^# ====/p' "$0" | sed 's/^# \{0,1\}//' | head -30
}

# ──────────────────────────────────────────────────────────────────────────────
# 参数解析
# ──────────────────────────────────────────────────────────────────────────────
cmd="${1:-}"
[ -n "$cmd" ] || { usage; exit 1; }
shift

# --help 不触发环境前置
case "$cmd" in --help|-h) usage; exit 0 ;; esac

# ──────────────────────────────────────────────────────────────────────────────
# 预检并加载环境变量
# ──────────────────────────────────────────────────────────────────────────────
case "$cmd" in
    database-init|nacos-config-init)
        check_environment
        if [ ! -f "$ENV_FILE" ]; then
            err "$ENV_FILE 不存在；请先执行 scripts/middleware/init-up.sh <bind> <stack>"
            exit 1
        fi
        load_env
        ;;
esac

# ──────────────────────────────────────────────────────────────────────────────
# 命令分发
# ──────────────────────────────────────────────────────────────────────────────
case "$cmd" in
    database-init)
        check=0
        while [ "$#" -gt 0 ]; do
            case "$1" in
                --check) check=1; shift ;;
                --help|-h) usage; exit 0 ;;
                *) err "未知参数: $1"; exit 1 ;;
            esac
        done

        # seed.sh database-init --check	自检
        # seed.sh database-init	        执行数据库初始化产物生成
        if [ "$check" -eq 1 ]; then
            do_database_init "check"
            exit $?
        else
            do_database_init "create"
        fi
        ;;

    nacos-config-init)
        check=0
        create_if_missing=0
        override=0
        auto_import=0
        while [ "$#" -gt 0 ]; do
            case "$1" in
                --check) check=1; shift ;;
                --create-if-missing) create_if_missing=1; shift ;;
                --override) override=1; shift ;;
                --auto-import) auto_import=1; shift ;;
                --help|-h) usage; exit 0 ;;
                *) err "未知参数: $1"; exit 1 ;;
            esac
        done

        # seed.sh nacos-config-init --check	                            自检
        # seed.sh nacos-config-init --create-if-missing	                缺失时创建 Nacos 配置
        # seed.sh nacos-config-init --create-if-missing --auto-import	缺失时创建，并自动导入
        # seed.sh nacos-config-init --override	                        覆盖 Nacos 配置
        # seed.sh nacos-config-init --override --auto-import	        覆盖 Nacos 配置，并自动导入
        if [ "$check" -eq 1 ]; then
            if [ "$create_if_missing" -eq 1 ] || [ "$override" -eq 1 ] || [ "$auto_import" -eq 1 ]; then
                err "nacos-config-init --check 不能与导入/导出参数混用"
                exit 1
            fi
            do_nacos_config_init "check" 0
            exit $?
        fi

        if [ "$create_if_missing" -eq "$override" ]; then
            err "nacos-config-init 非 --check 时，--create-if-missing / --override 必须二选一"
            exit 1
        fi

        if [ "$create_if_missing" -eq 1 ]; then
            do_nacos_config_init "create-if-missing" "$auto_import"
        else
            do_nacos_config_init "override" "$auto_import"
        fi
        ;;

    --help|-h)
        usage
        ;;

    *)
        err "未知命令: $cmd"
        usage
        exit 1
        ;;
esac
