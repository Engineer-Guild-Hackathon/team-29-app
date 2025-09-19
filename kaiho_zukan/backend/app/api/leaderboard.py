from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import select, func

from api.deps import get_current_user
from core.db import get_db
from models import User, Problem, Explanation, ProblemLike, ExplanationLike
from api.explanations import _icon_url, _rank_info

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
    - created_problems: number of problems created
    - created_expl: number of explanations created (excluding AI)
    - likes_problems: total likes received on problems
    - likes_expl: total likes received on explanations (excluding AI)
    - points: users.points column
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
        raise HTTPException(status_code=400, detail="unknown metric")

    user_ids = [int(item.get("user_id")) for item in items if item.get("user_id") is not None]
    if user_ids:
        user_rows = db.execute(select(User).where(User.id.in_(user_ids))).scalars().all()
        user_map = {u.id: u for u in user_rows}
        problem_counts = {
            int(uid): int(cnt or 0)
            for uid, cnt in db.execute(
                select(Problem.created_by, func.count())
                .where(Problem.created_by.in_(user_ids))
                .group_by(Problem.created_by)
            ).all()
        }
        explanation_counts = {
            int(uid): int(cnt or 0)
            for uid, cnt in db.execute(
                select(Explanation.user_id, func.count())
                .where(Explanation.user_id.in_(user_ids))
                .group_by(Explanation.user_id)
            ).all()
        }
        for item in items:
            uid = item.get("user_id")
            if uid is None:
                continue
            uid_int = int(uid)
            user_obj = user_map.get(uid_int)
            icon_url = _icon_url(user_obj) if user_obj else None
            total_creations = problem_counts.get(uid_int, 0) + explanation_counts.get(uid_int, 0)
            rank_label, rank_level = _rank_info(int(total_creations))
            item["icon_url"] = icon_url
            item["rank"] = rank_label
            item["rank_level"] = rank_level

    return {"metric": metric, "items": items}
