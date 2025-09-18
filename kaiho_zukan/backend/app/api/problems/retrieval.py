import random
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from api.deps import get_current_user
from core.db import get_db
from models import (
    Answer,
    Explanation,
    ModelAnswer,
    Option,
    Problem,
    ProblemExplLike,
    ProblemImage,
    ProblemLike,
    User,
)

router = APIRouter()


@router.get("/{pid:int}")
def get_problem(
    pid: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    problem = db.get(Problem, pid)
    if not problem:
        raise HTTPException(404, "not found")
    options = (
        db.execute(
            select(Option).where(Option.problem_id == problem.id).order_by(Option.id.asc())
        )
        .scalars()
        .all()
    )
    images = (
        db.execute(
            select(ProblemImage)
            .where(ProblemImage.problem_id == problem.id)
            .order_by(ProblemImage.id.asc())
        )
        .scalars()
        .all()
    )
    model_answer = db.execute(
        select(ModelAnswer).where(
            ModelAnswer.problem_id == problem.id,
            ModelAnswer.user_id == user.id,
        )
    ).scalar_one_or_none()
    return {
        "id": problem.id,
        "title": problem.title,
        "body": problem.body,
        "qtype": problem.qtype,
        "child_id": problem.child_id,
        "grand_id": problem.grand_id,
        "images": [f"/uploads/{im.filename}" for im in images],
        "options": [
            {"id": o.id, "text": o.text, "is_correct": bool(o.is_correct)}
            for o in options
        ],
        "model_answer": getattr(model_answer, "content", None),
        "like_count": problem.like_count,
        "expl_like_count": problem.expl_like_count,
    }


@router.get("/for-explain")
def problems_for_explain(
    child_id: int,
    grand_id: Optional[int] = None,
    sort: str = "likes",
    db: Session = Depends(get_db),
):
    query = (
        select(
            Problem,
            func.coalesce(func.sum(Explanation.like_count), 0).label("elikes"),
            func.count(func.distinct(func.coalesce(Explanation.user_id, -1))).label(
                "ex_cnt"
            ),
        )
        .outerjoin(Explanation, Explanation.problem_id == Problem.id)
        .where(Problem.child_id == child_id)
    )
    if grand_id:
        query = query.where(Problem.grand_id == grand_id)
    query = query.group_by(Problem.id)
    if sort == "likes":
        query = query.order_by(text("elikes DESC"), Problem.id.desc())
    elif sort == "explanations":
        query = query.order_by(text("ex_cnt DESC"), Problem.id.desc())
    else:
        query = query.order_by(Problem.id.desc())
    rows = db.execute(query).all()
    items = [
        {
            "id": row[0].id,
            "title": row[0].title,
            "body": row[0].body,
            "qtype": row[0].qtype,
            "like_count": int(row[1]),
            "ex_cnt": int(row[2]),
        }
        for row in rows
    ]
    return {"items": items}


@router.get("/next")
def next_problem(
    request: Request,
    child_id: str = Query(...),
    grand_id: Optional[str] = Query(None),
    include_answered: Optional[bool] = Query(False),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        child_id_int = int(str(child_id).strip())
    except Exception:
        raise HTTPException(400, "child_id must be integer")
    grand_id_int: Optional[int] = None
    if grand_id is not None and str(grand_id).strip() != "":
        try:
            grand_id_int = int(str(grand_id).strip())
        except Exception:
            raise HTTPException(400, "grand_id must be integer")

    sub_query = select(Answer.problem_id).where(
        Answer.user_id == user.id, Answer.is_correct == True  # noqa: E712
    )
    query = select(Problem).where(Problem.child_id == child_id_int)
    if grand_id_int is not None:
        query = query.where(Problem.grand_id == grand_id_int)
    if not include_answered:
        query = query.where(Problem.id.notin_(sub_query))
    problems = db.execute(query).scalars().all()
    if not problems:
        return {"problem": None}
    weights = [max(1, p.like_count) for p in problems]
    choice = random.choices(problems, weights=weights, k=1)[0]
    selected = choice
    options = db.execute(select(Option).where(Option.problem_id == selected.id)).scalars().all()
    expl_liked = bool(
        db.execute(
            select(ProblemExplLike).where(
                ProblemExplLike.problem_id == selected.id,
                ProblemExplLike.user_id == user.id,
            )
        ).scalar_one_or_none()
    )
    liked = bool(
        db.execute(
            select(ProblemLike).where(
                ProblemLike.problem_id == selected.id,
                ProblemLike.user_id == user.id,
            )
        ).scalar_one_or_none()
    )
    images = (
        db.execute(
            select(ProblemImage)
            .where(ProblemImage.problem_id == selected.id)
            .order_by(ProblemImage.id.asc())
        )
        .scalars()
        .all()
    )
    return {
        "id": selected.id,
        "title": selected.title,
        "body": selected.body,
        "qtype": selected.qtype,
        "like_count": selected.like_count,
        "liked": liked,
        "expl_like_count": selected.expl_like_count,
        "expl_liked": expl_liked,
        "images": [f"/uploads/{im.filename}" for im in images],
        "options": [{"id": o.id, "text": o.text, "content": o.text} for o in options],
    }
