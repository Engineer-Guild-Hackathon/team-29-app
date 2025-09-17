import datetime as dt
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import Integer, ForeignKey, Text, DateTime, UniqueConstraint, Boolean
from .base import Base

class ModelAnswer(Base):
    __tablename__ = "model_answers"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    problem_id: Mapped[int] = mapped_column(ForeignKey("problems.id"))
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)  # NULL=AI
    content: Mapped[str] = mapped_column(Text)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)
    __table_args__ = (UniqueConstraint("problem_id", "user_id", name="uq_model_answer_per_user"),)

class AiJudgement(Base):
    __tablename__ = "ai_judgements"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    problem_id: Mapped[int] = mapped_column(ForeignKey("problems.id"), index=True, nullable=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    is_wrong: Mapped[bool | None] = mapped_column(Boolean, nullable=True)   # True=間違い, False=正しい, None=未判定
    score: Mapped[int | None] = mapped_column(Integer, nullable=True)       # 0-100
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)
    updated_at: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)

    __table_args__ = (UniqueConstraint("problem_id", "user_id", name="uq_ai_judgement_pid_uid"),)
