# WisePen 中间件部署材料

本目录保存中间件部署的 Compose 与组件配置模板。推荐由 Deploy Kit 根据用户收集的配置生成实际 ENV、选择需要的 Compose 和服务，并按正确顺序执行初始化与启动。

运维人员也可以参考 `env/middleware.env.example` 自行设置 ENV 并手动执行 Compose，但不推荐这样使用。如您选择手工部署，则需自行保证凭据一致性、组件选择、共享网络、SQL 初始化顺序和跨服务配置完全匹配。

## 目录

- `compose/databases.yaml`：MySQL、Redis、MongoDB、Elasticsearch、Qdrant。
- `compose/core-middleware.yaml`：Nacos、etcd、APISIX、Kafka、JODConverter。
- `compose/observability.yaml`：OTel Collector、Tempo、Loki、Prometheus、Grafana。
- `compose/admin-tools.yaml`：APISIX Dashboard、Kibana、Kafka UI、Jenkins。
- `compose/onlyoffice.yaml`：OnlyOffice Document Server。
- `compose/mineru.yaml`：MinerU GPU API。
- `conf/`：挂载到容器中的组件配置。
- `template-data/`：需要随部署材料复制的初始化数据模板。
- `data/`：中间件运行时数据目录，不纳入版本管理。
- `env/middleware.env.example`：环境变量结构示例。
- `scripts/prepare-network.sh`：创建所有 WisePen Compose 共享的外部网络。
- `scripts/initialize-nacos-database.sh`：在 Nacos 启动前创建数据库和用户并导入 Nacos Schema。

## 关键启动顺序

Nacos 使用 MySQL 保存配置和注册中心数据，因此不能在 MySQL 数据库完成初始化前启动。Deploy Kit 和手工部署都必须遵守以下顺序。

### 1. 准备 ENV

Deploy Kit 会根据配置生成 `env/middleware.env`。手工维护时可以从示例复制：

```bash
cp env/middleware.env.example env/middleware.env
```

### 2. 创建共享网络

```bash
sh scripts/prepare-network.sh env/middleware.env
```

### 3. 启动数据库层

```bash
docker compose \
  -p wisepen-middleware \
  --env-file env/middleware.env \
  -f compose/databases.yaml \
  up -d
```

### 4. 初始化 Nacos 数据库

该脚本会等待 MySQL Ready，创建 Nacos 数据库和数据库账号，并导入 `template-data/nacos-init-database/nacos-schema.sql`。

随后脚本使用一次性 `httpd:2.4.63-alpine` 工具容器，根据 `NACOS_PASSWORD` 生成 BCrypt Hash，幂等写入 Nacos `users` 表并确保 `ROLE_ADMIN` 角色存在。

```bash
sh scripts/initialize-nacos-database.sh env/middleware.env
```

这一步成功完成后才能启动 Nacos。

### 5. 启动关键中间件

```bash
docker compose \
  -p wisepen-middleware \
  --env-file env/middleware.env \
  -f compose/core-middleware.yaml \
  up -d
```

### 6. 按需启动其他组件

例如启动可观测性与 OnlyOffice：

```bash
docker compose \
  -p wisepen-middleware \
  --env-file env/middleware.env \
  -f compose/observability.yaml \
  -f compose/onlyoffice.yaml \
  up -d
```

管理工具可按服务名启动，例如：

```bash
docker compose \
  -p wisepen-middleware \
  --env-file env/middleware.env \
  -f compose/admin-tools.yaml \
  up -d apisix-dashboard
```

## 端口绑定

- APISIX HTTP/HTTPS 默认绑定 `PUBLIC_BIND_HOST=0.0.0.0`。
- 中间件和管理端口默认绑定 `MIDDLEWARE_BIND_HOST=127.0.0.1`。
- Kafka External Listener 单独绑定 `KAFKA_EXTERNAL_BIND_HOST`。
- 需要公网访问的管理页面应优先通过 APISIX 配置路由，不建议直接修改为全网绑定。
