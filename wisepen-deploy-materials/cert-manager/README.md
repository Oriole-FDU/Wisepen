# WisePen cert-manager 部署材料

本目录保存 WisePen 自动证书申请、续期和分发所需的 Compose、镜像和脚本模板。推荐由 Deploy Kit 根据证书、访问入口、APISIX 和 OSS 配置生成 ENV 并启动。运维人员也可以手工填写，但需自行保证域名、凭据、ACME 状态目录和分发目标一致。

当证书管理方式为 `external`，或站点协议为 HTTP 时，不应生成或启动本 Compose。

## 目录

- `compose/cert-manager.yaml`：cert-manager 服务。
- `env/cert-manager.env.example`：环境变量结构示例。
- `scripts/init.sh`：加载或签发证书、绑定续期 Hook 并启动 cron。
- `scripts/reload.sh`：按开关向 APISIX、主前端 OSS 和 DrawIO OSS 分发证书。
- `data/`：ACME 账号、证书和续期状态，不纳入版本管理。

## 环境变量说明

### AliDNS DNS-01

```text
certificate.accessKeyId     -> ALIDNS_ACCESS_KEY_ID
certificate.accessKeySecret -> ALIDNS_ACCESS_KEY_SECRET
certificate.acmeCa          -> ACME_CA
certificate.acmeEmail       -> ACME_EMAIL
```

AliDNS 凭据只用于 ACME DNS-01 验证。

### 证书域名

```text
access.siteAddress                         -> CERT_PRIMARY_DOMAIN
certificate.isApplyWildcardCertificate    -> CERT_APPLY_WILDCARD
certificate.extraDomains                   -> CERT_EXTRA_DOMAINS
```

`CERT_EXTRA_DOMAINS` 使用逗号分隔。主域名和自动生成的 `*.主域名` 不需要重复写入。

### APISIX 分发

```text
certificate.isDistributeToApisix -> DISTRIBUTE_TO_APISIX
```

`APISIX_TLS_SNIS` 是逗号分隔的 APISIX HTTPS 域名列表；`APISIX_ADMIN_KEY` 用于调用 APISIX Admin API。关闭 APISIX 分发时，这些字段不会被脚本读取。

### 主前端 OSS

凭据来自独立的 `frontendOss` 配置：

```text
frontendOss.accessKeyId     -> FRONTEND_OSS_ACCESS_KEY_ID
frontendOss.accessKeySecret -> FRONTEND_OSS_ACCESS_KEY_SECRET
frontendOss.endpoint        -> FRONTEND_OSS_ENDPOINT
frontendOss.bucket          -> FRONTEND_OSS_BUCKET
access.siteAddress          -> FRONTEND_OSS_DOMAIN
```

### DrawIO OSS

凭据来自独立的 `drawioOss` 配置：

```text
drawioOss.accessKeyId       -> DRAWIO_OSS_ACCESS_KEY_ID
drawioOss.accessKeySecret   -> DRAWIO_OSS_ACCESS_KEY_SECRET
drawioOss.endpoint          -> DRAWIO_OSS_ENDPOINT
drawioOss.bucket            -> DRAWIO_OSS_BUCKET
DrawIO 完整访问域名          -> DRAWIO_OSS_DOMAIN
```

## ACME 状态来源

### 全新签发

```dotenv
CERT_STATE_SOURCE=new
CERT_MANAGER_DATA_DIR=/opt/wisepen/cert-manager
```

脚本在没有主域名证书配置时注册 ACME 账号并签发 EC-256 证书。

### 复用已有状态

```dotenv
CERT_STATE_SOURCE=existing
CERT_MANAGER_DATA_DIR=/已有/acme-data
```

已有目录必须包含与 `CERT_PRIMARY_DOMAIN` 对应的 acme.sh 证书配置。启动时会重新执行 `--install-cert` 绑定当前分发 Hook，并立即同步一次下游证书。

## 手工启动

复制并填写 ENV：

```bash
cp env/cert-manager.env.example env/cert-manager.env
```

确保中间件部署已经创建共享网络，然后启动：

```bash
docker compose \
  -p wisepen-cert-manager \
  --env-file env/cert-manager.env \
  -f compose/cert-manager.yaml \
  up -d --build
```

## 运行行为

1. 校验 ACME、域名和 AliDNS 配置。
2. 根据 `CERT_STATE_SOURCE` 签发新证书或加载已有状态。
3. 将证书导出到 `/acme.sh/exported/<主域名>/`。
4. 注册 `reload.sh` 为续期 Hook。
5. 按分发开关同步 APISIX、主前端 OSS、DrawIO OSS。
6. 使用 cron 维持后续自动续期。

注意：未启用的分发分支不要求对应凭据；三套阿里云凭据互相独立
