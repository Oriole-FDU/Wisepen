// Jenkins Job DSL seed script.
//
// 由 JCasC 通过 `jobs:` root section 调度（详见 casc.yaml）：JCasC 在自身启动时把
// 这个脚本提交给 Job DSL plugin 的执行环境，因此 multibranchPipelineJob() 等 DSL
// 方法可以直接调用。容器内文件路径：/var/jenkins_home/casc-jobs/seed.groovy
//
// 按 ${JENKINS_SCM_BASE_URL} 占位拼接 4 个仓库的 multibranch pipeline；
// 已存在则更新，不破坏既有 build 历史。
//
// 必备环境变量：JENKINS_SCM_BASE_URL（如 https://github.com/Oriole-FDU，无尾斜杠、无 .git）

import jenkins.model.Jenkins
import com.cloudbees.plugins.credentials.CredentialsProvider
import com.cloudbees.plugins.credentials.CredentialsMatchers
import com.cloudbees.plugins.credentials.common.StandardCredentials 

def scmBase = System.getenv('JENKINS_SCM_BASE_URL')
if (!scmBase) {
    println "[seed.groovy] WARN: JENKINS_SCM_BASE_URL not set; skipping seed"
    return
}

def scmCredentialsId = 'scm-credentials'
def scmCredential = CredentialsMatchers.firstOrNull(
    CredentialsProvider.lookupCredentialsInItemGroup(
        StandardCredentials.class,
        Jenkins.get(),
        null,
        null
    ),
    CredentialsMatchers.withId(scmCredentialsId)
)
def hasUsableScmCredential =
    scmCredential != null &&
    scmCredential.username?.trim() &&
    scmCredential.password?.plainText?.trim()
    
if (hasUsableScmCredential) {
    println "[seed.groovy] INFO: Found usable credentials '${scmCredentialsId}', SCM checkout will use it"
} else {
    println "[seed.groovy] INFO: Credentials '${scmCredentialsId}' missing or empty, SCM checkout will use anonymous access"
}

def repos = [
    'wisepen-cloud-gateway-deploy',  // 网关：Pipeline 顺序上推荐先跑
    'wisepen-cloud',
    'wisepen-cloud-ai',
    'wisepen-cloud-sidecar',
]

repos.each { repo ->
    multibranchPipelineJob(repo) {
        displayName(repo)
        description("Auto-seeded by JCasC + Job DSL. Source: ${scmBase}/${repo}.git")

        branchSources {
            git {
                id(repo)
                remote("${scmBase}/${repo}.git")
                if (hasUsableScmCredential) {
                    credentialsId(scmCredentialsId)
                }
                // 默认所有分支，CI 调度自行决定 only build master/release
            }
        }

        factory {
            workflowBranchProjectFactory {
                scriptPath('Jenkinsfile')
            }
        }

        orphanedItemStrategy {
            discardOldItems {
                numToKeep(20)
            }
        }

        // 周期扫描分支（5 分钟）
        triggers {
            periodicFolderTrigger {
                interval('5m')
            }
        }
    }
}

println "[seed.groovy] Provisioned ${repos.size()} multibranch pipeline(s) from ${scmBase}"
