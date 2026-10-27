import { useSetup } from "../state/SetupContext";
import {
  ConditionalPanel,
  FormSection,
  Notice,
  NumberField,
  RadioField,
  TextAreaField,
  TextField,
} from "../components/FormControls";

export function JenkinsStep() {
  const { document, update } = useSetup();
  const { jenkins, operations } = document!.answers;
  if (!jenkins) return null;

  return (
    <div className="grid gap-5">
      <FormSection
        title="Jenkins 来源"
        description="仓库、版本、Job、触发方式和构建工具均不向用户收集"
      >
        <RadioField
          label="Jenkins"
          value={jenkins.source}
          options={[
            { value: "managed", label: "由 WisePenDeploy 部署" },
            { value: "external", label: "使用已有 Jenkins" },
          ]}
          onChange={(value) => update("jenkins.source", value)}
        />
      </FormSection>

      {jenkins.source === "managed" ? (
        <FormSection title="由 WisePenDeploy 部署 Jenkins">
          <Notice>Jenkins 将获得构建镜像和部署 WisePen 服务所需的 Docker 访问能力</Notice>
          <RadioField
            label="访问范围"
            value={jenkins.managed?.accessScope}
            options={[
              { value: "local", label: "仅本机" },
              { value: "lan", label: "局域网" },
              { value: "domain", label: "域名访问" },
            ]}
            onChange={(value) => update("jenkins.managed.accessScope", value)}
          />
          <ConditionalPanel>
            <div className="md:col-span-2">
              {jenkins.managed?.accessScope === "domain" ? (
                <TextField label="Jenkins 访问域名" value={jenkins.managed?.domain} onChange={(v) => update("jenkins.managed.domain", v)} />
              ) : (
                <NumberField label="Jenkins 宿主机端口" value={jenkins.managed?.port} min={1} max={65535} onChange={(v) => update("jenkins.managed.port", v)} />
              )}
            </div>
            <div className="md:col-span-2">
              <RadioField
                label="持久化位置"
                value={jenkins.managed?.persistenceMode}
                options={[
                  { value: "root", label: "使用统一根目录" },
                  { value: "custom", label: "自定义路径" },
                ]}
                onChange={(value) => update("jenkins.managed.persistenceMode", value)}
              />
            </div>
            {jenkins.managed?.persistenceMode === "custom" ? (
              <div className="md:col-span-2">
                <TextField label="Jenkins 自定义持久化路径" value={jenkins.managed?.persistencePath} onChange={(v) => update("jenkins.managed.persistencePath", v)} />
              </div>
            ) : null}
          </ConditionalPanel>
          {operations.credentialPolicy?.mode === "manual" ? (
            <ConditionalPanel>
              <TextField label="Jenkins 管理用户名" value={operations.credentialPolicy.credentials?.jenkins?.username} onChange={(v) => update("operations.credentialPolicy.credentials.jenkins.username", v)} />
              <TextField label="Jenkins 管理密码" type="password" value={operations.credentialPolicy.credentials?.jenkins?.password} onChange={(v) => update("operations.credentialPolicy.credentials.jenkins.password", v)} />
            </ConditionalPanel>
          ) : null}
        </FormSection>
      ) : (
        <FormSection title="已有 Jenkins" description="API Token 必须具备创建和更新 WisePen Job 的权限">
          <div className="grid gap-4">
            <TextField label="Jenkins URL" value={jenkins.external?.url} placeholder="https://jenkins.example.com" onChange={(v) => update("jenkins.external.url", v)} />
            <div className="grid gap-4 md:grid-cols-2">
              <TextField label="管理用户名" value={jenkins.external?.username} onChange={(v) => update("jenkins.external.username", v)} />
              <TextField label="API Token" type="password" value={jenkins.external?.apiToken} onChange={(v) => update("jenkins.external.apiToken", v)} />
            </div>
          </div>
        </FormSection>
      )}

      <FormSection
        title="部署目标机器"
        description="Jenkins 完成构建后需要连接目标机器的 Docker 服务并启动 WisePen 容器"
      >
        <RadioField
          label="目标机器"
          value={jenkins.deploymentTarget?.mode}
          options={[
            { value: "local", label: "本地", description: "Jenkins 与 WisePen 运行在当前宿主机" },
            { value: "remote", label: "远程", description: "通过 SSH 在另一台服务器上部署 WisePen" },
          ]}
          onChange={(value) => update("jenkins.deploymentTarget.mode", value)}
        />
        {jenkins.deploymentTarget?.mode === "remote" ? (
          <ConditionalPanel>
            <TextField
              label="远程主机"
              value={jenkins.deploymentTarget?.remote?.host}
              placeholder="wisepen-server.example.com"
              onChange={(value) => update("jenkins.deploymentTarget.remote.host", value)}
            />
            <NumberField
              label="SSH 端口"
              value={jenkins.deploymentTarget?.remote?.sshPort}
              min={1}
              max={65535}
              onChange={(value) => update("jenkins.deploymentTarget.remote.sshPort", value)}
            />
            <div className="md:col-span-2">
              <TextField
                label="SSH 用户名"
                value={jenkins.deploymentTarget?.remote?.username}
                onChange={(value) => update("jenkins.deploymentTarget.remote.username", value)}
              />
            </div>
            <div className="md:col-span-2">
              <RadioField
                label="SSH 认证方式"
                value={jenkins.deploymentTarget?.remote?.authMode}
                options={[
                  { value: "private-key", label: "私钥" },
                  { value: "password", label: "密码" },
                ]}
                onChange={(value) => update("jenkins.deploymentTarget.remote.authMode", value)}
              />
            </div>
            <div className="md:col-span-2">
              {jenkins.deploymentTarget?.remote?.authMode === "password" ? (
                <TextField
                  label="SSH 密码"
                  type="password"
                  value={jenkins.deploymentTarget?.remote?.password}
                  onChange={(value) => update("jenkins.deploymentTarget.remote.password", value)}
                />
              ) : (
                <TextAreaField
                  label="SSH 私钥"
                  value={jenkins.deploymentTarget?.remote?.privateKey}
                  placeholder="-----BEGIN OPENSSH PRIVATE KEY-----"
                  onChange={(value) => update("jenkins.deploymentTarget.remote.privateKey", value)}
                />
              )}
            </div>
          </ConditionalPanel>
        ) : (
          <Notice status="success">将直接使用当前宿主机 Docker，不需要额外的远程连接信息</Notice>
        )}
      </FormSection>
    </div>
  );
}
