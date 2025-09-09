
from fastapi import FastAPI, Depends, HTTPException, UploadFile, File, Form, Request, Header, Query
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import (
    create_engine, text, func, select, ForeignKey, update,
    Integer, String, Text, Boolean, DateTime,
)
from sqlalchemy.orm import (
    sessionmaker, Session
)

from typing import Optional, List
import os, random, datetime as dt, threading, time, json
import logging
from passlib.context import CryptContext
from sqlalchemy.exc import OperationalError
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

DATABASE_URL = os.getenv("DATABASE_URL","mysql+pymysql://app:app@db:3306/learn")
JWT_SECRET = os.getenv("JWT_SECRET")
JWT_ALG = "HS256"
OPENAI_ENABLED = os.getenv("OPENAI_ENABLED","false").lower()=="true"
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL = os.getenv("OPENAI_MODEL","gpt-4o-mini")
UPLOAD_DIR = os.getenv("UPLOAD_DIR", "/data/uploads")

engine = create_engine(DATABASE_URL, pool_pre_ping=True, future=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)
from models import Base, User, Category, UserCategory, Problem, Option, Explanation, Answer, ProblemLike, ExplanationLike, ProblemExplLike, ProblemImage

"""Models imported from app.models"""
    
def create_all():
    Base.metadata.create_all(engine)

def ensure_schema():
    with engine.begin() as conn:
        try:
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS points INT NOT NULL DEFAULT 0"))
        except Exception:
            try:
                conn.execute(text("SELECT points FROM users LIMIT 1"))
            except Exception:
                conn.execute(text("ALTER TABLE users ADD COLUMN points INT NOT NULL DEFAULT 0"))
        try:
            conn.execute(text("ALTER TABLE categories ADD COLUMN IF NOT EXISTS level INT NOT NULL DEFAULT 0"))
        except Exception:
            try:
                conn.execute(text("SELECT level FROM categories LIMIT 1"))
            except Exception:
                conn.execute(text("ALTER TABLE categories ADD COLUMN level INT NOT NULL DEFAULT 0"))
        # problems.model_answer (nullable TEXT)
        try:
            conn.execute(text("ALTER TABLE problems ADD COLUMN IF NOT EXISTS model_answer TEXT NULL"))
        except Exception:
            try:
                conn.execute(text("SELECT model_answer FROM problems LIMIT 1"))
            except Exception:
                conn.execute(text("ALTER TABLE problems ADD COLUMN model_answer TEXT NULL"))
        # problems.expl_like_count (INT)
        try:
            conn.execute(text("ALTER TABLE problems ADD COLUMN IF NOT EXISTS expl_like_count INT NOT NULL DEFAULT 0"))
        except Exception:
            try:
                conn.execute(text("SELECT expl_like_count FROM problems LIMIT 1"))
            except Exception:
                conn.execute(text("ALTER TABLE problems ADD COLUMN expl_like_count INT NOT NULL DEFAULT 0"))
        # explanations.option_index (nullable INT)
        try:
            conn.execute(text("ALTER TABLE explanations ADD COLUMN IF NOT EXISTS option_index INT NULL"))
        except Exception:
            try:
                conn.execute(text("SELECT option_index FROM explanations LIMIT 1"))
            except Exception:
                conn.execute(text("ALTER TABLE explanations ADD COLUMN option_index INT NULL"))

from auth import hash_pw, verify_pw, make_token, parse_token
logger = logging.getLogger("uvicorn.error")

# (moved exception handler below after app is created)

def wait_for_db(max_tries: int = 60):
    for i in range(max_tries):
        try:
            with engine.connect() as conn:
                conn.execute(text("SELECT 1"))
            return
        except Exception:
            time.sleep(1)
    raise RuntimeError("DB not ready")

def seed_categories():
    """IT資格 / 基本情報 / 応用情報 と それぞれの単元を idempotent に投入"""
    with Session(engine) as s:
        def get_or_create(name: str, parent_id: int | None, level: int):
            q = select(Category).where(Category.name == name, Category.parent_id == parent_id)
            obj = s.execute(q).scalar_one_or_none()
            if obj:
                # level が 0 のまま残っていたら更新
                if obj.level != level:
                    obj.level = level
                return obj
            obj = Category(name=name, parent_id=parent_id, level=level)
            s.add(obj)
            s.flush()
            return obj

        it = get_or_create("IT資格", None, 0)
        basic = get_or_create("基本情報", it.id, 1)
        applied = get_or_create("応用情報", it.id, 1)

        basic_units = [
            "基礎理論","アルゴリズム・プログラミング","コンピュータ構成要素","システム構成要素",
            "ソフトウェア","ネットワーク","データベース","セキュリティ","開発技術",
            "プロジェクトマネジメント","サービスマネジメント","システム戦略","経営戦略・企業と法務"
        ]
        applied_units = [
            "アルゴリズム","ネットワーク","データベース","セキュリティ","組込み・IoT","マネジメント","ストラテジ"
        ]
        for u in basic_units:
            get_or_create(u, basic.id, 2)
        for u in applied_units:
            get_or_create(u, applied.id, 2)

        # ===== 学校教材（中学・高校）
        # 中学教材: 教科 -> 単元
        jr = get_or_create("中学教材", None, 0)
        jr_map: dict[str, list[str]] = {
            "国語": ["文法","読解","古典入門"],
            "数学": ["正負の数","文字式","方程式","関数","図形"],
            "英語": ["文法","読解","リスニング"],
            "理科": ["物理","化学","生物","地学"],
            "社会": ["地理","歴史","公民"],
        }
        for subj, units in jr_map.items():
            sc = get_or_create(subj, jr.id, 1)
            for u in units:
                get_or_create(u, sc.id, 2)

        # 高校教材: 教科 -> 単元（名称は一般的な区分を採用）
        hs = get_or_create("高校教材", None, 0)
        hs_map: dict[str, list[str]] = {
            "国語": ["現代文","古文","漢文"],
            "数学": ["数学I","数学A","数学II","数学B"],
            "英語": ["英語コミュニケーションI","英語コミュニケーションII","英語表現"],
            "理科": ["物理基礎","化学基礎","生物基礎","地学基礎","物理","化学","生物","地学"],
            "社会": ["日本史","世界史","地理","政治・経済","倫理"],
        }
        for subj, units in hs_map.items():
            sc = get_or_create(subj, hs.id, 1)
            for u in units:
                get_or_create(u, sc.id, 2)
        s.commit()

