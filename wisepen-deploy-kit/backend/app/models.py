from __future__ import annotations

from datetime import datetime
from typing import Annotated, Any, Literal

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class ApiModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        extra="forbid",
    )


class BasicAnswers(ApiModel):
    deployment_name: str | None = None
    environment: Literal["development", "testing", "production"] | None = None
    timezone: str | None = None
    persistence_root: str | None = None
    is_use_proxy: bool | None = None
    http_proxy: str | None = None
    https_proxy: str | None = None
    no_proxy: str | None = None


class DeploymentAnswers(ApiModel):
    artifact_mode: Literal["official-images", "jenkins-source"] | None = None


class CapabilitiesAnswers(ApiModel):
    is_deploy_docs_service: bool | None = None
    is_deploy_document_service: bool | None = None
    document_processor: dict[str, Any] | None = None
    is_deploy_note_service: bool | None = None
    is_deploy_ai_asset_service: bool | None = None
    is_deploy_sandbox_service: bool | None = None
    is_deploy_campus_extension_service: bool | None = None
    campus_extension_name: Literal["fudan-extension-service"] | None = None
    mineru: dict[str, Any] | None = None


class InfrastructureChoice(ApiModel):
    mode: Literal["managed", "external"] | None = None
    managed: dict[str, Any] = Field(default_factory=dict)
    external: dict[str, Any] = Field(default_factory=dict)


class AutoGenCredentialPolicy(ApiModel):
    mode: Literal["auto-gen"]


class UnifiedCredentialPolicy(ApiModel):
    mode: Literal["unified"]
    username: str
    password: str


class ManualCredentialPolicy(ApiModel):
    mode: Literal["manual"]
    credentials: dict[str, Any] = Field(default_factory=dict)


CredentialPolicy = Annotated[
    AutoGenCredentialPolicy | UnifiedCredentialPolicy | ManualCredentialPolicy,
    Field(discriminator="mode"),
]


class InfrastructureAnswers(ApiModel):
    mysql: InfrastructureChoice | None = None
    redis: InfrastructureChoice | None = None
    mongodb: InfrastructureChoice | None = None
    nacos: InfrastructureChoice | None = None
    etcd: InfrastructureChoice | None = None
    apisix: InfrastructureChoice | None = None
    elasticsearch: InfrastructureChoice | None = None
    kafka: InfrastructureChoice | None = None
    qdrant: InfrastructureChoice | None = None
    credential_policy: CredentialPolicy | None = None


class OperationsAnswers(ApiModel):
    is_deploy_observability: bool | None = None
    is_deploy_grafana: bool | None = None
    is_deploy_apisix_dashboard: bool | None = None
    is_deploy_kibana: bool | None = None
    is_deploy_kafka_ui: bool | None = None
    interface_access: dict[str, Any] = Field(default_factory=dict)
    credential_policy: CredentialPolicy | None = None


class AccessAnswers(ApiModel):
    scope: Literal["lan", "public"] | None = None
    site_protocol: Literal["http", "https"] | None = None
    site_address: str | None = None
    api_subdomain: str | None = None
    is_enable_intranet_api: bool | None = None
    intranet_api_subdomain: str | None = None
    intranet_ping_path: str | None = None
    intranet_probe_timeout_ms: int | None = None
    cors_origins: str | None = None
    frontend_deployment: Literal["oss", "container"] | None = None
    frontend_port: int | None = None
    is_enable_frontend_via_apisix: bool | None = None
    onlyoffice_subdomain: str | None = None
    onlyoffice_port: int | None = None
    is_deploy_drawio: bool | None = None
    drawio_deployment: Literal["oss", "container"] | None = None
    drawio_subdomain: str | None = None
    drawio_port: int | None = None


class FrontendOssAnswers(ApiModel):
    access_key_id: str
    access_key_secret: str
    endpoint: str
    bucket: str
    clean_policy: Literal["keep-previous-release", "delete-all-stale"]


class DrawioOssAnswers(ApiModel):
    access_key_id: str
    access_key_secret: str
    endpoint: str
    bucket: str


class ExternalCertificateAnswers(ApiModel):
    mode: Literal["external"]


class ManagedCertificateAnswers(ApiModel):
    mode: Literal["wisepen-cert-manager"]
    access_key_id: str
    access_key_secret: str
    acme_ca: Literal["zerossl", "letsencrypt"]
    acme_email: str
    state_source: Literal["new", "existing"]
    acme_data_path: str = ""
    is_apply_wildcard_certificate: bool
    extra_domains: str = ""
    is_distribute_to_apisix: bool
    is_distribute_to_frontend_oss: bool
    is_distribute_to_drawio_oss: bool


CertificateAnswers = Annotated[
    ExternalCertificateAnswers | ManagedCertificateAnswers,
    Field(discriminator="mode"),
]


class JenkinsAnswers(ApiModel):
    source: Literal["managed", "external"] | None = None
    managed: dict[str, Any] = Field(default_factory=dict)
    external: dict[str, Any] = Field(default_factory=dict)
    deployment_target: dict[str, Any] = Field(default_factory=dict)


class SetupAnswers(ApiModel):
    basic: BasicAnswers | None = None
    deployment: DeploymentAnswers | None = None
    capabilities: CapabilitiesAnswers | None = None
    infrastructure: InfrastructureAnswers | None = None
    operations: OperationsAnswers | None = None
    access: AccessAnswers | None = None
    frontend_oss: FrontendOssAnswers | None = None
    drawio_oss: DrawioOssAnswers | None = None
    certificate: CertificateAnswers | None = None
    jenkins: JenkinsAnswers | None = None


WorkflowStage = Literal["welcome", "collection", "generation", "execution"]
StageStatus = Literal["locked", "ready", "in_progress", "completed", "failed", "outdated"]


class StageState(ApiModel):
    status: StageStatus


class CollectionStageState(StageState):
    current_step: str = "basic"


class WorkflowStages(ApiModel):
    welcome: StageState = Field(default_factory=lambda: StageState(status="ready"))
    collection: CollectionStageState = Field(
        default_factory=lambda: CollectionStageState(status="locked")
    )
    generation: StageState = Field(default_factory=lambda: StageState(status="locked"))
    execution: StageState = Field(default_factory=lambda: StageState(status="locked"))


class SetupDocument(ApiModel):
    revision: int = 0
    status: Literal["empty", "draft", "collected"] = "empty"
    current_stage: WorkflowStage = "welcome"
    stages: WorkflowStages = Field(default_factory=WorkflowStages)
    created_at: datetime
    updated_at: datetime
    answers: SetupAnswers = Field(default_factory=SetupAnswers)


class SaveSetupRequest(ApiModel):
    revision: int
    current_stage: WorkflowStage
    current_step: str
    answers: SetupAnswers


class ValidationIssue(ApiModel):
    path: str
    code: str = "required"
    message: str


class ValidationResult(ApiModel):
    valid: bool
    errors: list[ValidationIssue] = Field(default_factory=list)
