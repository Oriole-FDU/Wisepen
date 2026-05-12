# Config Reference

WisePen 配置分布在多份文件中，**就近**记录在描述对象旁边。本文件**只**收录各子仓库 `.env` 字段总表 + 跨仓库命名约定。

| 想找 | 看这里 |
| --- | --- |
| 中间件 `.env`（强密码 / bind-data / observability profile / 各字段含义） | [`deploy/middleware/env.example`](../deploy/middleware/env.example) 顶部注释 |
| 业务 seed `business.env`（OSS / LLM / Memory / SMTP 四段） | [`deploy/business/seed/README.md`](../deploy/business/seed/README.md) + [`business.env.example`](../deploy/business/seed/business.env.example) |
| Nacos seed yaml 字段（`${VAR}` / `${VAR:default}` / 各服务关键字段） | [`deploy/business/seed/nacos/README.md`](../deploy/business/seed/nacos/README.md) |
| 中间件 profile（observability / search / bind-data） | [`deploy/middleware/profiles/README.md`](../deploy/middleware/profiles/README.md) |
---

## 各子仓库 `.env`（由 `scripts/envs/init-envs.sh` 自动生成 + 分发）

`init-envs.sh` 从 `deploy/middleware/.env` 派生出 4 份 `.env`，分别落到各子仓库。下表是字段总览；逐字段含义请打开各子仓库的 `.env.example`。

### `wisepen-cloud/.env`（7 个 Java 服务共用）

| 变量 | 来源 | 说明 |
| --- | --- | --- |
| `NACOS_SERVER_ADDR` | 中间件 .env | Nacos 控制台地址；本地形态 `localhost:8848`，远端形态由 `--remote-host` 注入 |
| `NACOS_USERNAME` | 中间件 `NACOS_USERNAME` | |
| `NACOS_PASSWORD` | 中间件 `NACOS_PASSWORD` | |
| `SPRING_PROFILES_ACTIVE` | 固定 `dev` | 容器化部署时由 docker compose 覆盖为 `prod` |
| `OTEL_SDK_DISABLED` | 固定 `true` | 本机开发关闭遥测；启用 observability profile 时改 `false` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://${HOST}:4318` | observability profile 用 |

### `wisepen-cloud-ai/services/wisepen-chat-service/src/chat/.env`

| 变量 | 来源 | 说明 |
| --- | --- | --- |
| `NACOS_SERVER_ADDR` / `_USERNAME` / `_PASSWORD` | 同上 | |
| `PROFILE` | 固定 `dev` | 容器化部署时由 docker compose 覆盖为 `prod`，data-id 拼为 `wisepen-chat-service-${PROFILE}.yaml` |

可选段（默认即可）：`SERVICE_HOST`/`SERVICE_PORT`/`LOG_LEVEL`/`NACOS_NAMESPACE_ID`/`NACOS_GROUP`/`NACOS_REGISTER_IP`，详见子仓库 `.env.example`。

### `wisepen-cloud-sidecar/wisepen-note-collab-service/.env`

| 变量 | 来源 | 说明 |
| --- | --- | --- |
| `NACOS_SERVER_ADDR` / `_USERNAME` / `_PASSWORD` | 同上 | |
| `PROFILE` | 固定 `dev` | 容器化部署时由 docker compose 覆盖为 `prod`，data-id 拼为 `wisepen-note-collab-service-${PROFILE}.yaml` |

可选段（默认即可）：`PORT`/`NACOS_NAMESPACE_ID`/`NACOS_GROUP`/`NACOS_REGISTER_IP`，详见子仓库 `.env.example`。

### `wisepen-cloud-gateway-deploy/.env`

| 变量 | 来源 | 说明 |
| --- | --- | --- |
| `APISIX_ADMIN_HOST` / `_PORT` | 中间件 .env | |
| `APISIX_ADMIN_KEY` | 中间件 .env | 推路由用的 X-API-KEY |
| `REDIS_AUTH_PASSWORD` | 中间件 `WISEPEN_REDIS_PASSWORD` | auth.lua 拉用户登录凭据用 |
| `FROM_SOURCE_SECRET` | 中间件 .env | APISIX → 后端服务的请求源校验密钥 |

### 前端

`wisepen-view/.env.local` 暂未纳入 `init-envs.sh` 自动分发。请按子仓库 `.env.example` 手动填写。

---

## 命名约定

- `WISEPEN_*`：WisePen 自定义变量
- 行业既有约定保留原名（`NACOS_SERVER_ADDR`、`OTEL_EXPORTER_OTLP_ENDPOINT`、`VITE_*`、`SPRING_PROFILES_ACTIVE` 等）
- 中间件 `.env` 中的 `_HOST_PORT` 后缀都指**宿主机映射端口**；不带后缀的（如 `KAFKA_INTERNAL_HOST_PORT`）也是宿主端口，命名带 `INTERNAL/EXTERNAL` 仅区分 Kafka listener 用途
- 业务 seed 字段（`WISEPEN_LLM_*` / `WISEPEN_OSS_*` / `MEMORY_*` / `WISEPEN_MAIL_*`）只出现在 `deploy/business/seed/business.env`，**绝不**进 `deploy/middleware/.env` 与任何容器环境

---

## Bootstrap 层 vs Nacos 层

| 层 | 位置 | 内容 | 修改重启 |
| --- | --- | --- | --- |
| Bootstrap | 各服务 `.env` | Nacos 拉配置「之前」必须就位的最小集合（`NACOS_SERVER_ADDR` / `NACOS_USERNAME` / `NACOS_PASSWORD` / `PROFILE`） | 改完要重启服务 |
| Nacos | `deploy/business/seed/nacos/*.yaml` | 业务连接串、密钥、各类调优参数 | Nacos UI 改即热生效（Spring `@RefreshScope` / pydantic-settings） |

凡能落到 Nacos 的字段一律落到 Nacos。