def seed_sample_problem():
    # Removed: sample problem seeding disabled
    return
from fastapi.responses import JSONResponse
app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
try:
    from fastapi.staticfiles import StaticFiles
    os.makedirs(UPLOAD_DIR, exist_ok=True)
    app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")
except Exception:
    pass

# Log 422 validation errors with details (must be after app is defined)
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    try:
        logger.error("422 Validation error: url=%s method=%s errors=%s", str(request.url), request.method, exc.errors())
    except Exception:
        pass
    # Sanitize errors to avoid non-serializable objects (e.g., UploadFile)
    simple = []
    try:
        for e in exc.errors():
            simple.append({
                "type": e.get("type"),
                "loc": e.get("loc"),
                "msg": e.get("msg"),
            })
    except Exception:
        simple = [{"msg": "validation error"}]
    return JSONResponse(status_code=422, content={"detail": simple})

@app.on_event("startup")
def on_start():
    wait_for_db()
    create_all()
    ensure_schema()
    seed_categories() 
    with engine.begin() as conn:
        conn.execute(text("SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci"))

def get_db():
    with SessionLocal() as db:
        db.execute(text("SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci"))
        yield db

def get_user(db: Session, authorization: Optional[str], request: Request):
    token = None
    # Prefer explicit dependency param if provided
    if authorization and authorization.lower().startswith("bearer "):
        token = authorization.split(" ",1)[1].strip()
    # Fallback to Authorization header
    if not token:
        auth = request.headers.get("authorization")
        if auth and auth.lower().startswith("bearer "):
            token = auth.split(" ",1)[1].strip()
    # Allow X-Access-Token as secondary header for compatibility
    if not token:
        token = request.headers.get("X-Access-Token")
    if not token:
        raise HTTPException(401, "Unauthorized")
    uid = parse_token(token)
    if not uid:
        raise HTTPException(401, "Invalid token")
    user = db.get(User, uid)
    if not user:
        raise HTTPException(401, "User not found")
    return user

from sqlalchemy import select


@app.post("/auth/register")
def register(payload: dict, db: Session = Depends(get_db)):
    username = payload.get("username","").strip()
    password = payload.get("password","")
    nickname = payload.get("nickname", username)
    if not username or not password: raise HTTPException(400, "username/password required")
    exists = db.execute(select(User).where(User.username==username)).scalar_one_or_none()
    if exists: raise HTTPException(400, "username already exists")
    user = User(username=username, password_hash=hash_pw(password), nickname=nickname)
    db.add(user); db.commit()
    return {"access_token": make_token(user.id)}

@app.post("/auth/login")
def login(payload: dict, db: Session = Depends(get_db)):
    username = payload.get("username","")
    password = payload.get("password","")
    user = db.execute(select(User).where(User.username==username)).scalar_one_or_none()
    if not user or not verify_pw(password, user.password_hash):
        raise HTTPException(401, "invalid credentials")
    return {"access_token": make_token(user.id)}

@app.get("/categories/tree")
def cat_tree(db: Session = Depends(get_db)):
    parents = db.execute(select(Category).where(Category.parent_id==None).order_by(Category.id)).scalars().all()
    def to_dict(cat: Category):
        return {"id": cat.id, "name": cat.name, "children":[{"id": c.id, "name": c.name, "children":[{"id": g.id,"name": g.name} for g in c.children]} for c in cat.children]}
    return [to_dict(p) for p in parents]

@app.get("/me")
def me(request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db)):
    user = get_user(db, authorization, request)
    cats = db.execute(
        select(Category.id, Category.name).join(UserCategory, UserCategory.category_id==Category.id).where(UserCategory.user_id==user.id)
    ).all()
    return {"id": user.id, "username": user.username, "nickname": user.nickname, "points": user.points,
            "categories": [{"id": c.id, "name": c.name} for c in cats]}

@app.post("/me/categories")
def set_my_categories(ids: List[int], request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db)):
    user = get_user(db, authorization, request)
    db.query(UserCategory).filter(UserCategory.user_id==user.id).delete()
    for cid in ids: db.add(UserCategory(user_id=user.id, category_id=cid))
    db.commit(); return {"ok": True}

# Problems
@app.post("/problems")
def create_problem(request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db),
    title: str = Form(...), body: Optional[str] = Form(None), qtype: str = Form(...),
    category_child_id: int = Form(...), category_grand_id: int = Form(...),
    options_text: Optional[str] = Form(None), options: Optional[str] = Form(None), correct_index: Optional[int] = Form(None),
    initial_explanation: Optional[str] = Form(None), option_explanations_text: Optional[str] = Form(None), option_explanations_json: Optional[str] = Form(None), model_answer: Optional[str] = Form(None),
    images: List[UploadFile] = File(None)):
    user = get_user(db, authorization, request)
    # Require model_answer for free-text problems
    if qtype == "free" and (model_answer is None or not str(model_answer).strip()):
        raise HTTPException(400, "model_answer required for free-text problems")
    p = Problem(title=title, body=body, qtype=qtype, child_id=category_child_id, grand_id=category_grand_id, created_by=user.id, model_answer=model_answer)
    db.add(p); db.flush()
    # accept both multiline options_text and comma-separated 'options' for compatibility
    if qtype=="mcq":
        # Accept both 'options_text' (multiline) and 'options' (comma-separated)
        if options_text is None and options is not None:
            options_text = "\n".join([s.strip() for s in str(options).split(",")])
        if options_text is not None:
            opts=[line.strip() for line in options_text.splitlines() if line.strip()]
        for i,t in enumerate(opts):
            db.add(Option(problem_id=p.id, text=t, is_correct=(i==int(correct_index or 0))))
        # per-option explanations
        # Prefer JSON array if provided to preserve newlines within each explanation
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
            # Back-compat: one explanation per line
            ex_lines = [line for line in option_explanations_text.splitlines()]
            for i, line in enumerate(ex_lines):
                if isinstance(line, str) and line.strip():
                    db.add(Explanation(problem_id=p.id, user_id=user.id, content=line, option_index=i))
    if initial_explanation:
        db.add(Explanation(problem_id=p.id, user_id=user.id, content=initial_explanation, option_index=None))
    # save images if any
    if images:
        for f in images:
            try:
                content = f.file.read()
                if not content:
                    continue
                base = os.path.basename(f.filename or "image")
                name, ext = os.path.splitext(base)
                safe_ext = ext.lower() if ext and ext.lower() in (".png",".jpg",".jpeg",".gif",".webp") else ".bin"
                fn = f"p{p.id}_{int(time.time()*1000)}_{random.randint(1000,9999)}{safe_ext}"
                path = os.path.join(UPLOAD_DIR, fn)
                with open(path, "wb") as out:
                    out.write(content)
                db.add(ProblemImage(problem_id=p.id, filename=fn))
            except Exception:
                continue
    db.commit()

    if OPENAI_ENABLED and OPENAI_API_KEY:
        threading.Thread(target=generate_ai_explanations, args=(p.id,), daemon=True).start()

    return {"id": p.id, "ok": True}

