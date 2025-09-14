from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship
from sqlalchemy import Integer, String, ForeignKey, Text, Boolean, DateTime, UniqueConstraint
import datetime as dt
from typing import Optional


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    username: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    nickname: Mapped[str | None] = mapped_column(String(64), nullable=True)
    points: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)


class Category(Base):
    __tablename__ = "categories"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(128))
    parent_id: Mapped[int | None] = mapped_column(ForeignKey("categories.id"), nullable=True)
    level: Mapped[int] = mapped_column(Integer, default=0)
    parent: Mapped[Optional["Category"]] = relationship(remote_side=[id], backref="children")


class UserCategory(Base):
    __tablename__ = "user_categories"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    category_id: Mapped[int] = mapped_column(ForeignKey("categories.id"))


class Problem(Base):
    __tablename__ = "problems"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(255))
    body: Mapped[str | None] = mapped_column(Text, nullable=True)
    qtype: Mapped[str] = mapped_column(String(8))  # 'mcq' or 'free'
    child_id: Mapped[int] = mapped_column(ForeignKey("categories.id"))
    grand_id: Mapped[int] = mapped_column(ForeignKey("categories.id"))
    like_count: Mapped[int] = mapped_column(Integer, default=0)
    expl_like_count: Mapped[int] = mapped_column(Integer, default=0)
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)


class ProblemImage(Base):
    __tablename__ = "problem_images"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    problem_id: Mapped[int] = mapped_column(ForeignKey("problems.id"))
    # Stored relative filename under upload dir
    filename: Mapped[str] = mapped_column(String(255))
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)


class Option(Base):
    __tablename__ = "options"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    problem_id: Mapped[int] = mapped_column(ForeignKey("problems.id"))
    text: Mapped[str] = mapped_column(String(255))
    is_correct: Mapped[bool] = mapped_column(Boolean, default=False)


class Explanation(Base):
    __tablename__ = "explanations"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    problem_id: Mapped[int] = mapped_column(ForeignKey("problems.id"))
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)  # None=AI
    content: Mapped[str] = mapped_column(Text)
    like_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)
    option_index: Mapped[int | None] = mapped_column(Integer, nullable=True)

class Answer(Base):
    __tablename__ = "answers"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    problem_id: Mapped[int] = mapped_column(ForeignKey("problems.id"))
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    selected_option_id: Mapped[int | None] = mapped_column(ForeignKey("options.id"), nullable=True)
    free_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_correct: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)


# Per-user likes (unique)
class ProblemLike(Base):
    __tablename__ = "problem_likes"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    problem_id: Mapped[int] = mapped_column(ForeignKey("problems.id"))
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    __table_args__ = (UniqueConstraint("problem_id", "user_id", name="uq_problem_like"),)


class ExplanationLike(Base):
    __tablename__ = "explanation_likes"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    explanation_id: Mapped[int] = mapped_column(ForeignKey("explanations.id"))
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    __table_args__ = (UniqueConstraint("explanation_id", "user_id", name="uq_explanation_like"),)


class ProblemExplLike(Base):
    __tablename__ = "problem_expl_likes"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    problem_id: Mapped[int] = mapped_column(ForeignKey("problems.id"))
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    __table_args__ = (UniqueConstraint("problem_id", "user_id", name="uq_problem_expl_like"),)


class ModelAnswer(Base):
    __tablename__ = "model_answers"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    problem_id: Mapped[int] = mapped_column(ForeignKey("problems.id"))
    # user_id is nullable: NULL means AI's model answer
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    content: Mapped[str] = mapped_column(Text)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)
    __table_args__ = (UniqueConstraint("problem_id", "user_id", name="uq_model_answer_per_user"),)

class ExplanationImage(Base):
    __tablename__ = "explanation_images"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    explanation_id: Mapped[int] = mapped_column(ForeignKey("explanations.id"))
    # UPLOAD_DIR 下の相対パス/ファイル名を保存
    filename: Mapped[str] = mapped_column(String(255))
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)

class ExplanationWrongFlag(Base):
    __tablename__ = "explanations_wrong_flags"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    explanation_id: Mapped[int] = mapped_column(ForeignKey("explanations.id"), index=True, nullable=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)

    __table_args__ = (
        UniqueConstraint("explanation_id", "user_id", name="uq_expl_wrongflag_user"),
    )

class AiJudgement(Base):
    __tablename__ = "ai_judgements"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    problem_id: Mapped[int] = mapped_column(ForeignKey("problems.id"), index=True, nullable=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    is_wrong: Mapped[bool | None] = mapped_column(Boolean, nullable=True)   # True=間違い, False=正しい, None=未判定
    score: Mapped[int | None] = mapped_column(Integer, nullable=True)       # 0-100 信頼度
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)
    updated_at: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)

    __table_args__ = (
        UniqueConstraint("problem_id", "user_id", name="uq_ai_judgement_pid_uid"),
    )