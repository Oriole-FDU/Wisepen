import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import {
  completeSetup,
  getSetup,
  resetSetup,
  saveSetup,
  validateSetup,
} from "../api/setup";
import {
  defaultAnswers,
  type SetupAnswers,
  type SetupDocument,
  type SetupStep,
  type ValidationResult,
  type WorkflowStage,
} from "../types/setup";

interface SetupContextValue {
  document: SetupDocument | null;
  loading: boolean;
  saving: boolean;
  dirty: boolean;
  error: string | null;
  update: (path: string, value: unknown) => void;
  save: (step?: SetupStep, stage?: WorkflowStage) => Promise<SetupDocument>;
  validate: () => Promise<ValidationResult>;
  complete: () => Promise<SetupDocument>;
  reset: () => Promise<void>;
  reload: () => Promise<void>;
}

const SetupContext = createContext<SetupContextValue | null>(null);

function clone<T>(value: T): T {
  return structuredClone(value);
}

function initializeEmptyDocument(document: SetupDocument): SetupDocument {
  if (document.status !== "empty") return document;
  return {
    ...document,
    answers: clone(defaultAnswers),
  };
}

function setNestedValue(answers: SetupAnswers, path: string, value: unknown): SetupAnswers {
  const next = clone(answers) as Record<string, any>;
  const parts = path.split(".");
  let current = next;
  parts.forEach((part, index) => {
    if (index === parts.length - 1) {
      current[part] = value;
      return;
    }
    if (!current[part] || typeof current[part] !== "object") {
      current[part] = {};
    }
    current = current[part];
  });
  return next as SetupAnswers;
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return "发生未知错误";
}

export function SetupProvider({ children }: { children: ReactNode }) {
  const [document, setDocument] = useState<SetupDocument | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [dirty, setDirty] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setDocument(initializeEmptyDocument(await getSetup()));
      setDirty(false);
    } catch (requestError) {
      setError(errorMessage(requestError));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    // Initial data comes from the backend, so this effect intentionally starts the load.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void reload();
  }, [reload]);

  const update = useCallback((path: string, value: unknown) => {
    setDocument((current) => {
      if (!current) return current;
      const stages = clone(current.stages);
      stages.welcome.status = "completed";
      stages.collection.status = "in_progress";
      stages.generation.status = "locked";
      stages.execution.status = "locked";
      return {
        ...current,
        status: "draft",
        currentStage: "collection",
        stages,
        answers: setNestedValue(current.answers, path, value),
      };
    });
    setDirty(true);
  }, []);

  const save = useCallback(
    async (step?: SetupStep, stage: WorkflowStage = "collection") => {
      if (!document) throw new Error("收集信息尚未加载");
      setSaving(true);
      setError(null);
      try {
        const saved = await saveSetup(
          document.revision,
          stage,
          step ?? document.stages.collection.currentStep,
          document.answers,
        );
        const merged = initializeEmptyDocument(saved);
        setDocument(merged);
        setDirty(false);
        return merged;
      } catch (requestError) {
        setError(errorMessage(requestError));
        throw requestError;
      } finally {
        setSaving(false);
      }
    },
    [document],
  );

  const validate = useCallback(async () => {
    const saved = dirty ? await save(document?.stages.collection.currentStep) : document;
    if (!saved) throw new Error("收集信息尚未加载");
    return validateSetup();
  }, [dirty, document, save]);

  const complete = useCallback(async () => {
    const saved = dirty ? await save("review") : document;
    if (!saved) throw new Error("收集信息尚未加载");
    const completed = initializeEmptyDocument(await completeSetup(saved.revision));
    setDocument(completed);
    setDirty(false);
    return completed;
  }, [dirty, document, save]);

  const reset = useCallback(async () => {
    setSaving(true);
    setError(null);
    try {
      setDocument(initializeEmptyDocument(await resetSetup()));
      setDirty(false);
    } catch (requestError) {
      setError(errorMessage(requestError));
      throw requestError;
    } finally {
      setSaving(false);
    }
  }, []);

  useEffect(() => {
    const listener = (event: BeforeUnloadEvent) => {
      if (!dirty) return;
      event.preventDefault();
    };
    window.addEventListener("beforeunload", listener);
    return () => window.removeEventListener("beforeunload", listener);
  }, [dirty]);

  const value = useMemo(
    () => ({ document, loading, saving, dirty, error, update, save, validate, complete, reset, reload }),
    [document, loading, saving, dirty, error, update, save, validate, complete, reset, reload],
  );

  return <SetupContext.Provider value={value}>{children}</SetupContext.Provider>;
}

// Context and its hook intentionally live together to keep this small application cohesive.
// eslint-disable-next-line react-refresh/only-export-components
export function useSetup(): SetupContextValue {
  const context = useContext(SetupContext);
  if (!context) throw new Error("useSetup must be used inside SetupProvider");
  return context;
}
