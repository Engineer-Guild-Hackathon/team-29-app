from typing import Optional

from fastapi import APIRouter, Depends, Form, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from api.deps import get_current_user
from core.db import get_db
from models import Answer, Explanation, Problem, User

router = APIRouter()


@router.post("/{pid:int}/answer")
def answer_problem(
    pid: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    selected_option_id: Optional[int] = Form(None),
    free_text: Optional[str] = Form(None),
    is_correct: Optional[bool] = Form(None),
):
    problem = db.get(Problem, pid)
    if not problem:
        raise HTTPException(404, "not found")
    correct: Optional[bool] = None
    if problem.qtype == "mcq":
        if selected_option_id is None:
            raise HTTPException(400, "option required")
        correct = None if is_correct is None else bool(is_correct)
    else:
        correct = None if is_correct is None else bool(is_correct)
    db.add(
        Answer(
            problem_id=pid,
            user_id=user.id,
            selected_option_id=selected_option_id,
            free_text=free_text,
            is_correct=correct,
        )
    )
    if correct:
        user.points += 1
    db.commit()
    explanations = db.execute(
        select(Explanation)
        .where(Explanation.problem_id == pid)
        .order_by(Explanation.like_count.desc(), Explanation.id.asc())
    ).scalars().all()
    return {
        "is_correct": correct,
        "explanations": [
            {
                "id": explanation.id,
                "content": explanation.content,
                "likes": explanation.like_count,
                "is_ai": explanation.user_id is None,
            }
            for explanation in explanations
        ],
    }
