from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Request
from sqlalchemy.orm import Session
from sqlalchemy import select, func
from typing import Optional, List
import os, time, random, threading

from api.deps import get_current_user
from core.db import get_db
from core.config import get_settings
from models import (
    User, Problem, Explanation, ExplanationLike, ExplanationImage, ExplanationWrongFlag,
    Option, Answer, ProblemImage, AiJudgement, Notification
)
from services.ai_judge import judge_problem_for_user, judge_explanation_ai

settings = get_settings()


def _icon_url(user: User) -> str:
    if getattr(user, "icon_path", None):
        return f"/uploads/{user.icon_path}"
    return f"https://api.dicebear.com/8.x/identicon/png?seed={user.username}"


def _rank_info(total_creations: int) -> tuple[str, int]:
    if total_creations <= 30:
        return "ランク：ブロンズ", 1
    elif total_creations <= 50:
        return "ランク：シルバー", 2
    elif total_creations <= 70:
        return "ランク：ゴールド", 3
    else:
        return "ランク：プラチナ", 4

router = APIRouter(prefix="/explanations", tags=["explanations"])

@router.get("/problem/{pid:int}")
def list_explanations(
    pid: int,
    sort: str = "likes",
    request: Request = None,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    q = select(Explanation).where(Explanation.problem_id == pid)
    if sort == "likes":
        q = q.order_by(Explanation.like_count.desc(), Explanation.id.asc())
    elif sort == "recent":
        q = q.order_by(Explanation.id.desc())
    exps = db.execute(q).scalars().all()

    ex_ids = [e.id for e in exps]
    wrong_flag_counts = {eid: 0 for eid in ex_ids}
    if ex_ids:
        rows = db.execute(
            select(ExplanationWrongFlag.explanation_id, func.count())
            .where(ExplanationWrongFlag.explanation_id.in_(ex_ids))
            .group_by(ExplanationWrongFlag.explanation_id)
        ).all()
        for eid, cnt in rows:
            wrong_flag_counts[int(eid)] = int(cnt or 0)

    flagged_rows = db.execute(
        select(ExplanationWrongFlag.explanation_id)
        .where(
            ExplanationWrongFlag.user_id == user.id,
            ExplanationWrongFlag.explanation_id.in_(ex_ids),
        )
    ).all() if ex_ids else []
    flagged_ids = {int(r[0]) for r in flagged_rows}

    liked_rows = db.execute(
        select(ExplanationLike.explanation_id)
        .where(
            ExplanationLike.user_id == user.id,
            ExplanationLike.explanation_id.in_(ex_ids),
        )
    ).all() if ex_ids else []
    liked_ids = {int(r[0]) for r in liked_rows}

    uids = list({e.user_id for e in exps if getattr(e, "user_id", None) is not None})
    user_map: dict[int, dict[str, object]] = {}
    problem_counts: dict[int, int] = {}
    explanation_counts: dict[int, int] = {}
    if uids:
        user_rows = db.execute(select(User).where(User.id.in_(uids))).scalars().all()
        problem_counts = {
            int(uid): int(cnt or 0)
            for uid, cnt in db.execute(
                select(Problem.created_by, func.count())
                .where(Problem.created_by.in_(uids))
                .group_by(Problem.created_by)
            ).all()
        }
        explanation_counts = {
            int(uid): int(cnt or 0)
            for uid, cnt in db.execute(
                select(Explanation.user_id, func.count())
                .where(Explanation.user_id.in_(uids))
                .group_by(Explanation.user_id)
            ).all()
        }
        for u in user_rows:
            total_creations = problem_counts.get(u.id, 0) + explanation_counts.get(u.id, 0)
            rank, rank_level = _rank_info(int(total_creations))
            display_name = u.nickname if u.nickname else u.username
            user_map[u.id] = {
                "user": u,
                "display_name": display_name,
                "icon_url": _icon_url(u),
                "rank": rank,
                "rank_level": rank_level,
                "problem_count": problem_counts.get(u.id, 0),
                "explanation_count": explanation_counts.get(u.id, 0),
            }
    judgement_map = {}
    if uids:
        jrows = db.execute(
            select(AiJudgement).where(
                AiJudgement.problem_id == pid,
                AiJudgement.user_id.in_(uids),
            )
        ).scalars().all()
        judgement_map = {j.user_id: j for j in jrows}

    try:
        solvers = db.execute(
            select(func.count(func.distinct(Answer.user_id))).where(Answer.problem_id == pid)
        ).scalar_one() or 0
    except Exception:
        solvers = 0

    items = []
    for e in exps:
        author_icon_url = None
        author_rank = None
        author_rank_level = None
        user_obj = None
        info = None
        if e.user_id is None:
            by = "AI"
        else:
            info = user_map.get(e.user_id)
            if info:
                by = info.get("display_name")
                author_icon_url = info.get("icon_url")
                author_rank = info.get("rank")
                author_rank_level = info.get("rank_level")
                user_obj = info.get("user")
            else:
                user_obj = db.get(User, e.user_id)
                by = (user_obj.nickname if user_obj and user_obj.nickname else (user_obj.username if user_obj else None))
        if user_obj is None and e.user_id is not None and info is None:
            user_obj = db.get(User, e.user_id)
        if author_icon_url is None and user_obj is not None:
            author_icon_url = _icon_url(user_obj)
        if author_rank is None and user_obj is not None:
            total_creations = problem_counts.get(user_obj.id, 0) + explanation_counts.get(user_obj.id, 0)
            author_rank, author_rank_level = _rank_info(int(total_creations))
            if by is None:
                by = user_obj.nickname if user_obj.nickname else user_obj.username

        if not by:
            by = "ユーザー"

        imgs = db.execute(
            select(ExplanationImage).where(ExplanationImage.explanation_id == e.id).order_by(ExplanationImage.id.asc())
        ).scalars().all()
        img_urls = [f"/uploads/{im.filename}" for im in imgs]

        j = judgement_map.get(getattr(e, "user_id", None))
        wrong_cnt = wrong_flag_counts.get(e.id, 0)
        crowd_maybe_wrong = (solvers >= 10 and (wrong_cnt / max(1, solvers)) > 0.3)

        if author_rank_level is not None:
            try:
                author_rank_level = int(author_rank_level)
            except (TypeError, ValueError):
                author_rank_level = None

        items.append({
            "id": e.id,
            "content": e.content,
            "likes": e.like_count,
            "is_ai": (e.user_id is None),
            "option_index": e.option_index,
            "user_id": e.user_id,
            "by": by,
            "author_icon_url": author_icon_url,
            "author_rank": author_rank,
            "author_rank_level": author_rank_level,
            "liked": (e.id in liked_ids),
            "images": img_urls,
            "ai_is_wrong": (j.is_wrong if j else None),
            "ai_judge_score": (j.score if j else None),
            "ai_judge_reason": (j.reason if j else None),
            "wrong_flag_count": wrong_cnt,
            "flagged_wrong": (e.id in flagged_ids),
            "solvers_count": int(solvers),
            "crowd_maybe_wrong": bool(crowd_maybe_wrong),
        })

    if sort not in ("likes", "recent"):
        import random
        random.shuffle(items)

    return {"items": items}

@router.post("/problem/{pid:int}")
def create_explanation(
    pid: int,
    content: str = Form(...),
    images: List[UploadFile] = File(None),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    p = db.get(Problem, pid)
    if not p:
        raise HTTPException(404, "not found")

    e = Explanation(problem_id=pid, user_id=user.id, content=content)
    db.add(e); db.flush()

    if images:
        os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
        subdir = os.path.join(settings.UPLOAD_DIR, "expl", str(e.id))
        os.makedirs(subdir, exist_ok=True)
        for f in images:
            try:
                blob = f.file.read()
                if not blob:
                    continue
                base = os.path.basename(f.filename or "image")
                name, ext = os.path.splitext(base)
                ext = (ext or "").lower()
                if ext not in (".png", ".jpg", ".jpeg", ".gif", ".webp"):
                    ext = ".bin"
                fn = f"e{e.id}_{int(time.time()*1000)}_{random.randint(1000,9999)}{ext}"
                path = os.path.join(subdir, fn)
                with open(path, "wb") as out:
                    out.write(blob)
                rel = os.path.relpath(path, settings.UPLOAD_DIR).replace("\\", "/")
                db.add(ExplanationImage(explanation_id=e.id, filename=rel))
            except Exception:
                continue

    db.commit()
    if settings.OPENAI_ENABLED and settings.OPENAI_API_KEY:
        threading.Thread(target=judge_problem_for_user, args=(pid, user.id), daemon=True).start()
        threading.Thread(target=judge_explanation_ai, args=(e.id,), daemon=True).start()
    return {"ok": True, "id": e.id}

@router.get("/problem/{pid:int}/mine")
def my_explanations(pid: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = db.execute(select(Explanation).where(Explanation.problem_id==pid, Explanation.user_id==user.id)).scalars().all()
    overall = None
    options = {}
    for e in rows:
        if e.option_index is None:
            overall = e.content
        else:
            options[int(e.option_index)] = e.content
    max_idx = max(options.keys()) if options else -1
    option_list = [options.get(i) for i in range(max_idx+1)]
    return {"overall": overall, "options": option_list}

@router.put("/{eid:int}")
def edit_explanation(
    eid: int,
    content: Optional[str] = Form(None),
    images: List[UploadFile] = File(None),
    clear_images: Optional[bool] = Form(False),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    e = db.get(Explanation, eid)
    if not e:
        raise HTTPException(404, "Explanation not found")
    if e.user_id is None:
        raise HTTPException(403, "AI explanation cannot be edited directly")
    if e.user_id != user.id:
        raise HTTPException(403, "forbidden")

    changed = False
    # If empty string is explicitly sent, delete this explanation
    if content is not None and (str(content).strip() == ""):
        # Remove likes and images first to avoid FK issues, then delete the row
        db.query(ExplanationLike).filter(ExplanationLike.explanation_id == eid).delete(synchronize_session=False)
        db.query(ExplanationImage).filter(ExplanationImage.explanation_id == eid).delete(synchronize_session=False)
        db.delete(e)
        db.commit()
        return {"ok": True, "deleted": True, "id": eid}
    if content is not None:
        e.content = content
        changed = True

    if clear_images:
        db.query(ExplanationImage).filter(ExplanationImage.explanation_id == eid).delete(synchronize_session=False)
        changed = True

    if images:
        os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
        subdir = os.path.join(settings.UPLOAD_DIR, "expl", str(e.id))
        os.makedirs(subdir, exist_ok=True)
        for f in images:
            try:
                blob = f.file.read()
                if not blob:
                    continue
                base = os.path.basename(f.filename or "image")
                name, ext = os.path.splitext(base)
                ext = (ext or "").lower()
                if ext not in (".png", ".jpg", ".jpeg", ".gif", ".webp"):
                    ext = ".bin"
                fn = f"e{e.id}_{int(time.time()*1000)}_{random.randint(1000,9999)}{ext}"
                path = os.path.join(subdir, fn)
                with open(path, "wb") as out:
                    out.write(blob)
                rel = os.path.relpath(path, settings.UPLOAD_DIR).replace("\\", "/")
                db.add(ExplanationImage(explanation_id=e.id, filename=rel))
                changed = True
            except Exception:
                continue

    if changed:
        db.commit()
        if settings.OPENAI_ENABLED and settings.OPENAI_API_KEY:
            threading.Thread(target=judge_problem_for_user, args=(e.problem_id, e.user_id), daemon=True).start()
            threading.Thread(target=judge_explanation_ai, args=(e.id,), daemon=True).start()

    return {"ok": True, "id": e.id}

# like / unlike on a single explanation
@router.post("/{eid:int}/like")
def like_explanation(eid: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    e = db.get(Explanation, eid)
    if not e:
        raise HTTPException(404, "not found")
    exists = db.execute(select(ExplanationLike).where(ExplanationLike.explanation_id==eid, ExplanationLike.user_id==user.id)).scalar_one_or_none()
    if not exists:
        db.add(ExplanationLike(explanation_id=eid, user_id=user.id))
        e.like_count += 1
        # upsert notification for explanation owner
        try:
            if e.user_id and e.user_id != user.id:
                exists_n = db.execute(
                    select(Notification).where(
                        Notification.user_id == e.user_id,
                        Notification.type == "explanation_like",
                        Notification.problem_id == e.problem_id,
                        Notification.actor_user_id == user.id,
                    )
                ).scalar_one_or_none()
                if not exists_n:
                    db.add(Notification(
                        user_id=e.user_id,
                        type="explanation_like",
                        problem_id=e.problem_id,
                        actor_user_id=user.id,
                        ai_judged_wrong=None,
                        crowd_judged_wrong=None,
                    ))
        except Exception:
            pass
        db.commit()
    return {"ok": True, "likes": e.like_count}

@router.delete("/{eid:int}/like")
def unlike_explanation(eid: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    e = db.get(Explanation, eid)
    if not e:
        raise HTTPException(404, "not found")
    row = db.execute(select(ExplanationLike).where(ExplanationLike.explanation_id==eid, ExplanationLike.user_id==user.id)).scalar_one_or_none()
    if row:
        db.delete(row)
        if e.like_count and e.like_count > 0:
            e.like_count -= 1
        db.commit()
    return {"ok": True, "likes": e.like_count}

# wrong-flags
@router.post("/{expl_id:int}/wrong-flags")
def add_wrong_flag(expl_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    e = db.get(Explanation, expl_id)
    if not e:
        raise HTTPException(404, "Explanation not found")
    exists = db.execute(
        select(ExplanationWrongFlag)
        .where(ExplanationWrongFlag.explanation_id == expl_id, ExplanationWrongFlag.user_id == user.id)
    ).scalar_one_or_none()
    if not exists:
        db.add(ExplanationWrongFlag(explanation_id=expl_id, user_id=user.id))
        db.commit()
        # If crowd judgement passes threshold (>=10 solvers and >30% flags), notify (upsert) the author
        try:
            # solvers count for the problem
            solvers = db.execute(select(func.count(func.distinct(Answer.user_id))).where(Answer.problem_id == e.problem_id)).scalar_one() or 0
            wrong_cnt = db.execute(select(func.count(ExplanationWrongFlag.id)).where(ExplanationWrongFlag.explanation_id == expl_id)).scalar_one() or 0
            if solvers >= 10 and (wrong_cnt / max(1, solvers)) > 0.3:
                if e.user_id and e.user_id != user.id:
                    existing = db.execute(
                        select(Notification).where(
                            Notification.user_id == e.user_id,
                            Notification.type == "explanation_wrong",
                            Notification.problem_id == e.problem_id,
                        )
                    ).scalar_one_or_none()
                    if existing:
                        existing.crowd_judged_wrong = True
                    else:
                        db.add(Notification(
                            user_id=e.user_id,
                            type="explanation_wrong",
                            problem_id=e.problem_id,
                            actor_user_id=None,
                            ai_judged_wrong=False,
                            crowd_judged_wrong=True,
                        ))
                    db.commit()
        except Exception:
            pass
    count = db.execute(
        select(func.count(ExplanationWrongFlag.id))
        .where(ExplanationWrongFlag.explanation_id == expl_id)
    ).scalar_one()
    return {"ok": True, "flagged": True, "count": int(count or 0)}

@router.delete("/{expl_id:int}/wrong-flags")
def remove_wrong_flag(expl_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    db.query(ExplanationWrongFlag).filter(
        ExplanationWrongFlag.explanation_id == expl_id,
        ExplanationWrongFlag.user_id == user.id
    ).delete(synchronize_session=False)
    db.commit()
    count = db.execute(
        select(func.count(ExplanationWrongFlag.id))
        .where(ExplanationWrongFlag.explanation_id == expl_id)
    ).scalar_one()
    return {"ok": True, "flagged": False, "count": int(count or 0)}

# delete my explanations under a problem
@router.delete("/problem/{pid:int}/mine")
def delete_my_explanations(pid: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    ex_ids = [row[0] for row in db.execute(select(Explanation.id).where(Explanation.problem_id == pid, Explanation.user_id == user.id)).all()]
    if not ex_ids:
        return {"ok": True, "deleted": 0}
    db.query(ExplanationLike).filter(ExplanationLike.explanation_id.in_(ex_ids)).delete(synchronize_session=False)
    deleted = db.query(Explanation).filter(Explanation.id.in_(ex_ids)).delete(synchronize_session=False)
    db.commit()
    return {"ok": True, "deleted": int(deleted or 0)}
