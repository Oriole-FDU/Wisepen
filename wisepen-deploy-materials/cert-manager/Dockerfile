# 固定 acme.sh 版本，避免上游 latest 更新后改变签发、续期或 Hook 行为
FROM neilpang/acme.sh:3.1.0

ARG TARGETARCH
# 固定 Aliyun CLI 版本，保证证书分发镜像可复现
ARG ALIYUN_CLI_VERSION=3.0.298

# bash 用于执行严格模式脚本
# curl/jq 用于 APISIX Admin API
# Aliyun CLI 用于更新 OSS CNAME 证书，根据构建目标选择 AMD64 或 ARM64 安装包
RUN apk add --no-cache bash ca-certificates curl jq tar wget && \
    case "${TARGETARCH}" in \
      amd64) aliyun_arch=amd64 ;; \
      arm64) aliyun_arch=arm64 ;; \
      *) echo "unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    archive="aliyun-cli-linux-${ALIYUN_CLI_VERSION}-${aliyun_arch}.tgz" && \
    wget -O "/tmp/${archive}" "https://aliyuncli.alicdn.com/${archive}" && \
    tar -xzf "/tmp/${archive}" -C /tmp && \
    install -m 0755 /tmp/aliyun /usr/local/bin/aliyun && \
    rm -f "/tmp/${archive}" /tmp/aliyun

# 脚本打包进镜像，避免运行时宿主机脚本被误改；ACME 状态通过 Volume 单独持久化
COPY scripts /scripts
RUN chmod 0755 /scripts/init.sh /scripts/reload.sh

# acme.sh 将账号、订单、证书配置和 cron 信息保存在该目录
WORKDIR /acme.sh
ENTRYPOINT ["/scripts/init.sh"]
