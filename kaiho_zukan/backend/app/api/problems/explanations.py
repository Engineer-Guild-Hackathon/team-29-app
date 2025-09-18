import os
import random
import threading
import time
from typing import List, Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from api.deps import get_current_user
from core.config import get_settings
from core.db import get_db
from models import (
    Answer,
    Explanation,
    ExplanationImage,
    ExplanationLike,
    ExplanationWrongFlag,
    Problem,
    User,
    AiJudgement,
)
from services.ai_judge import judge_problem_for_user

settings = get_settings()
router = APIRouter()


@router.get("/{pid:int}/explanations")
def problem_explanations(
    pid: int,
    sort: str = Query("likes"),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = select(Explanation).where(Explanation.problem_id == pid)
    if sort == "likes":
        query = query.order_by(Explanation.like_count.desc(), Explanation.id.asc())
    elif sort == "recent":
        query = query.order_by(Explanation.id.desc())
    explanations = db.execute(query).scalars().all()

    explanation_ids = [explanation.id for explanation in explanations]
    liked_rows = db.execute(
        select(ExplanationLike.explanation_id).where(
            ExplanationLike.user_id == user.id,
            ExplanationLike.explanation_id.in_(explanation_ids)
            if explanation_ids
            else (ExplanationLike.explanation_id == -1),
        )
    ).all() if explanation_ids else []
    liked_ids = {int(row[0]) for row in liked_rows}

    wrong_flag_counts = {eid: 0 for eid in explanation_ids}
    if explanation_ids:
        rows = db.execute(
            select(ExplanationWrongFlag.explanation_id, func.count())
            .where(ExplanationWrongFlag.explanation_id.in_(explanation_ids))
            .group_by(ExplanationWrongFlag.explanation_id)
        ).all()
        for explanation_id, count in rows:
            wrong_flag_counts[int(explanation_id)] = int(count or 0)
    flagged_rows = db.execute(
        select(ExplanationWrongFlag.explanation_id).where(
            ExplanationWrongFlag.user_id == user.id,
            ExplanationWrongFlag.explanation_id.in_(explanation_ids)
            if explanation_ids
            else (ExplanationWrongFlag.explanation_id == -1),
        )
    ).all() if explanation_ids else []
    flagged_ids = {int(row[0]) for row in flagged_rows}

    user_ids = list(
        {
            explanation.user_id
            for explanation in explanations
            if getattr(explanation, "user_id", None) is not None
        }
    )
    judgement_map: dict[int, AiJudgement] = {}
    if user_ids:
        judgements = (
            db.execute(
                select(AiJudgement).where(
                    AiJudgement.problem_id == pid,
                    AiJudgement.user_id.in_(user_ids),
                )
            )
            .scalars()
            .all()
        )
        judgement_map = {judgement.user_id: judgement for judgement in judgements}

    try:
        solvers = db.execute(
            select(func.count(func.distinct(Answer.user_id))).where(Answer.problem_id == pid)
        ).scalar_one() or 0
    except Exception:
        solvers = 0

    items = []
    for explanation in explanations:
        if explanation.user_id is None:
            created_by = "AI"
        else:
            user_row = db.get(User, explanation.user_id)
            created_by = (
                user_row.nickname
                if user_row and user_row.nickname
                else (user_row.username if user_row else None)
            )

        images = (
            db.execute(
                select(ExplanationImage)
                .where(ExplanationImage.explanation_id == explanation.id)
                .order_by(ExplanationImage.id.asc())
            )
            .scalars()
            .all()
        )
        image_urls = [f"/uploads/{image.filename}" for image in images]

        judgement = judgement_map.get(getattr(explanation, "user_id", None))
        wrong_count = wrong_flag_counts.get(explanation.id, 0)
        crowd_maybe_wrong = solvers >= 10 and (wrong_count / max(1, solvers)) > 0.3

        items.append(
            {
                "id": explanation.id,
                "content": explanation.content,
                "likes": explanation.like_count,
                "is_ai": explanation.user_id is None,
                "option_index": explanation.option_index,
                "user_id": explanation.user_id,
                "by": created_by,
                "liked": explanation.id in liked_ids,
                "images": image_urls,
                "ai_is_wrong": (judgement.is_wrong if judgement else None),
                "ai_judge_score": (judgement.score if judgement else None),
                "ai_judge_reason": (judgement.reason if judgement else None),
                "wrong_flag_count": wrong_count,
                "flagged_wrong": explanation.id in flagged_ids,
                "solvers_count": int(solvers),
                "crowd_maybe_wrong": bool(crowd_maybe_wrong),
            }
        )

    if sort not in ("likes", "recent"):
        random.shuffle(items)

    return {"items": items}


@router.post("/{pid:int}/explanations")
def create_explanation_under_problem(
    pid: int,
    content: str = Form(...),
    images: List[UploadFile] = File(None),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    problem = db.get(Problem, pid)
    if not problem:
        raise HTTPException(404, "not found")

    explanation = Explanation(problem_id=pid, user_id=user.id, content=content)
    db.add(explanation)
    db.flush()

    if images:
        os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
        subdir = os.path.join(settings.UPLOAD_DIR, "expl", str(explanation.id))
        os.makedirs(subdir, exist_ok=True)
        for upload in images:
            try:
                blob = upload.file.read()
                if not blob:
                    continue
                base = os.path.basename(upload.filename or "image")
                name, ext = os.path.splitext(base)
                ext = (ext or "").lower()
                if ext not in (".png", ".jpg", ".jpeg", ".gif", ".webp"):
                    ext = ".bin"
                filename = (
                    f"e{explanation.id}_{int(time.time() * 1000)}_{random.randint(1000, 9999)}{ext}"
                )
                path = os.path.join(subdir, filename)
                with open(path, "wb") as out:
                    out.write(blob)
                rel_path = os.path.relpath(path, settings.UPLOAD_DIR).replace("\\", "/")
                db.add(ExplanationImage(explanation_id=explanation.id, filename=rel_path))
            except Exception:
                continue

    db.commit()
    if settings.OPENAI_ENABLED and settings.OPENAI_API_KEY:
        threading.Thread(
            target=judge_problem_for_user, args=(pid, user.id), daemon=True
        ).start()
    return {"ok": True, "id": explanation.id}


@router.get("/{pid:int}/my-explanations")
def get_my_explanations_for_problem(
    pid: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = db.execute(
        select(Explanation).where(
            Explanation.problem_id == pid,
            Explanation.user_id == user.id,
        )
    ).scalars().all()
    overall: Optional[str] = None
    options: dict[int, Optional[str]] = {}
    for explanation in rows:
        if explanation.option_index is None:
            overall = explanation.content
        else:
            options[int(explanation.option_index)] = explanation.content
    max_index = max(options.keys()) if options else -1
    option_list = [options.get(i) for i in range(max_index + 1)]
    return {"overall": overall, "options": option_list}


@router.delete("/{pid:int}/my-explanations")
def delete_my_explanations_for_problem(
    pid: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    explanation_ids = [
        row[0]
        for row in db.execute(
            select(Explanation.id).where(
                Explanation.problem_id == pid,
                Explanation.user_id == user.id,
            )
        ).all()
    ]
    if not explanation_ids:
        return {"ok": True, "deleted": 0}
    db.query(ExplanationImage).filter(
        ExplanationImage.explanation_id.in_(explanation_ids)
    ).delete(synchronize_session=False)
    db.query(ExplanationLike).filter(
        ExplanationLike.explanation_id.in_(explanation_ids)
    ).delete(synchronize_session=False)
    deleted = db.query(Explanation).filter(Explanation.id.in_(explanation_ids)).delete(
        synchronize_session=False
    )
    db.commit()
    return {"ok": True, "deleted": len(explanation_ids)}
