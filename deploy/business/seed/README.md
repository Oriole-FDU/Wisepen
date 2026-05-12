# 业务 Seed

WisePen 把"中间件本身需要的种子"（如 Nacos schema）与"应用层种子"（业务库 schema、业务初始数据、Nacos 配置中心 yaml）拆成两个目录：

```text
deploy/middleware/seed/   # 中间件 infra 种子（仅中间件自身需要的）
deploy/business/seed/     # 所有应用层种子
```

本目录由 `scripts/middleware/seed.sh` 拼合渲染后挂入 mysql / mongo / push 进 nacos。
`business.env`（参考 `business.env.example` 复制）只在 seed 渲染 `*.tmpl` 时被读取一次，**不会进任何容器环境**。这保证了：

- 中间件 `.env`（基础设施层，如 mysql / redis 密码）干净，不混业务凭据
- 业务凭据（OSS / LLM api_key）独立管理，方便单独轮转
- 用户**不填**业务 env 也能让中间件正常启动（业务功能降级，详见下文）

## 目录结构

```text
deploy/business/seed/
├── README.md
├── business.env.example                       业务凭据样例（OSS / LLM api_key 等）
├── mysql/
│   ├── 01-wisepen-system.sql                  纯 schema（DDL）
│   ├── 02-wisepen-user.sql                    纯 schema（DDL）
│   └── 99-wisepen-system-bootstrap.sql.tmpl   sys_storage_config 默认 row（OSS）
├── mongo/
│   └── wisepen_chat.js.tmpl                   wisepen_chat 库 collections + provider/model 数据
└── nacos/
    ├── wisepen-common-{dev,prod}.yaml         Spring Cloud 共享配置
    └── wisepen-*-service-{dev,prod}.yaml      各业务服务（user/system/resource/document/
                                               file-storage/note/note-collab/chat）
```

## 工作机制

### 渲染流水线

`scripts/middleware/seed.sh database-init`（由 `scripts/middleware/up.sh` 调用）：

```text
deploy/middleware/seed/{mysql,mongo}/     ←─┐
                                            ├─→ 拼合 + 渲染 ─→ deploy/middleware/seed/.rendered/{mysql,mongo}/
deploy/business/seed/{mysql,mongo}/       ←─┘                       ↑
                                                              docker-compose 挂这个目录
deploy/business/seed/business.env         ←─ 仅在此一刻被读取（subshell 隔离）
```

`.rendered/` 是脚本生成物，git 忽略。docker-compose 直接挂 `.rendered/{mysql,mongo}` 到 mysql / mongo 容器的 `/docker-entrypoint-initdb.d/`，由 mysql / mongo 自身在**首次启动**（数据卷为空时）自动按文件名字典序执行。

> **注意**：mysql / mongo 容器只在 data volume 为空时执行 entrypoint-initdb。

### 模板语法

`*.tmpl` 文件支持以下占位（与 nacos seed yaml 共用同一套渲染器）：

| 语法 | 含义 |
| --- | --- |
| `${VAR}` | 必填；env 中无值或为空 → 渲染 fail |
| `${VAR:default}` | env 中无值或为空时用 default（default 也可空：`${VAR:}`） |
| `${A:${B:fallback}}` | 嵌套；从内向外解析 |
| `-- @if VAR\n ... -- @endif` (SQL) | VAR 非空 → 保留 body；空 / 未定义 → 整段连同标记一并删除 |
| `/* @if VAR */ ... /* @endif */` (JS) | 同上，C / JS 注释风格 |

`@if` 不支持嵌套；想做"AND" / "OR"组合请拆成多个独立块。

## business.env 字段（单文件分四段）

详见 [`business.env.example`](business.env.example)。文件内分四段，前两段是凭据（落 mysql/mongo 表），后两段是业务系统配置（写 nacos config）：

### [1] [2] 业务凭据段（落库；缺 → 业务降级）

| 段 | 字段 | 缺失影响 |
| --- | --- | --- |
| [1] LLM provider | `WISEPEN_LLM_PROVIDER_API_KEY` | mongo `wisepen_chat.wisepen_providers` 无 row → AI（chat-service）调模型时报错 |
| [2] 主存储 | `WISEPEN_OSS_*`（必填 `*_REGION/*_ENDPOINT/*_ACCESS_KEY_ID/*_ACCESS_KEY_SECRET/*_BUCKET_NAME`） | mysql `wisepen_system.sys_storage_config` 无 row → 文件存储（file-storage-service）上传/下载报错 |

`@if VAR ... @endif` 由 `WISEPEN_LLM_PROVIDER_API_KEY` / `WISEPEN_OSS_ACCESS_KEY_ID` 触发；空 → 整段 INSERT 跳过，库表正常存在但无业务数据。

### [3] [4] 业务系统配置段（写 nacos；缺 → 业务降级）

| 段 | 字段 | 写入位置 | 缺失影响 |
| --- | --- | --- | --- |
| [3] LLM 网关 + Memory + Summary | `LLM_BASE_URL` `LLM_API_KEY` `MEMORY_LLM_MODEL` `MEMORY_EMBEDDING_MODEL` `MEMORY_RERANKER_ZE_MODEL` `ZERO_ENTROPY_API_KEY` `SUMMARY_MODEL` | `nacos/wisepen-chat-service-{dev,prod}.yaml` | AI（chat-service）调模型时报错 |
| [4] 邮件（SMTP） | `WISEPEN_MAIL_HOST` `WISEPEN_MAIL_USERNAME` `WISEPEN_MAIL_PASSWORD`（`WISEPEN_MAIL_PORT` 已默认 465） | `nacos/wisepen-system-service-{dev,prod}.yaml` | 邮件功能（system-service）报错 |

这一段的字段在 yaml 里是 `${VAR:}`（默认空），缺 → Nacos 配置渲染阶段**不**报错，但 chat-service / system-service 跑起来后调相关功能会报错（业务降级）。`LLM_API_KEY` 通常和 `WISEPEN_LLM_PROVIDER_API_KEY` 同值。

## 想换 LLM provider 怎么办

仓库默认且**仅**默认 zhizengzeng（智增增）。`mongo/wisepen_chat.js.tmpl` 中 `wisepen_model_provider_mappings` 集合的 14 条 mapping 全部硬编码指向智增增的 `ObjectId(69d72506dfef56e2b20fc374)`。**想换 provider，必须**：

1. 停止 chat-service
2. 进 mongo `wisepen_chat` 库
3. 在 `wisepen_providers` 集合插入新 provider 文档（自己生成 ObjectId）
4. 在 `wisepen_model_provider_mappings` 集合插入新的提供者映射信息（请参考各提供者的官方文档）
5. （可选）把旧的 provider 标记 `is_active: false` 或删掉
6. 重启 chat-service

> 预计后续版本变更为可视化界面维护。

## OSS 之外的 storage provider？

后端目前只实现了 `ALIYUN_OSS`。`MINIO` / `TENCENT_COS` 等 provider 字段在 `sys_storage_config` 里有定义，但 Java 侧没有对应 SDK 封装；请勿改 `business.env` 中的 provider 字段，否则上传 / 下载流程会在路由分发阶段抛 `UnsupportedProviderException`。