from pydantic import BaseModel
from typing import Optional

class AiJudgementOut(BaseModel):
    problem_id: int
    user_id: int
    is_wrong: Optional[bool] = None
    score: Optional[int] = None
    reason: Optional[str] = None
    updated_at: Optional[str] = None
