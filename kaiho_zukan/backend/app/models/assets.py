import datetime as dt
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import Integer, ForeignKey, String, DateTime
from .base import Base

class ProblemImage(Base):
    __tablename__ = "problem_images"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    problem_id: Mapped[int] = mapped_column(ForeignKey("problems.id"))
    filename: Mapped[str] = mapped_column(String(255))  # UPLOAD_DIR 下の相対パスまたはファイル名
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)
