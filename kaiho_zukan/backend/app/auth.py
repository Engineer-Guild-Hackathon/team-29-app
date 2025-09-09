import os
import time
import logging
from passlib.context import CryptContext
from typing import Optional

# Use python-jose consistently (matching requirements.txt)
from jose import jwt
from jose.exceptions import ExpiredSignatureError, JWTClaimsError, JWTError


pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")
JWT_SECRET = os.getenv("JWT_SECRET")
JWT_ALG = "HS256"
JWT_EXPIRES_MIN = int(os.getenv("JWT_EXPIRES_MIN", "10080"))  # default: 7 days
logger = logging.getLogger("uvicorn.error")


def hash_pw(pw: str) -> str:
    return pwd.hash(pw)


def verify_pw(pw: str, hashed: str) -> bool:
    return pwd.verify(pw, hashed)


def make_token(user_id: int) -> str:
    if not JWT_SECRET:
        raise RuntimeError("JWT_SECRET is not set in environment")
    # sub must be a string per JWT spec and python-jose expectations
    payload = {
        "sub": str(user_id),
        "exp": int(time.time()) + JWT_EXPIRES_MIN * 60,
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALG)


def parse_token(token: str) -> Optional[int]:
    """Decode a Bearer token and return user id or None.

    Tries current `JWT_SECRET`, then `OLD_JWT_SECRET` if provided for rotation.
    """
    secrets: list[str] = []
    if JWT_SECRET:
        secrets.append(JWT_SECRET)
    legacy = os.getenv("OLD_JWT_SECRET")
    if legacy:
        secrets.append(legacy)
    for idx, secret in enumerate(secrets):
        try:
            payload = jwt.decode(token, secret, algorithms=[JWT_ALG])
            sub = payload.get("sub")
            if sub is not None:
                return int(sub)
        except ExpiredSignatureError as e:
            logger.warning("JWT expired (idx=%d): %s", idx, e)
        except JWTClaimsError as e:
            logger.warning("JWT claims error (idx=%d): %s", idx, e)
        except JWTError as e:
            logger.warning("JWT decode error (idx=%d): %s", idx, e)
        except Exception as e:
            logger.warning("JWT unexpected error (idx=%d): %s", idx, e)
    return None
