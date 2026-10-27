from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request, Response, status

from .models import SaveSetupRequest, SetupDocument, ValidationResult
from .store import JsonSetupStore, RevisionConflictError
from .validation import validate_complete


router = APIRouter(prefix="/api/v1/setup", tags=["setup"])


def _store(request: Request) -> JsonSetupStore:
    return request.app.state.setup_store


def _conflict(error: RevisionConflictError) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail={
            "code": "revision_conflict",
            "message": "收集信息已在其他页面中修改，请重新加载。",
            "expectedRevision": error.expected,
            "actualRevision": error.actual,
        },
    )


@router.get("", response_model=SetupDocument)
async def get_setup(request: Request) -> SetupDocument:
    return await _store(request).load()


@router.put("", response_model=SetupDocument)
async def save_setup(payload: SaveSetupRequest, request: Request) -> SetupDocument:
    try:
        return await _store(request).save(payload)
    except RevisionConflictError as error:
        raise _conflict(error) from error


@router.post("/validate", response_model=ValidationResult)
async def validate_setup(request: Request) -> ValidationResult:
    document = await _store(request).load()
    return validate_complete(document)


@router.post("/complete", response_model=SetupDocument)
async def complete_setup(payload: dict[str, int], request: Request) -> SetupDocument:
    document = await _store(request).load()
    result = validate_complete(document)
    if not result.valid:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=result.model_dump(mode="json", by_alias=True),
        )

    expected_revision = payload.get("revision")
    if not isinstance(expected_revision, int):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="revision is required",
        )
    try:
        return await _store(request).mark_collected(expected_revision)
    except RevisionConflictError as error:
        raise _conflict(error) from error


@router.delete("", response_model=SetupDocument)
async def reset_setup(request: Request, response: Response) -> SetupDocument:
    response.status_code = status.HTTP_200_OK
    return await _store(request).reset()
