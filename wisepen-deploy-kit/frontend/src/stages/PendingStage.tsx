import { Surface } from "@heroui/react";
import { Notice } from "../components/FormControls";
import type { StageStatus, WorkflowStage } from "../types/setup";

const content: Record<"generation" | "execution", { title: string; description: string }> = {
  generation: {
    title: "部署配置生成",
    description: "根据已确认的信息生成 Compose、环境变量和各组件配置，并在执行前提供检查结果",
  },
  execution: {
    title: "执行",
    description: "按照基础设施、数据库初始化、中间件和微服务的依赖顺序执行部署",
  },
};

export function PendingStage({
  stage,
  status,
}: {
  stage: Exclude<WorkflowStage, "welcome" | "collection">;
  status: StageStatus;
}) {
  const stageContent = content[stage];
  const locked = status === "locked";

  return (
    <main className="mx-auto max-w-5xl px-4 py-10 md:px-8">
      <Surface className="grid gap-5 rounded-3xl border border-default p-6 shadow-sm" variant="default">
        <div>
          <p className="text-sm font-medium text-accent">全局阶段</p>
          <h2 className="mt-1 text-2xl font-bold">{stageContent.title}</h2>
          <p className="mt-2 text-sm text-muted">{stageContent.description}</p>
        </div>
        {locked ? (
          <Notice status="warning" title="当前阶段尚未解锁">
            {stage === "generation"
              ? "完成并确认信息收集后才能进入部署配置生成"
              : "生成并确认部署配置后才能开始执行"}
          </Notice>
        ) : (
          <Notice title="阶段入口已就绪">
            当前只建立阶段边界，本阶段的具体功能尚未加入本次实现
          </Notice>
        )}
      </Surface>
    </main>
  );
}
