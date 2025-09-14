from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import Integer, String, ForeignKey, Boolean
from .base import Base

class Option(Base):
    __tablename__ = "options"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    problem_id: Mapped[int] = mapped_column(ForeignKey("problems.id"))
    text: Mapped[str] = mapped_column(String(255))
    is_correct: Mapped[bool] = mapped_column(Boolean, default=False)
