from pydantic import BaseModel
from typing import Optional, List

class RegisterIn(BaseModel):
    username: str
    password: str
    nickname: str

class LoginIn(BaseModel):
    username: str
    password: str

class TokenOut(BaseModel):
    access_token: str

class AnswerIn(BaseModel):
    selected_option_id: Optional[int] = None
    free_text: Optional[str] = None
    is_correct: Optional[bool] = None

class AiJudgementOut(BaseModel):
    problem_id: int
    user_id: int
    is_wrong: Optional[bool] = None
    score: Optional[int] = None
    reason: Optional[str] = None
    updated_at: Optional[str] = None