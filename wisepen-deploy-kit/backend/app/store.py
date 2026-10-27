from __future__ import annotations

import asyncio
import os
import shutil
from datetime import datetime, timezone
from pathlib import Path

from .models import SaveSetupRequest, SetupDocument


class RevisionConflictError(RuntimeError):
    def __init__(self, expected: int, actual: int) -> None:
        super().__init__(f"revision conflict: expected {expected}, actual {actual}")
        self.expected = expected
        self.actual = actual


class JsonSetupStore:
    def __init__(self, data_dir: Path) -> None:
        self.data_dir = data_dir
        self.path = data_dir / "setup.json"
        self.backup_path = data_dir / "setup.json.bak"
        self._lock = asyncio.Lock()

    @staticmethod
    def _now() -> datetime:
        return datetime.now(timezone.utc)

    def _empty_document(self) -> SetupDocument:
        now = self._now()
        return SetupDocument(created_at=now, updated_at=now)

    def _load_unlocked(self) -> SetupDocument:
        if not self.path.exists():
            return self._empty_document()
        return SetupDocument.model_validate_json(self.path.read_text(encoding="utf-8"))

    async def load(self) -> SetupDocument:
        async with self._lock:
            return self._load_unlocked()

    async def save(self, request: SaveSetupRequest) -> SetupDocument:
        async with self._lock:
            current = self._load_unlocked()
            if request.revision != current.revision:
                raise RevisionConflictError(request.revision, current.revision)

            now = self._now()
            stages = current.stages.model_copy(deep=True)
            status = current.status
            if request.current_stage == "collection":
                stages.welcome.status = "completed"
                stages.collection.status = "in_progress"
                stages.collection.current_step = request.current_step
                stages.generation.status = "locked"
                stages.execution.status = "locked"
                status = "draft"

            document = SetupDocument(
                revision=current.revision + 1,
                status=status,
                current_stage=request.current_stage,
                stages=stages,
                created_at=current.created_at,
                updated_at=now,
                answers=request.answers,
            )
            self._write_unlocked(document)
            return document

    async def mark_collected(self, expected_revision: int) -> SetupDocument:
        async with self._lock:
            current = self._load_unlocked()
            if expected_revision != current.revision:
                raise RevisionConflictError(expected_revision, current.revision)
            stages = current.stages.model_copy(deep=True)
            stages.welcome.status = "completed"
            stages.collection.status = "completed"
            stages.generation.status = "ready"
            stages.execution.status = "locked"
            document = current.model_copy(
                update={
                    "revision": current.revision + 1,
                    "status": "collected",
                    "current_stage": "generation",
                    "stages": stages,
                    "updated_at": self._now(),
                }
            )
            self._write_unlocked(document)
            return document

    async def reset(self) -> SetupDocument:
        async with self._lock:
            if self.path.exists():
                self.path.unlink()
            if self.backup_path.exists():
                self.backup_path.unlink()
            return self._empty_document()

    def _write_unlocked(self, document: SetupDocument) -> None:
        self.data_dir.mkdir(parents=True, exist_ok=True)
        temporary_path = self.data_dir / "setup.json.tmp"
        content = document.model_dump_json(by_alias=True, indent=2)

        with temporary_path.open("w", encoding="utf-8", newline="\n") as output:
            output.write(content)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())

        if self.path.exists():
            shutil.copy2(self.path, self.backup_path)
        os.replace(temporary_path, self.path)
