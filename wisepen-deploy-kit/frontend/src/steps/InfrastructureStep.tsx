import { Fieldset, Tabs } from "@heroui/react";
import { useSetup } from "../state/SetupContext";
import { INFRASTRUCTURE_COMPONENTS } from "../types/setup";
import {
  BooleanField,
  ConditionalPanel,
  FormSection,
  Notice,
  RadioField,
  SelectField,
  TextAreaField,
  TextField,
} from "../components/FormControls";

const labels: Record<string, string> = {
  mysql: "MySQL",
  redis: "Redis",
  mongodb: "MongoDB",
  nacos: "Nacos",
  etcd: "etcd",
  apisix: "APISIX",
  elasticsearch: "Elasticsearch",
  kafka: "Kafka",
  qdrant: "Qdrant",
};

const componentDescriptions: Record<string, string> = {
  mysql: "WisePen 事务数据库，缺失时无法启动",
  redis: "WisePen 分布式缓存，缺失时无法启动",
  mongodb: "WisePen 非结构化数据库，缺失时无法启动",
  nacos: "WisePen 微服务注册发现和启动配置入口",
  etcd: "存储 APISIX 路由、插件和网关运行配置",
  apisix: "作为 WisePen 的统一入口，负责路由、鉴权、跨域和 HTTPS 接入",
  elasticsearch: "WisePen 搜索引擎数据库，提供全文搜索和内容检索索引能力",
  kafka: "WisePen 服务间异步事件、任务分发和状态通知的核心总线，缺失时无法启动",
  qdrant: "保存向量索引，为语义检索和 AI 召回提供支持",
};

const fieldRows: Record<string, string[][]> = {
  mysql: [["host", "port"], ["username", "password"]],
  redis: [["host", "port"], ["username", "password"]],
  mongodb: [["host", "port"], ["username", "password"], ["authDatabase"]],
  nacos: [["address"], ["username", "password"]],
  etcd: [["endpoints"], ["username", "password"]],
  apisix: [["adminApiUrl"], ["adminKey"], ["httpGatewayUrl", "httpsGatewayUrl"]],
  elasticsearch: [["url"], ["username", "password"]],
  kafka: [["bootstrapServers"], ["username", "password"]],
  qdrant: [["url"], ["apiKey"]],
};

type InfrastructureComponent = (typeof INFRASTRUCTURE_COMPONENTS)[number];

const secretFields: Array<{
  key: string;
  label: string;
  component: InfrastructureComponent;
  type?: "password";
}> = [
  { key: "password", label: "MySQL Root 密码", component: "mysql", type: "password" },
  { key: "password", label: "Redis 密码", component: "redis", type: "password" },
  { key: "username", label: "MongoDB Root 用户名", component: "mongodb" },
  { key: "password", label: "MongoDB Root 密码", component: "mongodb", type: "password" },
  { key: "username", label: "Nacos 管理用户名", component: "nacos" },
  { key: "password", label: "Nacos 管理密码", component: "nacos", type: "password" },
  { key: "authToken", label: "Nacos 鉴权 Token", component: "nacos", type: "password" },
  { key: "identityKey", label: "Nacos Identity Key", component: "nacos", type: "password" },
  { key: "identityValue", label: "Nacos Identity Value", component: "nacos", type: "password" },
  { key: "password", label: "etcd Root 密码", component: "etcd", type: "password" },
  { key: "adminKey", label: "APISIX Admin Key", component: "apisix", type: "password" },
  { key: "password", label: "Elasticsearch elastic 密码", component: "elasticsearch", type: "password" },
  { key: "apiKey", label: "Qdrant API Key", component: "qdrant", type: "password" },
];

const fieldDefinitions: Record<
  string,
  Array<{ key: string; label: string; type?: "password" | "textarea"; placeholder?: string }>
> = {
  mysql: [
    { key: "host", label: "地址" },
    { key: "port", label: "端口", placeholder: "3306" },
    { key: "username", label: "管理用户名" },
    { key: "password", label: "管理密码", type: "password" },
  ],
  redis: [
    { key: "host", label: "地址" },
    { key: "port", label: "端口", placeholder: "6379" },
    { key: "username", label: "用户名（可选）" },
    { key: "password", label: "密码", type: "password" },
  ],
  mongodb: [
    { key: "host", label: "地址" },
    { key: "port", label: "端口", placeholder: "27017" },
    { key: "username", label: "用户名" },
    { key: "password", label: "密码", type: "password" },
    { key: "authDatabase", label: "Authentication Database", placeholder: "admin" },
  ],
  nacos: [
    { key: "address", label: "Nacos 地址", placeholder: "https://nacos.example.com" },
    { key: "username", label: "用户名" },
    { key: "password", label: "密码", type: "password" },
  ],
  etcd: [
    { key: "endpoints", label: "Endpoint 列表", type: "textarea", placeholder: "https://etcd-1:2379\nhttps://etcd-2:2379" },
    { key: "username", label: "用户名" },
    { key: "password", label: "密码", type: "password" },
  ],
  apisix: [
    { key: "adminApiUrl", label: "Admin API 地址", placeholder: "http://apisix.example.com:9180" },
    { key: "adminKey", label: "Admin Key", type: "password" },
    { key: "httpGatewayUrl", label: "HTTP 网关地址" },
    { key: "httpsGatewayUrl", label: "HTTPS 网关地址（可选）" },
  ],
  elasticsearch: [
    { key: "url", label: "Elasticsearch 地址", placeholder: "https://elasticsearch.example.com:9200" },
    { key: "username", label: "用户名" },
    { key: "password", label: "密码", type: "password" },
  ],
  kafka: [
    { key: "bootstrapServers", label: "Bootstrap Servers", placeholder: "kafka-1:9092,kafka-2:9092" },
    { key: "username", label: "用户名（使用认证时）" },
    { key: "password", label: "密码（使用认证时）", type: "password" },
  ],
  qdrant: [
    { key: "url", label: "Qdrant URL" },
    { key: "apiKey", label: "API Key", type: "password" },
  ],
};

