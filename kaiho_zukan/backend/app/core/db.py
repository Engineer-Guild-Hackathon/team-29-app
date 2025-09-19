import time, random, os, json, datetime as dt
from sqlalchemy import create_engine, text, select, func
from sqlalchemy.orm import sessionmaker, Session
from core.config import get_settings
from models import (
    Base, User, Category, UserCategory, Problem, Option, Explanation, Answer,
    ProblemLike, ExplanationLike, ProblemExplLike, ProblemImage, ModelAnswer,
    ExplanationImage, ExplanationWrongFlag, AiJudgement
)

settings = get_settings()
engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True, future=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)

def get_db():
    with SessionLocal() as db:
        # MySQLの照合を明示しておく（必要環境のみ）
        try:
            db.execute(text("SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci"))
        except Exception:
            pass
        yield db

def wait_for_db(max_tries: int = 60):
    for _ in range(max_tries):
        try:
            with engine.connect() as conn:
                conn.execute(text("SELECT 1"))
            return
        except Exception:
            time.sleep(1)
    raise RuntimeError("DB not ready")

def create_all():
    Base.metadata.create_all(engine)

def ensure_schema():
    with engine.begin() as conn:
        # users.icon_path
        try:
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS icon_path VARCHAR(255) NULL"))
        except Exception:
            try:
                conn.execute(text("SELECT icon_path FROM users LIMIT 1"))
            except Exception:
                conn.execute(text("ALTER TABLE users ADD COLUMN icon_path VARCHAR(255) NULL"))

        # users.points
        try:
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS points INT NOT NULL DEFAULT 0"))
        except Exception:
            try:
                conn.execute(text("SELECT points FROM users LIMIT 1"))
            except Exception:
                conn.execute(text("ALTER TABLE users ADD COLUMN points INT NOT NULL DEFAULT 0"))
        # categories.level
        try:
            conn.execute(text("ALTER TABLE categories ADD COLUMN IF NOT EXISTS level INT NOT NULL DEFAULT 0"))
        except Exception:
            try:
                conn.execute(text("SELECT level FROM categories LIMIT 1"))
            except Exception:
                conn.execute(text("ALTER TABLE categories ADD COLUMN level INT NOT NULL DEFAULT 0"))

        # problems.model_answer -> model_answers に移行
        try:
            rows = conn.execute(text(
                "SELECT id, created_by, model_answer FROM problems WHERE model_answer IS NOT NULL AND model_answer <> ''"
            )).all()
            if rows:
                for rid, owner, content in rows:
                    try:
                        conn.execute(text("""
                            INSERT IGNORE INTO model_answers(problem_id, user_id, content, created_at)
                            VALUES (:pid, :uid, :ct, NOW())
                        """), {"pid": rid, "uid": owner, "ct": content})
                    except Exception:
                        pass
            try:
                conn.execute(text("ALTER TABLE problems DROP COLUMN model_answer"))
            except Exception:
                pass
        except Exception:
            pass

        # model_answers.user_id を NULL許容
        try:
            conn.execute(text("ALTER TABLE model_answers MODIFY COLUMN user_id INT NULL"))
        except Exception:
            pass

        # problems.expl_like_count
        try:
            conn.execute(text("ALTER TABLE problems ADD COLUMN IF NOT EXISTS expl_like_count INT NOT NULL DEFAULT 0"))
        except Exception:
            try:
                conn.execute(text("SELECT expl_like_count FROM problems LIMIT 1"))
            except Exception:
                conn.execute(text("ALTER TABLE problems ADD COLUMN expl_like_count INT NOT NULL DEFAULT 0"))

        # explanations.option_index
        try:
            conn.execute(text("ALTER TABLE explanations ADD COLUMN IF NOT EXISTS option_index INT NULL"))
        except Exception:
            try:
                conn.execute(text("SELECT option_index FROM explanations LIMIT 1"))
            except Exception:
                conn.execute(text("ALTER TABLE explanations ADD COLUMN option_index INT NULL"))

        # explanation_images
        try:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS explanation_images (
                  id INT AUTO_INCREMENT PRIMARY KEY,
                  explanation_id INT NOT NULL,
                  filename VARCHAR(255) NOT NULL,
                  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                  CONSTRAINT fk_explimg_expl FOREIGN KEY (explanation_id) REFERENCES explanations(id) ON DELETE CASCADE,
                  INDEX idx_explimg_expl (explanation_id)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            """))
        except Exception:
            pass

        # ai_judgements
        try:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS ai_judgements (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    problem_id INT NOT NULL,
                    user_id INT NOT NULL,
                    is_wrong TINYINT NULL,
                    score INT NULL,
                    reason TEXT NULL,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    UNIQUE KEY uq_ai_judgement_pid_uid (problem_id, user_id),
                    KEY idx_pid (problem_id),
                    KEY idx_uid (user_id),
                    CONSTRAINT fk_aij_prob FOREIGN KEY (problem_id) REFERENCES problems(id) ON DELETE CASCADE,
                    CONSTRAINT fk_aij_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            """))
        except Exception:
            pass

        # explanations_wrong_flags
        conn.execute(text("""
        CREATE TABLE IF NOT EXISTS explanations_wrong_flags (
            id INT AUTO_INCREMENT PRIMARY KEY,
            explanation_id INT NOT NULL,
            user_id INT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY uq_expl_wrongflag_user (explanation_id, user_id),
            KEY idx_expl (explanation_id),
            KEY idx_user (user_id),
            CONSTRAINT fk_expl_wrongflag_expl FOREIGN KEY (explanation_id) REFERENCES explanations(id) ON DELETE CASCADE,
            CONSTRAINT fk_expl_wrongflag_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        """))

        # notifications
        conn.execute(text("""
        CREATE TABLE IF NOT EXISTS notifications (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            type VARCHAR(32) NOT NULL,
            problem_id INT NULL,
            actor_user_id INT NULL,
            ai_judged_wrong TINYINT NULL,
            crowd_judged_wrong TINYINT NULL,
            seen TINYINT NOT NULL DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY uq_notification_unique_event (user_id, type, problem_id, actor_user_id, ai_judged_wrong, crowd_judged_wrong),
            KEY idx_user (user_id),
            KEY idx_type (type),
            CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            CONSTRAINT fk_notif_problem FOREIGN KEY (problem_id) REFERENCES problems(id) ON DELETE CASCADE,
            CONSTRAINT fk_notif_actor FOREIGN KEY (actor_user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        """))

