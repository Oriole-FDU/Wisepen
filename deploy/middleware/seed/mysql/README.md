# MySQL Schema Seeds（中间件）

> 仅放 **中间件 infra** 自身需要的 sql。业务库 schema 与种子数据在
> `deploy/business/seed/mysql/`（[`README`](../../../business/seed/README.md)）。

`scripts/middleware/seed.sh database-init`（由 `scripts/middleware/up.sh` 第 1 阶段自动调用，也可单独跑）会把：

- 本目录的 `*.sql`
- `deploy/business/seed/mysql/*.sql`
- 渲染后的 `deploy/business/seed/mysql/*.sql.tmpl`

拼合到 `deploy/middleware/seed/.rendered/mysql/`，然后由 docker-compose 把这个 `.rendered` 目录挂到 mysql 容器的 `/docker-entrypoint-initdb.d/`，**首次启动**（容器已有 data volume 时不再执行）按字典序自动跑。

只想检查渲染产物而不写盘：`seed.sh database-init --check`。

## 当前文件

| 文件 | 库 | 内容 | 来源 / 维护 |
| --- | --- | --- | --- |
| `00-nacos-schema.sql` | `nacos` | Nacos v2.3.2 官方 schema（Apache-2.0），含 `users` / `roles` / `permissions` / `config_info` 等表 + bcrypt 默认账号 `nacos/nacos` | Nacos 上游 |