import { Separator } from "@heroui/react";
import { useSetup } from "../state/SetupContext";
import {
  BooleanField,
  ConditionalPanel,
  FormSection,
  RadioField,
  TextField,
} from "../components/FormControls";

const uiLabels: Record<string, string> = {
  grafana: "Grafana",
  apisixDashboard: "APISIX Dashboard",
  kibana: "Kibana",
  kafkaUi: "Kafka UI",
};

export function OperationsStep() {
  const { document, update } = useSetup();
  const { operations, deployment, jenkins } = document!.answers;
  const selectedInterfaces = Object.entries({
    grafana: Boolean(operations.isDeployObservability && operations.isDeployGrafana),
    apisixDashboard: Boolean(operations.isDeployApisixDashboard),
    kibana: Boolean(operations.isDeployKibana),
    kafkaUi: Boolean(operations.isDeployKafkaUi),
  })
    .filter(([, enabled]) => enabled)
    .map(([name]) => name);
  const accountTargets = [
    ...selectedInterfaces,
    ...(deployment.artifactMode === "jenkins-source" && jenkins?.source === "managed" ? ["jenkins"] : []),
  ];
  const accountLabels = { ...uiLabels, jenkins: "Jenkins" };

  return (
    <div className="grid gap-5">
      <FormSection title="运维功能" description="运维后端能力和可视化界面分开选择，所有界面均可不部署">
        <div className="grid gap-4 md:grid-cols-2">
          <BooleanField
            label="可观测能力"
            value={operations.isDeployObservability}
            description="作为整体收集，不拆分 OTel、Prometheus、Loki 与 Tempo"
            onChange={(value) => {
              update("operations.isDeployObservability", value);
              if (!value) update("operations.isDeployGrafana", false);
            }}
          />
          <BooleanField
            label="Grafana"
            value={operations.isDeployGrafana}
            description={operations.isDeployObservability ? "提供指标、日志和链路数据的可视化查询" : "请先启用可观测能力"}
            disabled={!operations.isDeployObservability}
            onChange={(value) => update("operations.isDeployGrafana", value)}
          />
          <BooleanField label="APISIX Dashboard" value={operations.isDeployApisixDashboard} onChange={(v) => update("operations.isDeployApisixDashboard", v)} />
          <BooleanField label="Kibana" value={operations.isDeployKibana} onChange={(v) => update("operations.isDeployKibana", v)} />
          <BooleanField label="Kafka UI" value={operations.isDeployKafkaUi} onChange={(v) => update("operations.isDeployKafkaUi", v)} />
        </div>
      </FormSection>

      {selectedInterfaces.length ? (
        <FormSection title="运维界面访问方式">
          <div className="grid gap-6">
            {selectedInterfaces.map((name, index) => {
              const access = operations.interfaceAccess?.[name] ?? {};
              return (
                <div key={name} className="grid gap-4">
                  {index ? <Separator /> : null}
                  <h3 className="font-semibold">{uiLabels[name]}</h3>
                  <RadioField
                    label="访问范围"
                    value={access.scope ?? "local"}
                    options={[
                      { value: "local", label: "仅本机" },
                      { value: "lan", label: "局域网" },
                      { value: "domain", label: "域名访问" },
                    ]}
                    onChange={(value) => update(`operations.interfaceAccess.${name}.scope`, value)}
                  />
                  {access.scope === "domain" ? (
                    <TextField
                      label="访问域名"
                      value={access.domain}
                      onChange={(value) => update(`operations.interfaceAccess.${name}.domain`, value)}
                    />
                  ) : (
                    <TextField
                      label="宿主机端口"
                      value={access.port}
                      onChange={(value) => update(`operations.interfaceAccess.${name}.port`, value)}
                    />
                  )}
                </div>
              );
            })}
          </div>
        </FormSection>
      ) : null}

      {accountTargets.length ? (
        <FormSection title="运维界面账号" description="该策略覆盖本次选择的可视化界面以及源码部署时的本地 Jenkins">
          <RadioField
            label="账号策略"
            value={operations.credentialPolicy?.mode}
            orientation="vertical"
            options={[
              { value: "auto-gen", label: "自动生成默认用户名和随机密码" },
              { value: "unified", label: "使用统一账号和密码" },
              { value: "manual", label: "现在为各界面分别设置" },
            ]}
            onChange={(value) => update(
              "operations.credentialPolicy",
              value === "auto-gen"
                ? { mode: "auto-gen" }
                : value === "unified"
                  ? { mode: "unified", username: "admin", password: "" }
                  : { mode: "manual", credentials: {} },
            )}
          />
          {operations.credentialPolicy?.mode === "unified" ? (
            <ConditionalPanel>
              <TextField label="统一管理员用户名" value={operations.credentialPolicy.username} onChange={(v) => update("operations.credentialPolicy.username", v)} />
              <TextField label="统一管理员密码" type="password" value={operations.credentialPolicy.password} onChange={(v) => update("operations.credentialPolicy.password", v)} />
            </ConditionalPanel>
          ) : null}
          {operations.credentialPolicy?.mode === "manual" ? (
            <ConditionalPanel>
              {accountTargets.map((name) => (
                <div key={name} className="grid gap-3 rounded-lg border border-default p-4">
                  <h3 className="font-medium">{accountLabels[name as keyof typeof accountLabels]}</h3>
                  <TextField
                    label="管理员用户名"
                    value={operations.credentialPolicy.credentials?.[name]?.username}
                    onChange={(v) => update(`operations.credentialPolicy.credentials.${name}.username`, v)}
                  />
                  <TextField
                    label="管理员密码"
                    type="password"
                    value={operations.credentialPolicy.credentials?.[name]?.password}
                    onChange={(v) => update(`operations.credentialPolicy.credentials.${name}.password`, v)}
                  />
                </div>
              ))}
            </ConditionalPanel>
          ) : null}
        </FormSection>
      ) : null}
    </div>
  );
}