def generate_ai_explanations(problem_id: int):
    """Background task to generate AI explanations.
    - MCQ: overall + per-option explanations (option_index=0..n-1)
    - free: overall only
    Safe to run multiple times; it clears prior AI explanations for the problem first.
    """
    try:
        from openai import OpenAI
        client = OpenAI(api_key=OPENAI_API_KEY)
        with SessionLocal() as db:
            p = db.get(Problem, problem_id)
            if not p:
                return
            # Remove prior AI explanations to avoid duplicates
            db.query(Explanation).filter(Explanation.problem_id==p.id, Explanation.user_id==None).delete(synchronize_session=False)

            if p.qtype == 'mcq':
                # Fetch options in stable order
                opts = list(db.execute(select(Option).where(Option.problem_id==p.id).order_by(Option.id.asc())).scalars().all())
                kana = ['ア','イ','ウ','エ','オ','カ','キ','ク','ケ','コ']
                opt_lines = []
                for i, o in enumerate(opts):
                    label = kana[i] if i < len(kana) else f'選択肢{i+1}'
                    opt_lines.append(f"{label}: {o.text}")
                options_block = "\n".join(opt_lines)
                prompt = (
                    "あなたは日本語の講師です。以下の択一問題について、簡潔な解説を作成してください。\n"
                    "出力は必ず次のJSON形式のみで返してください．ただし出力する文章に「アの解説：」「正解です。」といった文は含めず，解説だけ書いてください：\n"
                    "{overall: 全体の解説, options: [「アの解説」, 「イの解説」, ...]}\n"
                    "要件:\n- 各選択肢ごとに正誤の要点と理由を1〜2文で説明\n- 専門用語は簡潔に補足\n- overallでは問題全体の考え方を2〜4文で要約\n"
                    f"[問題タイトル]\n{p.title}\n"
                    f"[問題文]\n{p.body or ''}\n"
                    f"[選択肢]\n{options_block}\n"
                )
                # Build multimodal content (text + images if any)
                message_content = [{"type": "text", "text": prompt}]
                try:
                    imgs = list(db.execute(select(ProblemImage).where(ProblemImage.problem_id==p.id).order_by(ProblemImage.id.asc())).scalars().all())
                    import base64
                    for im in imgs[:4]:  # limit to first 4 images
                        fpath = os.path.join(UPLOAD_DIR, im.filename)
                        if not os.path.exists(fpath):
                            continue
                        with open(fpath, 'rb') as fh:
                            b64 = base64.b64encode(fh.read()).decode('ascii')
                        # Guess mime from extension
                        ext = os.path.splitext(im.filename)[1].lower()
                        mime = 'image/jpeg' if ext in ('.jpg', '.jpeg') else 'image/png' if ext=='.png' else 'image/webp' if ext=='.webp' else 'application/octet-stream'
                        data_url = f"data:{mime};base64,{b64}"
                        message_content.append({"type": "image_url", "image_url": {"url": data_url}})
                except Exception:
                    pass
                resp = client.chat.completions.create(
                    model=OPENAI_MODEL,
                    messages=[{"role": "user", "content": message_content}],
                    temperature=0.2,
                    max_tokens=700,
                )
                raw = (resp.choices[0].message.content or '').strip()
                overall_txt = None
                option_txts = []
                try:
                    data = json.loads(raw)
                    if isinstance(data, dict):
                        if isinstance(data.get('overall'), str):
                            overall_txt = data['overall'].strip()
                        if isinstance(data.get('options'), list):
                            option_txts = [str(x).strip() for x in data['options']]
                except Exception:
                    overall_txt = raw

                if overall_txt:
                    db.add(Explanation(problem_id=p.id, user_id=None, content=overall_txt, option_index=None))
                for i in range(len(opts)):
                    txt = option_txts[i] if i < len(option_txts) else None
                    if txt and txt.strip():
                        db.add(Explanation(problem_id=p.id, user_id=None, content=txt.strip(), option_index=i))
                db.commit()
            else:
                # Free-text problem: overall explanation only
                prompt = (
                    "あなたは日本語の講師です。次の記述式問題について、400〜600字で簡潔に解説してください。\n"
                    "- ポイントを1〜3個に絞る\n- 専門用語は短く補足\n"
                    f"[問題タイトル] {p.title}\n[問題文] {p.body or ''}\n"
                )
                # Build multimodal content (text + images if any)
                message_content = [{"type": "text", "text": prompt}]
                try:
                    imgs = list(db.execute(select(ProblemImage).where(ProblemImage.problem_id==p.id).order_by(ProblemImage.id.asc())).scalars().all())
                    import base64
                    for im in imgs[:4]:
                        fpath = os.path.join(UPLOAD_DIR, im.filename)
                        if not os.path.exists(fpath):
                            continue
                        with open(fpath, 'rb') as fh:
                            b64 = base64.b64encode(fh.read()).decode('ascii')
                        ext = os.path.splitext(im.filename)[1].lower()
                        mime = 'image/jpeg' if ext in ('.jpg', '.jpeg') else 'image/png' if ext=='.png' else 'image/webp' if ext=='.webp' else 'application/octet-stream'
                        data_url = f"data:{mime};base64,{b64}"
                        message_content.append({"type": "image_url", "image_url": {"url": data_url}})
                except Exception:
                    pass
                resp = client.chat.completions.create(
                    model=OPENAI_MODEL,
                    messages=[{"role":"user","content": message_content}],
                    temperature=0.2,
                    max_tokens=500,
                )
                content = (resp.choices[0].message.content or '').strip()
                if content:
                    db.add(Explanation(problem_id=p.id, user_id=None, content=content, option_index=None))
                    db.commit()
    except Exception:
        # Do not raise in background thread
        pass

