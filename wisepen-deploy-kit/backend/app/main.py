from __future__ import annotations

import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from .api import router as setup_router
from .store import JsonSetupStore


def create_app(data_dir: Path | None = None, static_dir: Path | None = None) -> FastAPI:
    project_root = Path(__file__).resolve().parents[2]
    configured_data_dir = os.getenv("WISEPEN_DEPLOY_DATA_DIR")
    resolved_data_dir = data_dir or (
        Path(configured_data_dir) if configured_data_dir else project_root / "data"
    )
    resolved_static_dir = static_dir or Path(__file__).resolve().parent.parent / "static"

    app = FastAPI(
        title="WisePenDeploy",
        description="WisePen 部署信息收集服务",
    )
    app.state.setup_store = JsonSetupStore(resolved_data_dir)
    app.include_router(setup_router)

    @app.get("/healthz", tags=["system"])
    async def healthz() -> dict[str, str]:
        return {"status": "ok"}

    assets_dir = resolved_static_dir / "assets"
    index_file = resolved_static_dir / "index.html"
    if assets_dir.exists():
        app.mount("/assets", StaticFiles(directory=assets_dir), name="assets")

    @app.get("/", include_in_schema=False)
    async def frontend_root():
        if index_file.exists():
            return FileResponse(index_file)
        return {
            "name": "WisePenDeploy",
            "message": "前端尚未构建，请在开发模式下启动 Vite。",
        }

    return app


app = create_app()
