from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from api.deps import get_current_user
from core.db import get_db
from models import Notification, Problem, ProblemExplLike, ProblemLike, User

router = APIRouter()


@router.post("/{pid:int}/like")
def like_problem(
    pid: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    problem = db.get(Problem, pid)
    if not problem:
        raise HTTPException(404, "not found")
    exists = db.execute(
        select(ProblemLike).where(
            ProblemLike.problem_id == pid,
            ProblemLike.user_id == user.id,
        )
    ).scalar_one_or_none()
    if not exists:
        db.add(ProblemLike(problem_id=pid, user_id=user.id))
        problem.like_count += 1
        try:
            if problem.created_by and problem.created_by != user.id:
                existing_notification = db.execute(
                    select(Notification).where(
                        Notification.user_id == problem.created_by,
                        Notification.type == "problem_like",
                        Notification.problem_id == problem.id,
                        Notification.actor_user_id == user.id,
                    )
                ).scalar_one_or_none()
                if not existing_notification:
                    db.add(
                        Notification(
                            user_id=problem.created_by,
                            type="problem_like",
                            problem_id=problem.id,
                            actor_user_id=user.id,
                            ai_judged_wrong=None,
                            crowd_judged_wrong=None,
                        )
                    )
        except Exception:
            pass
        db.commit()
    return {"ok": True, "like_count": problem.like_count}


@router.delete("/{pid:int}/like")
def unlike_problem(
    pid: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    problem = db.get(Problem, pid)
    if not problem:
        raise HTTPException(404, "not found")
    row = db.execute(
        select(ProblemLike).where(
            ProblemLike.problem_id == pid,
            ProblemLike.user_id == user.id,
        )
    ).scalar_one_or_none()
    if row:
        db.delete(row)
        if problem.like_count and problem.like_count > 0:
            problem.like_count -= 1
        db.commit()
    return {"ok": True, "like_count": problem.like_count}


@router.post("/{pid:int}/explanations/like")
def like_problem_explanations(
    pid: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    problem = db.get(Problem, pid)
    if not problem:
        raise HTTPException(404, "not found")
    exists = db.execute(
        select(ProblemExplLike).where(
            ProblemExplLike.problem_id == pid,
            ProblemExplLike.user_id == user.id,
        )
    ).scalar_one_or_none()
    if not exists:
        db.add(ProblemExplLike(problem_id=pid, user_id=user.id))
        problem.expl_like_count += 1
        db.commit()
    return {"ok": True, "expl_like_count": problem.expl_like_count}


@router.delete("/{pid:int}/explanations/like")
def unlike_problem_explanations(
    pid: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    problem = db.get(Problem, pid)
    if not problem:
        raise HTTPException(404, "not found")
    row = db.execute(
        select(ProblemExplLike).where(
            ProblemExplLike.problem_id == pid,
            ProblemExplLike.user_id == user.id,
        )
    ).scalar_one_or_none()
    if row:
        db.delete(row)
        if problem.expl_like_count and problem.expl_like_count > 0:
            problem.expl_like_count -= 1
        db.commit()
    return {"ok": True, "expl_like_count": problem.expl_like_count}
