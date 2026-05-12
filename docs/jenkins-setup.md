# Jenkins Setup

WisePen 的 Jenkins 是 `full` stack 的一部分：`scripts/middleware/init-up.sh <bind> full` 会启动它（`minimal` 不起 Jenkins），并通过 JCasC + Job DSL **零手工**地完成：

- 创建 admin 账号（无安装向导）
- 注入 SCM / Nacos 凭据
- 创建 4 条 multibranch pipeline，分别指向 `wisepen-cloud-gateway-deploy`、`wisepen-cloud`、`wisepen-cloud-ai`、`wisepen-cloud-sidecar`

只要 `deploy/middleware/.env` 里 Jenkins 段填对了，团队管理员就能用 Jenkins UI 直接 build。

---

## 自动化机制

启动序列：

1. `scripts/middleware/init-up.sh <bind> full` 触发 `docker compose --build`，构建 `wisepen-jenkins:local` 镜像
2. 容器启动时 JCasC 读取 `CASC_JENKINS_CONFIG=/var/jenkins_home/casc.yaml`
3. JCasC 看到 `jobs:` root section，把 `/var/jenkins_home/casc-jobs/seed.groovy` 提交给 Job DSL plugin 执行
4. seed.groovy 按 `${JENKINS_SCM_BASE_URL}` 拼四条 multibranch pipeline，全部用 `scm-credentials`
5. 每条 pipeline 周期扫描分支（5 分钟），找到分支的 `Jenkinsfile` 即建 build job

凭据约定（来自 `casc.yaml`）：

| ID | 类型 | 说明 |
| --- | --- | --- |
| `scm-credentials` | usernamePassword | 拉源码用的 GitHub PAT / 企业 Git 凭据 |
| `nacos-username` | secret-text | Pipeline 中 `credentials('nacos-username')` 取到 |
| `nacos-password` | secret-text | Pipeline 中 `credentials('nacos-password')` 取到 |

子仓库 `Jenkinsfile` 写法对齐：

```groovy
environment {
  NACOS_USER = credentials('nacos-username')
  NACOS_PWD  = credentials('nacos-password')
}
```

---

## .env 字段

Jenkins 段全部字段（端口、admin 账号、SCM 凭据、Pipeline 中 nacos 凭据）见 [`deploy/middleware/env.example`](../deploy/middleware/env.example) `Jenkins` 段。

---

## 改完 `.env` 后如何热更新

JCasC 支持热加载 —— 不必重建 Jenkins 容器：

```bash
# 改完 deploy/middleware/.env 中 Jenkins 段
scripts/middleware/jenkins.sh reload
```

底层调 `POST /configuration-as-code/reload`。注意：`JENKINS_SCM_BASE_URL` 的变更会让 `seed.groovy` 在下一次扫描时把旧 multibranch 替换为新地址（既有 build 历史保留）。

---

## 不要 Jenkins（小机器场景）

```bash
scripts/middleware/init-up.sh local minimal
```

`minimal` stack 不包含 Jenkins，省掉 ~1 GB RAM，仍可用 `scripts/apps/build-and-deploy.sh` 在本地完成等价编译/部署。

---

## Pipeline 范本（在子仓库的 Jenkinsfile 里）

子仓库根放 `Jenkinsfile`。**关键原则**：build 和 deploy 阶段都要做 legacy-net 探测（任何会跑 `docker compose` 的位置都要保持一致），否则在两类网络共存的过渡期会出现 deploy 阶段找不到中间件的奇怪故障：

```groovy
pipeline {
  agent any
  environment {
    APP_VERSION     = "${env.BRANCH_NAME}-${env.BUILD_NUMBER}"
    DOCKER_REGISTRY = "registry.your-org.example.com/wisepen"
  }
  stages {
    stage('Build') {
      steps {
        sh '[ -f mvnw ] && ./mvnw -DskipTests clean package || true'
      }
    }

    stage('Deploy') {
      environment {
        NACOS_USER = credentials('nacos-username')
        NACOS_PWD  = credentials('nacos-password')
      }
      steps {
        sh '''
          # 网络兼容
          # 检测到遗留 cloud-infra_cloud-net 时叠加 legacy-net overlay
          # 老中间件全部下线后，本脚本可以与docker-compose-app.legacy-net.yml文件、部署脚本中的探测分支一并删除
          docker network create wisepen-net 2>/dev/null || true
          COMPOSE_FILES="-f docker-compose-app.yml"
          if docker network inspect cloud-infra_cloud-net >/dev/null 2>&1; then
            echo "检测到遗留网络 cloud-infra_cloud-net，叠加 docker-compose-app.legacy-net.yml"
            COMPOSE_FILES="$COMPOSE_FILES -f docker-compose-app.legacy-net.yml"
          fi

          export NACOS_USERNAME="${NACOS_USER}"
          export NACOS_PASSWORD="${NACOS_PWD}"
          docker compose $COMPOSE_FILES up -d --remove-orphans
        '''
      }
    }
  }
}
```

未来由各子仓库自行维护其 Jenkinsfile 细节；本仓库只保证：

- Jenkins 已就绪并能扫到 `Jenkinsfile`
- `scm-credentials` / `nacos-username` / `nacos-password` 凭据已可用
- 共享网络 `wisepen-net` / 老网络兼容机制存在