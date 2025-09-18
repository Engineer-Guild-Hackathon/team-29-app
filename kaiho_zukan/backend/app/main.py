# backend/app/main.py
import os
import logging
from pathlib import Path

from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles

from core.config import get_settings
from core.db import wait_for_db, create_all, ensure_schema, seed_categories
from api.router import api_router

settings = get_settings()
logger = logging.getLogger("uvicorn.error")

app = FastAPI()

# CORS (必要に応じて絞ってください)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- /static 配信（リポジトリ同梱の画像やCSSなど） ---
BASE_DIR = Path(__file__).resolve().parent
STATIC_DIR = BASE_DIR / "static"
# 保険として作成（リポジトリに static/ を含める想定）
STATIC_DIR.mkdir(exist_ok=True)
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

# /icon で icon.png を直接返す
ICON_PATH = STATIC_DIR / "icon.png"

@app.get("/icon", response_class=FileResponse)
def get_icon():
    if not ICON_PATH.exists():
        raise HTTPException(status_code=404, detail="icon not found")
    return FileResponse(
        ICON_PATH,
        media_type="image/png",
        filename="icon.png",
        headers={"Cache-Control": "public, max-age=86400"},
    )

# --- /uploads 配信（実行時に書き込むアップロード先） ---
# settings.UPLOAD_DIR が存在しなくても作る
try:
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")
except Exception:
    # ローカル/CI などで設定が未定義でもアプリ起動は継続
    pass

# DB 初期化など（同期ブロッキングでOKな想定）
@app.on_event("startup")
def on_start():
    try:
        wait_for_db()
        create_all()
        ensure_schema()
        seed_categories()
    except Exception as e:
        logger.error("Startup error: %s", e)

# 422 バリデーションの簡易ロガー
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    try:
        logger.error(
            "422 Validation error: url=%s method=%s errors=%s",
            str(request.url),
            request.method,
            exc.errors(),
        )
    except Exception:
        pass

    simple = []
    try:
        for e in exc.errors():
            simple.append(
                {"type": e.get("type"), "loc": e.get("loc"), "msg": e.get("msg")}
            )
    except Exception:
        simple = [{"msg": "validation error"}]

    return JSONResponse(status_code=422, content={"detail": simple})

# ルーター集約（api_router 側の prefix 定義に従う）
app.include_router(api_router, prefix="")
