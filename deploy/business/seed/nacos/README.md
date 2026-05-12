# Nacos Seed 配置

由 `scripts/middleware/seed.sh nacos-config-init` 渲染并 POST 到 Nacos。

```bash
# 检查所有 yaml 模板能否正常渲染
scripts/middleware/seed.sh nacos-config-init --check

# 仅补缺失 dataId（已存在的不更新，up.sh 使用此指令）
scripts/middleware/seed.sh nacos-config-init --create-if-missing --auto-import

# 不加 --auto-import：只渲染并导出到 .rendered/nacos/，不写入 Nacos
scripts/middleware/seed.sh nacos-config-init --create-if-missing

# 强制覆盖所有 dataId
scripts/middleware/seed.sh nacos-config-init --override --auto-import
```

## 模板语法

详见 [`../README.md`](../README.md) "模板语法"段。
变量来自 `deploy/middleware/.env`（中间件 .env）+ `deploy/business/seed/business.env`（业务凭据 + 业务系统配置）。
seed.sh 将把所有 `${VAR}` 替换为字面值再 POST 到 Nacos，Java / Python / NodeJS 拉到的都是纯字符串。

## 文件清单

每个微服务对应两个 dataId：

```text
wisepen-{service}-dev.yaml
wisepen-{service}-prod.yaml
```

外加一组共享配置（仅用于 wisepen-cloud 中的 Java 微服务）：

```text
wisepen-common-dev.yaml
wisepen-common-prod.yaml
```

服务列表：

- `wisepen-user-service`
- `wisepen-system-service`
- `wisepen-resource-service`
- `wisepen-document-service`
- `wisepen-file-storage-service`
- `wisepen-note-service`
- `wisepen-note-collab-service`
- `wisepen-chat-service`
