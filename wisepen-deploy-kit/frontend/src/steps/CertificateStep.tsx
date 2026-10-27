import { Surface } from "@heroui/react";
import { useSetup } from "../state/SetupContext";
import { defaultManagedCertificate } from "../types/setup";
import {
  BooleanField,
  FormSection,
  Notice,
  RadioField,
  TextAreaField,
  TextField,
} from "../components/FormControls";

export function CertificateStep() {
  const { document, update } = useSetup();
  const { access, certificate } = document!.answers;
  const drawioUsesOss = access.isDeployDrawio && access.drawioDeployment === "oss";

  return (
    <div className="grid gap-5">
      <FormSection title="主站访问协议">
        <RadioField
          label="协议"
          value={access.siteProtocol}
          options={[
            { value: "http", label: "HTTP" },
            { value: "https", label: "HTTPS" },
          ]}
          onChange={(value) => update("access.siteProtocol", value)}
        />
      </FormSection>

      {access.siteProtocol === "https" ? (
        <FormSection title="HTTPS 证书管理">
          <RadioField
            label="证书管理方式"
            value={access.scope === "lan" ? "external" : certificate.mode}
            orientation="vertical"
            options={access.scope === "lan" ? [
              { value: "external", label: "由外部系统处理", description: "ACME 公共 CA 不为局域网 IP 签发证书，需要自行提供受信任证书" },
            ] : [
              { value: "wisepen-cert-manager", label: "WisePen cert-manager", description: "使用 AliDNS 完成域名验证，并向 APISIX 和所选 OSS 站点分发证书" },
              { value: "external", label: "由外部系统处理" },
            ]}
            onChange={(value) => update(
              "certificate",
              value === "wisepen-cert-manager"
                ? structuredClone(defaultManagedCertificate)
                : { mode: "external" },
            )}
          />
          {certificate.mode === "external" ? (
            <Notice status="warning" title="需要自行维护证书">
              选择外部系统后，WisePenDeploy 不负责证书申请、续期或分发，请确保 APISIX、前端 OSS、DrawIO OSS
              及其他 HTTPS 入口均已正确配置有效证书，否则可能出现浏览器安全警告、API 请求失败或站点无法访问
            </Notice>
          ) : null}
        </FormSection>
      ) : (
        <Notice status="warning" title="HTTP 不提供传输加密">
          登录凭据和业务数据不会获得传输层加密，仅建议在受信任的隔离网络中使用
        </Notice>
      )}

      {access.siteProtocol === "https" && certificate.mode === "wisepen-cert-manager" ? (
        <>
          <FormSection title="阿里云凭据" description="该凭据仅用于 cert-manager 执行 AliDNS DNS-01 验证，不与前端 OSS 或 DrawIO OSS 共用">
            <div className="grid gap-4 md:grid-cols-2">
              <TextField label="AccessKey ID" value={certificate.accessKeyId} onChange={(v) => update("certificate.accessKeyId", v)} />
              <TextField label="AccessKey Secret" type="password" value={certificate.accessKeySecret} onChange={(v) => update("certificate.accessKeySecret", v)} />
            </div>
          </FormSection>

          <FormSection
            title="ACME 与证书分发"
            description="ACME 是自动申请和续期证书的标准协议，无需预先注册账号；cert-manager 会使用填写的邮箱向所选 CA 自动注册，邮箱用于接收证书到期和账户安全通知"
          >
            <Notice>
              选择 ZeroSSL 或 Let’s Encrypt 后填写可接收邮件的地址即可，注册和后续续期均由 cert-manager 自动完成
            </Notice>
            <div className="grid gap-4 md:grid-cols-2">
              <RadioField
              label="ACME CA"
              value={certificate.acmeCa}
              options={[
                { value: "zerossl", label: "ZeroSSL" },
                { value: "letsencrypt", label: "Let’s Encrypt" },
              ]}
              onChange={(v) => update("certificate.acmeCa", v)}
            />
              <TextField label="ACME 注册邮箱" type="email" value={certificate.acmeEmail} onChange={(v) => update("certificate.acmeEmail", v)} />
              <RadioField
              label="证书状态来源"
              value={certificate.stateSource}
              options={[
                { value: "new", label: "全新签发" },
                { value: "existing", label: "使用已有 acme-data" },
              ]}
              onChange={(v) => update("certificate.stateSource", v)}
            />
              {certificate.stateSource === "existing" ? (
                <TextField label="已有 acme-data 路径" value={certificate.acmeDataPath} onChange={(v) => update("certificate.acmeDataPath", v)} />
              ) : null}
              <Surface className="rounded-2xl border border-default p-4 text-sm" variant="secondary">
                <span className="text-muted">主证书域名</span>
                <strong className="mt-1 block text-foreground">{access.siteAddress || "请先在访问与前端中填写主站域名"}</strong>
              </Surface>
              <BooleanField label="申请通配符证书" value={certificate.isApplyWildcardCertificate} onChange={(v) => update("certificate.isApplyWildcardCertificate", v)} />
            </div>
            <TextAreaField label="额外证书域名" value={certificate.extraDomains} description="每行一个域名" onChange={(v) => update("certificate.extraDomains", v)} />
            <div className="grid gap-3 md:grid-cols-2">
            <BooleanField
              label="向 APISIX 分发"
              value={certificate.isDistributeToApisix}
              description="关闭后网关证书不会自动安装或续期，必须由外部系统维护 APISIX HTTPS 证书"
              onChange={(v) => update("certificate.isDistributeToApisix", v)}
            />
            {access.frontendDeployment === "oss" ? (
              <BooleanField
                label="向主前端 OSS 分发"
                value={certificate.isDistributeToFrontendOss}
                description="关闭后主站 OSS CNAME 证书不会自动更新，必须由外部系统维护"
                onChange={(v) => update("certificate.isDistributeToFrontendOss", v)}
              />
            ) : null}
            {drawioUsesOss ? (
              <BooleanField
                label="向 DrawIO OSS 分发"
                value={certificate.isDistributeToDrawioOss}
                description="关闭后 DrawIO OSS CNAME 证书不会自动更新，必须由外部系统维护"
                onChange={(v) => update("certificate.isDistributeToDrawioOss", v)}
              />
            ) : null}
            </div>
          </FormSection>
        </>
      ) : null}
    </div>
  );
}
