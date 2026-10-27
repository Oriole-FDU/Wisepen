import { useSetup } from "../state/SetupContext";
import {
  BooleanField,
  ConditionalPanel,
  FormSection,
  Notice,
  NumberField,
  RadioField,
  TextAreaField,
  TextField,
} from "../components/FormControls";

const emptyFrontendOss = {
  accessKeyId: "",
  accessKeySecret: "",
  endpoint: "",
  bucket: "",
  cleanPolicy: "keep-previous-release",
};

const emptyDrawioOss = {
  accessKeyId: "",
  accessKeySecret: "",
  endpoint: "",
  bucket: "",
};

function OssCredentials({
  value,
  path,
  update,
}: {
  value: Record<string, any>;
  path: "frontendOss" | "drawioOss";
  update: (path: string, value: unknown) => void;
}) {
  return (
    <ConditionalPanel>
      <TextField
        label="阿里云 AccessKey ID"
        value={value.accessKeyId}
        onChange={(next) => update(`${path}.accessKeyId`, next)}
      />
      <TextField
        label="阿里云 AccessKey Secret"
        type="password"
        value={value.accessKeySecret}
        onChange={(next) => update(`${path}.accessKeySecret`, next)}
      />
    </ConditionalPanel>
  );
}

export function AccessStep() {
  const { document, update } = useSetup();
  const { access, frontendOss, drawioOss, capabilities } = document!.answers;
  const isPublic = access.scope === "public";
  const domainSuffix = access.siteAddress ? `.${access.siteAddress}` : ".主站域名";

  return (
    <div className="grid gap-5">
      <FormSection
        title="访问基准"
        description="先确定主站域名或部署设备 IP，后续服务入口将复用这个基准，不再重复填写完整地址"
      >
        <RadioField
          label="访问范围"
          value={access.scope}
          options={[
            { value: "lan", label: "仅局域网", description: "只能填写部署设备 IP，不使用域名" },
            { value: "public", label: "公网", description: "填写主站域名，再为各服务填写子域名前缀" },
          ]}
          onChange={(value) => {
            update("access.scope", value);
            if (value === "lan") {
              update("access.frontendDeployment", "container");
              update("access.drawioDeployment", "container");
              update("access.isEnableIntranetApi", false);
              update("frontendOss", null);
              update("drawioOss", null);
              update("certificate", { mode: "external" });
            }
          }}
        />
        <TextField
          label={isPublic ? "主站域名" : "部署设备 IP"}
          value={access.siteAddress}
          placeholder={isPublic ? "wisepen.example.com" : "192.168.1.10"}
          description={isPublic ? "只填写域名，不包含协议和路径" : "仅填写 IPv4 或 IPv6 地址，不允许填写域名"}
          onChange={(value) => update("access.siteAddress", value)}
        />
      </FormSection>

      <FormSection
        title="服务端部署方式"
        description={isPublic
          ? "公网部署可额外提供校内 API，让校内流量走内网以节约公网带宽并降低访问延迟"
          : "局域网部署通过上方设备 IP 访问 API，不配置任何服务域名"}
      >
        {isPublic ? (
          <TextField
            label="API 子域名前缀"
            value={access.apiSubdomain}
            placeholder="api"
            endContent={<span className="whitespace-nowrap text-muted">{domainSuffix}</span>}
            onChange={(value) => update("access.apiSubdomain", value)}
          />
        ) : (
          <Notice>API 将通过部署设备 IP 和 APISIX 监听端口访问</Notice>
        )}
        {isPublic ? (
          <BooleanField
            label="提供校内 API"
            value={access.isEnableIntranetApi}
            description="为校内用户提供独立内网入口，减少公网出口带宽占用；仅在服务器可被校内网络访问时启用"
            onChange={(value) => update("access.isEnableIntranetApi", value)}
          />
        ) : null}
        {isPublic && access.isEnableIntranetApi ? (
          <ConditionalPanel>
            <TextField
              label="校内 API 子域名前缀"
              value={access.intranetApiSubdomain}
              placeholder="api.intranet"
              endContent={<span className="whitespace-nowrap text-muted">{domainSuffix}</span>}
              onChange={(value) => update("access.intranetApiSubdomain", value)}
            />
            <TextField
              label="校内 API 探测路径"
              value={access.intranetPingPath}
              onChange={(value) => update("access.intranetPingPath", value)}
            />
            <NumberField
              label="校内探测超时（毫秒）"
              value={access.intranetProbeTimeoutMs}
              min={100}
              onChange={(value) => update("access.intranetProbeTimeoutMs", value)}
            />
          </ConditionalPanel>
        ) : null}
        <TextAreaField
          label="额外 CORS 来源"
          value={access.corsOrigins}
          placeholder="https://admin.example.com"
          description="允许其他管理站点或前端域名调用 WisePen API，可选且每行填写一个 URL 或正则"
          onChange={(value) => update("access.corsOrigins", value)}
        />
      </FormSection>

      <FormSection
        title="WisePenView 部署方式"
        description={isPublic
          ? "选择由阿里云 OSS 或 Nginx 容器提供前端静态资源"
          : "局域网模式使用 Nginx 容器提供前端静态资源"}
      >
        <RadioField
          label="前端部署目标"
          value={isPublic ? access.frontendDeployment : "container"}
          options={isPublic ? [
            { value: "oss", label: "阿里云 OSS", description: "推荐，节约目标服务器出口带宽" },
            { value: "container", label: "Nginx 容器", description: "适合低流量或无法使用 OSS 的环境" },
          ] : [
            { value: "container", label: "Nginx 容器", description: "由部署设备提供静态资源" },
          ]}
          onChange={(value) => {
            update("access.frontendDeployment", value);
            update("frontendOss", value === "oss" ? structuredClone(emptyFrontendOss) : null);
          }}
        />
        {access.frontendDeployment === "container" || !isPublic ? (
          <ConditionalPanel>
            <NumberField
              label="宿主机端口"
              value={access.frontendPort}
              min={1}
              max={65535}
              onChange={(value) => update("access.frontendPort", value)}
            />
            <BooleanField
              label="通过 APISIX 提供前端访问"
              value={access.isEnableFrontendViaApisix}
              onChange={(value) => update("access.isEnableFrontendViaApisix", value)}
            />
          </ConditionalPanel>
        ) : (
          <div className="grid gap-4">
            <OssCredentials value={frontendOss ?? emptyFrontendOss} path="frontendOss" update={update} />
            <ConditionalPanel>
              <TextField label="前端 OSS Endpoint" value={frontendOss?.endpoint} placeholder="oss-cn-shanghai.aliyuncs.com" onChange={(v) => update("frontendOss.endpoint", v)} />
              <TextField label="前端 OSS Bucket" value={frontendOss?.bucket} onChange={(v) => update("frontendOss.bucket", v)} />
              <div className="md:col-span-2">
                <RadioField
                  label="旧版本清理策略"
                  value={frontendOss?.cleanPolicy}
                  options={[
                    { value: "keep-previous-release", label: "保留上一版本" },
                    { value: "delete-all-stale", label: "删除全部旧版本" },
                  ]}
                  onChange={(v) => update("frontendOss.cleanPolicy", v)}
                />
              </div>
            </ConditionalPanel>
          </div>
        )}
      </FormSection>

      {capabilities.isDeployDocumentService && capabilities.documentProcessor?.type === "onlyoffice" ? (
        <FormSection title="OnlyOffice 访问入口" description="WisePenView 使用这个入口在浏览器中加载文档编辑器">
          {isPublic ? (
            <TextField
              label="OnlyOffice 子域名前缀"
              value={access.onlyofficeSubdomain}
              placeholder="office"
              endContent={<span className="whitespace-nowrap text-muted">{domainSuffix}</span>}
              onChange={(value) => update("access.onlyofficeSubdomain", value)}
            />
          ) : (
            <NumberField
              label="OnlyOffice 宿主机端口"
              value={access.onlyofficePort}
              min={1}
              max={65535}
              onChange={(value) => update("access.onlyofficePort", value)}
            />
          )}
        </FormSection>
      ) : null}

      <FormSection title="DrawIO" description={isPublic
        ? "选择由阿里云 OSS 或 Nginx 容器提供 DrawIO 静态资源"
        : "局域网模式使用 Nginx 容器提供 DrawIO 静态资源"}
      >
        <BooleanField
          label="部署 DrawIO"
          value={access.isDeployDrawio}
          onChange={(value) => {
            update("access.isDeployDrawio", value);
            if (!value) update("drawioOss", null);
          }}
        />
        {access.isDeployDrawio ? (
          <div className="grid gap-4">
            <RadioField
              label="DrawIO 部署方式"
              value={isPublic ? access.drawioDeployment : "container"}
              options={isPublic ? [
                { value: "oss", label: "阿里云 OSS", description: "推荐，节约目标服务器出口带宽" },
                { value: "container", label: "Nginx 容器", description: "适合低流量或无法使用 OSS 的环境" },
              ] : [
                { value: "container", label: "Nginx 容器", description: "由部署设备提供静态资源" },
              ]}
              onChange={(value) => {
                update("access.drawioDeployment", value);
                update("drawioOss", value === "oss" ? structuredClone(emptyDrawioOss) : null);
              }}
            />
            {isPublic ? (
              <TextField
                label="DrawIO 子域名前缀"
                value={access.drawioSubdomain}
                placeholder="drawio"
                endContent={<span className="whitespace-nowrap text-muted">{domainSuffix}</span>}
                onChange={(value) => update("access.drawioSubdomain", value)}
              />
            ) : null}
            {isPublic && access.drawioDeployment === "oss" ? (
              <>
                <OssCredentials value={drawioOss ?? emptyDrawioOss} path="drawioOss" update={update} />
                <ConditionalPanel>
                  <TextField label="DrawIO OSS Endpoint" value={drawioOss?.endpoint} placeholder="oss-cn-shanghai.aliyuncs.com" onChange={(v) => update("drawioOss.endpoint", v)} />
                  <TextField label="DrawIO OSS Bucket" value={drawioOss?.bucket} onChange={(v) => update("drawioOss.bucket", v)} />
                </ConditionalPanel>
              </>
            ) : (
              <ConditionalPanel>
                <NumberField
                  label="DrawIO 宿主机端口"
                  value={access.drawioPort}
                  min={1}
                  max={65535}
                  onChange={(value) => update("access.drawioPort", value)}
                />
              </ConditionalPanel>
            )}
          </div>
        ) : null}
      </FormSection>
    </div>
  );
}
