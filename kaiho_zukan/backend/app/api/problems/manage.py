import json
import os
import random
import threading
import time
from typing import List, Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from sqlalchemy import select, update
from sqlalchemy.orm import Session

from api.deps import get_current_user
from core.config import get_settings
from core.db import get_db
from models import (
    Answer,
    Explanation,
    ExplanationImage,
    ExplanationLike,
    ModelAnswer,
    Option,
    Problem,
    ProblemExplLike,
    ProblemImage,
    ProblemLike,
    User,
)
from services.ai_explain import generate_ai_explanations
from services.ai_judge import judge_all_explanations, judge_problem_for_user

settings = get_settings()
router = APIRouter()


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
    p = Problem(
        title=title,
        body=body,
        qtype=qtype,
        child_id=category_child_id,
        grand_id=category_grand_id,
        created_by=user.id,
    )
    db.add(p)
    db.flush()

    if model_answer is not None and str(model_answer).strip():
        db.add(
            ModelAnswer(
                problem_id=p.id,
                user_id=user.id,
                content=str(model_answer).strip(),
            )
        )

    if qtype == "mcq":
        if options_text is None and options is not None:
            options_text = "\n".join([s.strip() for s in str(options).split(",")])
        opts: List[str] = []
        if options_text is not None:
            opts = [line.strip() for line in options_text.splitlines() if line.strip()]
        for i, text in enumerate(opts):
            db.add(Option(problem_id=p.id, text=text, is_correct=(i == int(correct_index or 0))))

        if option_explanations_json:
            try:
                arr = json.loads(option_explanations_json)
                if isinstance(arr, list):
                    for i, txt in enumerate(arr):
                        if isinstance(txt, str) and txt.strip():
                            db.add(
                                Explanation(
                                    problem_id=p.id,
                                    user_id=user.id,
                                    content=txt,
                                    option_index=i,
                                )
                            )
            except Exception:
                pass
        elif option_explanations_text:
            ex_lines = [line for line in option_explanations_text.splitlines()]
            for i, line in enumerate(ex_lines):
                if isinstance(line, str) and line.strip():
                    db.add(
                        Explanation(
                            problem_id=p.id,
                            user_id=user.id,
                            content=line,
                            option_index=i,
                        )
                    )

    if initial_explanation:
        db.add(
            Explanation(
                problem_id=p.id,
                user_id=user.id,
                content=initial_explanation,
                option_index=None,
            )
        )

    if images:
        os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
        for f in images:
            try:
                content = f.file.read()
                if not content:
                    continue
                base = os.path.basename(f.filename or "image")
                name, ext = os.path.splitext(base)
                safe_ext = (
                    ext.lower()
                    if ext and ext.lower() in (".png", ".jpg", ".jpeg", ".gif", ".webp")
                    else ".bin"
                )
                filename = f"p{p.id}_{int(time.time() * 1000)}_{random.randint(1000, 9999)}{safe_ext}"
                path = os.path.join(settings.UPLOAD_DIR, filename)
                with open(path, "wb") as out:
                    out.write(content)
                db.add(ProblemImage(problem_id=p.id, filename=filename))
            except Exception:
                continue

    db.commit()

    if settings.OPENAI_ENABLED and settings.OPENAI_API_KEY:
        def _gen_and_judge(pid: int, uid: int) -> None:
            try:
                generate_ai_explanations(pid)
                judge_all_explanations(pid)
                judge_problem_for_user(pid, uid)
            except Exception:
                pass

        threading.Thread(target=_gen_and_judge, args=(p.id, user.id), daemon=True).start()

    return {"id": p.id, "ok": True}


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
    is_owner = p.created_by == user.id
    updated_explanations = False
    should_regen_ai = is_owner and any(
        v is not None
        for v in [
            title,
            body,
            qtype,
            category_child_id,
            category_grand_id,
            options_text,
            options,
            correct_index,
            model_answer,
        ]
    )

    if not is_owner and any(
        v is not None
        for v in [
            title,
            body,
            qtype,
            category_child_id,
            category_grand_id,
            options_text,
            options,
            correct_index,
            model_answer,
        ]
    ):
        raise HTTPException(403, "not owner")

    if is_owner and title is not None:
        p.title = title
    if is_owner and body is not None:
        p.body = body
    if is_owner and qtype is not None:
        p.qtype = qtype
    if is_owner and category_child_id is not None:
        p.child_id = category_child_id
    if is_owner and category_grand_id is not None:
        p.grand_id = category_grand_id

    if is_owner and model_answer is not None:
        txt = str(model_answer).strip()
        existing = db.execute(
            select(ModelAnswer).where(
                ModelAnswer.problem_id == p.id, ModelAnswer.user_id == user.id
            )
        ).scalar_one_or_none()
        if txt:
            if existing:
                existing.content = txt
            else:
                db.add(ModelAnswer(problem_id=p.id, user_id=user.id, content=txt))
        elif existing:
            db.delete(existing)

    if p.qtype == "mcq":
        if is_owner:
            if options_text is None and options is not None:
                options_text = "\n".join([s.strip() for s in str(options).split(",")])
            if options_text is not None:
                db.execute(
                    update(Answer)
                    .where(Answer.problem_id == p.id)
                    .values(selected_option_id=None)
                )
                db.query(Option).filter(Option.problem_id == p.id).delete()
                opts = [line.strip() for line in options_text.splitlines() if line.strip()]
                for i, text in enumerate(opts):
                    db.add(Option(problem_id=p.id, text=text, is_correct=(i == int(correct_index or 0))))
        me = user.id
        if (option_explanations_json is not None) or (option_explanations_text is not None):
            updated_explanations = True
            ex_ids = [
                row[0]
                for row in db.execute(
                    select(Explanation.id)
                    .where(
                        Explanation.problem_id == p.id,
                        Explanation.user_id == me,
                        Explanation.option_index != None,
                    )
                ).all()
            ]
            if ex_ids:
                db.query(ExplanationImage).filter(
                    ExplanationImage.explanation_id.in_(ex_ids)
                ).delete(synchronize_session=False)
                db.query(ExplanationLike).filter(
                    ExplanationLike.explanation_id.in_(ex_ids)
                ).delete(synchronize_session=False)
                db.query(Explanation).filter(Explanation.id.in_(ex_ids)).delete(
                    synchronize_session=False
                )
            if option_explanations_json is not None:
                try:
                    arr = json.loads(option_explanations_json)
                    if isinstance(arr, list):
                        for i, txt in enumerate(arr):
                            if isinstance(txt, str) and txt.strip():
                                db.add(
                                    Explanation(
                                        problem_id=p.id,
                                        user_id=me,
                                        content=txt,
                                        option_index=i,
                                    )
                                )
                except Exception:
                    pass
            elif option_explanations_text is not None:
                ex_lines = [line for line in option_explanations_text.splitlines()]
                for i, line in enumerate(ex_lines):
                    if isinstance(line, str) and line.strip():
                        db.add(
                            Explanation(
                                problem_id=p.id,
                                user_id=me,
                                content=line,
                                option_index=i,
                            )
                        )

    if initial_explanation is not None:
        updated_explanations = True
        me = user.id
        ex_ids = [
            row[0]
            for row in db.execute(
                select(Explanation.id)
                .where(
                    Explanation.problem_id == p.id,
                    Explanation.user_id == me,
                    Explanation.option_index == None,
                )
            ).all()
        ]
        if ex_ids:
            db.query(ExplanationImage).filter(
                ExplanationImage.explanation_id.in_(ex_ids)
            ).delete(synchronize_session=False)
            db.query(ExplanationLike).filter(
                ExplanationLike.explanation_id.in_(ex_ids)
            ).delete(synchronize_session=False)
            db.query(Explanation).filter(Explanation.id.in_(ex_ids)).delete(
                synchronize_session=False
            )
        if initial_explanation.strip():
            db.add(
                Explanation(
                    problem_id=p.id,
                    user_id=me,
                    content=initial_explanation.strip(),
                    option_index=None,
                )
            )

    db.commit()

    if settings.OPENAI_ENABLED and settings.OPENAI_API_KEY:
        if should_regen_ai or updated_explanations:
            threading.Thread(
                target=judge_problem_for_user,
                args=(p.id, user.id),
                daemon=True,
            ).start()

    return {"ok": True}


