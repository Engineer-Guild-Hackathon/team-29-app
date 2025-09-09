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
