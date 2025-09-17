from pydantic import BaseModel

class RegisterIn(BaseModel):
    username: str
    password: str
    nickname: str

class LoginIn(BaseModel):
    username: str
    password: str

class TokenOut(BaseModel):
    access_token: str
