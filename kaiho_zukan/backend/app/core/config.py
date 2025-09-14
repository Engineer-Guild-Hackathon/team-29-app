import os
from functools import lru_cache

class Settings:
    DATABASE_URL: str = os.getenv("DATABASE_URL", "mysql+pymysql://app:app@db:3306/learn")
    JWT_SECRET: str | None = os.getenv("JWT_SECRET")
    JWT_ALG: str = "HS256"
    # Minutes; default 7 days
    JWT_EXPIRES_MIN: int = int(os.getenv("JWT_EXPIRES_MIN", "10080"))

    OPENAI_ENABLED: bool = os.getenv("OPENAI_ENABLED", "false").lower() == "true"
    OPENAI_API_KEY: str | None = os.getenv("OPENAI_API_KEY")
    OPENAI_MODEL: str = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

    UPLOAD_DIR: str = os.getenv("UPLOAD_DIR", "/data/uploads")

@lru_cache
def get_settings() -> Settings:
    return Settings()
