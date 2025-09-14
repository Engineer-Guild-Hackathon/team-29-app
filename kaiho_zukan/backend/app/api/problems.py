from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Request, Query
from sqlalchemy.orm import Session
from sqlalchemy import select, update, func, text
from typing import Optional, List
import os, time, random, json, threading

from api.deps import get_current_user
from core.db import get_db
from core.config import get_settings
from models import (
    User, Problem, Option, Explanation, Answer, ProblemLike, ExplanationLike,
    ProblemExplLike, ProblemImage, ModelAnswer, ExplanationImage, AiJudgement, ExplanationWrongFlag
)
from services.ai_explain import generate_ai_explanations, regenerate_ai_explanations_preserve_likes
from services.ai_judge import judge_all_explanations, judge_problem_for_user
from services.util import extract_json_block

settings = get_settings()
router = APIRouter(prefix="/problems", tags=["problems"])

@router.post("")
def create_problem(
    request: Request,
    title: str = Form(...),
    body: Optional[str] = Form(None),
    qtype: str = Form(...),
    category_child_id: int = Form(...),
    category_grand_id: int = Form(...),
    options_text: Optional[str] = Form(None),
    options: Optional[str] = Form(None),
    correct_index: Optional[int] = Form(None),
    initial_explanation: Optional[str] = Form(None),
    option_explanations_text: Optional[str] = Form(None),
    option_explanations_json: Optional[str] = Form(None),
    model_answer: Optional[str] = Form(None),
    images: List[UploadFile] = File(None),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    p = Problem(title=title, body=body, qtype=qtype, child_id=category_child_id, grand_id=category_grand_id, created_by=user.id)
    db.add(p); db.flush()

    if model_answer is not None and str(model_answer).strip():
        db.add(ModelAnswer(problem_id=p.id, user_id=user.id, content=str(model_answer).strip()))

    if qtype == "mcq":
        if options_text is None and options is not None:
            options_text = "\n".join([s.strip() for s in str(options).split(",")])
        opts = []
        if options_text is not None:
            opts = [line.strip() for line in options_text.splitlines() if line.strip()]
        for i, t in enumerate(opts):
            db.add(Option(problem_id=p.id, text=t, is_correct=(i==int(correct_index or 0))))

        if option_explanations_json:
            try:
                arr = json.loads(option_explanations_json)
                if isinstance(arr, list):
                    for i, txt in enumerate(arr):
                        if isinstance(txt, str) and txt.strip():
                            db.add(Explanation(problem_id=p.id, user_id=user.id, content=txt, option_index=i))
            except Exception:
                pass
        elif option_explanations_text:
            ex_lines = [line for line in option_explanations_text.splitlines()]
            for i, line in enumerate(ex_lines):
                if isinstance(line, str) and line.strip():
                    db.add(Explanation(problem_id=p.id, user_id=user.id, content=line, option_index=i))

    if initial_explanation:
        db.add(Explanation(problem_id=p.id, user_id=user.id, content=initial_explanation, option_index=None))

    if images:
        os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
        for f in images:
            try:
                content = f.file.read()
                if not content:
                    continue
                base = os.path.basename(f.filename or "image")
                name, ext = os.path.splitext(base)
                safe_ext = ext.lower() if ext and ext.lower() in (".png",".jpg",".jpeg",".gif",".webp") else ".bin"
                fn = f"p{p.id}_{int(time.time()*1000)}_{random.randint(1000,9999)}{safe_ext}"
                path = os.path.join(settings.UPLOAD_DIR, fn)
                with open(path, "wb") as out:
                    out.write(content)
                db.add(ProblemImage(problem_id=p.id, filename=fn))
            except Exception:
                continue

    db.commit()

    if settings.OPENAI_ENABLED and settings.OPENAI_API_KEY:
        def _gen_and_judge(pid: int, uid: int):
            try:
                generate_ai_explanations(pid)
                judge_all_explanations(pid)
                # クリエイター本人の解説/模範解答もユーザ単位で判定を残す
                judge_problem_for_user(pid, uid)
            except Exception:
                pass
        threading.Thread(target=_gen_and_judge, args=(p.id, user.id), daemon=True).start()

    return {"id": p.id, "ok": True}

@router.get("/{pid:int}")
def get_problem(
    pid: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    p = db.get(Problem, pid)
    if not p:
        raise HTTPException(404, "not found")
    opts = db.execute(select(Option).where(Option.problem_id==p.id).order_by(Option.id.asc())).scalars().all()
    imgs = db.execute(select(ProblemImage).where(ProblemImage.problem_id==p.id).order_by(ProblemImage.id.asc())).scalars().all()
    ma = db.execute(select(ModelAnswer).where(ModelAnswer.problem_id==p.id, ModelAnswer.user_id==user.id)).scalar_one_or_none()
    return {
        "id": p.id, "title": p.title, "body": p.body, "qtype": p.qtype,
        "child_id": p.child_id, "grand_id": p.grand_id,
        "images": [f"/uploads/{im.filename}" for im in imgs],
        "options": [{"id": o.id, "text": o.text, "is_correct": bool(o.is_correct)} for o in opts],
        "model_answer": getattr(ma, "content", None),
        "like_count": p.like_count, "expl_like_count": p.expl_like_count,
    }

@router.put("/{pid:int}")
def edit_problem(
    pid: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    title: Optional[str] = Form(None),
    body: Optional[str] = Form(None),
    qtype: Optional[str] = Form(None),
    category_child_id: Optional[int] = Form(None),
    category_grand_id: Optional[int] = Form(None),
    options_text: Optional[str] = Form(None),
    options: Optional[str] = Form(None),
    correct_index: Optional[int] = Form(None),
    initial_explanation: Optional[str] = Form(None),
    option_explanations_text: Optional[str] = Form(None),
    option_explanations_json: Optional[str] = Form(None),
    model_answer: Optional[str] = Form(None),
    images: List[UploadFile] = File(None),
):
    p = db.get(Problem, pid)
    if not p:
        raise HTTPException(404, "not found")
    is_owner = (p.created_by == user.id)
    updated_explanations = False
    should_regen_ai = is_owner and any(v is not None for v in [title, body, qtype, category_child_id, category_grand_id, options_text, options, correct_index, model_answer])

    if not is_owner:
        if any(v is not None for v in [title, body, qtype, category_child_id, category_grand_id, options_text, options, correct_index, model_answer]):
            raise HTTPException(403, "not owner")

    if is_owner and title is not None: p.title = title
    if is_owner and body is not None: p.body = body
    if is_owner and qtype is not None: p.qtype = qtype
    if is_owner and category_child_id is not None: p.child_id = category_child_id
    if is_owner and category_grand_id is not None: p.grand_id = category_grand_id

    if is_owner and model_answer is not None:
        txt = str(model_answer).strip()
        existing = db.execute(select(ModelAnswer).where(ModelAnswer.problem_id==p.id, ModelAnswer.user_id==user.id)).scalar_one_or_none()
        if txt:
            if existing:
                existing.content = txt
            else:
                db.add(ModelAnswer(problem_id=p.id, user_id=user.id, content=txt))
        else:
            if existing:
                db.delete(existing)

    if p.qtype == "mcq":
        if is_owner:
            if options_text is None and options is not None:
                options_text = "\n".join([s.strip() for s in str(options).split(",")])
            if options_text is not None:
                db.execute(update(Answer).where(Answer.problem_id==p.id).values(selected_option_id=None))
                db.query(Option).filter(Option.problem_id==p.id).delete()
                opts=[line.strip() for line in options_text.splitlines() if line.strip()]
                for i,t in enumerate(opts):
                    db.add(Option(problem_id=p.id, text=t, is_correct=(i==int(correct_index or 0))))
        me = user.id
        if (option_explanations_json is not None) or (option_explanations_text is not None):
            updated_explanations = True
            ex_ids = [row[0] for row in db.execute(
                select(Explanation.id)
                .where(Explanation.problem_id == p.id, Explanation.user_id == me, Explanation.option_index != None)
            ).all()]
            if ex_ids:
                from models import ExplanationImage, ExplanationLike
                db.query(ExplanationImage).filter(ExplanationImage.explanation_id.in_(ex_ids)).delete(synchronize_session=False)
                db.query(ExplanationLike).filter(ExplanationLike.explanation_id.in_(ex_ids)).delete(synchronize_session=False)
                db.query(Explanation).filter(Explanation.id.in_(ex_ids)).delete(synchronize_session=False)
            if option_explanations_json is not None:
                try:
                    arr = json.loads(option_explanations_json)
                    if isinstance(arr, list):
                        for i, txt in enumerate(arr):
                            if isinstance(txt, str) and txt.strip():
                                db.add(Explanation(problem_id=p.id, user_id=me, content=txt, option_index=i))
                except Exception:
                    pass
            elif option_explanations_text is not None:
                ex_lines = [line for line in option_explanations_text.splitlines()]
                for i, line in enumerate(ex_lines):
                    if isinstance(line, str) and line.strip():
                        db.add(Explanation(problem_id=p.id, user_id=me, content=line, option_index=i))

    if initial_explanation is not None:
        updated_explanations = True
        me = user.id
        ex_ids = [row[0] for row in db.execute(
            select(Explanation.id)
            .where(Explanation.problem_id == p.id, Explanation.user_id == me, Explanation.option_index == None)
        ).all()]
        if ex_ids:
            from models import ExplanationImage, ExplanationLike
            db.query(ExplanationImage).filter(ExplanationImage.explanation_id.in_(ex_ids)).delete(synchronize_session=False)
            db.query(ExplanationLike).filter(ExplanationLike.explanation_id.in_(ex_ids)).delete(synchronize_session=False)
            db.query(Explanation).filter(Explanation.id.in_(ex_ids)).delete(synchronize_session=False)
        if initial_explanation.strip():
            db.add(Explanation(problem_id=p.id, user_id=me, content=initial_explanation.strip(), option_index=None))

    db.commit()

    if settings.OPENAI_ENABLED and settings.OPENAI_API_KEY:
        if should_regen_ai or updated_explanations:
            threading.Thread(
                target=judge_problem_for_user,
                args=(p.id, user.id),
                daemon=True
            ).start()

    return {"ok": True}

@router.get("/{pid:int}/explanations")
def problem_explanations(
    pid: int,
    sort: str = Query("likes"),
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
    # liked by current user
    liked_rows = db.execute(
        select(ExplanationLike.explanation_id)
        .where(
            ExplanationLike.user_id == user.id,
            ExplanationLike.explanation_id.in_(ex_ids) if ex_ids else (ExplanationLike.explanation_id == -1),
        )
    ).all() if ex_ids else []
    liked_ids = {int(r[0]) for r in liked_rows}

    # wrong flags counts and user flag state
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
            ExplanationWrongFlag.explanation_id.in_(ex_ids) if ex_ids else (ExplanationWrongFlag.explanation_id == -1),
        )
    ).all() if ex_ids else []
    flagged_ids = {int(r[0]) for r in flagged_rows}

    # per-user judgements (by explanation's author) and solvers count
    uids = list({e.user_id for e in exps if getattr(e, "user_id", None) is not None})
    judgement_map = {}
    if uids:
        jrows = db.execute(
            select(AiJudgement).where(
                AiJudgement.problem_id == pid,
                AiJudgement.user_id.in_(uids),
            )
        ).scalars().all()
        judgement_map = {j.user_id: j for j in jrows}

    # solvers count
    try:
        solvers = db.execute(
            select(func.count(func.distinct(Answer.user_id))).where(Answer.problem_id == pid)
        ).scalar_one() or 0
    except Exception:
        solvers = 0

    items = []
    for e in exps:
        if e.user_id is None:
            by = "AI"
        else:
            u = db.get(User, e.user_id)
            by = (u.nickname if u and u.nickname else (u.username if u else None))

        imgs = db.execute(
            select(ExplanationImage).where(ExplanationImage.explanation_id == e.id).order_by(ExplanationImage.id.asc())
        ).scalars().all()
        img_urls = [f"/uploads/{im.filename}" for im in imgs]

        j = judgement_map.get(getattr(e, "user_id", None))
        wrong_cnt = wrong_flag_counts.get(e.id, 0)
        crowd_maybe_wrong = (solvers >= 10 and (wrong_cnt / max(1, solvers)) > 0.3)

        items.append({
            "id": e.id,
            "content": e.content,
            "likes": e.like_count,
            "is_ai": (e.user_id is None),
            "option_index": e.option_index,
            "user_id": e.user_id,
            "by": by,
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
        import random as _random
        _random.shuffle(items)
    return {"items": items}

@router.get("/{pid:int}/my-explanations")
def get_my_explanations_for_problem(pid: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = db.execute(
        select(Explanation).where(Explanation.problem_id == pid, Explanation.user_id == user.id)
    ).scalars().all()
    overall = None
    options: dict[int, Optional[str]] = {}
    for e in rows:
        if e.option_index is None:
            overall = e.content
        else:
            options[int(e.option_index)] = e.content
    max_idx = max(options.keys()) if options else -1
    option_list = [options.get(i) for i in range(max_idx + 1)]
    return {"overall": overall, "options": option_list}

@router.delete("/{pid:int}/my-explanations")
def delete_my_explanations_for_problem(pid: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    ex_ids = [
        row[0]
        for row in db.execute(
            select(Explanation.id).where(Explanation.problem_id == pid, Explanation.user_id == user.id)
        ).all()
    ]
    if not ex_ids:
        return {"ok": True, "deleted": 0}
    from models import ExplanationImage, ExplanationLike
    db.query(ExplanationImage).filter(ExplanationImage.explanation_id.in_(ex_ids)).delete(synchronize_session=False)
    db.query(ExplanationLike).filter(ExplanationLike.explanation_id.in_(ex_ids)).delete(synchronize_session=False)
    db.query(Explanation).filter(Explanation.id.in_(ex_ids)).delete(synchronize_session=False)
    db.commit()
    return {"ok": True, "deleted": len(ex_ids)}

@router.get("/for-explain")
def problems_for_explain(child_id: int, grand_id: Optional[int] = None, sort: str="likes", db: Session = Depends(get_db)):
    from models import Explanation
    q = select(
        Problem,
        func.coalesce(func.sum(Explanation.like_count),0).label("elikes"),
        func.count(func.distinct(func.coalesce(Explanation.user_id, -1))).label("ex_cnt")
    ).outerjoin(Explanation, Explanation.problem_id==Problem.id).where(Problem.child_id==child_id)
    if grand_id:
        q = q.where(Problem.grand_id==grand_id)
    q = q.group_by(Problem.id)
    if sort=="likes": q = q.order_by(text("elikes DESC"), Problem.id.desc())
    elif sort=="explanations": q = q.order_by(text("ex_cnt DESC"), Problem.id.desc())
    else: q = q.order_by(Problem.id.desc())
    rows = db.execute(q).all()
    items=[{"id":r[0].id,"title":r[0].title,"body": r[0].body, "qtype": r[0].qtype, "like_count":int(r[1]),"ex_cnt":int(r[2])} for r in rows]
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
        child_id_i = int(str(child_id).strip())
    except Exception:
        raise HTTPException(400, "child_id must be integer")
    grand_id_i: Optional[int] = None
    if grand_id is not None and str(grand_id).strip() != "":
        try:
            grand_id_i = int(str(grand_id).strip())
        except Exception:
            raise HTTPException(400, "grand_id must be integer")

    subq = select(Answer.problem_id).where(Answer.user_id==user.id, Answer.is_correct==True)
    q = select(Problem).where(Problem.child_id==child_id_i)
    if grand_id_i is not None:
        q = q.where(Problem.grand_id==grand_id_i)
    if not include_answered:
        q = q.where(Problem.id.notin_(subq))
    qs = db.execute(q).scalars().all()
    if not qs:
        return {"problem": None}
    weights = [max(1, p.like_count) for p in qs]
    choice = random.choices(qs, weights=weights, k=1)[0]
    p = choice
    opts = db.execute(select(Option).where(Option.problem_id==p.id)).scalars().all()
    expl_liked = bool(db.execute(select(ProblemExplLike).where(ProblemExplLike.problem_id==p.id, ProblemExplLike.user_id==user.id)).scalar_one_or_none())
    liked = bool(db.execute(select(ProblemLike).where(ProblemLike.problem_id==p.id, ProblemLike.user_id==user.id)).scalar_one_or_none())
    imgs = db.execute(select(ProblemImage).where(ProblemImage.problem_id==p.id).order_by(ProblemImage.id.asc())).scalars().all()
    return {"id": p.id, "title": p.title, "body": p.body, "qtype": p.qtype,
            "like_count": p.like_count, "liked": liked,
            "expl_like_count": p.expl_like_count, "expl_liked": expl_liked,
            "images": [f"/uploads/{im.filename}" for im in imgs],
            "options":[{"id":o.id, "text":o.text, "content": o.text} for o in opts]}

@router.post("/{pid:int}/answer")
def answer_problem(
    pid: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    selected_option_id: Optional[int]=Form(None),
    free_text: Optional[str]=Form(None),
    is_correct: Optional[bool]=Form(None),
):
    p = db.get(Problem, pid)
    if not p:
        raise HTTPException(404, "not found")
    correct = None
    if p.qtype=="mcq":
        if selected_option_id is None:
            raise HTTPException(400, "option required")
        correct = None if is_correct is None else bool(is_correct)
    else:
        correct = None if is_correct is None else bool(is_correct)
    db.add(Answer(problem_id=pid, user_id=user.id, selected_option_id=selected_option_id, free_text=free_text, is_correct=correct))
    if correct:
        user.points += 1
    db.commit()
    ex = db.execute(select(Explanation).where(Explanation.problem_id==pid).order_by(Explanation.like_count.desc(), Explanation.id.asc())).scalars().all()
    return {"is_correct": correct, "explanations":[{"id":e.id,"content":e.content,"likes":e.like_count, "is_ai": (e.user_id is None)} for e in ex]}

# Problem like / unlike
@router.post("/{pid:int}/like")
def like_problem(pid: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    p = db.get(Problem, pid)
    if not p:
        raise HTTPException(404, "not found")
    exists = db.execute(select(ProblemLike).where(ProblemLike.problem_id==pid, ProblemLike.user_id==user.id)).scalar_one_or_none()
    if not exists:
        db.add(ProblemLike(problem_id=pid, user_id=user.id))
        p.like_count += 1
        db.commit()
    return {"ok": True, "like_count": p.like_count}

@router.delete("/{pid:int}/like")
def unlike_problem(pid: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    p = db.get(Problem, pid)
    if not p:
        raise HTTPException(404, "not found")
    row = db.execute(select(ProblemLike).where(ProblemLike.problem_id==pid, ProblemLike.user_id==user.id)).scalar_one_or_none()
    if row:
        db.delete(row)
        if p.like_count and p.like_count > 0:
            p.like_count -= 1
        db.commit()
    return {"ok": True, "like_count": p.like_count}

# Problem explanations like / unlike (summary)
@router.post("/{pid:int}/explanations/like")
def like_problem_explanations(pid: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    p = db.get(Problem, pid)
    if not p:
        raise HTTPException(404, "not found")
    exists = db.execute(select(ProblemExplLike).where(ProblemExplLike.problem_id==pid, ProblemExplLike.user_id==user.id)).scalar_one_or_none()
    if not exists:
        db.add(ProblemExplLike(problem_id=pid, user_id=user.id))
        p.expl_like_count += 1
        db.commit()
    return {"ok": True, "expl_like_count": p.expl_like_count}

@router.delete("/{pid:int}/explanations/like")
def unlike_problem_explanations(pid: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    p = db.get(Problem, pid)
    if not p:
        raise HTTPException(404, "not found")
    row = db.execute(select(ProblemExplLike).where(ProblemExplLike.problem_id==pid, ProblemExplLike.user_id==user.id)).scalar_one_or_none()
    if row:
        db.delete(row)
        if p.expl_like_count and p.expl_like_count > 0:
            p.expl_like_count -= 1
        db.commit()
    return {"ok": True, "expl_like_count": p.expl_like_count}

# Model answers
@router.post("/{pid:int}/model-answer")
def upsert_model_answer(
    pid: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    content: Optional[str] = Form(None),
    content_q: Optional[str] = Query(None),
):
    p = db.get(Problem, pid)
    if not p:
        raise HTTPException(404, "not found")
    txt = (content if (content is not None) else content_q or "").strip()
    existing = db.execute(select(ModelAnswer).where(ModelAnswer.problem_id==pid, ModelAnswer.user_id==user.id)).scalar_one_or_none()
    if not txt:
        if existing:
            db.delete(existing); db.commit()
        return {"ok": True}
    if existing:
        existing.content = txt
    else:
        db.add(ModelAnswer(problem_id=pid, user_id=user.id, content=txt))
    db.commit(); return {"ok": True}

@router.get("/{pid:int}/model-answer")
def get_my_model_answer(pid: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    ma = db.execute(select(ModelAnswer).where(ModelAnswer.problem_id==pid, ModelAnswer.user_id==user.id)).scalar_one_or_none()
    return {"content": getattr(ma, 'content', None)}

@router.get("/{pid:int}/model-answers")
def list_model_answers(pid: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = db.execute(
        select(ModelAnswer.content, ModelAnswer.user_id, User.username, User.nickname)
        .outerjoin(User, User.id==ModelAnswer.user_id)
        .where(ModelAnswer.problem_id==pid)
        .order_by(ModelAnswer.id.desc())
    ).all()
    items = []
    for content, uid, username, nickname in rows:
        if uid is None:
            items.append({"user_id": None, "username": "AI", "nickname": "AI", "content": content, "is_ai": True})
        else:
            items.append({"user_id": int(uid), "username": username, "nickname": nickname, "content": content, "is_ai": False})
    return {"items": items}

@router.delete("/{pid:int}")
def delete_problem(pid: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    p = db.get(Problem, pid)
    if not p:
        raise HTTPException(404, "not found")
    if p.created_by != user.id:
        raise HTTPException(403, "forbidden")
    ex_ids = [row[0] for row in db.execute(select(Explanation.id).where(Explanation.problem_id == pid)).all()]
    if ex_ids:
        db.query(ExplanationLike).filter(ExplanationLike.explanation_id.in_(ex_ids)).delete(synchronize_session=False)
    db.query(Explanation).filter(Explanation.problem_id == pid).delete(synchronize_session=False)
    db.query(Answer).filter(Answer.problem_id == pid).delete(synchronize_session=False)
    db.query(Option).filter(Option.problem_id == pid).delete(synchronize_session=False)
    db.query(ProblemLike).filter(ProblemLike.problem_id == pid).delete(synchronize_session=False)
    db.query(ProblemExplLike).filter(ProblemExplLike.problem_id == pid).delete(synchronize_session=False)
    db.query(ModelAnswer).filter(ModelAnswer.problem_id == pid).delete(synchronize_session=False)
    # 一部環境では ai_judgements のFKに ON DELETE CASCADE が効いていない場合があるため、明示削除
    try:
        from models import AiJudgement
        db.query(AiJudgement).filter(AiJudgement.problem_id == pid).delete(synchronize_session=False)
    except Exception:
        pass
    imgs = db.execute(select(ProblemImage).where(ProblemImage.problem_id == pid)).scalars().all()
    for img in imgs:
        try:
            path = os.path.join(settings.UPLOAD_DIR, img.filename)
            if os.path.exists(path):
                os.remove(path)
        except Exception:
            pass
    db.query(ProblemImage).filter(ProblemImage.problem_id == pid).delete(synchronize_session=False)
    db.delete(p)
    db.commit()
    return {"ok": True}
