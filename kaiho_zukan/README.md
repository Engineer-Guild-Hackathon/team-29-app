# Modular FastAPI backend (refactor)

This is a split of your monolithic backend into packages:
- `app/core`: configuration, security (JWT, password hashing)
- `app/db`: engine/session, startup tasks
- `app/models`: SQLAlchemy models
- `app/schemas`: Pydantic schemas
- `app/api/routers`: FastAPI routers grouped by domain
- `app/services`: background tasks (e.g., AI explanations)
- `app/utils`: helpers (file saving, JSON extraction)
- `app/main.py`: application factory and router registration
## How to run

```bash
export DATABASE_URL="mysql+pymysql://app:app@db:3306/learn"
export JWT_SECRET="change-me"
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Static uploads are served at `/uploads` (env `UPLOAD_DIR`, default `/data/uploads`).
