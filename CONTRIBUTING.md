# 贡献指南

感谢有兴趣为 WisePen 做贡献。本文档说明如何参与、开发与提交改动。

## 仓库形态

WisePen 平台主仓库（即本仓库）通过 git submodule 引入五个子仓库：

- [wisepen-view](https://github.com/Oriole-FDU/WisePenView) – 前端（React + Vite + Ant Design + BlockNote）
- [wisepen-cloud](https://github.com/Oriole-FDU/WisePenCloud) – 后端（Spring Cloud Alibaba + MyBatis-Plus）
- [wisepen-cloud-ai](https://github.com/Oriole-FDU/WisePenCloud-AI) – AI 服务
- [wisepen-cloud-sidecar](https://github.com/Oriole-FDU/WisePenCloud-Sidecar) – 边车服务
- [wisepen-cloud-gateway-deploy](https://github.com/Oriole-FDU/WisePenCloud-GatewayDeploy) – APISIX 网关路由模板与初始化脚本

业务变更请直接到对应子仓库提 PR；平台级变更（部署、文档、跨子仓库联调）在主仓库提 PR。

submodule 的常见操作等见 [docs/submodule-workflow.md](docs/submodule-workflow.md)。

## 启动 Wisepen

```bash
# 克隆主仓库与所有子仓库
git clone --recurse-submodules https://github.com/Oriole-FDU/Wisepen.git
cd wisepen

# 首次初始化并启动中间件 (本地)
scripts/middleware/init-up.sh local minimal

# 启动微服务
scripts/apps/build-and-deploy.sh
```

submodule 的常见操作等见 [docs/getting-started.md](docs/getting-started.md)。

## 分支模型

- `main`：默认分支，保持可发布
- `feat/*`：新功能
- `fix/*`：缺陷修复
- `docs/*`：文档
- `chore/*`：构建 / 依赖 / 工程
- `refactor/*`：不改变行为的重构
- `test/*`：测试

## Commit 规范

采用 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/v1.0.0/)。

```text
feat(wisepen-cloud-ai): add ReAct loop guard
fix(wisepen-view): correct base URL fallback when env unset
docs: explain dev/prod profile semantics
chore(deploy): bump apisix to 3.8.0
```

允许的 type：`feat` / `fix` / `docs` / `chore` / `refactor` / `test` / `perf` / `style` / `ci` / `build`。

如果改动跨多个子仓库，请保证每个子仓库各自提一个 PR，commit 信息一致。

## PR 流程

1. fork 对应子仓库（主仓库变更直接基于本仓库分支即可）
2. 新建分支：`git checkout -b feat/your-feature`
3. 提交并推送
4. 创建 PR，按 PR 模板填写：
   - Summary：为什么改、改了什么
   - Test Plan：如何验证
   - Breaking Changes：是否有破坏性变更
5. 等待 reviewer 反馈；必要时联动平台主仓库 PR（更新 submodule 指针）

## 平台级版本

平台版本由主仓库维护，对应 [versions.yaml](versions.yaml) 中的子仓库 commit/tag 组合。

## 行为准则

请保持友善、专业的交流。具体准则参考 [Contributor Covenant](https://www.contributor-covenant.org/zh-cn/version/2/1/code_of_conduct/)。

## 配置与机密

- **不要**把真实凭证写入仓库；任何 `.env`、`.env.local`、`.env.internal` 都已在 `.gitignore` 中
- **不要**修改子仓库的 `dev` profile 默认值为 `wisepen-dev-server`；占位符默认 `localhost`
- 报告安全漏洞请使用 GitHub Security Advisory，而不是公开 issue