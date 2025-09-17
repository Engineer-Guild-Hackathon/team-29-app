from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import select

from api.deps import get_current_user
from core.db import get_db
from models import User, Notification, Problem

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("")
def list_notifications(
    unseen_only: bool = False,
    limit: int = 50,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    q = select(Notification).where(Notification.user_id == user.id).order_by(Notification.created_at.desc())
    if unseen_only:
        q = q.where(Notification.seen == False)  # noqa: E712 (SQLAlchemy boolean expr)
    rows = db.execute(q.limit(max(1, min(200, limit)))).scalars().all()
    items = [
        (n, db.get(Problem, n.problem_id) if n.problem_id else None, db.get(User, n.actor_user_id) if n.actor_user_id else None)
        for n in rows
    ]
    out = []
    for n, prob, actor in items:
        out.append({
            "id": n.id,
            "type": n.type,
            "problem_id": n.problem_id,
            "problem_title": getattr(prob, "title", None),
            "actor_user_id": n.actor_user_id,
            "actor_name": getattr(actor, "nickname", None) or getattr(actor, "username", None),
            "ai_judged_wrong": n.ai_judged_wrong,
            "crowd_judged_wrong": n.crowd_judged_wrong,
            "seen": bool(n.seen),
            "created_at": n.created_at.isoformat() if hasattr(n.created_at, 'isoformat') else n.created_at,
        })
    return {"items": out}


@router.post("/seen")
def mark_seen(
    ids: List[int],
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not isinstance(ids, list) or not ids:
        return {"ok": True, "updated": 0}
    rows = db.execute(
        select(Notification).where(Notification.user_id == user.id, Notification.id.in_(ids))
    ).scalars().all()
    for n in rows:
        n.seen = True
    db.commit()
    return {"ok": True, "updated": len(rows)}

