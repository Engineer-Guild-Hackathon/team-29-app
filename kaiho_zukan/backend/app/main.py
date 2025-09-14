import os, logging
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from core.config import get_settings
from core.db import wait_for_db, create_all, ensure_schema, seed_categories
from api.router import api_router

settings = get_settings()
logger = logging.getLogger("uvicorn.error")

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

# uploads mount
try:
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")
except Exception:
    pass

@app.on_event("startup")
def on_start():
    wait_for_db()
    create_all()
    ensure_schema()
    seed_categories()

# 422バリデーションの簡易ロガー
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    try:
        logger.error("422 Validation error: url=%s method=%s errors=%s", str(request.url), request.method, exc.errors())
    except Exception:
        pass
    simple = []
    try:
        for e in exc.errors():
            simple.append({"type": e.get("type"), "loc": e.get("loc"), "msg": e.get("msg")})
    except Exception:
        simple = [{"msg": "validation error"}]
    return JSONResponse(status_code=422, content={"detail": simple})

# attach routers (全部 /api 直下に集約)
app.include_router(api_router, prefix="")
