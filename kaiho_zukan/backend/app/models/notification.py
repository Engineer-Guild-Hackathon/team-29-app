import datetime as dt
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import Integer, String, Boolean, DateTime, ForeignKey, UniqueConstraint
from .base import Base


class Notification(Base):
    __tablename__ = "notifications"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    # recipient (who will see the notification)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    # type: 'problem_like' | 'explanation_like' | 'explanation_wrong'
    type: Mapped[str] = mapped_column(String(32), index=True)

    # related entities
    problem_id: Mapped[int | None] = mapped_column(ForeignKey("problems.id"), nullable=True, index=True)
    actor_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)

    # wrong-judgement flags (for explanation_wrong)
    ai_judged_wrong: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    crowd_judged_wrong: Mapped[bool | None] = mapped_column(Boolean, nullable=True)

    # state
    seen: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)

    __table_args__ = (
        # avoid duplicates for the same event signature
        UniqueConstraint(
            "user_id",
            "type",
            "problem_id",
            "actor_user_id",
            "ai_judged_wrong",
            "crowd_judged_wrong",
            name="uq_notification_unique_event",
        ),
    )

