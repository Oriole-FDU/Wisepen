# Profiles

按需叠加在核心 `docker-compose.yml` 之上的可选层。三者作为整体由 `stack=full` 一并启用，`stack=minimal` 仅起核心 compose。

| Profile | 服务 | 主要端口 | 资源占用（约） |
| --- | --- | --- | --- | --- |
| `jenkins.yml` | jenkins | 8080, 50000 | 1.0 GB RAM |
| `observability.yml` | otel-collector, tempo, loki, prometheus, grafana | 3000 (Grafana), 3100 (Loki), 3200 (Tempo), 4317/4318 (OTLP), 8889 (OTel→Prom) | 1.5 GB RAM |
| `search.yml` | elasticsearch, kibana | 9200 (ES), 5601 (Kibana) | 1.0 GB RAM |
