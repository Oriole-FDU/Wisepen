import { Spinner } from "@heroui/react";
import { useEffect, useMemo, useState } from "react";
import { WizardLayout, type StepDefinition } from "./components/WizardLayout";
import { WorkflowShell } from "./components/WorkflowShell";
import { useSetup } from "./state/SetupContext";
import { AccessStep } from "./steps/AccessStep";
import { CertificateStep } from "./steps/CertificateStep";
import { BasicStep } from "./steps/BasicStep";
import { CapabilitiesStep } from "./steps/CapabilitiesStep";
import { InfrastructureStep } from "./steps/InfrastructureStep";
import { JenkinsStep } from "./steps/JenkinsStep";
import { OperationsStep } from "./steps/OperationsStep";
import { ReviewStep } from "./steps/ReviewStep";
import { PendingStage } from "./stages/PendingStage";
import { WelcomeStage } from "./stages/WelcomeStage";
import type { SetupDocument, SetupStep, WorkflowStage } from "./types/setup";

const baseSteps: StepDefinition[] = [
  { id: "basic", label: "基本信息", description: "收集部署标识、持久化根目录和网络代理" },
  { id: "capabilities", label: "业务能力", description: "选择制品来源和可选业务能力" },
  { id: "infrastructure", label: "基础设施", description: "指定必需基础设施由本地部署还是接入已有实例" },
  { id: "operations", label: "运维功能", description: "选择运维能力、可视化界面和账号策略" },
  { id: "access", label: "访问与前端", description: "收集用户访问入口和 WisePenView 部署方式" },
  { id: "certificate", label: "证书", description: "选择主站访问协议和 HTTPS 证书管理方式" },
  { id: "jenkins", label: "Jenkins", description: "仅在选择源码构建并部署时收集 Jenkins 信息" },
  { id: "review", label: "确认", description: "核对、校验并确认信息收集完成" },
];

function stepContent(step: SetupStep) {
  switch (step) {
    case "basic": return <BasicStep />;
    case "capabilities": return <CapabilitiesStep />;
    case "infrastructure": return <InfrastructureStep />;
    case "operations": return <OperationsStep />;
    case "access": return <AccessStep />;
    case "certificate": return <CertificateStep />;
    case "jenkins": return <JenkinsStep />;
    case "review": return <ReviewStep />;
  }
}

export default function App() {
  const { document, loading } = useSetup();
  if (loading || !document) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center gap-3">
        <Spinner />
        <span className="text-sm text-muted">正在加载收集信息…</span>
      </div>
    );
  }
  return <LoadedApplication initialDocument={document} />;
}

function LoadedApplication({ initialDocument }: { initialDocument: SetupDocument }) {
  const { document, saving, dirty, save } = useSetup();
  const [activeStage, setActiveStage] = useState<WorkflowStage>(initialDocument.currentStage);

  useEffect(() => {
    if (document?.currentStage) setActiveStage(document.currentStage);
  }, [document?.currentStage]);

  if (!document) return null;

  const changeStage = (stage: WorkflowStage) => {
    if (document.stages[stage].status !== "locked") setActiveStage(stage);
  };

  const startCollection = async () => {
    await save(document.stages.collection.currentStep, "collection");
    setActiveStage("collection");
  };

  return (
    <WorkflowShell
      activeStage={activeStage}
      workflowStages={document.stages}
      setupStatus={document.status}
      dirty={dirty}
      onStageChange={changeStage}
    >
      {activeStage === "welcome" ? (
        <WelcomeStage
          hasStarted={document.stages.collection.status !== "locked"}
          saving={saving}
          onStart={() => void startCollection()}
        />
      ) : null}
      {activeStage === "collection" ? <CollectionWizard initialDocument={document} /> : null}
      {activeStage === "generation" ? (
        <PendingStage stage="generation" status={document.stages.generation.status} />
      ) : null}
      {activeStage === "execution" ? (
        <PendingStage stage="execution" status={document.stages.execution.status} />
      ) : null}
    </WorkflowShell>
  );
}

function CollectionWizard({ initialDocument }: { initialDocument: SetupDocument }) {
  const { document, saving, error, save } = useSetup();
  const [activeStep, setActiveStep] = useState<SetupStep>(initialDocument.stages.collection.currentStep);

  const steps = useMemo(() => {
    if (document?.answers.deployment.artifactMode === "jenkins-source") return baseSteps;
    return baseSteps.filter((step) => step.id !== "jenkins");
  }, [document?.answers.deployment.artifactMode]);

  if (!document) return null;

  const resolvedStep = steps.some((step) => step.id === activeStep) ? activeStep : "review";
  const index = steps.findIndex((step) => step.id === resolvedStep);

  const previous = () => {
    if (index > 0) setActiveStep(steps[index - 1].id);
  };

  const next = async () => {
    const nextStep = steps[Math.min(index + 1, steps.length - 1)].id;
    await save(nextStep);
    setActiveStep(nextStep);
  };

  const saveCurrent = async () => {
    await save(resolvedStep);
  };

  return (
    <WizardLayout
      steps={steps}
      activeStep={resolvedStep}
      saving={saving}
      error={error}
      onStepChange={setActiveStep}
      onPrevious={previous}
      onSave={() => void saveCurrent()}
      onNext={() => void next()}
    >
      {stepContent(resolvedStep)}
    </WizardLayout>
  );
}
