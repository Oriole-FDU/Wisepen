import { Alert } from "@heroui/react";
import type { ValidationIssue } from "../types/setup";

export function ErrorSummary({ errors }: { errors: ValidationIssue[] }) {
  if (!errors.length) return null;
  return (
    <Alert status="danger">
      <Alert.Indicator />
      <Alert.Content>
        <Alert.Title>发现 {errors.length} 个待补充项</Alert.Title>
        <Alert.Description>
          <ul className="mt-1 list-disc space-y-1 pl-5 text-sm">
            {errors.map((error, index) => (
              <li key={`${error.path}-${index}`}>
                {error.message}
                <code className="ml-2 text-xs opacity-70">{error.path}</code>
              </li>
            ))}
          </ul>
        </Alert.Description>
      </Alert.Content>
    </Alert>
  );
}
