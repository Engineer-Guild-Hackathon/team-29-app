import os, json, base64, time, random
from sqlalchemy import select, func
from sqlalchemy.orm import Session
from core.config import get_settings
from core.db import SessionLocal
from models import Problem, Option, Explanation, ProblemImage, ModelAnswer, ExplanationImage
from services.util import extract_json_block

settings = get_settings()

def _image_part(path: str) -> dict:
    ext = os.path.splitext(path)[1].lower()
    mime = 'image/jpeg' if ext in ('.jpg', '.jpeg') else 'image/png' if ext=='.png' else 'image/webp' if ext=='.webp' else 'application/octet-stream'
    with open(path, "rb") as fh:
        b64 = base64.b64encode(fh.read()).decode("ascii")
    return {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{b64}"}}

def generate_ai_explanations(problem_id: int):
    """問題ごとの AI 解説生成（MCQ: overall + per-option / free: overall）"""
    if not (settings.OPENAI_ENABLED and settings.OPENAI_API_KEY):
        return
    from openai import OpenAI
    client = OpenAI(api_key=settings.OPENAI_API_KEY)

    with SessionLocal() as db:
        p = db.get(Problem, problem_id)
        if not p: return
        # 同問題のAI解説を削除してから生成（重複防止）
        db.query(Explanation).filter(Explanation.problem_id==p.id, Explanation.user_id==None).delete(synchronize_session=False)

        if p.qtype == 'mcq':
            opts = list(db.execute(select(Option).where(Option.problem_id==p.id).order_by(Option.id.asc())).scalars().all())
            kana = ['ア','イ','ウ','エ','オ','カ','キ','ク','ケ','コ']
            opt_lines = []
            for i, o in enumerate(opts):
                label = kana[i] if i < len(kana) else f'選択肢{i+1}'
                opt_lines.append(f"{label}: {o.text}")
            options_block = "\n".join(opt_lines)
            prompt = (
                "あなたは教育用の優秀な出題解説者です。次の選択式の問題について、模範解答と全体の解説，選択肢ごとの解説を作成してください。\n"
                "出力は必ずJSONのみで、{model_answer, overall, options} を含めてください。\n"
                "フォーマット: {model_answer:'ア', overall:'...', options:['...','...']}\n"
                "注意: options配列は提示順に並べ、各要素は1〜2文で簡潔に。overallは2〜4文。\n"
                "選択肢ごとの解説には『ア：』『アの解説：』などのラベルを含めず、解説文のみ。\n"
                f"[タイトル]\n{p.title}\n[本文]\n{p.body or ''}\n[選択肢]\n{options_block}\n"
            )

            message_content = [{"type":"text","text":prompt}]
            try:
                imgs = list(db.execute(select(ProblemImage).where(ProblemImage.problem_id==p.id).order_by(ProblemImage.id.asc())).scalars().all())
                for im in imgs[:4]:
                    fpath = os.path.join(settings.UPLOAD_DIR, im.filename)
                    if os.path.exists(fpath):
                        message_content.append(_image_part(fpath))
            except Exception:
                pass

            resp = client.chat.completions.create(
                model=settings.OPENAI_MODEL,
                messages=[{"role": "user", "content": message_content}],
                temperature=0.2,
                max_tokens=700,
            )
            raw = (resp.choices[0].message.content or '').strip()
            txt = extract_json_block(raw)
            try:
                data = json.loads(txt)
            except Exception:
                data = None

            overall_txt = None
            option_txts = []
            model_answer_txt = None
            if isinstance(data, dict):
                if isinstance(data.get('model_answer'), str):
                    model_answer_txt = data['model_answer'].strip()
                if isinstance(data.get('overall'), str):
                    overall_txt = data['overall'].strip()
                if isinstance(data.get('options'), list):
                    option_txts = [str(x).strip() for x in data['options']]
            else:
                overall_txt = raw

            if overall_txt:
                db.add(Explanation(problem_id=p.id, user_id=None, content=overall_txt, option_index=None))
            for i in range(len(opts)):
                txti = option_txts[i] if i < len(option_txts) else None
                if txti and txti.strip():
                    db.add(Explanation(problem_id=p.id, user_id=None, content=txti.strip(), option_index=i))
            # AIの模範解答を upsert（user_id=None）
            try:
                db.query(ModelAnswer).filter(ModelAnswer.problem_id==p.id, ModelAnswer.user_id==None).delete(synchronize_session=False)
            except Exception:
                pass
            if model_answer_txt and model_answer_txt.strip():
                db.add(ModelAnswer(problem_id=p.id, user_id=None, content=model_answer_txt.strip()))
            db.commit()

        else:
            # 記述式: overall のみ
            prompt = (
                "あなたは教育用の優秀な出題解説者です。次の記述式の問題について、模範解答と全体解説（200〜400字）を作成してください。\n"
                "出力は必ずJSONのみで、{model_answer:'...', overall:'...'} の形にしてください。\n"
                f"[タイトル] {p.title}\n[本文] {p.body or ''}\n"
            )
            message_content = [{"type":"text","text":prompt}]
            try:
                imgs = list(db.execute(select(ProblemImage).where(ProblemImage.problem_id==p.id).order_by(ProblemImage.id.asc())).scalars().all())
                for im in imgs[:4]:
                    fpath = os.path.join(settings.UPLOAD_DIR, im.filename)
                    if os.path.exists(fpath):
                        message_content.append(_image_part(fpath))
            except Exception:
                pass

            resp = client.chat.completions.create(
                model=settings.OPENAI_MODEL,
                messages=[{"role":"user","content": message_content}],
                temperature=0.2,
                max_tokens=500,
            )
            content = (resp.choices[0].message.content or '').strip()
            txt = extract_json_block(content)
            try:
                data = json.loads(txt)
            except Exception:
                data = None

            overall_txt = None
            model_answer_txt = None
            if isinstance(data, dict):
                if isinstance(data.get('model_answer'), str):
                    model_answer_txt = data['model_answer'].strip()
                if isinstance(data.get('overall'), str):
                    overall_txt = data['overall'].strip()
            else:
                overall_txt = content

            if overall_txt:
                db.add(Explanation(problem_id=p.id, user_id=None, content=overall_txt, option_index=None))
            try:
                db.query(ModelAnswer).filter(ModelAnswer.problem_id==p.id, ModelAnswer.user_id==None).delete(synchronize_session=False)
            except Exception:
                pass
            if model_answer_txt and model_answer_txt.strip():
                db.add(ModelAnswer(problem_id=p.id, user_id=None, content=model_answer_txt.strip()))
            db.commit()

def regenerate_ai_explanations_preserve_likes(problem_id: int):
    """AI解説を再生成し、旧AI解説の like_count を option_index/overall 対応で引き継ぐ"""
    prev: dict[object,int] = {}
    with SessionLocal() as db:
        for e in db.execute(select(Explanation).where(Explanation.problem_id==problem_id, Explanation.user_id==None)).scalars().all():
            key = 'overall' if e.option_index is None else int(e.option_index)
            prev[key] = int(e.like_count or 0)

    generate_ai_explanations(problem_id)

    with SessionLocal() as db:
        rows = db.execute(select(Explanation).where(Explanation.problem_id==problem_id, Explanation.user_id==None)).scalars().all()
        changed = False
        for e in rows:
            key = 'overall' if e.option_index is None else int(e.option_index)
            if key in prev and int(e.like_count or 0) != prev[key]:
                e.like_count = prev[key]
                changed = True
        if changed:
            db.commit()