def regenerate_ai_explanations_preserve_likes(problem_id: int):
    """Regenerate AI explanations and preserve like_count by mapping on option_index/overall.
    Note: ExplanationLike 行は引き継ぎません（集計値のみ維持）。
    """
    try:
        # Capture previous like counts for AI explanations
        with SessionLocal() as db:
            prev = {}
            for e in db.execute(select(Explanation).where(Explanation.problem_id==problem_id, Explanation.user_id==None)).scalars().all():
                key = 'overall' if e.option_index is None else int(e.option_index)
                prev[key] = int(e.like_count or 0)
        # Regenerate fresh AI explanations (this clears prior AI explanations internally)
        generate_ai_explanations(problem_id)
        # Apply preserved counts to new rows
        with SessionLocal() as db:
            rows = db.execute(select(Explanation).where(Explanation.problem_id==problem_id, Explanation.user_id==None)).scalars().all()
            changed = False
            for e in rows:
                key = 'overall' if e.option_index is None else int(e.option_index)
                if key in prev:
                    if int(e.like_count or 0) != prev[key]:
                        e.like_count = prev[key]
                        changed = True
            if changed:
                db.commit()
    except Exception:
        pass

def generate_ai_explanation(problem_id: int):
    try:
        from openai import OpenAI
        client = OpenAI(api_key=OPENAI_API_KEY)
        with SessionLocal() as db:
            p = db.get(Problem, problem_id)
            if not p: return
            prompt = f"""あなたは日本語の講師です。次の問題に対して、200〜250文字程度で、
- ポイントを2~3個に絞る
- 問題文または正解の選択肢に含まれる重要な専門用語について詳しく説明する
というスタイルで、簡潔な解説を作成してください。
[問題タイトル] {p.title}
[問題文] {p.body or ''}
[種類] {p.qtype}
"""
            resp = client.chat.completions.create(model=OPENAI_MODEL, messages=[{"role":"user","content":prompt}], temperature=0.2, max_tokens=240)
            content = resp.choices[0].message.content.strip()
            db.add(Explanation(problem_id=p.id, user_id=None, content=content)); db.commit()
    except Exception: pass

@app.get("/problems/{pid:int}")
def problem_detail(pid: int, request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db)):
    p = db.get(Problem, pid)
    if not p: raise HTTPException(404, "not found")
    opts = db.execute(select(Option).where(Option.problem_id==pid)).scalars().all()
    # options include aliases for frontend compatibility: text/content and is_correct
    expl_liked = False
    liked = False
    try:
        u = get_user(db, authorization, request)
        if u:
            liked = db.execute(select(ProblemExplLike).where(ProblemExplLike.problem_id==p.id, ProblemExplLike.user_id==u.id)).scalar_one_or_none()
            expl_liked = (liked is not None)
            pl = db.execute(select(ProblemLike).where(ProblemLike.problem_id==p.id, ProblemLike.user_id==u.id)).scalar_one_or_none()
            liked = (pl is not None)
    except Exception:
        pass
    data = {"id": p.id, "title": p.title, "body": p.body, "qtype": p.qtype, "like_count": p.like_count, "liked": liked, "expl_like_count": p.expl_like_count, "expl_liked": expl_liked,
             "options":[{"id":o.id, "text":o.text, "content": o.text, "is_correct": bool(o.is_correct)} for o in opts],
             "images": [f"/uploads/{im.filename}" for im in db.execute(select(ProblemImage).where(ProblemImage.problem_id==pid).order_by(ProblemImage.id.asc())).scalars().all()]}
    # Only owner can see model_answer
    try:
        user = get_user(db, authorization, request)
        if user and user.id == p.created_by and p.model_answer is not None:
            data["model_answer"] = p.model_answer
    except HTTPException:
        pass
    return data

@app.get("/problems/for-explain")
def problems_for_explain(child_id: int, grand_id: Optional[int] = None, sort: str="likes", db: Session = Depends(get_db)):
    from sqlalchemy import func
    # likes: sum of explanation likes
    # ex_cnt: distinct authors (user-wise). AI(None) is treated as a single author via COALESCE(-1)
    q = select(Problem,
               func.coalesce(func.sum(Explanation.like_count),0).label("elikes"),
               func.count(func.distinct(func.coalesce(Explanation.user_id, -1))).label("ex_cnt")).outerjoin(Explanation, Explanation.problem_id==Problem.id)\
        .where(Problem.child_id==child_id)
    if grand_id: q = q.where(Problem.grand_id==grand_id)
    q = q.group_by(Problem.id)
    if sort=="likes": q = q.order_by(text("elikes DESC"), Problem.id.desc())
    elif sort=="explanations": q = q.order_by(text("ex_cnt DESC"), Problem.id.desc())
    else: q = q.order_by(Problem.id.desc())
    rows = db.execute(q).all()
    items=[{"id":r[0].id,"title":r[0].title,"body": r[0].body, "qtype": r[0].qtype, "like_count":int(r[1]),"ex_cnt":int(r[2])} for r in rows]
    return {"items": items}

@app.post("/problems/{pid}/explanations")
def create_explanation(pid: int, request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db),
                       content: str = Form(...)):
    user = get_user(db, authorization, request)
    p = db.get(Problem, pid)
    if not p: raise HTTPException(404, "not found")
    e = Explanation(problem_id=pid, user_id=user.id, content=content); db.add(e)
    db.commit(); return {"ok": True, "id": e.id}

