import datetime as dt
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import Integer, String, ForeignKey, Text, DateTime
from .base import Base

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
