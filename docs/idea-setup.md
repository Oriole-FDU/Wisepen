# IDEA Setup (仅Java推荐使用IDEA)

WisePen 子仓库的 IDEA run config 不持有任何环境信息（host、凭证、OTel 端点等）。所有「在哪」通过 `.env` 注入，由 [EnvFile 插件](https://plugins.jetbrains.com/plugin/7861-envfile) 在启动时挂载。


## EnvFile 插件挂 `wisepen-cloud/.env`

1. 安装 **[EnvFile](https://plugins.jetbrains.com/plugin/7861-envfile)**（Settings → Plugins → Marketplace 搜 `EnvFile`）
2. 打开任一 `*Application` run config（例如 `UserApplication`）
3. 切到 **EnvFile** 标签，勾选 **Enable EnvFile** → **Add** → 选 `wisepen-cloud/.env`
4. 7 个 Spring Boot run config 都做同样操作；它们共用同一个 `.env`
5. 启动应用，`bootstrap.yml` 中的 `${NACOS_SERVER_ADDR:localhost:8848}` 等占位符会从该 `.env` 解析

> Python（`wisepen-chat-service`）和 Node（`wisepen-note-collab-service`）由各自的运行时自动读取就近的 `.env`，无需 EnvFile 插件。

## 不要做的事

- 不要把 `NACOS_PASSWORD` 等凭证写回 `runConfigurations/*.xml`（已外置到 EnvFile）
- 不要把生成的 `.env` 加进版本控制（已被各子仓库 `.gitignore`）
- 不要修改 `bootstrap.yml` 中占位符的默认值（外部贡献者依赖 `localhost` 默认开箱可用）