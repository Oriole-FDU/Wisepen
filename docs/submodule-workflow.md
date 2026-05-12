# Submodule Workflow

本仓库通过 git submodule 聚合五个独立子仓库。项目仍然保持原有的分仓开发模式：业务代码在各子仓中独立开发、提交和 review；主仓 `wisepen` 只负责记录平台级集成状态，包括 submodule 指针、部署脚本、文档和发布版本。

## 仓库结构

```text
wisepen/                              ← 主仓库（管理 submodule 指针、部署、文档、发布）
├── .gitmodules                       ← submodule 元数据
├── wisepen-view/                     ← 前端子仓
├── wisepen-cloud/                    ← 后端子仓
├── wisepen-cloud-ai/                 ← AI 服务子仓
├── wisepen-cloud-sidecar/            ← Sidecar 子仓
└── wisepen-cloud-gateway-deploy/     ← 网关 / 部署子仓
````

主仓库不直接持有业务代码，只记录五个 submodule 当前对应的 commit。各子仓仍然是独立 Git 仓库，有自己的分支、commit、PR 和 review 流程。

## 基本原则

日常开发仍然以子仓为主。前端开发关注 `wisepen-view`，后端开发关注 `wisepen-cloud`，AI 服务开发关注 `wisepen-cloud-ai`，部署相关改动关注对应部署仓库。

主仓主要由核心维护者维护，用来记录当前平台整体使用的是哪一组子仓 commit。例如：

```text
wisepen-view:                     commit A
wisepen-cloud:                    commit B
wisepen-cloud-ai:                 commit C
wisepen-cloud-sidecar:            commit D
wisepen-cloud-gateway-deploy:     commit E
```

这组 commit 共同构成一个可运行、可部署、可复现的平台状态。子仓的 `main` 分支可以继续向前演进，但主仓不会自动跟随每个子仓的最新提交；只有当核心维护者更新 submodule 指针后，主仓才会记录新的平台组合。

## 推荐协作规则

大多数业务开发只需要在子仓完成，例如修改前端页面、后端接口、AI 服务逻辑，或修复某个子仓内部 bug。这类改动不直接修改主仓，开发者也不需要在每次子仓改动后同步提交主仓。

普通开发者默认只向对应子仓库贡献代码。开发者进入自己负责的子仓，创建功能分支，完成代码修改、commit 和 push 后，在该子仓中提交 PR。

以 `wisepen-cloud` 为例：

```bash
cd wisepen-cloud
git checkout -b feat/my-feature

# 修改代码
git add .
git commit -m "feat: my feature"
git push origin feat/my-feature
```

然后在 `wisepen-cloud` 仓库中提 PR。PR 合并后，代码进入该子仓的 `main` 分支。是否同步到主仓，由核心维护者根据部署、发布或集成需要决定。

核心维护者负责维护主仓的 submodule 指针，确保主仓记录的是一组可 clone、可运行、可部署、可复现的平台状态。当子仓改动需要进入整体部署、版本发布或跨仓集成时，核心维护者再更新主仓指针，并通过主仓 commit 或 PR 记录这组平台级版本组合。

## 第一次克隆

推荐在 `git clone` 时直接拉取所有 submodule：

```bash
git clone --recurse-submodules https://github.com/Oriole-FDU/wisepen.git
cd wisepen
```

如果已经普通 clone 了主仓，可以再初始化 submodule：

```bash
bash scripts/common/sync-submodules.sh init
```

## 日常拉取主仓更新

如果开发者是通过主仓进入项目，建议先在本地配置一次 submodule 递归更新：

```bash
git config --local submodule.recurse true
```

配置后，执行：

```bash
git pull
```

会同时把 submodule 更新到主仓当前记录的 commit。

如果没有进行上述配置，也可以在拉取主仓后手动同步：

```bash
git pull
bash scripts/common/sync-submodules.sh pin
```

其中 `pin` 表示把各 submodule 更新到主仓当前记录的 commit。

## 常见问题

### 1. 子仓已经 merge，但主仓里还是旧代码

这是正常现象。主仓记录的是固定 commit，不会自动跟随子仓 `main` 的最新提交。如果某个子仓的新代码需要进入平台整体部署、发布或集成验证，需要核心维护者在主仓中更新对应的 submodule 指针。

### 2. 我只改了一个子仓，是否需要提交主仓

通常不需要。普通开发者只需要在对应子仓提交代码并提 PR。只有当该改动需要进入平台整体部署、发布版本，或者涉及跨子仓集成时，才需要更新主仓。