def seed_categories():
    """IT資格/中学/高校/大学カテゴリを冪等投入"""
    from models import Category
    from sqlalchemy import select
    with SessionLocal() as s:
        def get_or_create(name: str, parent_id: int | None, level: int):
            q = select(Category).where(Category.name == name, Category.parent_id == parent_id)
            obj = s.execute(q).scalar_one_or_none()
            if obj:
                if obj.level != level:
                    obj.level = level
                return obj
            obj = Category(name=name, parent_id=parent_id, level=level)
            s.add(obj); s.flush(); return obj

        it = get_or_create("IT資格", None, 0)
        basic = get_or_create("基本情報", it.id, 1)
        applied = get_or_create("応用情報", it.id, 1)
        for u in ["基礎理論","アルゴリズム・プログラミング","コンピュータ構成要素","システム構成要素",
                  "ソフトウェア","ネットワーク","データベース","セキュリティ","開発技術",
                  "プロジェクトマネジメント","サービスマネジメント","システム戦略","経営戦略・企業と法務"]:
            get_or_create(u, basic.id, 2)
        for u in ["アルゴリズム","ネットワーク","データベース","セキュリティ","組込み・IoT","マネジメント","ストラテジ"]:
            get_or_create(u, applied.id, 2)

        jr = get_or_create("中学教材", None, 0)
        jr_map = {
            "国語": ["文法","読解","古典入門"],
            "数学": ["正負の数","文字式","方程式","関数","図形"],
            "英語": ["文法","読解","リスニング"],
            "理科": ["物理","化学","生物","地学"],
            "社会": ["地理","歴史","公民"],
        }
        for subj, units in jr_map.items():
            sc = get_or_create(subj, jr.id, 1)
            for u in units: get_or_create(u, sc.id, 2)

        hs = get_or_create("高校教材", None, 0)
        hs_map = {
            "国語": ["現代文","古文","漢文"],
            "数学": ["数学I","数学A","数学II","数学B"],
            "英語": ["英語コミュニケーションI","英語コミュニケーションII","英語表現"],
            "理科": ["物理基礎","化学基礎","生物基礎","地学基礎","物理","化学","生物","地学"],
            "社会": ["日本史","世界史","地理","政治・経済","倫理"],
        }
        for subj, units in hs_map.items():
            sc = get_or_create(subj, hs.id, 1)
            for u in units: get_or_create(u, sc.id, 2)

        uni = get_or_create("大学教材", None, 0)
        math = get_or_create("数学", uni.id, 1)
        for u in ["線形代数","微分方程式","複素関数","フーリエ解析"]: get_or_create(u, math.id, 2)
        ee = get_or_create("電気電子", uni.id, 1)
        for u in ["電気回路","電子回路","電磁気学"]: get_or_create(u, ee.id, 2)
        info = get_or_create("情報", uni.id, 1)
        for u in ["情報理論","論理回路"]: get_or_create(u, info.id, 2)
        s.commit()
