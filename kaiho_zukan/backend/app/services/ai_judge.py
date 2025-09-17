import os, json, base64, datetime as dt
from sqlalchemy import select
from core.config import get_settings
from core.db import SessionLocal
from models import (
    Problem, Option, Explanation, ExplanationImage, ProblemImage, ModelAnswer, AiJudgement, Notification
)
from services.util import extract_json_block

settings = get_settings()

def _image_part(path: str) -> dict:
    ext = os.path.splitext(path)[1].lower()
    mime = 'image/jpeg' if ext in ('.jpg', '.jpeg') else 'image/png' if ext=='.png' else 'image/webp' if ext=='.webp' else 'application/octet-stream'
    with open(path, "rb") as fh:
        b64 = base64.b64encode(fh.read()).decode("ascii")
    return {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{b64}"}}

def judge_problem_for_user(problem_id: int, target_user_id: int):
    """(pid, uid) 単位で、ユーザの模範解答+全体解説+選択肢別解説をまとめてAI判定し ai_judgements に保存"""
    if not (settings.OPENAI_ENABLED and settings.OPENAI_API_KEY):
        return
    from openai import OpenAI
    client = OpenAI(api_key=settings.OPENAI_API_KEY)

    with SessionLocal() as db:
        p = db.get(Problem, problem_id)
        if not p: return

        # ユーザの model answer
        ma = db.execute(
            select(ModelAnswer).where(
                ModelAnswer.problem_id == problem_id,
                ModelAnswer.user_id == target_user_id
            )
        ).scalar_one_or_none()
        user_model_answer = getattr(ma, "content", None)

        # ユーザの全体解説/選択肢別解説
        rows = db.execute(
            select(Explanation).where(
                Explanation.problem_id == problem_id,
                Explanation.user_id == target_user_id
            ).order_by(Explanation.id.asc())
        ).scalars().all()
        overall = None
        per_options: dict[int, str] = {}
        for e in rows:
            if e.option_index is None:
                overall = e.content
            else:
                per_options[int(e.option_index)] = e.content

        # 選択肢
        opts = list(db.execute(
            select(Option).where(Option.problem_id == problem_id).order_by(Option.id.asc())
        ).scalars().all())
        kana = ['ア','イ','ウ','エ','オ','カ','キ','ク','ケ','コ']
        opt_lines = []
        for i, o in enumerate(opts):
            label = kana[i] if i < len(kana) else f"選択肢{i+1}"
            opt_lines.append(f"{label}: {o.text}")

        prompt = (
            "あなたは厳密な答案レビューアです。次の情報に基づき、"
            "ユーザが投稿した『模範解答・全体解説・選択肢ごとの解説』が、問題設定に照らして"
            "誤りを含むかどうかを1回の判定でまとめて評価してください。\n"
            "ただし解説が不十分でも模範解答があっていれば正解判定にしてください。\n"
            "問題及び解答解説が難しく正解かどうか判定できない場合は，正解判定としてください。\n"
            "出力は必ずJSONのみ：{is_wrong: true|false, score: 0..100, reason: string}\n"
            "- is_wrong: 内容に事実誤認や重大な誤解がある場合 true、そうでなければ false\n"
            "- score: 判定の確信度（0-100）\n"
            "- reason: 2〜3文で簡潔に（代表的な誤りや懸念点を要約）\n\n"
            f"[問題タイトル]\n{p.title}\n"
            f"[問題文]\n{p.body or ''}\n"
        )
        if opt_lines:
            prompt += "[選択肢]\n" + "\n".join(opt_lines) + "\n"

        if user_model_answer:
            user_model_answer_disp = user_model_answer
            try:
                if (p.qtype or '').lower() == 'mcq':
                    import re as _re
                    def _repl(m):
                        try:
                            idx = int(m.group(1)) - 1
                            return kana[idx] if 0 <= idx < len(kana) else m.group(0)
                        except Exception:
                            return m.group(0)
                    user_model_answer_disp = _re.sub(r"\b([1-9]|10)\b", _repl, user_model_answer)
            except Exception:
                pass
            prompt += f"[ユーザの模範解答]\n{user_model_answer_disp}\n"

        prompt += f"[ユーザの全体解説]\n{overall or ''}\n"
        if opts:
            prompt += "[ユーザの選択肢ごとの解説]\n"
            for i, _o in enumerate(opts):
                txt = per_options.get(i, "")
                label = kana[i] if i < len(kana) else f"選択肢{i+1}"
                prompt += f"{label}: {txt}\n"

        message_content = [{"type": "text", "text": prompt}]

        # 問題画像（最大4）
        try:
            pimgs = list(db.execute(select(ProblemImage).where(ProblemImage.problem_id==p.id).order_by(ProblemImage.id.asc())).scalars().all())
            for im in pimgs[:4]:
                fpath = os.path.join(settings.UPLOAD_DIR, im.filename)
                if os.path.exists(fpath):
                    message_content.append(_image_part(fpath))
        except Exception:
            pass

        resp = client.chat.completions.create(
            model=settings.OPENAI_MODEL,
            messages=[{"role": "user", "content": message_content}],
            temperature=0.0,
            max_tokens=400,
        )
        raw = (resp.choices[0].message.content or "").strip()
        data_txt = extract_json_block(raw)
        try:
            data = json.loads(data_txt)
        except Exception:
            data = None

        is_wrong = None; score = None; reason = None
        if isinstance(data, dict):
            v = str(data.get("is_wrong", "")).strip().lower()
            if v in ("true", "false"):
                is_wrong = (v == "true")
            elif isinstance(data.get("is_wrong"), bool):
                is_wrong = bool(data["is_wrong"])
            if isinstance(data.get("score"), (int, float)):
                score = int(max(0, min(100, round(float(data["score"])))))
            if isinstance(data.get("reason"), str):
                reason = data["reason"].strip()

        if (is_wrong is not None) or (score is not None) or reason:
            row = db.execute(
                select(AiJudgement).where(
                    AiJudgement.problem_id == problem_id,
                    AiJudgement.user_id == target_user_id
                )
            ).scalar_one_or_none()
            if row is None:
                row = AiJudgement(problem_id=problem_id, user_id=target_user_id)
                db.add(row)
            if is_wrong is not None: row.is_wrong = is_wrong
            if score is not None: row.score = score
            if reason: row.reason = reason[:2000]
            row.updated_at = dt.datetime.utcnow()
            db.commit()
            # Upsert notification for the explanation owner when AI flags as wrong
            try:
                if (is_wrong is True) and (target_user_id is not None):
                    existing = db.execute(
                        select(Notification).where(
                            Notification.user_id == target_user_id,
                            Notification.type == "explanation_wrong",
                            Notification.problem_id == problem_id,
                        )
                    ).scalar_one_or_none()
                    if existing:
                        existing.ai_judged_wrong = True
                    else:
                        db.add(Notification(
                            user_id=target_user_id,
                            type="explanation_wrong",
                            problem_id=problem_id,
                            actor_user_id=None,
                            ai_judged_wrong=True,
                            crowd_judged_wrong=False,
                        ))
                    db.commit()
            except Exception:
                pass

def judge_explanation_ai(expl_id: int):
    """指定の解説に対して、問題本文・選択肢・画像をコンテキストにAIで正誤二値判定"""
    if not (settings.OPENAI_ENABLED and settings.OPENAI_API_KEY):
        return
    from openai import OpenAI
    client = OpenAI(api_key=settings.OPENAI_API_KEY)

    with SessionLocal() as db:
        e = db.get(Explanation, expl_id)
        if not e: return
        p = db.get(Problem, e.problem_id)
        if not p: return

        opts = []
        correct_labels = []
        if p.qtype == "mcq":
            kana = ['ア','イ','ウ','エ','オ','カ','キ','ク','ケ','コ']
            rows = list(db.execute(select(Option).where(Option.problem_id==p.id).order_by(Option.id.asc())).scalars().all())
            for i, o in enumerate(rows):
                label = kana[i] if i < len(kana) else f"選択肢{i+1}"
                opts.append(f"{label}: {o.text}")
                if o.is_correct:
                    correct_labels.append(label)

        message_content = []
        prompt = (
            "あなたは厳密な答案レビューアです。以下の“解説”が、与えられた問題設定に照らして"
            "事実誤認や論理誤りを含むかを二値で判定してください。\n"
            "ただし解説が不十分でも模範解答があっていれば正解と確信してください。\n"
            "出力は必ずJSONのみ：{is_wrong: true|false, score: 0..100, reason: string}\n"
            "- is_wrong: 解説が誤っているなら true、それ以外は false\n"
            "- score: 判定の確信度\n"
            "- reason: 最大2〜3文で簡潔に\n\n"
            f"[問題タイトル]\n{p.title}\n"
            f"[問題文]\n{p.body or ''}\n"
        )
        if opts:
            prompt += f"[選択肢]\n" + "\n".join(opts) + "\n"
            if correct_labels:
                prompt += f"[正解ラベル]\n{', '.join(correct_labels)}\n"
        prompt += f"\n[レビュー対象の解説]\n{e.content}\n"
        message_content.append({"type": "text", "text": prompt})

        # 問題画像（最大4）
        try:
            pimgs = list(db.execute(select(ProblemImage).where(ProblemImage.problem_id==p.id).order_by(ProblemImage.id.asc())).scalars().all())
            for im in pimgs[:4]:
                fpath = os.path.join(settings.UPLOAD_DIR, im.filename)
                if os.path.exists(fpath):
                    message_content.append(_image_part(fpath))
        except Exception:
            pass
        # 解説画像（最大2）
        try:
            eimgs = list(db.execute(select(ExplanationImage).where(ExplanationImage.explanation_id==e.id).order_by(ExplanationImage.id.asc())).scalars().all())
            for im in eimgs[:2]:
                fpath = os.path.join(settings.UPLOAD_DIR, im.filename)
                if os.path.exists(fpath):
                    message_content.append(_image_part(fpath))
        except Exception:
            pass

        resp = client.chat.completions.create(
            model=settings.OPENAI_MODEL,
            messages=[{"role":"user","content": message_content}],
            temperature=0.0,
            max_tokens=400,
        )
        raw = (resp.choices[0].message.content or "").strip()
        data_txt = extract_json_block(raw)
        try:
            data = json.loads(data_txt)
        except Exception:
            data = None

        is_wrong = None; score = None; reason = None
        if isinstance(data, dict):
            v = str(data.get("is_wrong", "")).strip().lower()
            if v in ("true", "false"):
                is_wrong = (v == "true")
            elif isinstance(data.get("is_wrong"), bool):
                is_wrong = bool(data["is_wrong"])
            if isinstance(data.get("score"), (int, float)):
                score = int(max(0, min(100, round(float(data["score"])))))
            if isinstance(data.get("reason"), str):
                reason = data["reason"].strip()

        changed = False
        if is_wrong is not None:
            e.ai_is_wrong = is_wrong  # 旧カラムを使わないならスキップしてOK
            changed = True
        if score is not None:
            e.ai_judge_score = score
            changed = True
        if reason:
            e.ai_judge_reason = reason[:2000]
            changed = True
        if changed:
            db.commit()
            try:
                # notify (upsert) author if AI judged wrong
                if (is_wrong is True) and (e.user_id is not None):
                    existing = db.execute(
                        select(Notification).where(
                            Notification.user_id == e.user_id,
                            Notification.type == "explanation_wrong",
                            Notification.problem_id == e.problem_id,
                        )
                    ).scalar_one_or_none()
                    if existing:
                        existing.ai_judged_wrong = True
                        # keep crowd_judged_wrong as is (might be set elsewhere)
                    else:
                        db.add(Notification(
                            user_id=e.user_id,
                            type="explanation_wrong",
                            problem_id=e.problem_id,
                            actor_user_id=None,
                            ai_judged_wrong=True,
                            crowd_judged_wrong=False,
                        ))
                    db.commit()
            except Exception:
                pass

def judge_all_explanations(problem_id: int):
    """指定問題の全解説に対して順次AI誤り判定"""
    try:
        with SessionLocal() as db:
            ids = [row[0] for row in db.execute(
                select(Explanation.id).where(Explanation.problem_id==problem_id)
            ).all()]
        for eid in ids:
            judge_explanation_ai(eid)
    except Exception:
        pass
