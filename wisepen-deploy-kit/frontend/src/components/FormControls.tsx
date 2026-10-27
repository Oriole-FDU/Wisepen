import {
  Alert,
  Description,
  Fieldset,
  Input,
  InputGroup,
  Label,
  ListBox,
  Radio,
  RadioGroup,
  Select,
  Surface,
  Switch,
  TextArea,
  TextField as HeroTextField,
} from "@heroui/react";
import { useId, type HTMLInputTypeAttribute, type ReactNode } from "react";

export function FormSection({
  title,
  description,
  children,
}: {
  title: string;
  description?: string;
  children: ReactNode;
}) {
  return (
    <Surface className="grid gap-4 rounded-3xl border border-default p-5 shadow-sm" variant="default">
      <header>
        <h2 className="text-lg font-semibold text-foreground">{title}</h2>
        {description ? <p className="mt-1 text-sm text-muted">{description}</p> : null}
      </header>
      <div className="grid gap-4">{children}</div>
    </Surface>
  );
}

export function TextField({
  label,
  value,
  onChange,
  type = "text",
  description,
  placeholder,
  required,
  endContent,
}: {
  label: string;
  value: string | number | undefined | null;
  onChange: (value: string) => void;
  type?: HTMLInputTypeAttribute;
  description?: string;
  placeholder?: string;
  required?: boolean;
  endContent?: ReactNode;
}) {
  return (
    <HeroTextField
      className="min-w-0"
      fullWidth
      isRequired={required}
      value={value == null ? "" : String(value)}
      onChange={onChange}
    >
      <Label>{label}</Label>
      {endContent ? (
        <InputGroup variant="secondary">
          <InputGroup.Input type={type} placeholder={placeholder} />
          <InputGroup.Suffix>{endContent}</InputGroup.Suffix>
        </InputGroup>
      ) : (
        <Input type={type} placeholder={placeholder} variant="secondary" />
      )}
      {description ? <Description>{description}</Description> : null}
    </HeroTextField>
  );
}

export function NumberField({
  label,
  value,
  onChange,
  min,
  max,
  step,
  description,
}: {
  label: string;
  value: number | string | undefined | null;
  onChange: (value: number | undefined) => void;
  min?: number;
  max?: number;
  step?: number;
  description?: string;
}) {
  return (
    <HeroTextField
      className="min-w-0"
      fullWidth
      value={value == null ? "" : String(value)}
      onChange={(next) => onChange(next === "" ? undefined : Number(next))}
    >
      <Label>{label}</Label>
      <Input type="number" min={min} max={max} step={step} variant="secondary" />
      {description ? <Description>{description}</Description> : null}
    </HeroTextField>
  );
}

export function TextAreaField({
  label,
  value,
  onChange,
  description,
  placeholder,
}: {
  label: string;
  value: string | undefined | null;
  onChange: (value: string) => void;
  description?: string;
  placeholder?: string;
}) {
  return (
    <HeroTextField className="min-w-0" fullWidth value={value ?? ""} onChange={onChange}>
      <Label>{label}</Label>
      <TextArea placeholder={placeholder} variant="secondary" />
      {description ? <Description>{description}</Description> : null}
    </HeroTextField>
  );
}

export function SelectField({
  label,
  value,
  options,
  onChange,
  description,
}: {
  label: string;
  value: string | undefined | null;
  options: Array<{ key: string; label: string }>;
  onChange: (value: string) => void;
  description?: string;
}) {
  return (
    <Select
      className="min-w-0"
      fullWidth
      placeholder="请选择"
      variant="secondary"
      value={value ?? null}
      onChange={(selected) => {
        if (selected != null) onChange(String(selected));
      }}
    >
      <Label>{label}</Label>
      <Select.Trigger>
        <Select.Value />
        <Select.Indicator />
      </Select.Trigger>
      {description ? <Description>{description}</Description> : null}
      <Select.Popover>
        <ListBox>
          {options.map((option) => (
            <ListBox.Item key={option.key} id={option.key} textValue={option.label}>
              {option.label}
              <ListBox.ItemIndicator />
            </ListBox.Item>
          ))}
        </ListBox>
      </Select.Popover>
    </Select>
  );
}

export function RadioField({
  label,
  value,
  options,
  onChange,
  orientation = "horizontal",
}: {
  label: string;
  value: string | undefined | null;
  options: Array<{ value: string; label: string; description?: string }>;
  onChange: (value: string) => void;
  orientation?: "horizontal" | "vertical";
}) {
  const name = useId();

  return (
    <RadioGroup
      name={name}
      value={value ?? ""}
      orientation={orientation}
      variant="secondary"
      onChange={(next) => onChange(String(next))}
    >
      <Label>{label}</Label>
      {options.map((option) => (
        <Radio key={option.value} value={option.value}>
          <Radio.Content>
            <Radio.Control>
              <Radio.Indicator />
            </Radio.Control>
            {option.label}
          </Radio.Content>
          {option.description ? <Description>{option.description}</Description> : null}
        </Radio>
      ))}
    </RadioGroup>
  );
}

export function BooleanField({
  label,
  value,
  onChange,
  description,
  disabled = false,
}: {
  label: string;
  value: boolean | undefined | null;
  onChange: (value: boolean) => void;
  description?: string;
  disabled?: boolean;
}) {
  return (
    <Switch isSelected={Boolean(value)} isDisabled={disabled} onChange={onChange}>
      <Switch.Content>
        <Switch.Control>
          <Switch.Thumb />
        </Switch.Control>
        <span className="grid gap-0.5">
          <Label>{label}</Label>
          {description ? <Description>{description}</Description> : null}
        </span>
      </Switch.Content>
    </Switch>
  );
}

export function ConditionalPanel({ children }: { children: ReactNode }) {
  return (
    <Fieldset className="rounded-2xl border border-default p-4">
      <Fieldset.Group className="grid gap-4 md:grid-cols-2">{children}</Fieldset.Group>
    </Fieldset>
  );
}

export function Notice({
  children,
  status = "accent",
  title,
}: {
  children: ReactNode;
  status?: "accent" | "success" | "warning" | "danger";
  title?: string;
}) {
  return (
    <Alert status={status}>
      <Alert.Indicator />
      <Alert.Content>
        {title ? <Alert.Title>{title}</Alert.Title> : null}
        <Alert.Description>{children}</Alert.Description>
      </Alert.Content>
    </Alert>
  );
}
