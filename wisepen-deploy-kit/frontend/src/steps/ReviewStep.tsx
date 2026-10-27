import { Button, Chip, Surface } from "@heroui/react";
import { useState } from "react";
import { ApiError } from "../api/setup";
import { ErrorSummary } from "../components/ErrorSummary";
import { FormSection, Notice } from "../components/FormControls";
import { useSetup } from "../state/SetupContext";
import { INFRASTRUCTURE_COMPONENTS, type ValidationIssue } from "../types/setup";

const artifactLabels: Record<string, string> = {
  "official-images": "WisePen 成品镜像",
  "jenkins-source": "Jenkins 源码构建并部署",
};

const sourceLabels: Record<string, string> = {
  managed: "WisePenDeploy 部署",
  external: "已有实例",
};

export function ReviewStep() {
  const { document, dirty, saving, validate, complete, reset } = useSetup();
  const [errors, setErrors] = useState<ValidationIssue[]>([]);
  const [message, setMessage] = useState<string | null>(null);
  const answers = document!.answers;

  const runValidation = async () => {
    setMessage(null);
    const result = await validate();
    setErrors(result.errors);
    if (result.valid) setMessage("信息完整性校验通过，尚未生成任何部署配置");
  };

  const finish = async () => {
    setMessage(null);
    try {
      await complete();
      setErrors([]);
      setMessage("信息收集已确认完成，状态已标记为 collected");
    } catch (error) {
      if (error instanceof ApiError && error.status === 422) {
        const detail = error.detail as { errors?: ValidationIssue[] };
        setErrors(detail.errors ?? []);
        return;
      }
      throw error;
    }
  };

  const download = () => {
    const blob = new Blob([JSON.stringify(document?.answers, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const anchor = window.document.createElement("a");
    anchor.href = url;
    anchor.download = "wisepen-deployment-answers.json";
    anchor.click();
    URL.revokeObjectURL(url);
  };

  const resetAll = async () => {
    if (!window.confirm("确认清空全部已收集信息？此操作不能在界面中撤销")) return;
    await reset();
    setErrors([]);
    window.location.reload();
  };

  return (
    <div className="grid gap-5">
      <ErrorSummary errors={errors} />
      {message ? <Notice status="success">{message}</Notice> : null}

      <FormSection title="信息收集摘要" description="这里只展示已填写内容，不推导或生成部署配置">
        <div className="grid gap-3 md:grid-cols-2">
          <Summary label="部署名称" value={answers.basic.deploymentName} />
          <Summary label="环境" value={answers.basic.environment} />
          <Summary label="持久化根目录" value={answers.basic.persistenceRoot} />
          <Summary label="制品来源" value={artifactLabels[answers.deployment.artifactMode] ?? answers.deployment.artifactMode} />
          <Summary label="前端部署" value={answers.access.frontendDeployment} />
          <Summary label="证书管理" value={answers.certificate.mode} />
        </div>
      </FormSection>

      <FormSection title="业务能力">
        <div className="flex flex-wrap gap-2">
          {[
            ["文档 API", answers.capabilities.isDeployDocsService],
            ["文档处理", answers.capabilities.isDeployDocumentService],
            ["笔记", answers.capabilities.isDeployNoteService],
            ["AI 资源", answers.capabilities.isDeployAiAssetService],
            ["代码沙箱", answers.capabilities.isDeploySandboxService],
            ["高校扩展包", answers.capabilities.isDeployCampusExtensionService],
          ].map(([label, enabled]) => (
            <Chip key={String(label)} color={enabled ? "accent" : "default"} variant={enabled ? "soft" : "secondary"}>
              {label}: {enabled ? "启用" : "不启用"}
            </Chip>
          ))}
          {answers.capabilities.isDeployCampusExtensionService ? (
            <Chip variant="soft">高校扩展: {answers.capabilities.campusExtensionName}</Chip>
          ) : null}
          <Chip variant="soft">MinerU: {answers.capabilities.mineru?.mode}</Chip>
        </div>
      </FormSection>

      <FormSection title="基础设施来源">
        <div className="grid gap-2 md:grid-cols-3">
          {INFRASTRUCTURE_COMPONENTS.map((name) => {
            const choice = answers.infrastructure[name];
            return (
              <Surface key={name} className="flex items-center justify-between rounded-lg px-3 py-2 text-sm" variant="secondary">
                <span>{name}</span>
                <span className="text-muted">{sourceLabels[choice.mode]}</span>
              </Surface>
            );
          })}
        </div>
      </FormSection>

      <div className="flex flex-wrap justify-end gap-3">
        <Button variant="danger-soft" onPress={() => void resetAll()} isDisabled={saving}>重置</Button>
        <Button variant="secondary" onPress={download}>导出 JSON</Button>
        <Button variant="secondary" onPress={() => void runValidation()} isPending={saving}>校验完整性</Button>
        <Button variant="primary" onPress={() => void finish()} isPending={saving} isDisabled={document?.status === "collected" && !dirty}>
          {document?.status === "collected" && !dirty ? "已确认完成" : "确认信息收集完成"}
        </Button>
      </div>
    </div>
  );
}

function Summary({ label, value }: { label: string; value: unknown }) {
  return (
    <Surface className="rounded-lg px-3 py-2" variant="secondary">
      <div className="text-xs text-muted">{label}</div>
      <div className="mt-1 break-all text-sm font-medium">{value == null || value === "" ? "未填写" : String(value)}</div>
    </Surface>
  );
}
