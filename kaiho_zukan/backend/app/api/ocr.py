from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse
from PIL import Image
import io, base64
from core.config import get_settings

settings = get_settings()

router = APIRouter()


@router.post("/ocr")
async def ocr_image(
    file: UploadFile = File(..., description="Image file for OCR (png/jpg/jpeg)"),
    lang: str = Form("jpn+eng"),
):
    try:
        content = await file.read()
        if not content:
            raise HTTPException(status_code=400, detail="empty file")

        # Validate image
        try:
            Image.open(io.BytesIO(content))
        except Exception:
            raise HTTPException(status_code=400, detail="invalid image")

        # Prefer OpenAI (gpt-4o-mini) when enabled, otherwise 400 (or later: fallback to tesseract)
        if not (settings.OPENAI_ENABLED and settings.OPENAI_API_KEY):
            raise HTTPException(status_code=400, detail="openai disabled or missing api key")

        # Build data URL for image
        filename = (file.filename or "image").lower()
        ext = ".png"
        if filename.endswith((".jpg", ".jpeg")):
            ext = ".jpg"
        mime = "image/jpeg" if ext in (".jpg", ".jpeg") else "image/png"
        b64 = base64.b64encode(content).decode("ascii")
        data_url = f"data:{mime};base64,{b64}"

        # Call OpenAI vision with concise OCR instruction (Japanese+English)
        try:
            from openai import OpenAI
            client = OpenAI(api_key=settings.OPENAI_API_KEY)
            prompt = (
                "以下の画像内に含まれるテキストだけを正確に抽出して返してください。"
                "改行も適切に保持し、説明や前後の補足は一切不要です。"
            )
            message = [
                {"type": "text", "text": prompt},
                {"type": "image_url", "image_url": {"url": data_url}},
            ]
            resp = client.chat.completions.create(
                model=(settings.OPENAI_MODEL or "gpt-4o-mini"),
                messages=[{"role": "user", "content": message}],
                temperature=0.0,
                max_tokens=1500,
            )
            text = (resp.choices[0].message.content or "").strip()
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"openai error: {e}")

        return JSONResponse({"ok": True, "text": text, "lang": lang, "model": settings.OPENAI_MODEL})
    finally:
        await file.close()
