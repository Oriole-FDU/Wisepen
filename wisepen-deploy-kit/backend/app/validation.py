from __future__ import annotations

from ipaddress import ip_address
from typing import Any

from .models import SetupDocument, ValidationIssue, ValidationResult


REQUIRED_INFRASTRUCTURE = (
    "mysql",
    "redis",
    "mongodb",
    "nacos",
    "etcd",
    "apisix",
    "elasticsearch",
    "kafka",
    "qdrant",
)

EXTERNAL_REQUIRED_FIELDS: dict[str, tuple[str, ...]] = {
    "mysql": ("host", "port", "username", "password", "isNeedCreateDatabase", "isNeedCreateUser", "isNeedImportSchema"),
    "redis": ("host", "port", "password"),
    "mongodb": ("host", "port", "username", "password", "authDatabase"),
    "nacos": ("address", "username", "password", "isNeedInitializeNacos"),
    "etcd": ("endpoints", "username", "password"),
    "apisix": ("adminApiUrl", "adminKey", "httpGatewayUrl", "isNeedConfigureApisixRoutesAndPlugins"),
    "elasticsearch": ("url", "username", "password"),
    "kafka": ("bootstrapServers", "securityProtocol"),
    "qdrant": ("url", "apiKey"),
}

MANUAL_CREDENTIAL_FIELDS: dict[str, tuple[str, ...]] = {
    "mysql": ("password",),
    "redis": ("password",),
    "mongodb": ("username", "password"),
    "nacos": ("username", "password", "authToken", "identityKey", "identityValue"),
    "etcd": ("password",),
    "apisix": ("adminKey",),
    "elasticsearch": ("password",),
    "qdrant": ("apiKey",),
}


def _dump(document: SetupDocument) -> dict[str, Any]:
    return document.model_dump(mode="json", by_alias=True)


def _get(data: Any, path: str, default: Any = None) -> Any:
    current = data
    for part in path.split("."):
        if not isinstance(current, dict) or part not in current:
            return default
        current = current[part]
    return current


def _present(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, (list, dict)):
        return bool(value)
    return True


def _is_ip(value: Any) -> bool:
    try:
        ip_address(str(value).strip())
        return True
    except ValueError:
        return False


