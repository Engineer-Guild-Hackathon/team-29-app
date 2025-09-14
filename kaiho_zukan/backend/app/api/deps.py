from fastapi import Depends, Request, HTTPException
from sqlalchemy.orm import Session
from core.db import get_db
from security.auth import parse_token
from models import User

def get_current_user(
    request: Request,
    db: Session = Depends(get_db),
    authorization: str | None = None
) -> User:
    token = None
    if authorization and authorization.lower().startswith("bearer "):
        token = authorization.split(" ", 1)[1].strip()
    if not token:
        auth = request.headers.get("authorization")
        if auth and auth.lower().startswith("bearer "):
            token = auth.split(" ",1)[1].strip()
    if not token:
        token = request.headers.get("X-Access-Token")
    if not token:
        raise HTTPException(401, "Unauthorized")
    uid = parse_token(token)
    if not uid:
        raise HTTPException(401, "Invalid token")
    user = db.get(User, uid)
    if not user:
        raise HTTPException(401, "User not found")
    return user
