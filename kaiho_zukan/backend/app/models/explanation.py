import datetime as dt
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import Integer, ForeignKey, Text, DateTime, String, UniqueConstraint

from .base import Base

class Explanation(Base):
    __tablename__ = "explanations"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    problem_id: Mapped[int] = mapped_column(ForeignKey("problems.id"))
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)  # None=AI
    content: Mapped[str] = mapped_column(Text)
    like_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)
    option_index: Mapped[int | None] = mapped_column(Integer, nullable=True)

class ExplanationImage(Base):
    __tablename__ = "explanation_images"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    explanation_id: Mapped[int] = mapped_column(ForeignKey("explanations.id"))
    filename: Mapped[str] = mapped_column(String(255))  # UPLOAD_DIR 下の相対パス
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