@app.get("/problems/{pid:int}/explanations")
def list_explanations(pid: int, sort: str="likes", request: Request = None, authorization: Optional[str] = None, db: Session = Depends(get_db)):
    q = select(Explanation).where(Explanation.problem_id==pid)
    if sort=="likes":
        q = q.order_by(Explanation.like_count.desc(), Explanation.id.asc())
    elif sort=="recent":
        q = q.order_by(Explanation.id.desc())
    # fetch
    ex = db.execute(q).scalars().all()
    # determine liked ids by current user (optional)
    liked_ids = set()
    try:
        u = get_user(db, authorization, request)
        if u:
            liked_rows = db.execute(
                select(ExplanationLike.explanation_id)
                .join(Explanation, Explanation.id==ExplanationLike.explanation_id)
                .where(Explanation.problem_id==pid, ExplanationLike.user_id==u.id)
            ).all()
            liked_ids = {r[0] for r in liked_rows}
    except Exception:
        liked_ids = set()
    # enrich with author nickname and user_id
    items = []
    for e in ex:
        by = None
        if e.user_id is None:
            by = "AI"
        else:
            u = db.get(User, e.user_id)
            by = (u.nickname if u and u.nickname else (u.username if u else None))
        items.append({
            "id": e.id,
            "content": e.content,
            "likes": e.like_count,
            "is_ai": (e.user_id is None),
            "option_index": e.option_index,
            "user_id": e.user_id,
            "by": by,
            "liked": (e.id in liked_ids),
        })
    # if random requested, shuffle after enrichment
    if sort not in ("likes", "recent"):
        import random; random.shuffle(items)
    return {"items": items}

@app.get("/problems/{pid:int}/my-explanations")
def my_explanations(pid: int, request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db)):
    user = get_user(db, authorization, request)
    rows = db.execute(select(Explanation).where(Explanation.problem_id==pid, Explanation.user_id==user.id)).scalars().all()
    overall = None
    options = {}
    for e in rows:
        if e.option_index is None:
            overall = e.content
        else:
            options[int(e.option_index)] = e.content
    # Pack options as list in order
    max_idx = max(options.keys()) if options else -1
    option_list = [options.get(i) for i in range(max_idx+1)]
    return {"overall": overall, "options": option_list}

@app.post("/explanations/{eid}/like")
def like_explanation(eid: int, request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db)):
    user = get_user(db, authorization, request)
    e = db.get(Explanation, eid)
    if not e:
        raise HTTPException(404, "not found")
    # user-unique like
    exists = db.execute(select(ExplanationLike).where(ExplanationLike.explanation_id==eid, ExplanationLike.user_id==user.id)).scalar_one_or_none()
    if not exists:
        db.add(ExplanationLike(explanation_id=eid, user_id=user.id))
        e.like_count += 1
        db.commit()
    return {"ok": True, "likes": e.like_count}

# Toggle off: remove user's like for a specific explanation
@app.delete("/explanations/{eid}/like")
def unlike_explanation(eid: int, request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db)):
    user = get_user(db, authorization, request)
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

@app.get("/my/problems")
def my_problems(request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db), sort: str="new"):
    user = get_user(db, authorization, request)
    from sqlalchemy import func
    # Count distinct authors (user-wise). Treat AI(None) as a single author via COALESCE(-1).
    ex_authors = func.count(func.distinct(func.coalesce(Explanation.user_id, -1))).label("ex_cnt")
    q = select(Problem, ex_authors).outerjoin(Explanation, Explanation.problem_id==Problem.id).where(Problem.created_by==user.id).group_by(Problem.id)
    if sort=="likes": q = q.order_by(Problem.like_count.desc(), Problem.id.desc())
    elif sort=="ex_cnt": q = q.order_by(text("ex_cnt DESC"), Problem.id.desc())
    else: q = q.order_by(Problem.id.desc())
    rows = db.execute(q).all()
    return {"items":[{"id":r[0].id,"title":r[0].title,"qtype":r[0].qtype,"like_count":r[0].like_count,"ex_cnt":int(r[1])} for r in rows]}

@app.put("/problems/{pid}")
def edit_problem(pid: int, request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db),
    title: Optional[str] = Form(None), body: Optional[str] = Form(None), qtype: Optional[str] = Form(None),
    category_child_id: Optional[int] = Form(None), category_grand_id: Optional[int] = Form(None),
    options_text: Optional[str] = Form(None), options: Optional[str] = Form(None), correct_index: Optional[int] = Form(None),
    initial_explanation: Optional[str] = Form(None), option_explanations_text: Optional[str] = Form(None), option_explanations_json: Optional[str] = Form(None), model_answer: Optional[str] = Form(None),
    images: List[UploadFile] = File(None)):
    user = get_user(db, authorization, request)
    p = db.get(Problem, pid)
    if not p: raise HTTPException(404, "not found")
    is_owner = (p.created_by == user.id)
    # Determine whether problem metadata/options were updated by owner (not just explanations)
    should_regen_ai = is_owner and any(v is not None for v in [title, body, qtype, category_child_id, category_grand_id, options_text, options, correct_index, model_answer])
    # Only owners may change problem attributes/options. Non-owners may update ONLY their own explanations via this endpoint.
    if not is_owner:
        if any(v is not None for v in [title, body, qtype, category_child_id, category_grand_id, options_text, options, correct_index, model_answer]):
            raise HTTPException(403, "not owner")
    if is_owner and title is not None: p.title = title
    if is_owner and body is not None: p.body = body
    if is_owner and qtype is not None: p.qtype = qtype
    if is_owner and category_child_id is not None: p.child_id = category_child_id
    if is_owner and category_grand_id is not None: p.grand_id = category_grand_id
    if is_owner and model_answer is not None: p.model_answer = model_answer
    if p.qtype=="mcq":
        # Owners may edit option texts/correct index
        if is_owner:
            if options_text is None and options is not None:
                options_text = "\n".join([s.strip() for s in str(options).split(",")])
            if options_text is not None:
                # answers may reference options; null them before deleting options to avoid FK violation
                db.execute(update(Answer).where(Answer.problem_id==p.id).values(selected_option_id=None))
                db.query(Option).filter(Option.problem_id==p.id).delete()
                opts=[line.strip() for line in options_text.splitlines() if line.strip()]
                for i,t in enumerate(opts):
                    db.add(Option(problem_id=p.id, text=t, is_correct=(i==int(correct_index or 0))))
        # Any user may (re)write their own per-option explanations
        me = user.id
        if (option_explanations_json is not None) or (option_explanations_text is not None):
            db.query(Explanation).filter(Explanation.problem_id==p.id, Explanation.user_id==me, Explanation.option_index!=None).delete()
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
    # update overall explanation by this user if provided
    if initial_explanation is not None:
        me = user.id
        db.query(Explanation).filter(Explanation.problem_id==p.id, Explanation.user_id==me, Explanation.option_index==None).delete()
        if initial_explanation.strip():
            db.add(Explanation(problem_id=p.id, user_id=me, content=initial_explanation.strip(), option_index=None))
    # Enforce model_answer for free-text problems after updates (only for owners modifying model_answer/qtype)
    if is_owner and p.qtype == "free" and (p.model_answer is None or not str(p.model_answer).strip()):
        raise HTTPException(400, "model_answer required for free-text problems")
    db.commit(); return {"ok": True}

