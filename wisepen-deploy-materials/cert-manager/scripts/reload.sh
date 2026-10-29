#!/usr/bin/env bash

# WisePen 证书分发 Hook
#
# 调用时机：
# - init.sh 首次执行 install-cert 时调用一次，用于安装刚签发或刚加载的证书；
# - acme.sh 后续续期成功时自动调用，使下游系统切换到新证书。
#
# 功能流程：
# 1. 接收导出的完整证书链和私钥文件；
# 2. 根据 DISTRIBUTE_TO_APISIX 更新 APISIX SSL 资源及其 SNI；
# 3. 根据 DISTRIBUTE_TO_FRONTEND_OSS 更新主前端 OSS CNAME 证书；
# 4. 根据 DISTRIBUTE_TO_DRAWIO_OSS 更新 DrawIO OSS CNAME 证书；
# 5. 所有已启用目标均成功后才向 acme.sh 报告本次分发成功。

# 续期 Hook 涉及证书私钥和多个远程目标，任一命令失败都必须向 acme.sh 返回非零状态，
# 以便续期日志准确反映分发失败，而不是在部分目标未更新时继续报告成功
set -Eeuo pipefail

# ---
# 第一阶段：确认 acme.sh 传入的证书产物可用
if [[ "$#" -ne 2 ]]; then
  echo "usage: $0 <fullchain-file> <private-key-file>" >&2
  exit 1
fi

cert_file=$1
key_file=$2
if [[ ! -s "${cert_file}" || ! -s "${key_file}" ]]; then
  echo "[ERROR] certificate or private key file is missing" >&2
  exit 1
fi

# 校验当前启用分支需要的变量
require_vars() {
  local name
  for name in "$@"; do
    if [[ -z "${!name:-}" ]]; then
      echo "[ERROR] missing required environment variable: ${name}" >&2
      exit 1
    fi
  done
}

validate_flag() {
  local name=$1
  case "${!name:-false}" in
    true|false) ;;
    *) echo "[ERROR] ${name} must be true or false" >&2; exit 1 ;;
  esac
}

# ---
# 第二阶段：校验分发计划
validate_flag DISTRIBUTE_TO_APISIX
validate_flag DISTRIBUTE_TO_FRONTEND_OSS
validate_flag DISTRIBUTE_TO_DRAWIO_OSS

# ---
# 第三阶段：向 APISIX 分发
# APISIX 使用一条稳定 SSL 资源承载证书
# 首次运行创建资源，后续续期通过相同 ID 覆盖证书内容

# SNI 列表决定该证书匹配哪些 HTTPS 入口
# 将逗号分隔的 SNI 转成 JSON 数组，并由 jq 读取 PEM 文件生成 Payload
# 使用 jq --rawfile 可保留证书换行并正确完成 JSON 转义，避免手工拼接破坏私钥内容
if [[ "${DISTRIBUTE_TO_APISIX:-false}" == "true" ]]; then
  require_vars APISIX_ADMIN_URL APISIX_ADMIN_KEY APISIX_SSL_ID APISIX_TLS_SNIS

  snis_json=$(jq -Rn --arg value "${APISIX_TLS_SNIS}" '
    $value
    | split(",")
    | map(gsub("^\\s+|\\s+$"; ""))
    | map(select(length > 0))
  ')
  if [[ "$(jq 'length' <<< "${snis_json}")" -eq 0 ]]; then
    echo "[ERROR] APISIX_TLS_SNIS must contain at least one domain" >&2
    exit 1
  fi

  payload=$(jq -n \
    --rawfile cert "${cert_file}" \
    --rawfile key "${key_file}" \
    --argjson snis "${snis_json}" \
    '{cert: $cert, key: $key, snis: $snis}')

  # --fail-with-body 让 4xx/5xx 返回失败状态，同时保留响应正文用于诊断
  # PUT 使用 APISIX_SSL_ID，确保首次创建和后续续期更新同一条 SSL 资源
  curl --fail-with-body --silent --show-error \
    -X PUT "${APISIX_ADMIN_URL%/}/apisix/admin/ssls/${APISIX_SSL_ID}" \
    -H "X-API-KEY: ${APISIX_ADMIN_KEY}" \
    -H "Content-Type: application/json" \
    --data-binary "${payload}"
  echo "[INFO] APISIX certificate updated"
fi

# ---
# 第四阶段：准备 OSS CNAME 证书更新能力
# 主前端和 DrawIO 使用同一种 OSS API，但各自拥有独立的凭据、Endpoint、Bucket 和域名。
# 该函数只负责更新调用方指定的一个 OSS 目标，不决定哪些目标需要分发。
# OSS CNAME 证书更新逻辑由主前端和 DrawIO 共用
push_oss_certificate() {
  local label=$1
  local id_var=$2
  local secret_var=$3
  local endpoint_var=$4
  local bucket_var=$5
  local domain_var=$6

  require_vars "${id_var}" "${secret_var}" "${endpoint_var}" "${bucket_var}" "${domain_var}"

  local access_key_id=${!id_var}
  local access_key_secret=${!secret_var}
  local endpoint=${!endpoint_var}
  local bucket=${!bucket_var}
  local domain=${!domain_var}
  # OSS API 需要 XML 请求体，其中包含明文私钥
  # 临时文件设为 600，并在成功或失败后立即删除
  local request_file
  request_file=$(mktemp)
  chmod 600 "${request_file}"

  cat > "${request_file}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<BucketCnameConfiguration>
  <Cname>
    <Domain>${domain}</Domain>
    <CertificateConfiguration>
      <Certificate>$(cat "${cert_file}")</Certificate>
      <PrivateKey>$(cat "${key_file}")</PrivateKey>
      <Force>true</Force>
    </CertificateConfiguration>
  </Cname>
</BucketCnameConfiguration>
EOF

  # 凭据只注入当前 ossutil 子进程，不 export 到后续分发分支或其他命令
  if ! OSS_ACCESS_KEY_ID="${access_key_id}" \
    OSS_ACCESS_KEY_SECRET="${access_key_secret}" \
      aliyun ossutil api put-cname \
        --endpoint "${endpoint}" \
        --bucket "${bucket}" \
        --cname-configuration "file://${request_file}"; then
    rm -f "${request_file}"
    echo "[ERROR] failed to update ${label} OSS certificate" >&2
    return 1
  fi

  rm -f "${request_file}"
  echo "[INFO] ${label} OSS certificate updated"
}

# ---
# 第五阶段：执行已启用的 OSS 分发目标
# 主前端和 DrawIO 分别执行；任一已启用目标失败都会终止 Hook，避免部分更新被报告为成功
if [[ "${DISTRIBUTE_TO_FRONTEND_OSS:-false}" == "true" ]]; then
  push_oss_certificate \
    "frontend" \
    FRONTEND_OSS_ACCESS_KEY_ID \
    FRONTEND_OSS_ACCESS_KEY_SECRET \
    FRONTEND_OSS_ENDPOINT \
    FRONTEND_OSS_BUCKET \
    FRONTEND_OSS_DOMAIN
fi

if [[ "${DISTRIBUTE_TO_DRAWIO_OSS:-false}" == "true" ]]; then
  push_oss_certificate \
    "DrawIO" \
    DRAWIO_OSS_ACCESS_KEY_ID \
    DRAWIO_OSS_ACCESS_KEY_SECRET \
    DRAWIO_OSS_ENDPOINT \
    DRAWIO_OSS_BUCKET \
    DRAWIO_OSS_DOMAIN
fi

# 第六阶段：确认本轮所有已启用目标均已更新
# acme.sh 会收到成功退出状态
echo "[INFO] certificate distribution completed"
