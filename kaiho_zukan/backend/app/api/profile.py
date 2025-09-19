from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import select, func
import os
import uuid
import shutil

from api.deps import get_current_user
from core.db import get_db
from core.config import get_settings
from models import (
    User,
    Answer,
    Problem,
    Explanation,
    ProblemLike,
    ExplanationLike,
)

router = APIRouter(tags=["profile"])

settings = get_settings()


def _icon_url(user: User) -> str:
    if user.icon_path:
        return f"/uploads/{user.icon_path}"
    return f"https://api.dicebear.com/8.x/identicon/png?seed={user.username}"



def _rank_from_creations(total_creations: int) -> str:
    if total_creations <= 30:
        return "ブロンズ"
    elif total_creations <= 50:
        return "シルバー"
    elif total_creations <= 70:
        return "ゴールド"
    else:
        return "プラチナ"


def _profile_payload(user: User, db: Session, include_answer_stats: bool = True) -> dict:
    answer_count = (
        db.execute(select(func.count(Answer.id)).where(Answer.user_id == user.id)).scalar()
        or 0
    )
    correct_count = (
        db.execute(
            select(func.count(Answer.id)).where(Answer.user_id == user.id, Answer.is_correct == True)
        ).scalar()
        or 0
    )
    accuracy = float(round((correct_count / answer_count) * 100, 1)) if answer_count > 0 else 0.0

    question_count = (
        db.execute(select(func.count(Problem.id)).where(Problem.created_by == user.id)).scalar() or 0
    )
    answer_creation_count = (
        db.execute(select(func.count(Explanation.id)).where(Explanation.user_id == user.id)).scalar() or 0
    )
    question_likes = (
        db.execute(
            select(func.count(ProblemLike.id))
            .join(Problem, ProblemLike.problem_id == Problem.id)
            .where(Problem.created_by == user.id)
        ).scalar()
        or 0
    )
    explanation_likes = (
        db.execute(
            select(func.count(ExplanationLike.id))
            .join(Explanation, ExplanationLike.explanation_id == Explanation.id)
            .where(Explanation.user_id == user.id)
        ).scalar()
        or 0
    )

    total_creations = int(question_count) + int(answer_creation_count)
    rank = _rank_from_creations(total_creations)

    payload = {
        "id": user.id,
        "username": user.username,
        "nickname": user.nickname,
        "answer_count": int(answer_count),
        "correct_count": int(correct_count),
        "accuracy": accuracy,
        "question_count": int(question_count),
        "answer_creation_count": int(answer_creation_count),
        "question_likes": int(question_likes),
        "explanation_likes": int(explanation_likes),
        "rank": rank,
        "icon_url": _icon_url(user),
    }

    if not include_answer_stats:
        for key in ("answer_count", "correct_count", "accuracy"):
            payload.pop(key, None)

    return payload



@router.get("/profile")
def get_profile(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _profile_payload(user, db, include_answer_stats=True)



@router.get("/profile/{user_id}")
def get_profile_by_user_id(
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    target = db.get(User, user_id)
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    # reuse same payload but omit answer stats for other users
    include_answer = (target.id == current_user.id)
    return _profile_payload(target, db, include_answer_stats=include_answer)

@router.post("/profile/icon")
def upload_profile_icon(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="画像ファイルをアップロードしてください")

    ext = os.path.splitext(file.filename or "")[1].lower()
    content_type_map = {
        "image/png": ".png",
        "image/jpeg": ".jpg",
        "image/jpg": ".jpg",
        "image/gif": ".gif",
        "image/webp": ".webp",
    }
    if ext not in {".png", ".jpg", ".jpeg", ".gif", ".webp"}:
        ext = content_type_map.get(file.content_type, ".png")
    if ext == ".jpeg":
        ext = ".jpg"

    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    dest_dir = os.path.join(settings.UPLOAD_DIR, "profile", str(user.id))
    os.makedirs(dest_dir, exist_ok=True)

    filename = f"{uuid.uuid4().hex}{ext}"
    dest_path = os.path.join(dest_dir, filename)
    with open(dest_path, "wb") as out:
        shutil.copyfileobj(file.file, out)

    rel_path = os.path.relpath(dest_path, settings.UPLOAD_DIR).replace("\\", "/")

    if user.icon_path:
        old_path = os.path.join(settings.UPLOAD_DIR, user.icon_path)
        if os.path.exists(old_path):
            try:
                os.remove(old_path)
            except OSError:
                pass

    user.icon_path = rel_path
    db.add(user)
    db.commit()
    db.refresh(user)

    return {"icon_url": _icon_url(user)}
