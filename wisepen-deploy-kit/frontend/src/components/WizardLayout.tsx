import { Alert, Button, ProgressBar, Surface } from "@heroui/react";
import type { ReactNode } from "react";
import type { SetupStep } from "../types/setup";

export interface StepDefinition {
  id: SetupStep;
  label: string;
  description: string;
}

export function WizardLayout({
  steps,
  activeStep,
  saving,
  error,
  children,
  onStepChange,
  onPrevious,
  onSave,
  onNext,
}: {
  steps: StepDefinition[];
  activeStep: SetupStep;
  saving: boolean;
  error: string | null;
  children: ReactNode;
  onStepChange: (step: SetupStep) => void;
  onPrevious: () => void;
  onSave: () => void;
  onNext: () => void;
}) {
  const activeIndex = steps.findIndex((step) => step.id === activeStep);
  const active = steps[activeIndex] ?? steps[0];
  const isReview = active.id === "review";

  return (
    <div className="mx-auto grid max-w-7xl gap-6 px-4 py-6 md:grid-cols-[240px_minmax(0,1fr)] md:px-8">
        <Surface className="h-fit rounded-2xl border border-default p-3 md:sticky md:top-6" variant="default">
          <ProgressBar aria-label="收集进度" value={((activeIndex + 1) / steps.length) * 100} className="mb-4">
            <ProgressBar.Track>
              <ProgressBar.Fill />
            </ProgressBar.Track>
          </ProgressBar>
          <nav className="grid gap-1">
            {steps.map((step, index) => (
              <button
                key={step.id}
                type="button"
                onClick={() => onStepChange(step.id)}
                className={`rounded-lg px-3 py-2 text-left transition ${step.id === active.id ? "bg-accent-soft text-accent" : "hover:bg-default"}`}
              >
                <span className="mr-2 text-xs text-muted">{index + 1}</span>
                <span className="text-sm font-medium">{step.label}</span>
              </button>
            ))}
          </nav>
        </Surface>

        <main className="min-w-0">
          <div className="mb-5">
            <p className="text-sm text-accent">信息收集 · {activeIndex + 1} / {steps.length}</p>
            <h2 className="mt-1 text-2xl font-bold">{active.label}</h2>
            <p className="mt-1 text-sm text-muted">{active.description}</p>
          </div>
          {error ? (
            <Alert className="mb-4" status="danger">
              <Alert.Indicator />
              <Alert.Content>
                <Alert.Description>{error}</Alert.Description>
              </Alert.Content>
            </Alert>
          ) : null}
          {children}
          {!isReview ? (
            <div className="mt-6 flex items-center justify-between border-t border-default pt-5">
              <Button variant="tertiary" onPress={onPrevious} isDisabled={activeIndex === 0 || saving}>上一步</Button>
              <div className="flex gap-3">
                <Button variant="secondary" onPress={onSave} isPending={saving}>保存草稿</Button>
                <Button variant="primary" onPress={onNext} isPending={saving}>下一步</Button>
              </div>
            </div>
          ) : null}
        </main>
    </div>
  );
}
