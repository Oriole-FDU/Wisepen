import { Button, Surface } from "@heroui/react";

const stageCards = [
  ["1", "欢迎", "了解 WisePenDeploy 的工作范围和部署流程"],
  ["2", "信息收集", "选择业务能力、基础设施、访问入口和证书方案"],
  ["3", "部署配置生成", "根据已确认的信息生成并检查部署配置"],
  ["4", "执行", "按照依赖顺序初始化基础设施并启动 WisePen 服务"],
] as const;

export function WelcomeStage({
  hasStarted,
  saving,
  onStart,
}: {
  hasStarted: boolean;
  saving: boolean;
  onStart: () => void;
}) {
  return (
    <main className="mx-auto grid max-w-5xl gap-6 px-4 py-10 md:px-8">
      <div className="text-center">
        <p className="text-sm font-medium text-accent">欢迎使用 WisePenDeploy</p>
        <h2 className="mt-2 text-3xl font-bold tracking-tight">开始部署 WisePen</h2>
        <p className="mx-auto mt-3 max-w-2xl text-muted">
          WisePenDeploy 将引导你完成信息收集、部署配置生成和实际执行，所有部署信息均保存在当前设备
        </p>
      </div>

      <Surface className="grid gap-4 rounded-3xl border border-default p-6 shadow-sm" variant="default">
        <h3 className="text-lg font-semibold">部署过程</h3>
        <div className="grid gap-4 md:grid-cols-2">
          {stageCards.map(([number, title, description]) => (
            <Surface key={number} className="flex gap-4 rounded-2xl p-4" variant="secondary">
              <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-accent text-sm font-bold text-accent-foreground">
                {number}
              </span>
              <span>
                <strong className="block">{title}</strong>
                <span className="mt-1 block text-sm text-muted">{description}</span>
              </span>
            </Surface>
          ))}
        </div>
      </Surface>

      <Surface className="rounded-3xl border border-default p-6 shadow-sm" variant="default">
        <h3 className="font-semibold">当前阶段范围</h3>
        <p className="mt-2 text-sm text-muted">
          先完成部署信息收集并确认结果，配置生成和执行阶段将在对应阶段中独立进行
        </p>
        <div className="mt-5 flex justify-end">
          <Button variant="primary" isPending={saving} onPress={onStart}>
            {hasStarted ? "继续信息收集" : "开始信息收集"}
          </Button>
        </div>
      </Surface>
    </main>
  );
}