function ExternalFields({ component }: { component: InfrastructureComponent }) {
  const { document, update } = useSetup();
  const external = document!.answers.infrastructure[component]?.external ?? {};
  const prefix = `infrastructure.${component}.external`;

  return (
    <ConditionalPanel>
      {fieldRows[component].map((row) => (
        <div
          key={row.join("-")}
          className={`grid gap-4 md:col-span-2 ${row.length > 1 ? "md:grid-cols-2" : "grid-cols-1"}`}
        >
          {row.map((fieldKey) => {
            const field = fieldDefinitions[component].find((candidate) => candidate.key === fieldKey)!;
            return field.type === "textarea" ? (
              <TextAreaField
                key={field.key}
                label={field.label}
                value={external[field.key]}
                placeholder={field.placeholder}
                onChange={(value) => update(`${prefix}.${field.key}`, value)}
              />
            ) : (
              <TextField
                key={field.key}
                label={field.label}
                value={external[field.key]}
                type={field.type}
                placeholder={field.placeholder}
                onChange={(value) => update(`${prefix}.${field.key}`, value)}
              />
            );
          })}
        </div>
      ))}

      {component === "kafka" ? (
        <div className="md:col-span-2">
          <SelectField
            label="Security Protocol"
            value={external.securityProtocol}
            options={[
              { key: "PLAINTEXT", label: "PLAINTEXT" },
              { key: "SSL", label: "SSL" },
              { key: "SASL_PLAINTEXT", label: "SASL_PLAINTEXT" },
              { key: "SASL_SSL", label: "SASL_SSL" },
            ]}
            onChange={(value) => update(`${prefix}.securityProtocol`, value)}
          />
        </div>
      ) : null}

      {component === "mysql" ? (
        <div className="grid gap-4 md:col-span-2">
          <BooleanField
            label="允许创建数据库"
            value={external.isNeedCreateDatabase}
            description="关闭后 WisePenDeploy 不会建库，仅在管理员已提前创建全部所需数据库时关闭"
            onChange={(v) => update(`${prefix}.isNeedCreateDatabase`, v)}
          />
          <BooleanField
            label="允许创建用户"
            value={external.isNeedCreateUser}
            description="关闭后 WisePenDeploy 不会创建应用账号，仅在管理员已提前创建并授权所需账号时关闭"
            onChange={(v) => update(`${prefix}.isNeedCreateUser`, v)}
          />
          <BooleanField
            label="允许导入初始化 Schema"
            value={external.isNeedImportSchema}
            description="关闭后不会导入表结构和基础数据，仅在数据库已完成兼容版本初始化或从已有部署迁移时关闭"
            onChange={(v) => update(`${prefix}.isNeedImportSchema`, v)}
          />
        </div>
      ) : null}
      {component === "nacos" ? (
        <div className="md:col-span-2">
          <BooleanField
            label="允许执行基础初始化"
            value={external.isNeedInitializeNacos}
            description="关闭后不会写入 WisePen 启动所需的基础命名空间和系统配置，仅在管理员已完成等价初始化时关闭"
            onChange={(v) => update(`${prefix}.isNeedInitializeNacos`, v)}
          />
        </div>
      ) : null}
      {component === "apisix" ? (
        <div className="md:col-span-2">
          <BooleanField
            label="允许写入路由和插件配置"
            value={external.isNeedConfigureApisixRoutesAndPlugins}
            description="关闭后无法注册 WisePen 路由和网关插件，仅在外部系统已维护完整等价配置时关闭"
            onChange={(v) => update(`${prefix}.isNeedConfigureApisixRoutesAndPlugins`, v)}
          />
        </div>
      ) : null}

      {component !== "apisix" && component !== "kafka" ? (
        <div className="grid gap-4 rounded-xl border border-default p-4 md:col-span-2">
          <RadioField
            label="连接加密"
            value={external.isEnableTls ? "tls" : "plain"}
            options={[
              { value: "plain", label: "不使用 TLS" },
              { value: "tls", label: "使用 TLS" },
            ]}
            onChange={(value) => update(`${prefix}.isEnableTls`, value === "tls")}
          />
          {external.isEnableTls ? (
            <TextAreaField
              label="CA 证书"
              value={external.caCertificate}
              placeholder="-----BEGIN CERTIFICATE-----"
              description="粘贴用于验证已有实例服务端证书的 CA 证书"
              onChange={(value) => update(`${prefix}.caCertificate`, value)}
            />
          ) : (
            <p className="text-sm text-warning">连接不会加密，仅应在可信隔离网络中使用</p>
          )}
        </div>
      ) : null}
    </ConditionalPanel>
  );
}

