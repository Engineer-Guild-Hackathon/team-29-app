import time, logging, os
from typing import Optional
from passlib.context import CryptContext
from jose import jwt
from jose.exceptions import ExpiredSignatureError, JWTClaimsError, JWTError
from core.config import get_settings

settings = get_settings()
pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")
logger = logging.getLogger("uvicorn.error")

def hash_pw(pw: str) -> str: return pwd.hash(pw)
def verify_pw(pw: str, hashed: str) -> bool: return pwd.verify(pw, hashed)

def make_token(user_id: int) -> str:
    if not settings.JWT_SECRET:
        raise RuntimeError("JWT_SECRET is not set")
    payload = {"sub": str(user_id), "exp": int(time.time()) + settings.JWT_EXPIRES_MIN * 60}
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALG)

def parse_token(token: str) -> Optional[int]:
    secrets: list[str] = []
    if settings.JWT_SECRET: secrets.append(settings.JWT_SECRET)
    legacy = os.getenv("OLD_JWT_SECRET")
    if legacy: secrets.append(legacy)
    for idx, secret in enumerate(secrets):
        try:
            payload = jwt.decode(token, secret, algorithms=[settings.JWT_ALG])
            sub = payload.get("sub"); 
            if sub is not None: return int(sub)
        except (ExpiredSignatureError, JWTClaimsError, JWTError) as e:
            logger.warning("JWT error (idx=%d): %s", idx, e)
        except Exception as e:
            logger.warning("JWT unexpected (idx=%d): %s", idx, e)
    return None
