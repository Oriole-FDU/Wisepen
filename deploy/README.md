# deploy/

WisePen 平台的部署编排文件。

```text
deploy/
├── middleware/      中间件 docker compose（本地与开发服务器共用一套）
│   ├── docker-compose.yml          MySQL/Redis/Mongo/Nacos/APISIX/Kafka/Qdrant/JOD
│   ├── env.example                 中间件部署所需全部环境变量
│   ├── conf/                       APISIX/observability 等容器内挂载的只读配置
│   ├── seed/                       中间件种子
│   │   ├── mysql
│   │   ├── jenkins/                JCasC + Job DSL
│   │   └── .rendered/              seed.sh 拼合 + 渲染产物（git 忽略；docker-compose 挂这里）
│   └── profiles/                   可选 compose 叠加层（stack=full 时随 init-up.sh / up.sh 叠加）
│       ├── jenkins/                Jenkins 自定义镜像
│       ├── jenkins.yml             Jenkins LTS
│       ├── observability.yml       OTel + Tempo + Loki + Prometheus + Grafana
│       └── search.yml              Elasticsearch + Kibana
├── business/                       应用层种子
│   └── seed/
│       ├── README.md               
│       ├── business.env.example    业务凭据样例
│       ├── mysql/                  
│       ├── mongo/                  
│       └── nacos/                  wisepen-*-service-{dev,prod}.yaml
└── envs/            中间件部署后由 init-envs.sh 生成的各微服务 .env 归档（git 忽略）
```

**Seed 双路径**：`deploy/middleware/seed/` 只放中间件 infra 种子（nacos schema），`deploy/business/seed/` 放所有应用层种子（业务库、应用 nacos 配置）。两者由 `scripts/middleware/seed.sh database-init` 拼合渲染到 `deploy/middleware/seed/.rendered/`，挂入 mysql / mongo 容器；nacos 配置由 `scripts/middleware/seed.sh nacos-config-init --auto-import` 走 REST API push。详见各自 README。

## 中间件形态

`deploy/middleware/docker-compose.yml` 通过 `WISEPEN_BIND_ADDR` 兼容两种部署形态（首次部署时由 `init-up.sh <bind>` 写回 `.env`，日常 `up.sh` 不动）：

- 本地形态：`WISEPEN_BIND_ADDR=127.0.0.1`，所有端口仅自机访问（`init-up.sh local <stack>`）
- 开发服务器形态：`WISEPEN_BIND_ADDR=0.0.0.0`，对外暴露（`init-up.sh server <stack>`）

## 微服务部署

由各微服务自己的 `docker-compose-app.yml`（位于子仓库根）负责，本目录不持有应用层 compose。

子仓库 compose 引用本目录中间件创建的网络 `wisepen-net`
老中间件兼容由各子仓库的 `docker-compose-app.legacy-net.yml` overlay 自动启用

## 入口脚本

| 任务 | 脚本 |
| --- | --- |
| 首次部署中间件（含配置导入） | `scripts/middleware/init-up.sh local\|server minimal\|full` |
| 日常启停中间件 | `scripts/middleware/up.sh` / `scripts/middleware/down.sh [--volumes]` |
| Jenkins JCasC 热加载 | `scripts/middleware/jenkins.sh reload` |
| 生成各微服务 .env 并分发 | `scripts/envs/init-envs.sh [--random-secrets]` |
| 本地一键打包 + 起所有微服务（Java + Python + NodeJS） | `scripts/apps/build-and-deploy.sh` |
| dev-server Jenkins 流水线（推荐） | `docs/jenkins-setup.md` |