export function InfrastructureStep() {
  const { document, update } = useSetup();
  const infrastructure = document!.answers.infrastructure;

  return (
    <div className="grid gap-5">
      <FormSection
        title="必需基础设施"
        description="每项能力必须存在，请选择由 WisePenDeploy 部署或提供已有实例的连接信息"
      >
        <Tabs defaultSelectedKey="mysql">
          <Tabs.ListContainer className="w-full overflow-x-auto border-b border-default">
            <Tabs.List aria-label="基础设施组件">
              {INFRASTRUCTURE_COMPONENTS.map((component) => (
                <Tabs.Tab key={component} id={component}>
                  {labels[component]}
                  <Tabs.Indicator />
                </Tabs.Tab>
              ))}
            </Tabs.List>
          </Tabs.ListContainer>
          {INFRASTRUCTURE_COMPONENTS.map((component) => {
            const choice = infrastructure[component];
            return (
              <Tabs.Panel key={component} id={component} className="pt-5">
                <div className="grid gap-5 px-1 pb-1">
                  <div>
                    <h3 className="text-lg font-semibold">{labels[component]}</h3>
                    <p className="mt-1 text-sm text-muted">{componentDescriptions[component]}</p>
                  </div>
                  <RadioField
                    label="组件来源"
                    value={choice.mode}
                    options={[
                      { value: "managed", label: "由 WisePenDeploy 部署" },
                      { value: "external", label: "使用已有实例" },
                    ]}
                    onChange={(value) => update(`infrastructure.${component}.mode`, value)}
                  />
                  {choice.mode === "managed" ? (
                    <Notice status="success">
                      该组件将使用全局持久化根目录及下方选择的基础设施凭据策略
                    </Notice>
                  ) : (
                    <ExternalFields component={component} />
                  )}
                </div>
              </Tabs.Panel>
            );
          })}
        </Tabs>
      </FormSection>

      <FormSection
        title="基础设施密码和密钥"
        description="配置由 WisePenDeploy 部署的基础设施所使用的管理员账号、密码和服务密钥"
      >
        <RadioField
          label="收集策略"
          value={infrastructure.credentialPolicy.mode}
          options={[
            { value: "auto-gen", label: "自动生成各组件默认用户名和随机密码" },
            { value: "unified", label: "使用统一账号和密码" },
            { value: "manual", label: "现在逐项指定" },
          ]}
          onChange={(value) => update(
            "infrastructure.credentialPolicy",
            value === "auto-gen"
              ? { mode: "auto-gen" }
              : value === "unified"
                ? { mode: "unified", username: "admin", password: "" }
                : { mode: "manual", credentials: {} },
          )}
        />
        {infrastructure.credentialPolicy.mode === "unified" ? (
          <ConditionalPanel>
            <TextField
              label="统一用户名"
              value={infrastructure.credentialPolicy.username}
              onChange={(value) => update("infrastructure.credentialPolicy.username", value)}
            />
            <TextField
              label="统一密码"
              type="password"
              value={infrastructure.credentialPolicy.password}
              description="将用于本次由 WisePenDeploy 部署且支持账号认证的基础设施"
              onChange={(value) => update("infrastructure.credentialPolicy.password", value)}
            />
          </ConditionalPanel>
        ) : null}
        {infrastructure.credentialPolicy.mode === "manual" ? (
          <div className="grid gap-4 md:grid-cols-2">
            {INFRASTRUCTURE_COMPONENTS.map((component) => {
              const fields = secretFields.filter((field) => field.component === component);
              if (infrastructure[component].mode !== "managed" || fields.length === 0) return null;

              return (
                <Fieldset
                  key={component}
                  className={`rounded-2xl border border-default p-4 ${fields.length > 1 ? "md:col-span-2" : ""}`}
                >
                  <Fieldset.Legend>{labels[component]}</Fieldset.Legend>
                  <Fieldset.Group className={`grid gap-4 ${fields.length > 1 ? "md:grid-cols-2" : ""}`}>
                    {fields.map((field) => (
                      <TextField
                        key={field.key}
                        label={field.label}
                        type={field.type}
                        value={infrastructure.credentialPolicy.credentials?.[component]?.[field.key]}
                        onChange={(value) => update(
                          `infrastructure.credentialPolicy.credentials.${component}.${field.key}`,
                          value,
                        )}
                      />
                    ))}
                  </Fieldset.Group>
                </Fieldset>
              );
            })}
          </div>
        ) : null}
      </FormSection>
    </div>
  );
}
