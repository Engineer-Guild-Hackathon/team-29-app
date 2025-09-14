from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import Integer, ForeignKey, UniqueConstraint
from .base import Base

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
