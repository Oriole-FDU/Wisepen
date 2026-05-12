# Getting Started

WisePen 支持如下的中间件与服务部署方式：

- **中间件部署方式**
  - 本地部署：`WISEPEN_BIND_ADDR=127.0.0.1`，端口仅自机访问
  - 开发服务器部署：`WISEPEN_BIND_ADDR=0.0.0.0`，对外暴露
- **微服务部署方式**
  - 本机进程启动（IDE 加载 `.env`）
  - 容器部署（手动部署）
  - 容器部署（Jenkins 流水线）

---

## Step 0 ─ 前置依赖

- Docker 24+ 与 Docker Compose v2
- 编译环境：（Java）JDK 21、Maven 3.9+；（Python）：Python 3.11+、`uv`；前端 / Node：Node.js 20+、`pnpm` 9+

---

## Step 1 ─ 启动中间件

```text
init-up.sh <bind> <stack>      首次部署 / 完整重建
    bind  ∈ {local, server}    local=127.0.0.1（仅自机），server=0.0.0.0（对外暴露）
    stack ∈ {minimal, full}    minimal=核心中间件，full=minimal + jenkins + observability + search
up.sh                          日常启动
```

### 本地部署与启动中间件（不推荐在个人开发设备上启动）

```bash
git clone --recurse-submodules https://github.com/Oriole-FDU/wisepen.git
cd wisepen
# 首次启动
scripts/middleware/init-up.sh local minimal
# 后续日常启停
scripts/middleware/down.sh
scripts/middleware/up.sh
```

> 数据卷默认走 docker named volumes（不污染仓库目录）。想把数据落到指定目录：在 `.env` 设置形如 `WISEPEN_DATA_ROOT=/srv/wisepen` 的绝对路径，init-up.sh / up.sh 会自动叠加 `profiles/bind-data*.yml` 并按各容器 UID 做 `mkdir + chown`。

### 开发服务器部署与启动中间件（对外暴露，不推荐在个人开发设备上启动）

```bash
# 生成强随机密码（基于 env.example 生成 deploy/middleware/.env）
scripts/envs/init-envs.sh --random-secrets
# 首次启动
scripts/middleware/init-up.sh server full
# 后续日常启停
scripts/middleware/down.sh
scripts/middleware/up.sh
```

团队成员可以从本机 IDE 连接服务器（需管理员自行分发.env）。

### 业务种子（强烈建议事先填写业务系统配置段）

`deploy/business/seed/business.env`（**不**进任何容器，仅在 seed 渲染期被读一次）单文件分四段：业务凭据（OSS / LLM api_key 等，落 mysql/mongo）+ 业务系统配置（LLM 网关 / Memory / SMTP，写 Nacos）。任一段缺失都不阻塞首次启动，仅相应业务降级。

```bash
cp deploy/business/seed/business.env.example deploy/business/seed/business.env
# 首次启动时自动初始化
scripts/middleware/init-up.sh local minimal     # 或 server full

# 重新初始化
scripts/middleware/seed.sh database-init
scripts/middleware/seed.sh nacos-config-init --override --auto-import
```

> **注意**：mysql / mongo 容器只在 data volume 为空时执行 entrypoint-initdb。因此 scripts/middleware/seed.sh database-init 的生成物 `.rendered/{mysql,mongo}` 在data volume 不为空时无法被容器执行，请尝试手动导入。

## 字段表 / 缺值影响见 `[deploy/business/seed/README.md](../deploy/business/seed/README.md)`。

## Step 2 ─ 启动微服务

### 本机进程启动（IDE 加载 `.env`）

中间件已启动的前提下：

```bash
scripts/envs/init-envs.sh
```

会从 `deploy/middleware/.env` 生成 4 个 `.env` 并归档到 `deploy/envs/`：`wisepen-cloud/.env`、`wisepen-cloud-ai/services/wisepen-chat-service/src/chat/.env`、`wisepen-cloud-sidecar/wisepen-note-collab-service/.env`、`wisepen-cloud-gateway-deploy/.env`。

当中间件部署在开发服务器时，需管理员自行收集并分发.env。可使用：

```bash
scripts/envs/init-envs.sh --remote-host=wisepen-dev.example.com:8848
```

之后在 IDE 中：

- Java：安装 [EnvFile 插件](https://plugins.jetbrains.com/plugin/7861-envfile)，挂 `wisepen-cloud/.env`，跑各 `*Application` run config（详见 [idea-setup.md](idea-setup.md)）
- Python（以 Chat 为例）：`uv run uvicorn chat.main:app --reload`（在 `wisepen-cloud-ai/services/wisepen-chat-service/src`）
- Node（以 Note Collab 为例）：`pnpm dev`（在 `wisepen-cloud-sidecar/wisepen-note-collab-service`）
- 前端：`pnpm dev`（在 `wisepen-view`）

### 容器部署（手动部署）

```bash
# 先注册 APISIX 路由（一次即可）
scripts/apps/build-and-deploy.sh --only gateway

# 启动所有 Java 微服务
scripts/apps/build-and-deploy.sh --only java

# 启动所有 Python 微服务
scripts/apps/build-and-deploy.sh --only python

# 启动所有 NodeJS sidecar 微服务
scripts/apps/build-and-deploy.sh --only nodejs

# 全部启动
scripts/apps/build-and-deploy.sh
```

前端（wisepen-view）镜像化部署本轮不在脚本范围；用 IDE / pnpm dev 即可。

### 容器部署（Jenkins 流水线）

`scripts/middleware/init-up.sh server full` 启动的 Jenkins 已通过 JCasC 自动配置好 admin、SCM 凭据、4 条 multibranch pipeline。

详见 [jenkins-setup.md](jenkins-setup.md)。