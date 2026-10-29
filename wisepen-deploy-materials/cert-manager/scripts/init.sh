#!/usr/bin/env bash

# WisePen cert-manager 启动入口
#
# 功能流程：
# 1. 校验证书签发所需的 ACME、域名和 AliDNS 配置；
# 2. 根据主域名、通配符开关和额外域名生成完整证书域名清单；
# 3. 在 new 模式下签发新证书，或在 existing 模式下加载已有 acme.sh 状态；
# 4. 将证书导出到稳定路径，并把 reload.sh 注册为首次安装和后续续期的分发 Hook；
# 5. 启动 cron，使 acme.sh 在容器长期运行期间自动检查和续期证书。
#
# 输入来自容器 ENV；账号、订单、证书配置和导出证书写入 /acme.sh 持久化卷

# -E：ERR Trap 可继承到函数；-e：命令失败立即退出；-u：禁止读取未定义变量；
# pipefail：管道任一环节失败都视为整个管道失败
set -Eeuo pipefail

# ---
# 第一阶段：校验签发配置
# 下列字段参与证书签发，无论证书最终分发到哪里都必须存在
# APISIX 和 OSS 凭据由 reload.sh 按分发开关条件校验，未启用分支不要求填写
required_vars=(
  CERT_STATE_SOURCE
  ACME_CA
  ACME_EMAIL
  CERT_PRIMARY_DOMAIN
  CERT_APPLY_WILDCARD
  ALIDNS_ACCESS_KEY_ID
  ALIDNS_ACCESS_KEY_SECRET
)
for name in "${required_vars[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "[ERROR] missing required environment variable: ${name}" >&2
    exit 1
  fi
done

# 状态来源决定“没有找到主域名证书配置”时的行为
# new 允许注册账号并签发；existing 认为目录由用户提供，缺失时直接失败
case "${CERT_STATE_SOURCE}" in
  new|existing) ;;
  *) echo "[ERROR] CERT_STATE_SOURCE must be new or existing" >&2; exit 1 ;;
esac

# 只接受信息收集页面已经提供的 CA，避免把任意字符串直接传入 acme.sh
case "${ACME_CA}" in
  zerossl|letsencrypt) ;;
  *) echo "[ERROR] ACME_CA must be zerossl or letsencrypt" >&2; exit 1 ;;
esac

case "${CERT_APPLY_WILDCARD}" in
  true|false) ;;
  *) echo "[ERROR] CERT_APPLY_WILDCARD must be true or false" >&2; exit 1 ;;
esac

if [[ ! "${CERT_PRIMARY_DOMAIN}" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]; then
  echo "[ERROR] invalid CERT_PRIMARY_DOMAIN" >&2
  exit 1
fi

# acme.sh 的 dns_ali 插件使用固定变量名 Ali_Key / Ali_Secret
# 该映射只用于 DNS-01 TXT 记录
export Ali_Key="${ALIDNS_ACCESS_KEY_ID}"
export Ali_Secret="${ALIDNS_ACCESS_KEY_SECRET}"

# ---
# 第二阶段：生成证书域名清单
# 主域名始终进入证书；通配符和额外 SAN 域名根据配置追加
# 使用数组拼装 acme.sh 参数，避免 eval 或二次 Shell 解析
# seen_domains 去除主域名、自动通配符域名和额外域名之间的重复项
declare -a domain_args=(-d "${CERT_PRIMARY_DOMAIN}")
declare -A seen_domains=(["${CERT_PRIMARY_DOMAIN}"]=1)

if [[ "${CERT_APPLY_WILDCARD}" == "true" ]]; then
  wildcard_domain="*.${CERT_PRIMARY_DOMAIN}"
  domain_args+=(-d "${wildcard_domain}")
  seen_domains["${wildcard_domain}"]=1
fi

# 额外域名采用逗号分隔；逐项去除首尾空白并进行格式校验
IFS=',' read -r -a extra_domains <<< "${CERT_EXTRA_DOMAINS:-}"
for domain in "${extra_domains[@]}"; do
  domain="${domain#"${domain%%[![:space:]]*}"}"
  domain="${domain%"${domain##*[![:space:]]}"}"
  [[ -z "${domain}" ]] && continue
  if [[ ! "${domain}" =~ ^(\*\.)?[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]; then
    echo "[ERROR] invalid extra certificate domain: ${domain}" >&2
    exit 1
  fi
  if [[ -z "${seen_domains[$domain]:-}" ]]; then
    domain_args+=(-d "${domain}")
    seen_domains["${domain}"]=1
  fi
done

# ---
# 第三阶段：查找已有证书状态或执行首次签发
# install-cert 将证书复制到稳定导出路径
# 后续续期完成后继续覆盖相同文件，并执行已登记的 reload Hook
export_dir="/acme.sh/exported/${CERT_PRIMARY_DOMAIN}"
cert_file="${export_dir}/fullchain.cer"
key_file="${export_dir}/privkey.key"
mkdir -p "${export_dir}"

# ECC 和 RSA 使用不同状态目录及命令参数。优先识别 ECC，已有 RSA 状态也可复用
cert_mode_args=()
if [[ -f "/acme.sh/${CERT_PRIMARY_DOMAIN}_ecc/${CERT_PRIMARY_DOMAIN}.conf" ]]; then
  cert_mode_args=(--ecc)
elif [[ -f "/acme.sh/${CERT_PRIMARY_DOMAIN}/${CERT_PRIMARY_DOMAIN}.conf" ]]; then
  cert_mode_args=()
elif [[ "${CERT_STATE_SOURCE}" == "existing" ]]; then
  echo "[ERROR] existing ACME state does not contain certificate config for ${CERT_PRIMARY_DOMAIN}" >&2
  exit 1
else
  # new 模式且不存在证书状态时，注册 ACME 账号并通过 AliDNS DNS-01 签发 EC-256 证书
  # DNS 插件负责创建和清理 TXT 记录
  echo "[INFO] registering ACME account and issuing certificate"
  acme.sh --register-account -m "${ACME_EMAIL}" --server "${ACME_CA}"
  acme.sh --set-default-ca --server "${ACME_CA}"
  acme.sh --issue --server "${ACME_CA}" --dns dns_ali --keylength ec-256 "${domain_args[@]}"
  cert_mode_args=(--ecc)
fi

# ---
# 第四阶段：导出证书并执行下游分发
# 新签发和复用已有状态都重新执行 install-cert
# 1. 导出到稳定路径；2. 保存当前 reload Hook；3. 立即执行一次下游分发
acme.sh --install-cert -d "${CERT_PRIMARY_DOMAIN}" "${cert_mode_args[@]}" \
  --key-file "${key_file}" \
  --fullchain-file "${cert_file}" \
  --reloadcmd "/scripts/reload.sh ${cert_file} ${key_file}"

# ---
# 第五阶段：启动自动续期守护进程
# install-cert 会立即执行 reloadcmd，并将其保存为后续续期 Hook
# cron 负责定期调用 acme.sh；是否续期由 acme.sh 根据证书有效期判断
acme.sh --install-cronjob
echo "[INFO] certificate manager ready; starting cron"
exec crond -f
