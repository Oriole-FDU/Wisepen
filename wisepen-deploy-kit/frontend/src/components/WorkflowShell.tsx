import { Chip, Surface } from "@heroui/react";
import type { ReactNode } from "react";
import type { SetupStatus, WorkflowStage, WorkflowStages } from "../types/setup";

const stages: Array<{ id: WorkflowStage; label: string; description: string }> = [
  { id: "welcome", label: "欢迎", description: "了解部署流程" },
  { id: "collection", label: "信息收集", description: "填写部署需求" },
  { id: "generation", label: "部署配置生成", description: "生成并检查配置" },
  { id: "execution", label: "执行", description: "部署 WisePen" },
];

const statusLabels = {
  locked: "未解锁",
  ready: "可开始",
  in_progress: "进行中",
  completed: "已完成",
  failed: "失败",
  outdated: "需更新",
} as const;

export function WorkflowShell({
  activeStage,
  workflowStages,
  setupStatus,
  dirty,
  children,
  onStageChange,
}: {
  activeStage: WorkflowStage;
  workflowStages: WorkflowStages;
  setupStatus: SetupStatus;
  dirty: boolean;
  children: ReactNode;
  onStageChange: (stage: WorkflowStage) => void;
}) {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <header className="border-b border-default">
        <Surface className="rounded-none" variant="default">
          <div className="mx-auto max-w-7xl px-4 py-4 md:px-8">
            <div className="flex items-center justify-between gap-4">
              <div>
                <h1 className="text-xl font-bold tracking-tight">WisePenDeploy</h1>
                <p className="text-sm text-muted">WisePen 部署向导</p>
              </div>
              <div className="flex items-center gap-2">
                {dirty ? <Chip color="warning" variant="soft">未保存</Chip> : null}
                <Chip color={setupStatus === "collected" ? "success" : "default"} variant="soft">
                  {setupStatus === "collected" ? "信息已确认" : setupStatus === "draft" ? "草稿" : "未开始"}
                </Chip>
              </div>
            </div>

            <nav className="mt-5 overflow-x-auto pb-1" aria-label="部署阶段">
              <ol className="grid min-w-[760px] grid-cols-4 gap-3">
                {stages.map((stage, index) => {
                  const state = workflowStages[stage.id];
                  const isActive = stage.id === activeStage;
                  const isLocked = state.status === "locked";
                  return (
                    <li key={stage.id}>
                      <button
                        type="button"
                        disabled={isLocked}
                        onClick={() => onStageChange(stage.id)}
                        className={`flex w-full items-start gap-3 rounded-2xl border p-3 text-left transition ${
                          isActive
                            ? "border-accent bg-accent-soft text-accent"
                            : isLocked
                              ? "cursor-not-allowed border-default text-muted opacity-60"
                              : "border-default hover:bg-default"
                        }`}
                      >
                        <span className={`flex size-7 shrink-0 items-center justify-center rounded-full text-sm font-semibold ${
                          isActive ? "bg-accent text-accent-foreground" : "bg-default text-foreground"
                        }`}>
                          {index + 1}
                        </span>
                        <span className="min-w-0">
                          <span className="block font-semibold">{stage.label}</span>
                          <span className="mt-0.5 block text-xs opacity-75">{stage.description}</span>
                          <span className="mt-1 block text-xs">{statusLabels[state.status]}</span>
                        </span>
                      </button>
                    </li>
                  );
                })}
              </ol>
            </nav>
          </div>
        </Surface>
      </header>
      {children}
    </div>
  );
}
