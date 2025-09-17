from pydantic import BaseModel
from typing import Optional

class AnswerIn(BaseModel):
    selected_option_id: Optional[int] = None
    free_text: Optional[str] = None
    is_correct: Optional[bool] = None