# Update profile (nickname)
@app.put("/me")
def update_me(request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db), nickname: Optional[str] = Form(None)):
    user = get_user(db, authorization, request)
    if nickname is not None:
        user.nickname = nickname
        db.commit()
    # If problem content changed by owner, regenerate AI explanations preserving like counts
    if should_regen_ai and OPENAI_ENABLED and OPENAI_API_KEY:
        try:
            db.commit()  # ensure latest changes are visible
        except Exception:
            pass
        threading.Thread(target=regenerate_ai_explanations_preserve_likes, args=(p.id,), daemon=True).start()
    return {"ok": True}

@app.get("/problems/next")
def next_problem(
    request: Request,
    child_id: str = Query(...),
    grand_id: Optional[str] = Query(None),
    include_answered: Optional[bool] = Query(False),
    db: Session = Depends(get_db)
):
    # Parse query params robustly to avoid validation-related 422
    try:
        child_id_i = int(str(child_id).strip())
    except Exception:
        logger.warning("/problems/next invalid child_id: %s", child_id)
        raise HTTPException(400, "child_id must be integer")
    grand_id_i: Optional[int] = None
    if grand_id is not None and str(grand_id).strip() != "":
        try:
            grand_id_i = int(str(grand_id).strip())
        except Exception:
            logger.warning("/problems/next invalid grand_id: %s", grand_id)
            raise HTTPException(400, "grand_id must be integer")

    user = get_user(db, None, request)
    logger.info("/problems/next user=%s child_id=%s grand_id=%s", getattr(user, 'id', None), child_id_i, grand_id_i)
    subq = select(Answer.problem_id).where(Answer.user_id==user.id, Answer.is_correct==True)
    q = select(Problem).where(Problem.child_id==child_id_i)
    if grand_id_i is not None:
        q = q.where(Problem.grand_id==grand_id_i)
    # exclude already-correct problems unless include_answered is True
    if not include_answered:
        q = q.where(Problem.id.notin_(subq))
    qs = db.execute(q).scalars().all()
    if not qs: return {"problem": None}
    import random
    weights = [max(1, p.like_count) for p in qs]
    choice = random.choices(qs, weights=weights, k=1)[0]
    p = choice; opts = db.execute(select(Option).where(Option.problem_id==p.id)).scalars().all()
    # whether current user liked problem explanations / problem itself
    expl_liked = False
    liked = False
    try:
        el = db.execute(select(ProblemExplLike).where(ProblemExplLike.problem_id==p.id, ProblemExplLike.user_id==user.id)).scalar_one_or_none()
        expl_liked = (el is not None)
        pl = db.execute(select(ProblemLike).where(ProblemLike.problem_id==p.id, ProblemLike.user_id==user.id)).scalar_one_or_none()
        liked = (pl is not None)
    except Exception:
        expl_liked = False
        liked = False
    imgs = db.execute(select(ProblemImage).where(ProblemImage.problem_id==p.id).order_by(ProblemImage.id.asc())).scalars().all()
    return {"id": p.id, "title": p.title, "body": p.body, "qtype": p.qtype, "like_count": p.like_count, "liked": liked, "expl_like_count": p.expl_like_count, "expl_liked": expl_liked,
             "images": [f"/uploads/{im.filename}" for im in imgs],
             "options":[{"id":o.id, "text":o.text, "content": o.text} for o in opts]}

@app.post("/problems/{pid:int}/answer")
def answer(pid: int, request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db),
           selected_option_id: Optional[int]=Form(None), free_text: Optional[str]=Form(None),
           is_correct: Optional[bool]=Form(None)):
    user = get_user(db, authorization, request)
    p = db.get(Problem, pid)
    if not p: raise HTTPException(404, "not found")
    correct = None
    if p.qtype=="mcq":
        if selected_option_id is None: raise HTTPException(400, "option required")
        o = db.get(Option, selected_option_id)
        correct = bool(o and o.is_correct)
    else:
        if is_correct is None: raise HTTPException(400, "is_correct required")
        correct = bool(is_correct)
    db.add(Answer(problem_id=pid, user_id=user.id, selected_option_id=selected_option_id, free_text=free_text, is_correct=correct))
    if correct:
        user.points += 1
    db.commit()
    ex = db.execute(select(Explanation).where(Explanation.problem_id==pid).order_by(Explanation.like_count.desc(), Explanation.id.asc())).scalars().all()
    return {"is_correct": correct, "explanations":[{"id":e.id,"content":e.content,"likes":e.like_count, "is_ai": (e.user_id is None)} for e in ex]}

# Problem like
@app.post("/problems/{pid:int}/like")
def like_problem(pid: int, request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db)):
    user = get_user(db, authorization, request)
    p = db.get(Problem, pid)
    if not p:
        raise HTTPException(404, "not found")
    # user-unique like
    exists = db.execute(select(ProblemLike).where(ProblemLike.problem_id==pid, ProblemLike.user_id==user.id)).scalar_one_or_none()
    if not exists:
        db.add(ProblemLike(problem_id=pid, user_id=user.id))
        p.like_count += 1
        db.commit()
    return {"ok": True, "like_count": p.like_count}

