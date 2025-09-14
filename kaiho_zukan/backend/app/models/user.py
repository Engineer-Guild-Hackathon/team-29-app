import datetime as dt
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import Integer, String, DateTime
from .base import Base

class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    username: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    nickname: Mapped[str | None] = mapped_column(String(64), nullable=True)
    points: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)