@router.delete("/{pid:int}")
def delete_problem(
    pid: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    p = db.get(Problem, pid)
    if not p:
        raise HTTPException(404, "not found")
    if p.created_by != user.id:
        raise HTTPException(403, "forbidden")
    ex_ids = [
        row[0]
        for row in db.execute(select(Explanation.id).where(Explanation.problem_id == pid)).all()
    ]
    if ex_ids:
        db.query(ExplanationLike).filter(
            ExplanationLike.explanation_id.in_(ex_ids)
        ).delete(synchronize_session=False)
    db.query(Explanation).filter(Explanation.problem_id == pid).delete(
        synchronize_session=False
    )
    db.query(Answer).filter(Answer.problem_id == pid).delete(synchronize_session=False)
    db.query(Option).filter(Option.problem_id == pid).delete(synchronize_session=False)
    db.query(ProblemLike).filter(ProblemLike.problem_id == pid).delete(
        synchronize_session=False
    )
    db.query(ProblemExplLike).filter(ProblemExplLike.problem_id == pid).delete(
        synchronize_session=False
    )
    db.query(ModelAnswer).filter(ModelAnswer.problem_id == pid).delete(
        synchronize_session=False
    )
    try:
        from models import AiJudgement

        db.query(AiJudgement).filter(AiJudgement.problem_id == pid).delete(
            synchronize_session=False
        )
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
    db.query(ProblemImage).filter(ProblemImage.problem_id == pid).delete(
        synchronize_session=False
    )
    db.delete(p)
    db.commit()
    return {"ok": True}