# Toggle off: remove current user's like for problem
@app.delete("/problems/{pid:int}/like")
def unlike_problem(pid: int, request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db)):
    user = get_user(db, authorization, request)
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

# Explanations like (problem-level)
@app.post("/problems/{pid:int}/explanations/like")
def like_problem_explanations(pid: int, request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db)):
    user = get_user(db, authorization, request)
    p = db.get(Problem, pid)
    if not p:
        raise HTTPException(404, "not found")
    # user-unique like for problem's explanations
    exists = db.execute(select(ProblemExplLike).where(ProblemExplLike.problem_id==pid, ProblemExplLike.user_id==user.id)).scalar_one_or_none()
    if not exists:
        db.add(ProblemExplLike(problem_id=pid, user_id=user.id))
        p.expl_like_count += 1
        db.commit()
    return {"ok": True, "expl_like_count": p.expl_like_count}

# Toggle off: remove current user's like for problem explanations (summary)
@app.delete("/problems/{pid:int}/explanations/like")
def unlike_problem_explanations(pid: int, request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db)):
    user = get_user(db, authorization, request)
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

# Leaderboard
@app.get("/leaderboard")
def leaderboard(metric: str = "points", db: Session = Depends(get_db)):
    metric = (metric or "points").lower()
    items = []
    if metric == "points":
        rows = db.execute(select(User.id, User.username, User.nickname, User.points.label("val")).order_by(User.points.desc(), User.id.asc())).all()
        items = [{"user_id": r.id, "username": r.username, "nickname": r.nickname, "value": int(r.val or 0), "score": int(r.val or 0)} for r in rows]
    elif metric in ("created_problem", "created_problems", "problems_created"):
        # Count of problems created per user
        from sqlalchemy import func
        rows = db.execute(
            select(User.id, User.username, User.nickname, func.count(Problem.id).label("val"))
            .outerjoin(Problem, Problem.created_by==User.id)
            .group_by(User.id)
            .order_by(text("val DESC"), User.id.asc())
        ).all()
        items = [{"user_id": r.id, "username": r.username, "nickname": r.nickname, "value": int(r.val or 0), "score": int(r.val or 0)} for r in rows]
    elif metric in ("created_expl", "created_explanation", "explanations_created"):
        # Count explanations by distinct problem per user (avoid counting per-option multiples)
        from sqlalchemy import func
        rows = db.execute(
            select(User.id, User.username, User.nickname, func.count(func.distinct(Explanation.problem_id)).label("val"))
            .outerjoin(Explanation, Explanation.user_id==User.id)
            .group_by(User.id)
            .order_by(text("val DESC"), User.id.asc())
        ).all()
        items = [{"user_id": r.id, "username": r.username, "nickname": r.nickname, "value": int(r.val or 0), "score": int(r.val or 0)} for r in rows]
    elif metric == "likes":
        # Sum of likes on explanations written by the user
        from sqlalchemy import func
        rows = db.execute(
            select(User.id, User.username, User.nickname, func.coalesce(func.sum(Explanation.like_count), 0).label("val"))
            .outerjoin(Explanation, Explanation.user_id==User.id)
            .group_by(User.id)
            .order_by(text("val DESC"), User.id.asc())
        ).all()
        items = [{"user_id": r.id, "username": r.username, "nickname": r.nickname, "value": int(r.val or 0), "score": int(r.val or 0)} for r in rows]
    elif metric in ("likes_problem", "likes_problems"):
        # Sum of likes on problems the user created
        from sqlalchemy import func
        rows = db.execute(
            select(User.id, User.username, User.nickname, func.coalesce(func.sum(Problem.like_count), 0).label("val"))
            .outerjoin(Problem, Problem.created_by==User.id)
            .group_by(User.id)
            .order_by(text("val DESC"), User.id.asc())
        ).all()
        items = [{"user_id": r.id, "username": r.username, "nickname": r.nickname, "value": int(r.val or 0), "score": int(r.val or 0)} for r in rows]
    elif metric in ("likes_expl", "likes_explanations"):
        # Sum likes for explanations per problem per user, then aggregate per user (avoid per-option inflation)
        from sqlalchemy import func
        sub = (
            select(Explanation.user_id.label("uid"), Explanation.problem_id.label("pid"), func.coalesce(func.sum(Explanation.like_count), 0).label("grp"))
            .group_by(Explanation.user_id, Explanation.problem_id)
        ).subquery()
        rows = db.execute(
            select(User.id, User.username, User.nickname, func.coalesce(func.sum(sub.c.grp), 0).label("val"))
            .outerjoin(sub, sub.c.uid==User.id)
            .group_by(User.id)
            .order_by(text("val DESC"), User.id.asc())
        ).all()
        items = [{"user_id": r.id, "username": r.username, "nickname": r.nickname, "value": int(r.val or 0), "score": int(r.val or 0)} for r in rows]
    elif metric == "created":
        from sqlalchemy import func
        rows = db.execute(
            select(User.id, User.username, User.nickname, func.count(Problem.id).label("val"))
            .outerjoin(Problem, Problem.created_by==User.id)
            .group_by(User.id)
            .order_by(text("val DESC"), User.id.asc())
        ).all()
        items = [{"user_id": r.id, "username": r.username, "nickname": r.nickname, "value": int(r.val or 0), "score": int(r.val or 0)} for r in rows]
    else:
        # default fallback to points
        rows = db.execute(select(User.id, User.username, User.nickname, User.points.label("val")).order_by(User.points.desc(), User.id.asc())).all()
        items = [{"user_id": r.id, "username": r.username, "nickname": r.nickname, "value": int(r.val or 0), "score": int(r.val or 0)} for r in rows]
    return {"items": items}

