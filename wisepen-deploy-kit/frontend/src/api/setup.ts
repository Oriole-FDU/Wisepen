import type {
  SetupAnswers,
  SetupDocument,
  SetupStep,
  ValidationResult,
  WorkflowStage,
} from "../types/setup";

export class ApiError extends Error {
  status: number;
  detail: unknown;

  constructor(status: number, detail: unknown) {
    super(typeof detail === "string" ? detail : `请求失败：${status}`);
    this.status = status;
    this.detail = detail;
  }
}

async function request<T>(url: string, init?: RequestInit): Promise<T> {
  const response = await fetch(url, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...init?.headers,
    },
  });

  const body = await response.json().catch(() => null);
  if (!response.ok) {
    throw new ApiError(response.status, body?.detail ?? body);
  }
  return body as T;
}

export function getSetup(): Promise<SetupDocument> {
  return request<SetupDocument>("/api/v1/setup");
}

export function saveSetup(
  revision: number,
  currentStage: WorkflowStage,
  currentStep: SetupStep,
  answers: SetupAnswers,
): Promise<SetupDocument> {
  return request<SetupDocument>("/api/v1/setup", {
    method: "PUT",
    body: JSON.stringify({ revision, currentStage, currentStep, answers }),
  });
}

export function validateSetup(): Promise<ValidationResult> {
  return request<ValidationResult>("/api/v1/setup/validate", { method: "POST" });
}

export function completeSetup(revision: number): Promise<SetupDocument> {
  return request<SetupDocument>("/api/v1/setup/complete", {
    method: "POST",
    body: JSON.stringify({ revision }),
  });
}

export function resetSetup(): Promise<SetupDocument> {
  return request<SetupDocument>("/api/v1/setup", { method: "DELETE" });
}
