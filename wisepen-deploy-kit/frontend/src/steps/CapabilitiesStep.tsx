import { useSetup } from "../state/SetupContext";
import { defaultJenkins } from "../types/setup";
import {
  BooleanField,
  ConditionalPanel,
  FormSection,
  NumberField,
  RadioField,
  SelectField,
  TextField,
} from "../components/FormControls";

export function CapabilitiesStep() {
  const { document, update } = useSetup();
  const { deployment, capabilities } = document!.answers;
  const processor = capabilities.documentProcessor ?? {};
  const mineru = capabilities.mineru ?? {};

  return (
    <div className="grid gap-5">
      <FormSection title="WisePen 制品来源">
        <RadioField
          label="部署方式"
          value={deployment.artifactMode}
          orientation="horizontal"
          options={[
            {
              value: "official-images",
              label: "使用 WisePen 成品镜像",
              description: "直接拉取 WisePen 官方成品镜像，部署更快且不需要 Jenkins",
            },
            {
              value: "jenkins-source",
              label: "通过 Jenkins 从源码构建并部署",
              description: "由内置流水线构建并持续部署，适合需要源码定制或持续更新的环境",
            },
          ]}
          onChange={(value) => {
            update("deployment.artifactMode", value);
            update("jenkins", value === "jenkins-source" ? structuredClone(defaultJenkins) : null);
          }}
        />
      </FormSection>

      <FormSection title="业务能力" description="请选择本次部署需要启用的 WisePen 扩展能力">
        <div className="grid gap-4 md:grid-cols-2">
          <BooleanField
            label="文档 API"
            value={capabilities.isDeployDocsService}
            description="提供 API 文档站点，仅开发和接口调试场景需要"
            onChange={(v) => update("capabilities.isDeployDocsService", v)}
          />
          <BooleanField label="文档处理" value={capabilities.isDeployDocumentService} onChange={(v) => update("capabilities.isDeployDocumentService", v)} />
          <BooleanField label="笔记" value={capabilities.isDeployNoteService} onChange={(v) => update("capabilities.isDeployNoteService", v)} />
          <BooleanField label="AI 资源" value={capabilities.isDeployAiAssetService} onChange={(v) => update("capabilities.isDeployAiAssetService", v)} />
          <BooleanField label="代码沙箱" value={capabilities.isDeploySandboxService} onChange={(v) => update("capabilities.isDeploySandboxService", v)} />
          <BooleanField
            label="高校扩展包"
            value={capabilities.isDeployCampusExtensionService}
            description="启用所选高校的专属扩展服务"
            onChange={(v) => update("capabilities.isDeployCampusExtensionService", v)}
          />
        </div>
        {capabilities.isDeployCampusExtensionService ? (
          <ConditionalPanel>
            <SelectField
              label="高校扩展服务"
              value={capabilities.campusExtensionName}
              options={[{ key: "fudan-extension-service", label: "复旦大学" }]}
              description="当前仅支持复旦大学，后续可扩展其他高校"
              onChange={(value) => update("capabilities.campusExtensionName", value)}
            />
          </ConditionalPanel>
        ) : null}
      </FormSection>

      {capabilities.isDeployDocumentService ? (
        <FormSection title="文档处理方式" description="启用文档处理时必须选择一种业务中间件">
          <RadioField
            label="文档转换方案"
            value={processor.type}
            options={[
              { value: "onlyoffice", label: "OnlyOffice", description: "支持文档转换和在线编辑" },
              { value: "jodconverter", label: "JODConverter", description: "仅支持文档转换，文档编辑功能将不可用" },
            ]}
            onChange={(value) => update("capabilities.documentProcessor.type", value)}
          />
          {processor.type === "onlyoffice" ? (
            <ConditionalPanel>
              <div className="md:col-span-2">
                <RadioField
                  label="JWT Secret"
                  value={processor.jwtSecret?.mode}
                  options={[
                    { value: "auto-gen", label: "自动生成" },
                    { value: "manual", label: "现在指定" },
                  ]}
                  onChange={(value) => update(
                    "capabilities.documentProcessor.jwtSecret",
                    value === "auto-gen" ? { mode: "auto-gen" } : { mode: "manual", value: "" },
                  )}
                />
              </div>
              <div className="md:col-span-2">
                {processor.jwtSecret?.mode === "manual" ? (
                  <TextField
                    label="JWT Secret"
                    type="password"
                    value={processor.jwtSecret?.value}
                    onChange={(value) => update("capabilities.documentProcessor.jwtSecret.value", value)}
                  />
                ) : (
                  <p className="text-sm text-muted">部署配置生成阶段将创建随机 JWT Secret</p>
                )}
              </div>
            </ConditionalPanel>
          ) : (
            <ConditionalPanel>
              <div className="md:col-span-2">
                <NumberField
                  label="最大上传文件大小（MB）"
                  value={processor.maxFileSizeMb}
                  min={1}
                  onChange={(value) => update("capabilities.documentProcessor.maxFileSizeMb", value)}
                />
              </div>
              <div className="md:col-span-2">
                <BooleanField
                  label="使用自定义字体目录"
                  value={processor.isUseCustomFonts}
                  onChange={(value) => update("capabilities.documentProcessor.isUseCustomFonts", value)}
                />
              </div>
              {processor.isUseCustomFonts ? (
                <div className="md:col-span-2">
                  <TextField
                    label="自定义字体目录"
                    value={processor.customFontsDirectory}
                    onChange={(value) => update("capabilities.documentProcessor.customFontsDirectory", value)}
                  />
                </div>
              ) : null}
            </ConditionalPanel>
          )}
        </FormSection>
      ) : null}

      <FormSection
        title="MinerU"
        description="用于增强 Markdown 和复杂文档的结构化解析，改善内容切分与检索质量；不部署时仍可使用基础解析，但 Markdown 解析效果会下降并影响检索准确性"
      >
        <RadioField
          label="运行模式"
          value={mineru.mode}
          options={[
            { value: "none", label: "不使用" },
            { value: "cpu", label: "CPU" },
            { value: "gpu", label: "GPU" },
          ]}
          onChange={(value) => update("capabilities.mineru.mode", value)}
        />
        {mineru.mode !== "none" ? (
          <ConditionalPanel>
            <NumberField
              label="最大并发请求数"
              value={mineru.maxConcurrency}
              min={1}
              onChange={(value) => update("capabilities.mineru.maxConcurrency", value)}
            />
            <TextField
              label="模型目录"
              value={mineru.modelDirectory}
              onChange={(value) => update("capabilities.mineru.modelDirectory", value)}
            />
            {mineru.mode === "gpu" ? (
              <>
                <TextField
                  label="GPU 设备编号"
                  value={mineru.gpuDevice}
                  onChange={(value) => update("capabilities.mineru.gpuDevice", value)}
                />
                <NumberField
                  label="GPU 显存使用比例"
                  value={mineru.gpuMemoryUtilization}
                  min={0.1}
                  max={1}
                  step={0.1}
                  onChange={(value) => update("capabilities.mineru.gpuMemoryUtilization", value)}
                />
              </>
            ) : null}
          </ConditionalPanel>
        ) : null}
      </FormSection>
    </div>
  );
}
