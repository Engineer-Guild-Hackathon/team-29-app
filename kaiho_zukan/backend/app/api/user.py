from fastapi import APIRouter, Depends
from sqlalchemy import select, func
from sqlalchemy.orm import Session

from api.deps import get_current_user
from core.db import get_db
from models import User, Problem, Explanation, Answer


router = APIRouter(prefix="/user", tags=["user"]) 


@router.get("/profile")
def get_profile(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    # Answers stats
    answers_count = db.scalar(select(func.count(Answer.id)).where(Answer.user_id == user.id)) or 0
    correct_answers_count = db.scalar(
        select(func.count(Answer.id)).where(Answer.user_id == user.id, Answer.is_correct.is_(True))
    ) or 0
    accuracy_rate = float(round((correct_answers_count / answers_count * 100.0) if answers_count else 0.0, 1))

    # Contributions
    problems_created = db.scalar(select(func.count(Problem.id)).where(Problem.created_by == user.id)) or 0
    solutions_created = db.scalar(select(func.count(Explanation.id)).where(Explanation.user_id == user.id)) or 0

    # Likes received on own content
    problem_likes = db.scalar(
        select(func.coalesce(func.sum(Problem.like_count), 0)).where(Problem.created_by == user.id)
    ) or 0
    solution_likes = db.scalar(
        select(func.coalesce(func.sum(Explanation.like_count), 0)).where(Explanation.user_id == user.id)
    ) or 0

    total_likes = int(problem_likes) + int(solution_likes)

    # Rank logic
    if total_likes >= 100:
        rank = "Platinum"
    elif total_likes >= 50:
        rank = "Gold"
    elif total_likes >= 20:
        rank = "Silver"
    else:
        rank = "Bronze"

    return {
        "answers_count": int(answers_count),
        "correct_answers_count": int(correct_answers_count),
        "accuracy_rate": accuracy_rate,
        "problems_created": int(problems_created),
        "solutions_created": int(solutions_created),
        "problem_likes": int(problem_likes),
        "solution_likes": int(solution_likes),
        "rank": rank,
    }

