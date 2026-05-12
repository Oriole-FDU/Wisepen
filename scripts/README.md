# scripts/

WisePen 平台脚本集合。当前以 bash 为主（Linux / macOS / Git Bash / WSL2 均可）。Windows 用户推荐 [Git for Windows](https://git-scm.com/download/win) 自带的 Bash 或 [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install)。

## 目录

```text
scripts/
├── middleware/                      中间件部署脚本
│   ├── init-up.sh <bind> <stack>    首次部署 / 完整重建
│   ├── up.sh                        日常启动
│   ├── down.sh                      日常停止
│   ├── seed.sh                      种子初始化入口
│   ├── jenkins.sh reload            Jenkins JCasC 热加载入口
│   └── lib/                         实现库（common / preflight / compose / ready / render / seed / jenkins）
├── apps/                            微服务部署脚本
│   └── build-and-deploy.sh          部署并启动微服务
└── envs/                            环境变量脚本
    └── init-envs.sh                 从 deploy/middleware/.env 派生并分发到各子仓库
```

## 通用约定

- 所有脚本以 `set -euo pipefail` 开头
- 项目根路径定位通过 `SCRIPT_DIR` + `..`，不依赖 cwd
- 错误信息走 stderr，正常输出走 stdout
- `.env` 文件均不进 git
- 所有脚本支持 `--help` / `-h` 打印用法

## 中间件 vs 微服务的部署边界

- 中间件（MySQL / Redis / Nacos / APISIX / Kafka / Qdrant / Jenkins / ...）由本仓库 `deploy/middleware/` 全权负责
- 微服务（Java / Python / Node / 前端）由各子仓库自己的 `docker-compose-app.yml` 持有
- `scripts/apps/build-and-deploy.sh` 是 Jenkins 的等价部署脚本；与 Jenkinsfile 里的逻辑保持对齐
