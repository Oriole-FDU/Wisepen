# envs/

由 `scripts/envs/init-envs.sh` 在中间件部署后生成各微服务 / 前端的 `.env` 归档；脚本同时把它们分发到子仓库实际位置（如 `wisepen-cloud/.env`）。

| 归档文件 | 分发目标 |
| --- | --- |
| `wisepen-cloud.env` | `wisepen-cloud/.env` |
| `wisepen-chat-service.env` | `wisepen-cloud-ai/services/wisepen-chat-service/src/chat/.env` |
| `wisepen-note-collab-service.env` | `wisepen-cloud-sidecar/wisepen-note-collab-service/.env` |
| `wisepen-cloud-gateway-deploy.env` | `wisepen-cloud-gateway-deploy/.env` |

本目录的 `*.env` 由 `.gitignore` 保护，永远不要提交。