# Review stats
@app.get("/review/stats")
def review_stats(category_id: int, request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db), grand_id: Optional[int] = None):
    user = get_user(db, authorization, request)
    # answers joined with problems filtered by child category
    base = select(func.count(Answer.id)).join(Problem, Problem.id==Answer.problem_id).where(Answer.user_id==user.id, Problem.child_id==category_id)
    if grand_id is not None:
        base = base.where(Problem.grand_id==grand_id)
    solved = db.execute(base).scalar_one()
    base_correct = select(func.count(Answer.id)).join(Problem, Problem.id==Answer.problem_id).where(Answer.user_id==user.id, Problem.child_id==category_id, Answer.is_correct==True)
    if grand_id is not None:
        base_correct = base_correct.where(Problem.grand_id==grand_id)
    correct = db.execute(base_correct).scalar_one()
    solved = int(solved or 0); correct = int(correct or 0)
    rate = int(round((correct/solved*100), 0)) if solved>0 else 0
    return {"solved": solved, "correct": correct, "rate": rate}

# Review history: latest answer per problem for the user, filtered by child/grand
@app.get("/review/history")
def review_history(category_id: int, grand_id: Optional[int] = None, request: Request = None, authorization: Optional[str] = None, db: Session = Depends(get_db)):
    user = get_user(db, authorization, request)
    # subquery to get latest answer id per problem for this user under filters
    base = select(Answer.id).join(Problem, Problem.id==Answer.problem_id).where(Answer.user_id==user.id, Problem.child_id==category_id)
    if grand_id is not None:
        base = base.where(Problem.grand_id==grand_id)
    # latest id per problem (assuming autoincrement id follows time)
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

# Review item detail: problem + user's latest answer + top explanations by likes
@app.get("/review/item")
def review_item(pid: int, request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db)):
    user = get_user(db, authorization, request)
    p = db.get(Problem, pid)
    if not p: raise HTTPException(404, "not found")
    # latest answer by this user
    a = db.execute(select(Answer).where(Answer.user_id==user.id, Answer.problem_id==pid).order_by(Answer.id.desc()).limit(1)).scalar_one_or_none()
    latest = None
    if a:
        latest = {"is_correct": a.is_correct, "free_text": a.free_text, "selected_option_id": a.selected_option_id}
    # top explanations by likes
    ex = db.execute(select(Explanation).where(Explanation.problem_id==pid).order_by(Explanation.like_count.desc(), Explanation.id.asc()).limit(5)).scalars().all()
    ex_items = [{"id": e.id, "content": e.content, "likes": e.like_count, "is_ai": (e.user_id is None)} for e in ex]
    return {"problem": {"id": p.id, "title": p.title, "body": p.body, "qtype": p.qtype}, "latest_answer": latest, "explanations": ex_items}

# Override correctness: add a manual answer record with desired correctness
@app.post("/review/mark")
def review_mark(pid: int, is_correct: bool, request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db)):
    user = get_user(db, authorization, request)
    # Create a light-weight answer record to reflect override
    db.add(Answer(problem_id=pid, user_id=user.id, selected_option_id=None, free_text=None, is_correct=bool(is_correct)))
    db.commit()
    return {"ok": True}

# List problems that current user has posted explanations for
@app.get("/my/explanations/problems")
def my_explanations_problems(request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db)):
    user = get_user(db, authorization, request)
    from sqlalchemy import func
    rows = db.execute(
        select(Problem.id, Problem.title, Problem.qtype, func.coalesce(func.sum(Explanation.like_count), 0).label("my_like"))
        .join(Explanation, Explanation.problem_id==Problem.id)
        .where(Explanation.user_id==user.id)
        .group_by(Problem.id)
        .order_by(Problem.id.desc())
    ).all()
    return {"items": [{"id": r.id, "title": r.title, "qtype": r.qtype, "my_like_count": int(getattr(r, 'my_like') or 0)} for r in rows]}

# Delete a problem (owner only)
@app.delete("/problems/{pid:int}")
def delete_problem(pid: int, request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db)):
    user = get_user(db, authorization, request)
    p = db.get(Problem, pid)
    if not p:
        raise HTTPException(404, "not found")
    if p.created_by != user.id:
        raise HTTPException(403, "forbidden")
    # Delete likes on explanations under this problem
    ex_ids = [row[0] for row in db.execute(select(Explanation.id).where(Explanation.problem_id == pid)).all()]
    if ex_ids:
        db.query(ExplanationLike).filter(ExplanationLike.explanation_id.in_(ex_ids)).delete(synchronize_session=False)
    # Delete explanations, answers, options
    db.query(Explanation).filter(Explanation.problem_id == pid).delete(synchronize_session=False)
    db.query(Answer).filter(Answer.problem_id == pid).delete(synchronize_session=False)
    db.query(Option).filter(Option.problem_id == pid).delete(synchronize_session=False)
    # Delete problem-level likes
    db.query(ProblemLike).filter(ProblemLike.problem_id == pid).delete(synchronize_session=False)
    db.query(ProblemExplLike).filter(ProblemExplLike.problem_id == pid).delete(synchronize_session=False)
    # Delete images from disk and rows
    imgs = db.execute(select(ProblemImage).where(ProblemImage.problem_id == pid)).scalars().all()
    for img in imgs:
        try:
            path = os.path.join(UPLOAD_DIR, img.filename)
            if os.path.exists(path):
                os.remove(path)
        except Exception:
            pass
    db.query(ProblemImage).filter(ProblemImage.problem_id == pid).delete(synchronize_session=False)
    # Finally delete problem
    db.delete(p)
    db.commit()
    return {"ok": True}

# Delete current user's explanations for a problem
@app.delete("/problems/{pid:int}/my-explanations")
def delete_my_explanations(pid: int, request: Request, authorization: Optional[str] = None, db: Session = Depends(get_db)):
    user = get_user(db, authorization, request)
    ex_ids = [row[0] for row in db.execute(select(Explanation.id).where(Explanation.problem_id == pid, Explanation.user_id == user.id)).all()]
    if not ex_ids:
        return {"ok": True, "deleted": 0}
    db.query(ExplanationLike).filter(ExplanationLike.explanation_id.in_(ex_ids)).delete(synchronize_session=False)
    deleted = db.query(Explanation).filter(Explanation.id.in_(ex_ids)).delete(synchronize_session=False)
    db.commit()
    return {"ok": True, "deleted": int(deleted or 0)}

## sample problem seeding removed
