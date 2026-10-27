export type SetupStatus = "empty" | "draft" | "collected";
export type WorkflowStage = "welcome" | "collection" | "generation" | "execution";
export type StageStatus = "locked" | "ready" | "in_progress" | "completed" | "failed" | "outdated";

export interface StageState {
  status: StageStatus;
}

export interface WorkflowStages {
  welcome: StageState;
  collection: StageState & { currentStep: SetupStep };
  generation: StageState;
  execution: StageState;
}

export type SetupStep =
  | "basic"
  | "capabilities"
  | "infrastructure"
  | "operations"
  | "access"
  | "certificate"
  | "jenkins"
  | "review";

export type JsonObject = Record<string, any>;

export interface InfrastructureChoice {
  mode: "managed" | "external";
  managed: JsonObject;
  external: JsonObject;
}

export interface InfrastructureAnswers {
  mysql: InfrastructureChoice;
  redis: InfrastructureChoice;
  mongodb: InfrastructureChoice;
  nacos: InfrastructureChoice;
  etcd: InfrastructureChoice;
  apisix: InfrastructureChoice;
  elasticsearch: InfrastructureChoice;
  kafka: InfrastructureChoice;
  qdrant: InfrastructureChoice;
  credentialPolicy: JsonObject;
}

export interface SetupAnswers {
  basic: JsonObject;
  deployment: JsonObject;
  capabilities: JsonObject;
  infrastructure: InfrastructureAnswers;
  operations: JsonObject;
  access: JsonObject;
  frontendOss: JsonObject | null;
  drawioOss: JsonObject | null;
  certificate: JsonObject;
  jenkins: JsonObject | null;
}

export interface SetupDocument {
  revision: number;
  status: SetupStatus;
  currentStage: WorkflowStage;
  stages: WorkflowStages;
  createdAt: string;
  updatedAt: string;
  answers: SetupAnswers;
}

export interface ValidationIssue {
  path: string;
  code: string;
  message: string;
}

export interface ValidationResult {
  valid: boolean;
  errors: ValidationIssue[];
}

export const INFRASTRUCTURE_COMPONENTS = [
  "mysql",
  "redis",
  "mongodb",
  "nacos",
  "etcd",
  "apisix",
  "elasticsearch",
  "kafka",
  "qdrant",
] as const;

const externalDefaults: Record<string, JsonObject> = {
  mysql: { port: 3306, isEnableTls: false, isNeedCreateDatabase: false, isNeedCreateUser: false, isNeedImportSchema: false },
  redis: { port: 6379, isEnableTls: false },
  mongodb: { port: 27017, authDatabase: "admin", isEnableTls: false },
  nacos: { isEnableTls: false, isNeedInitializeNacos: false },
  etcd: { isEnableTls: false },
  apisix: { isNeedConfigureApisixRoutesAndPlugins: false },
  elasticsearch: { isEnableTls: false },
  kafka: { securityProtocol: "PLAINTEXT" },
  qdrant: { isEnableTls: false },
};

const infrastructureComponents = Object.fromEntries(
  INFRASTRUCTURE_COMPONENTS.map((name) => [
    name,
    { mode: "managed", managed: {}, external: externalDefaults[name] },
  ]),
) as Record<(typeof INFRASTRUCTURE_COMPONENTS)[number], InfrastructureChoice>;

const infrastructure: InfrastructureAnswers = {
  ...infrastructureComponents,
  credentialPolicy: { mode: "auto-gen" },
};

export const defaultAnswers: SetupAnswers = {
  basic: {
    deploymentName: "",
    environment: "production",
    timezone: "Asia/Shanghai",
    persistenceRoot: "/opt/wisepen",
    isUseProxy: false,
    httpProxy: "",
    httpsProxy: "",
    noProxy: "",
  },
  deployment: {
    artifactMode: "official-images",
  },
  capabilities: {
    isDeployDocsService: true,
    isDeployDocumentService: true,
    documentProcessor: {
      type: "onlyoffice",
      jwtSecret: { mode: "auto-gen" },
      maxFileSizeMb: 100,
      isUseCustomFonts: false,
      customFontsDirectory: "",
    },
    isDeployNoteService: true,
    isDeployAiAssetService: true,
    isDeploySandboxService: true,
    isDeployCampusExtensionService: true,
    campusExtensionName: "fudan-extension-service",
    mineru: {
      mode: "none",
      maxConcurrency: 1,
      modelDirectory: "/opt/wisepen/models/mineru",
      gpuDevice: "0",
      gpuMemoryUtilization: 0.8,
    },
  },
  infrastructure,
  operations: {
    isDeployObservability: false,
    isDeployGrafana: false,
    isDeployApisixDashboard: false,
    isDeployKibana: false,
    isDeployKafkaUi: false,
    interfaceAccess: {
      grafana: { scope: "lan", port: 3000, domain: "" },
      apisixDashboard: { scope: "lan", port: 9000, domain: "" },
      kibana: { scope: "lan", port: 5601, domain: "" },
      kafkaUi: { scope: "lan", port: 9091, domain: "" },
    },
    credentialPolicy: { mode: "auto-gen" },
  },
  access: {
    scope: "lan",
    siteProtocol: "https",
    siteAddress: "",
    apiSubdomain: "api",
    isEnableIntranetApi: false,
    intranetApiSubdomain: "api.intranet",
    intranetPingPath: "/ping",
    intranetProbeTimeoutMs: 1000,
    corsOrigins: "",
    frontendDeployment: "container",
    frontendPort: 8085,
    isEnableFrontendViaApisix: true,
    onlyofficeSubdomain: "office",
    onlyofficePort: 8101,
    isDeployDrawio: true,
    drawioDeployment: "container",
    drawioSubdomain: "drawio",
    drawioPort: 8086,
  },
  frontendOss: null,
  drawioOss: null,
  certificate: { mode: "external" },
  jenkins: null,
  /* Jenkins defaults are inserted only when source building is selected. */
} as SetupAnswers;

export const defaultManagedCertificate: JsonObject = {
  mode: "wisepen-cert-manager",
  accessKeyId: "",
  accessKeySecret: "",
  acmeCa: "zerossl",
  acmeEmail: "",
  stateSource: "new",
  acmeDataPath: "",
  isApplyWildcardCertificate: true,
  extraDomains: "",
  isDistributeToApisix: true,
  isDistributeToFrontendOss: true,
  isDistributeToDrawioOss: false,
};

export const defaultJenkins: JsonObject = {
  source: "managed",
  managed: {
    accessScope: "lan",
    port: 8080,
    domain: "",
    persistenceMode: "root",
    persistencePath: "",
  },
  external: {
    url: "",
    username: "",
    apiToken: "",
  },
  deploymentTarget: {
    mode: "local",
    remote: {
      host: "",
      sshPort: 22,
      username: "",
      authMode: "private-key",
      password: "",
      privateKey: "",
    },
  },
};
