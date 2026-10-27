import { useSetup } from "../state/SetupContext";
import {
  BooleanField,
  ConditionalPanel,
  FormSection,
  SelectField,
  TextAreaField,
  TextField,
} from "../components/FormControls";

export function BasicStep() {
  const { document, update } = useSetup();
  const basic = document!.answers.basic;

  return (
    <div className="grid gap-5">
      <FormSection
        title="部署基本信息"
        description="这里只收集用户输入，不会在当前阶段生成目录、密码或部署配置"
      >
        <div className="grid gap-4 md:grid-cols-2">
          <TextField
            label="部署名称"
            value={basic.deploymentName}
            placeholder="wisepen-production"
            required
            onChange={(value) => update("basic.deploymentName", value)}
          />
          <SelectField
            label="环境类型"
            value={basic.environment}
            options={[
              { key: "development", label: "开发环境" },
              { key: "testing", label: "测试环境" },
              { key: "production", label: "生产环境" },
            ]}
            onChange={(value) => update("basic.environment", value)}
          />
          <TextField
            label="时区"
            value={basic.timezone}
            placeholder="Asia/Shanghai"
            onChange={(value) => update("basic.timezone", value)}
          />
          <TextField
            label="宿主机持久化根目录"
            value={basic.persistenceRoot}
            placeholder="/opt/wisepen"
            description="本阶段仅保存根目录，不派生任何组件子目录"
            onChange={(value) => update("basic.persistenceRoot", value)}
          />
        </div>
      </FormSection>

      <FormSection title="网络代理" description="如果访问公网不需要代理，请保持关闭">
        <BooleanField
          label="使用 HTTP/HTTPS 代理"
          value={basic.isUseProxy}
          onChange={(value) => update("basic.isUseProxy", value)}
        />
        {basic.isUseProxy ? (
          <ConditionalPanel>
            <TextField
              label="HTTP Proxy"
              value={basic.httpProxy}
              placeholder="http://proxy.example.com:8080"
              onChange={(value) => update("basic.httpProxy", value)}
            />
            <TextField
              label="HTTPS Proxy"
              value={basic.httpsProxy}
              placeholder="http://proxy.example.com:8080"
              onChange={(value) => update("basic.httpsProxy", value)}
            />
            <div className="md:col-span-2">
              <TextAreaField
                label="No Proxy 补充项"
                value={basic.noProxy}
                placeholder="example.internal,10.0.0.0/8"
                description="使用逗号或换行分隔"
                onChange={(value) => update("basic.noProxy", value)}
              />
            </div>
          </ConditionalPanel>
        ) : null}
      </FormSection>
    </div>
  );
}
