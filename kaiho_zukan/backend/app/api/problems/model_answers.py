from typing import Optional

from fastapi import APIRouter, Depends, Form, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from api.deps import get_current_user
from core.db import get_db
from models import ModelAnswer, Problem, User

router = APIRouter()


@router.post("/{pid:int}/model-answer")
def upsert_model_answer(
    pid: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    content: Optional[str] = Form(None),
    content_q: Optional[str] = Query(None),
):
    problem = db.get(Problem, pid)
    if not problem:
        raise HTTPException(404, "not found")
    text = (content if (content is not None) else content_q or "").strip()
    existing = db.execute(
        select(ModelAnswer).where(
            ModelAnswer.problem_id == pid,
            ModelAnswer.user_id == user.id,
        )
    ).scalar_one_or_none()
    if not text:
        if existing:
            db.delete(existing)
            db.commit()
        return {"ok": True}
    if existing:
        existing.content = text
    else:
        db.add(ModelAnswer(problem_id=pid, user_id=user.id, content=text))
    db.commit()
    return {"ok": True}


@router.get("/{pid:int}/model-answer")
def get_my_model_answer(
    pid: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    model_answer = db.execute(
        select(ModelAnswer).where(
            ModelAnswer.problem_id == pid,
            ModelAnswer.user_id == user.id,
        )
    ).scalar_one_or_none()
    return {"content": getattr(model_answer, "content", None)}


@router.get("/{pid:int}/model-answers")
def list_model_answers(
    pid: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = db.execute(
        select(ModelAnswer.content, ModelAnswer.user_id, User.username, User.nickname)
        .outerjoin(User, User.id == ModelAnswer.user_id)
        .where(ModelAnswer.problem_id == pid)
        .order_by(ModelAnswer.id.desc())
    ).all()
    items = []
    for content, user_id, username, nickname in rows:
        if user_id is None:
            items.append(
                {
                    "user_id": None,
                    "username": "AI",
                    "nickname": "AI",
                    "content": content,
                    "is_ai": True,
                }
            )
        else:
            items.append(
                {
                    "user_id": int(user_id),
                    "username": username,
                    "nickname": nickname,
                    "content": content,
                    "is_ai": False,
                }
            )
    return {"items": items}
