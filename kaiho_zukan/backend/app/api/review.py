from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import select, func
from typing import Optional
from api.deps import get_current_user
from core.db import get_db
from models import User, Problem, Answer, Explanation, ExplanationLike, ExplanationWrongFlag, AiJudgement, ExplanationImage

router = APIRouter(prefix="/review", tags=["review"])

@router.get("/stats")
def review_stats(category_id: int, grand_id: Optional[int] = None, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    base = select(func.max(Answer.id).label("aid")).join(
        Problem, Problem.id == Answer.problem_id
    ).where(
        Answer.user_id == user.id, Problem.child_id == category_id
    )
    if grand_id is not None:
        base = base.where(Problem.grand_id == grand_id)
    sub = base.group_by(Answer.problem_id).subquery()

    solved = db.execute(select(func.count()).select_from(sub)).scalar_one() or 0
    correct = db.execute(
        select(func.count())
        .select_from(Answer)
        .join(sub, Answer.id == sub.c.aid)
        .where(Answer.is_correct == True)
    ).scalar_one() or 0
    rate = int(round((correct/solved*100), 0)) if solved > 0 else 0
    return {"solved": int(solved), "correct": int(correct), "rate": rate}

@router.get("/history")
def review_history(category_id: int, grand_id: Optional[int] = None, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    base = select(Answer.id).join(Problem, Problem.id==Answer.problem_id).where(Answer.user_id==user.id, Problem.child_id==category_id)
    if grand_id is not None:
        base = base.where(Problem.grand_id==grand_id)
    sub = select(func.max(Answer.id).label("aid")).select_from(Answer).join(Problem, Problem.id==Answer.problem_id).where(Answer.user_id==user.id, Problem.child_id==category_id)
    if grand_id is not None:
        sub = sub.where(Problem.grand_id==grand_id)
    sub = sub.group_by(Answer.problem_id).subquery()
    rows = db.execute(
        select(Answer, Problem)
        .join(sub, sub.c.aid==Answer.id)
        .join(Problem, Problem.id==Answer.problem_id)
        .order_by(Answer.id.desc())
    ).all()
    items = []
    for a, p in rows:
        items.append({"id": p.id, "title": p.title, "qtype": p.qtype, "answered_at": a.created_at.isoformat(), "is_correct": bool(a.is_correct) if a.is_correct is not None else None})
    return {"items": items}

@router.get("/item")
def review_item(pid: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    p = db.get(Problem, pid)
    if not p:
        raise HTTPException(404, "not found")
    a = db.execute(select(Answer).where(Answer.user_id==user.id, Answer.problem_id==pid).order_by(Answer.id.desc()).limit(1)).scalar_one_or_none()
    latest = None
    if a:
        latest = {"is_correct": a.is_correct, "free_text": a.free_text, "selected_option_id": a.selected_option_id}
    # explanations with AI/judge metadata (align with /explanations/problem/{pid})
    ex = db.execute(select(Explanation).where(Explanation.problem_id==pid).order_by(Explanation.like_count.desc(), Explanation.id.asc()).limit(10)).scalars().all()
    ex_ids = [e.id for e in ex]
    liked_ids = set()
    if ex_ids:
        rows = db.execute(select(ExplanationLike.explanation_id).where(ExplanationLike.user_id==user.id, ExplanationLike.explanation_id.in_(ex_ids))).all()
        liked_ids = {int(r[0]) for r in rows}
    wrong_flag_counts = {eid: 0 for eid in ex_ids}
    if ex_ids:
        rows = db.execute(select(ExplanationWrongFlag.explanation_id, func.count()).where(ExplanationWrongFlag.explanation_id.in_(ex_ids)).group_by(ExplanationWrongFlag.explanation_id)).all()
        for eid, cnt in rows:
            wrong_flag_counts[int(eid)] = int(cnt or 0)
    flagged_ids = set()
    if ex_ids:
        rows = db.execute(select(ExplanationWrongFlag.explanation_id).where(ExplanationWrongFlag.user_id==user.id, ExplanationWrongFlag.explanation_id.in_(ex_ids))).all()
        flagged_ids = {int(r[0]) for r in rows}
    # per-user judgements
    uids = list({e.user_id for e in ex if getattr(e, "user_id", None) is not None})
    judgement_map = {}
    if uids:
        jrows = db.execute(select(AiJudgement).where(AiJudgement.problem_id==pid, AiJudgement.user_id.in_(uids))).scalars().all()
        judgement_map = {j.user_id: j for j in jrows}
    try:
        solvers = db.execute(select(func.count(func.distinct(Answer.user_id))).where(Answer.problem_id == pid)).scalar_one() or 0
    except Exception:
        solvers = 0
    ex_items = []
    for e in ex:
        imgs = db.execute(select(ExplanationImage).where(ExplanationImage.explanation_id==e.id).order_by(ExplanationImage.id.asc())).scalars().all()
        img_urls = [f"/uploads/{im.filename}" for im in imgs]
        j = judgement_map.get(getattr(e, "user_id", None))
        wrong_cnt = wrong_flag_counts.get(e.id, 0)
        crowd_maybe_wrong = (solvers >= 10 and (wrong_cnt / max(1, solvers)) > 0.3)
        ex_items.append({
            "id": e.id,
            "content": e.content,
            "likes": e.like_count,
            "is_ai": (e.user_id is None),
            "by_user_id": e.user_id,
            "images": img_urls,
            "liked": (e.id in liked_ids),
            "ai_is_wrong": (j.is_wrong if j else None),
            "ai_judge_score": (j.score if j else None),
            "ai_judge_reason": (j.reason if j else None),
            "wrong_flag_count": wrong_cnt,
            "flagged_wrong": (e.id in flagged_ids),
            "solvers_count": int(solvers),
            "crowd_maybe_wrong": bool(crowd_maybe_wrong),
        })
    return {"problem": {"id": p.id, "title": p.title, "body": p.body, "qtype": p.qtype}, "latest_answer": latest, "explanations": ex_items}

@router.post("/mark")
def review_mark(pid: int, is_correct: bool, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    db.add(Answer(problem_id=pid, user_id=user.id, selected_option_id=None, free_text=None, is_correct=bool(is_correct)))
    db.commit()
    return {"ok": True}
