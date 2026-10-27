from __future__ import annotations

from pathlib import Path

from fastapi.testclient import TestClient

from app.main import create_app


def client(tmp_path: Path) -> TestClient:
    return TestClient(create_app(data_dir=tmp_path, static_dir=tmp_path / "static"))


def test_empty_document_is_returned_when_file_does_not_exist(tmp_path: Path) -> None:
    response = client(tmp_path).get("/api/v1/setup")

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "empty"
    assert body["revision"] == 0
    assert "schemaVersion" not in body
    assert body["currentStage"] == "welcome"
    assert body["stages"]["welcome"]["status"] == "ready"
    assert body["stages"]["collection"]["status"] == "locked"
    assert body["stages"]["generation"]["status"] == "locked"
    assert body["stages"]["execution"]["status"] == "locked"
    assert all(value is None for value in body["answers"].values())


def test_save_is_atomic_and_increments_revision(tmp_path: Path) -> None:
    api = client(tmp_path)
    response = api.put(
        "/api/v1/setup",
        json={
            "revision": 0,
            "currentStage": "collection",
            "currentStep": "capabilities",
            "answers": {
                "basic": {
                    "deploymentName": "test",
                    "environment": "testing",
                }
            },
        },
    )

    assert response.status_code == 200
    assert response.json()["revision"] == 1
    assert response.json()["status"] == "draft"
    assert response.json()["currentStage"] == "collection"
    assert response.json()["stages"]["welcome"]["status"] == "completed"
    assert response.json()["stages"]["collection"]["status"] == "in_progress"
    assert response.json()["stages"]["collection"]["currentStep"] == "capabilities"
    assert (tmp_path / "setup.json").exists()


def test_revision_conflict_does_not_overwrite_document(tmp_path: Path) -> None:
    api = client(tmp_path)
    payload = {"revision": 0, "currentStage": "collection", "currentStep": "basic", "answers": {}}
    assert api.put("/api/v1/setup", json=payload).status_code == 200

    response = api.put("/api/v1/setup", json=payload)

    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "revision_conflict"
    assert api.get("/api/v1/setup").json()["revision"] == 1


def test_old_or_unknown_fields_are_rejected(tmp_path: Path) -> None:
    response = client(tmp_path).put(
        "/api/v1/setup",
        json={
            "revision": 0,
            "currentStage": "collection",
            "currentStep": "basic",
            "answers": {"basic": {"proxyEnabled": False}},
        },
    )

    assert response.status_code == 422
    assert not (tmp_path / "setup.json").exists()


def test_complete_rejects_incomplete_answers(tmp_path: Path) -> None:
    api = client(tmp_path)
    api.put(
        "/api/v1/setup",
        json={"revision": 0, "currentStage": "collection", "currentStep": "review", "answers": {}},
    )

    response = api.post("/api/v1/setup/complete", json={"revision": 1})

    assert response.status_code == 422
    detail = response.json()["detail"]
    assert detail["valid"] is False
    assert any(issue["path"] == "answers.basic.deploymentName" for issue in detail["errors"])


def test_complete_marks_valid_answers_as_collected(tmp_path: Path) -> None:
    api = client(tmp_path)
    infrastructure = {
        name: {"mode": "managed", "managed": {}, "external": {}}
        for name in (
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
    }
    infrastructure["credentialPolicy"] = {"mode": "auto-gen"}
    answers = {
        "basic": {
            "deploymentName": "production",
            "environment": "production",
            "timezone": "Asia/Shanghai",
            "persistenceRoot": "/opt/wisepen",
            "isUseProxy": False,
        },
        "deployment": {"artifactMode": "official-images"},
        "capabilities": {
            "isDeployDocsService": False,
            "isDeployDocumentService": False,
            "isDeployNoteService": False,
            "isDeployAiAssetService": False,
            "isDeploySandboxService": False,
            "isDeployCampusExtensionService": False,
            "mineru": {"mode": "none"},
        },
        "infrastructure": infrastructure,
        "operations": {
            "isDeployObservability": False,
            "isDeployGrafana": False,
            "isDeployApisixDashboard": False,
            "isDeployKibana": False,
            "isDeployKafkaUi": False,
            "credentialPolicy": {"mode": "auto-gen"},
        },
        "access": {
            "scope": "lan",
            "siteProtocol": "http",
            "siteAddress": "192.0.2.10",
            "isEnableIntranetApi": False,
            "frontendDeployment": "container",
            "frontendPort": 8085,
            "isEnableFrontendViaApisix": True,
            "isDeployDrawio": False,
        },
        "frontendOss": None,
        "drawioOss": None,
        "certificate": {"mode": "external"},
        "jenkins": None,
    }
    saved = api.put(
        "/api/v1/setup",
        json={"revision": 0, "currentStage": "collection", "currentStep": "review", "answers": answers},
    )
    assert saved.status_code == 200

    response = api.post("/api/v1/setup/complete", json={"revision": 1})

    assert response.status_code == 200
    assert response.json()["status"] == "collected"
    assert response.json()["revision"] == 2
    assert response.json()["currentStage"] == "generation"
    assert response.json()["stages"]["collection"]["status"] == "completed"
    assert response.json()["stages"]["generation"]["status"] == "ready"
    assert response.json()["stages"]["execution"]["status"] == "locked"


def test_reset_removes_persisted_document(tmp_path: Path) -> None:
    api = client(tmp_path)
    api.put(
        "/api/v1/setup",
        json={"revision": 0, "currentStage": "collection", "currentStep": "basic", "answers": {}},
    )

    response = api.delete("/api/v1/setup")

    assert response.status_code == 200
    assert response.json()["status"] == "empty"
    assert not (tmp_path / "setup.json").exists()