def _is_domain(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    domain = value.strip().rstrip(".")
    if not domain or _is_ip(domain) or "://" in domain or len(domain) > 253:
        return False
    labels = domain.split(".")
    return len(labels) >= 2 and all(
        label
        and len(label) <= 63
        and label[0].isalnum()
        and label[-1].isalnum()
        and all(char.isalnum() or char == "-" for char in label)
        for label in labels
    )


def _is_subdomain_prefix(value: Any) -> bool:
    if not isinstance(value, str) or not value.strip():
        return False
    return all(
        label
        and label[0].isalnum()
        and label[-1].isalnum()
        and all(char.isalnum() or char == "-" for char in label)
        for label in value.strip().split(".")
    )


def validate_complete(document: SetupDocument) -> ValidationResult:
    data = _dump(document)
    answers = data.get("answers", {})
    errors: list[ValidationIssue] = []

    def add(path: str, message: str, code: str = "required") -> None:
        errors.append(ValidationIssue(path=path, code=code, message=message))

    def require(path: str, message: str) -> Any:
        value = _get(answers, path)
        if not _present(value):
            add(f"answers.{path}", message)
        return value

    require("basic.deploymentName", "请填写部署名称")
    require("basic.environment", "请选择环境类型")
    require("basic.timezone", "请填写时区")
    require("basic.persistenceRoot", "请填写宿主机持久化根目录")
    if _get(answers, "basic.isUseProxy"):
        if not _present(_get(answers, "basic.httpProxy")) and not _present(_get(answers, "basic.httpsProxy")):
            add("answers.basic.httpProxy", "启用代理后至少填写一个代理地址")

    artifact_mode = require("deployment.artifactMode", "请选择 WisePen 制品来源")

    for field, label in (
        ("isDeployDocsService", "文档 API"),
        ("isDeployDocumentService", "文档处理"),
        ("isDeployNoteService", "笔记"),
        ("isDeployAiAssetService", "AI 资源"),
        ("isDeploySandboxService", "代码沙箱"),
        ("isDeployCampusExtensionService", "高校扩展包"),
    ):
        if _get(answers, f"capabilities.{field}") is None:
            add(f"answers.capabilities.{field}", f"请选择是否启用{label}能力")

    if _get(answers, "capabilities.isDeployCampusExtensionService"):
        require("capabilities.campusExtensionName", "请选择高校扩展服务")

    if _get(answers, "capabilities.isDeployDocumentService"):
        processor_type = require(
            "capabilities.documentProcessor.type",
            "启用文档处理后必须选择 OnlyOffice 或 JODConverter",
        )
        if processor_type == "onlyoffice":
            secret_mode = require(
                "capabilities.documentProcessor.jwtSecret.mode",
                "请选择 OnlyOffice JWT Secret 的收集策略",
            )
            if secret_mode == "manual":
                require("capabilities.documentProcessor.jwtSecret.value", "请填写 OnlyOffice JWT Secret")
        elif processor_type == "jodconverter":
            require("capabilities.documentProcessor.maxFileSizeMb", "请填写 JODConverter 最大文件大小")

    mineru_mode = require("capabilities.mineru.mode", "请选择 MinerU 模式")
    if mineru_mode in {"cpu", "gpu"}:
        require("capabilities.mineru.maxConcurrency", "请填写 MinerU 最大并发数")
        require("capabilities.mineru.modelDirectory", "请填写 MinerU 模型目录")
    if mineru_mode == "gpu":
        require("capabilities.mineru.gpuDevice", "请填写 MinerU GPU 设备编号")
        require("capabilities.mineru.gpuMemoryUtilization", "请填写 MinerU GPU 显存使用比例")

    infrastructure = _get(answers, "infrastructure", {}) or {}
    for component in REQUIRED_INFRASTRUCTURE:
        choice = infrastructure.get(component)
        if not isinstance(choice, dict):
            add(f"answers.infrastructure.{component}", f"请选择 {component} 的来源")
            continue
        mode = choice.get("mode")
        if mode not in {"managed", "external"}:
            add(f"answers.infrastructure.{component}.mode", f"请选择 {component} 的来源")
            continue
        if mode == "external":
            external = choice.get("external") or {}
            for field in EXTERNAL_REQUIRED_FIELDS[component]:
                if not _present(external.get(field)):
                    add(
                        f"answers.infrastructure.{component}.external.{field}",
                        f"使用已有 {component} 时必须填写 {field}",
                    )
            if external.get("isEnableTls") and not _present(external.get("caCertificate")):
                add(
                    f"answers.infrastructure.{component}.external.caCertificate",
                    f"{component} 启用 TLS 时必须填写 CA 证书",
                )

    observability = _get(answers, "operations.isDeployObservability")
    if observability is None:
        add("answers.operations.isDeployObservability", "请选择是否部署可观测能力")
    if observability and _get(answers, "operations.isDeployGrafana") is None:
        add("answers.operations.isDeployGrafana", "请选择是否部署 Grafana")
    if not observability and _get(answers, "operations.isDeployGrafana"):
        add("answers.operations.isDeployGrafana", "部署 Grafana 前必须部署可观测能力", "dependency")
    for field, label in (
        ("isDeployApisixDashboard", "APISIX Dashboard"),
        ("isDeployKibana", "Kibana"),
        ("isDeployKafkaUi", "Kafka UI"),
    ):
        if _get(answers, f"operations.{field}") is None:
            add(f"answers.operations.{field}", f"请选择是否部署 {label}")

    selected_interfaces = []
    if observability and _get(answers, "operations.isDeployGrafana"):
        selected_interfaces.append("grafana")
    if _get(answers, "operations.isDeployApisixDashboard"):
        selected_interfaces.append("apisixDashboard")
    if _get(answers, "operations.isDeployKibana"):
        selected_interfaces.append("kibana")
    if _get(answers, "operations.isDeployKafkaUi"):
        selected_interfaces.append("kafkaUi")

    for interface in selected_interfaces:
        scope_value = require(
            f"operations.interfaceAccess.{interface}.scope",
            f"请选择 {interface} 的访问范围",
        )
        if scope_value == "domain":
            require(f"operations.interfaceAccess.{interface}.domain", f"请填写 {interface} 的访问域名")
        elif scope_value in {"local", "lan"}:
            require(f"operations.interfaceAccess.{interface}.port", f"请填写 {interface} 的宿主机端口")

    account_targets = list(selected_interfaces)
    if artifact_mode == "jenkins-source" and _get(answers, "jenkins.source") == "managed":
        account_targets.append("jenkins")
    if account_targets:
        account_mode = require("operations.credentialPolicy.mode", "请选择运维界面凭据策略")
        if account_mode == "unified":
            require("operations.credentialPolicy.username", "请填写统一管理员用户名")
            require("operations.credentialPolicy.password", "请填写统一管理员密码")
        elif account_mode == "manual":
            for interface in account_targets:
                require(f"operations.credentialPolicy.credentials.{interface}.username", f"请填写 {interface} 管理用户名")
                require(f"operations.credentialPolicy.credentials.{interface}.password", f"请填写 {interface} 管理密码")

    credential_mode = require(
        "infrastructure.credentialPolicy.mode",
        "请选择基础设施密码和密钥策略",
    )
    if credential_mode == "unified":
        require("infrastructure.credentialPolicy.username", "请填写基础设施统一用户名")
        require("infrastructure.credentialPolicy.password", "请填写基础设施统一密码")
    elif credential_mode == "manual":
        credentials = _get(answers, "infrastructure.credentialPolicy.credentials", {}) or {}
        for component, fields in MANUAL_CREDENTIAL_FIELDS.items():
            choice = infrastructure.get(component)
            if not isinstance(choice, dict) or choice.get("mode") != "managed":
                continue
            for field in fields:
                if not _present(_get(credentials, f"{component}.{field}")):
                    add(
                        f"answers.infrastructure.credentialPolicy.credentials.{component}.{field}",
                        f"手动设置基础设施凭据时必须填写 {component}.{field}",
                    )

    scope = require("access.scope", "请选择 WisePen 访问范围")
    protocol = require("access.siteProtocol", "请选择主站访问协议")
    site_address = require("access.siteAddress", "请填写主站域名或部署设备 IP")
    if scope == "lan" and _present(site_address) and not _is_ip(site_address):
        add("answers.access.siteAddress", "仅局域网模式必须填写部署设备 IP，不能填写域名", "format")
    if scope == "public" and _present(site_address) and not _is_domain(site_address):
        add("answers.access.siteAddress", "公网模式必须填写主站域名，不能填写 IP、协议或路径", "format")

    if scope == "public":
        api_subdomain = require("access.apiSubdomain", "请填写 API 子域名前缀")
        if _present(api_subdomain) and not _is_subdomain_prefix(api_subdomain):
            add("answers.access.apiSubdomain", "API 子域名前缀格式不正确", "format")
        if _get(answers, "access.isEnableIntranetApi") is None:
            add("answers.access.isEnableIntranetApi", "请选择是否提供校内 API")
        if _get(answers, "access.isEnableIntranetApi"):
            intranet_subdomain = require("access.intranetApiSubdomain", "请填写校内 API 子域名前缀")
            if _present(intranet_subdomain) and not _is_subdomain_prefix(intranet_subdomain):
                add("answers.access.intranetApiSubdomain", "校内 API 子域名前缀格式不正确", "format")
            require("access.intranetPingPath", "请填写校内 API 探测路径")
            require("access.intranetProbeTimeoutMs", "请填写校内 API 探测超时")

    frontend_deployment = require("access.frontendDeployment", "请选择 WisePenView 部署方式")
    if scope == "lan" and frontend_deployment != "container":
        add("answers.access.frontendDeployment", "仅局域网模式只能使用 Nginx 容器部署 WisePenView", "choice")
    if frontend_deployment == "container":
        require("access.frontendPort", "请填写前端容器宿主机端口")
        if _get(answers, "access.isEnableFrontendViaApisix") is None:
            add("answers.access.isEnableFrontendViaApisix", "请选择前端是否通过 APISIX 访问")

    if (
        _get(answers, "capabilities.isDeployDocumentService")
        and _get(answers, "capabilities.documentProcessor.type") == "onlyoffice"
    ):
        if scope == "public":
            onlyoffice_subdomain = require("access.onlyofficeSubdomain", "请填写 OnlyOffice 子域名前缀")
            if _present(onlyoffice_subdomain) and not _is_subdomain_prefix(onlyoffice_subdomain):
                add("answers.access.onlyofficeSubdomain", "OnlyOffice 子域名前缀格式不正确", "format")
        else:
            require("access.onlyofficePort", "请填写 OnlyOffice 宿主机端口")

    drawio_deployment = None
    if _get(answers, "access.isDeployDrawio"):
        drawio_deployment = require("access.drawioDeployment", "请选择 DrawIO 部署方式")
        if scope == "lan" and drawio_deployment != "container":
            add("answers.access.drawioDeployment", "仅局域网模式只能使用 Nginx 容器部署 DrawIO", "choice")
        if scope == "public":
            drawio_subdomain = require("access.drawioSubdomain", "请填写 DrawIO 子域名前缀")
            if _present(drawio_subdomain) and not _is_subdomain_prefix(drawio_subdomain):
                add("answers.access.drawioSubdomain", "DrawIO 子域名前缀格式不正确", "format")
        if drawio_deployment == "container":
            require("access.drawioPort", "请填写 DrawIO 容器宿主机端口")

    certificate_mode = None
    if protocol == "https":
        certificate_mode = require("certificate.mode", "请选择 HTTPS 证书管理方式")
        if certificate_mode not in {"wisepen-cert-manager", "external"}:
            add("answers.certificate.mode", "HTTPS 必须选择 WisePen cert-manager 或外部证书系统", "choice")
        if scope == "lan" and certificate_mode == "wisepen-cert-manager":
            add("answers.certificate.mode", "局域网 IP 无法通过公共 ACME CA 签发证书，请使用外部证书系统", "choice")

    drawio_oss_enabled = drawio_deployment == "oss"
    if frontend_deployment == "oss":
        for field, label in (
            ("accessKeyId", "前端 OSS AccessKey ID"),
            ("accessKeySecret", "前端 OSS AccessKey Secret"),
            ("endpoint", "前端 OSS Endpoint"),
            ("bucket", "前端 OSS Bucket"),
            ("cleanPolicy", "前端 OSS 清理策略"),
        ):
            require(f"frontendOss.{field}", f"请填写{label}")
    if drawio_oss_enabled:
        for field, label in (
            ("accessKeyId", "DrawIO OSS AccessKey ID"),
            ("accessKeySecret", "DrawIO OSS AccessKey Secret"),
            ("endpoint", "DrawIO OSS Endpoint"),
            ("bucket", "DrawIO OSS Bucket"),
        ):
            require(f"drawioOss.{field}", f"请填写{label}")
    if protocol == "https" and certificate_mode == "wisepen-cert-manager":
        for field, label in (
            ("accessKeyId", "cert-manager AliDNS AccessKey ID"),
            ("accessKeySecret", "cert-manager AliDNS AccessKey Secret"),
            ("acmeCa", "ACME CA"),
            ("acmeEmail", "ACME 注册邮箱"),
            ("stateSource", "证书状态来源"),
            ("isApplyWildcardCertificate", "是否申请通配符证书"),
            ("isDistributeToApisix", "是否向 APISIX 分发证书"),
        ):
            value = _get(answers, f"certificate.{field}")
            if value is None or not _present(value):
                add(f"answers.certificate.{field}", f"请填写{label}")
        if _get(answers, "certificate.stateSource") == "existing":
            require("certificate.acmeDataPath", "请填写已有 acme-data 路径")

    if artifact_mode == "jenkins-source":
        source = require("jenkins.source", "请选择 Jenkins 来源")
        if source == "managed":
            require("jenkins.managed.accessScope", "请选择 Jenkins 访问范围")
            if _get(answers, "jenkins.managed.accessScope") in {"local", "lan"}:
                require("jenkins.managed.port", "请填写 Jenkins 访问端口")
            if _get(answers, "jenkins.managed.accessScope") == "domain":
                require("jenkins.managed.domain", "请填写 Jenkins 访问域名")
            require("jenkins.managed.persistenceMode", "请选择 Jenkins 持久化位置策略")
            if _get(answers, "jenkins.managed.persistenceMode") == "custom":
                require("jenkins.managed.persistencePath", "请填写 Jenkins 自定义持久化路径")
        elif source == "external":
            for field, label in (
                ("url", "Jenkins URL"),
                ("username", "Jenkins 管理用户名"),
                ("apiToken", "Jenkins API Token"),
            ):
                value = _get(answers, f"jenkins.external.{field}")
                if value is None or not _present(value):
                    add(f"answers.jenkins.external.{field}", f"请填写{label}")

        target_mode = require("jenkins.deploymentTarget.mode", "请选择 Jenkins 部署目标机器")
        if target_mode == "remote":
            require("jenkins.deploymentTarget.remote.host", "请填写远程目标主机")
            require("jenkins.deploymentTarget.remote.sshPort", "请填写远程目标 SSH 端口")
            require("jenkins.deploymentTarget.remote.username", "请填写远程目标 SSH 用户名")
            auth_mode = require("jenkins.deploymentTarget.remote.authMode", "请选择远程目标 SSH 认证方式")
            if auth_mode == "password":
                require("jenkins.deploymentTarget.remote.password", "请填写远程目标 SSH 密码")
            elif auth_mode == "private-key":
                require("jenkins.deploymentTarget.remote.privateKey", "请填写远程目标 SSH 私钥")

    _ = scope, protocol
    return ValidationResult(valid=not errors, errors=errors)
