from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import select, func

from api.deps import get_current_user
from core.db import get_db
from models import User, Problem, Explanation, ProblemLike, ExplanationLike

router = APIRouter(prefix="/leaderboard", tags=["leaderboard"])


@router.get("")
def leaderboard(
    metric: str = Query("created_problems"),
    limit: int = Query(20, ge=1, le=100),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Supported metrics:
    - created_problems: 作問数（Problem.created_by）
    - created_expl: 解説作成数（Explanation.user_id, AIは除外）
    - likes_problems: 自分の問題に付いたいいね合計
    - likes_expl: 自分の解説に付いたいいね合計（AIは除外）
    - points: users.points をそのまま
    """
    items: list[dict] = []

    if metric == "created_problems":
        q = (
            select(User.id, User.username, User.nickname, func.count(Problem.id).label("value"))
            .join(Problem, Problem.created_by == User.id)
            .group_by(User.id)
            .order_by(func.count(Problem.id).desc(), User.id.asc())
            .limit(limit)
        )
        rows = db.execute(q).all()
        items = [
            {"user_id": uid, "username": un, "nickname": nn, "value": int(v or 0)}
            for uid, un, nn, v in rows
        ]

    elif metric == "created_expl":
        q = (
            select(User.id, User.username, User.nickname, func.count(Explanation.id).label("value"))
            .join(Explanation, Explanation.user_id == User.id)
            .where(Explanation.user_id != None)
            .group_by(User.id)
            .order_by(func.count(Explanation.id).desc(), User.id.asc())
            .limit(limit)
        )
        rows = db.execute(q).all()
        items = [
            {"user_id": uid, "username": un, "nickname": nn, "value": int(v or 0)}
            for uid, un, nn, v in rows
        ]

    elif metric == "likes_problems":
        q = (
            select(User.id, User.username, User.nickname, func.count(ProblemLike.id).label("value"))
            .join(Problem, Problem.created_by == User.id)
            .join(ProblemLike, ProblemLike.problem_id == Problem.id)
            .group_by(User.id)
            .order_by(func.count(ProblemLike.id).desc(), User.id.asc())
            .limit(limit)
        )
        rows = db.execute(q).all()
        items = [
            {"user_id": uid, "username": un, "nickname": nn, "value": int(v or 0)}
            for uid, un, nn, v in rows
        ]

    elif metric == "likes_expl":
        q = (
            select(User.id, User.username, User.nickname, func.count(ExplanationLike.id).label("value"))
            .join(Explanation, Explanation.user_id == User.id)
            .join(ExplanationLike, ExplanationLike.explanation_id == Explanation.id)
            .where(Explanation.user_id != None)
            .group_by(User.id)
            .order_by(func.count(ExplanationLike.id).desc(), User.id.asc())
            .limit(limit)
        )
        rows = db.execute(q).all()
        items = [
            {"user_id": uid, "username": un, "nickname": nn, "value": int(v or 0)}
            for uid, un, nn, v in rows
        ]

    elif metric == "points":
        q = (
            select(User.id, User.username, User.nickname, User.points.label("value"))
            .order_by(User.points.desc(), User.id.asc())
            .limit(limit)
        )
        rows = db.execute(q).all()
        items = [
            {"user_id": uid, "username": un, "nickname": nn, "value": int(v or 0)}
            for uid, un, nn, v in rows
        ]
    else:
        # unknown metric
        raise HTTPException(status_code=400, detail="unknown metric")

    return {"metric": metric, "items": items}

