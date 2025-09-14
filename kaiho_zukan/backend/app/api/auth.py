from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import select
from core.db import get_db
from models import User
from security.auth import hash_pw, verify_pw, make_token
from schemas.auth import RegisterIn, LoginIn, TokenOut

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/register", response_model=TokenOut)
def register(payload: RegisterIn, db: Session = Depends(get_db)):
    username = payload.username.strip()
    if not username or not payload.password:
        raise HTTPException(400, "username/password required")
    exists = db.execute(select(User).where(User.username==username)).scalar_one_or_none()
    if exists:
        raise HTTPException(400, "username already exists")
    user = User(username=username, password_hash=hash_pw(payload.password), nickname=payload.nickname or username)
    db.add(user); db.commit()
    return TokenOut(access_token=make_token(user.id))

@router.post("/login", response_model=TokenOut)
def login(payload: LoginIn, db: Session = Depends(get_db)):
    user = db.execute(select(User).where(User.username==payload.username)).scalar_one_or_none()
    if not user or not verify_pw(payload.password, user.password_hash):
        raise HTTPException(401, "invalid credentials")
    return TokenOut(access_token=make_token(user.id))
