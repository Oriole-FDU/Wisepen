# Changelog

本文件记录 WisePen 平台级别的发布。各子仓库的细节变更见各自的 CHANGELOG。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

> 计划项：Q2 能力建设（Skill 资源化、AI 能力增强、资源流通体系雏形）。详见 [README 路线图](README.md#路线图)。

## [v0.1.0-dev] - 2026-05-12

WisePen 首个公开开发版本。Q1 平台底座建设完成，提供面向高校课程场景的课程知识管理、协同笔记与 AI Chat 基础能力，适合开发、联调、教学试点与非商业研究场景使用。

### Added

#### 用户、组织与基础计费体系

- 注册登录、邮箱验证、密码找回与基础账户管理。
- 课程组 / 用户组、成员管理、角色与权限配置。
- Token 钱包、额度管理、充值券与消费记录。

#### 课程资源管理与权限体系

- 支持 Note、PDF、Word、PPT、Excel 等多类资源的统一资源模型。
- 个人空间、课程组空间、标签树与目录组织。
- 资源访问控制、下载边界、链接分享与共享授权。

#### 文档上传、预览与产权保护

- 对象存储直传、秒传与上传初始化流程。
- 文档状态流转与异步处理链路。
- PDF 在线预览与动态水印。

#### 笔记与协同研写底座

- 基于 Yjs 的多人实时协同编辑。
- 编辑房间管理、权限校验、只读 / 可编辑连接模式。
- 文档快照、版本历史与细粒度操作日志。

#### AI Chat 服务与 Skill 雏形

- 多模型接入与流式对话。
- 会话管理、历史消息分页、上下文管理。
- 基于 Mem0 的长期记忆、摘要压缩与 Token 统计。
- 示例 Skill 加载、工具调用与示例任务，为后续 Skill 资源化打底。

#### 工程与服务治理基础

- 多服务拆分：`wisepen-view` / `wisepen-cloud` / `wisepen-cloud-ai` / `wisepen-cloud-sidecar` / `wisepen-cloud-gateway-deploy` 五子仓 + 主仓 submodule 聚合。
- APISIX 网关 + Nacos 服务发现 + Kafka 消息事件。
- Docker Compose 中间件与业务编排，覆盖 MySQL、Redis、MongoDB、Nacos、APISIX、Kafka、Qdrant 等。
- 中间件 / 业务种子 / 微服务三层配置边界与脚本化 `.env` 分发（`scripts/envs/init-envs.sh`）。
- Jenkins 流水线模板与持续集成基础。

### Documentation

- 主仓 `README.md`、`CONTRIBUTING.md`、`docs/` 上手指南、配置说明、IDEA / PyCharm 指南、Jenkins 指南与 submodule 工作流文档。
- `deploy/README.md`、`scripts/README.md` 部署与脚本目录说明。
- `versions.yaml` 维护平台版本与五个 submodule commit / tag 组合。

### Security

- 仓库默认不携带任何真实凭据；`.env`、`.env.local`、`.env.internal`、`deploy/envs/*.env`、`deploy/business/seed/business.env` 等敏感文件已纳入 `.gitignore`。
- `deploy/middleware/local-default.env` 仅作为本机 `127.0.0.1` 体验默认值，**严禁直接用于对外暴露的部署**；对外部署请使用 `scripts/envs/init-envs.sh --random-secrets` 生成强随机密码。
- 安全问题请通过 GitHub Security Advisory 报告，避免在公开 issue 中披露敏感细节。

### Known Limitations

- `v0.1.0-dev` 仍处于快速迭代阶段，尚未声明为通用生产稳定版本。
- 文件存储后端目前仅实现 `ALIYUN_OSS`，`MINIO` / `TENCENT_COS` 等 provider 暂未实现。
- LLM provider 默认且仅默认 `zhizengzeng`（智增增），切换 provider 需要手动重做 `wisepen_chat.wisepen_model_provider_mappings` 集合，详见 `deploy/business/seed/business.env.example`。
- 前端 `.env.local` 暂未纳入自动分发，需按 `wisepen-view/.env.example` 手动配置。

[Unreleased]: https://github.com/Oriole-FDU/Wisepen/compare/v0.1.0-dev...HEAD
[v0.1.0-dev]: https://github.com/Oriole-FDU/Wisepen/releases/tag/v0.1.0-dev
