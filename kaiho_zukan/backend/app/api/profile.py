from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import select, func

from api.deps import get_current_user
from core.db import get_db
from models import (
    User,
    Answer,
    Problem,
    Explanation,
    ProblemLike,
    ExplanationLike,
)

router = APIRouter(tags=["profile"])


def _rank_from_likes(total_likes: int) -> str:
    if total_likes <= 10:
        return "ブロンズ"
    elif total_likes <= 20:
        return "シルバー"
    elif total_likes <= 30:
        return "ゴールド"
    else:
        return "プラチナ"


@router.get("/profile")
def get_profile(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
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

    total_likes = int(question_likes) + int(explanation_likes)
    rank = _rank_from_likes(total_likes)

    icon_url = f"https://api.dicebear.com/8.x/identicon/png?seed={user.username}"

    return {
        "username": user.username,
        "answer_count": int(answer_count),
        "correct_count": int(correct_count),
        "accuracy": accuracy,
        "question_count": int(question_count),
        "answer_creation_count": int(answer_creation_count),
        "question_likes": int(question_likes),
        "explanation_likes": int(explanation_likes),
        "rank": rank,
        "icon_url": icon_url,
    }
