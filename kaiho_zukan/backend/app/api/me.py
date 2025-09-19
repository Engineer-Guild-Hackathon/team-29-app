from fastapi import APIRouter, Depends, Form
from sqlalchemy.orm import Session
from sqlalchemy import select, func, text
from api.deps import get_current_user
from core.db import get_db
from models import User, Category, UserCategory



def _icon_url(user: User) -> str:
    if getattr(user, "icon_path", None):
        return f"/uploads/{user.icon_path}"
    return f"https://api.dicebear.com/8.x/identicon/png?seed={user.username}"

router = APIRouter(tags=["me"])

@router.get("/me")
def me(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    cats = db.execute(
        select(Category.id, Category.name).join(UserCategory, UserCategory.category_id==Category.id).where(UserCategory.user_id==user.id)
    ).all()
    return {"id": user.id, "username": user.username, "nickname": user.nickname, "points": user.points,
            "icon_url": _icon_url(user),
            "categories": [{"id": c.id, "name": c.name} for c in cats]}

@router.post("/me/categories")
def set_my_categories(ids: list[int], user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    db.query(UserCategory).filter(UserCategory.user_id==user.id).delete()
    for cid in ids:
        db.add(UserCategory(user_id=user.id, category_id=cid))
    db.commit()
    return {"ok": True}

@router.put("/me")
def update_me(nickname: str | None = Form(None), user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if nickname is not None:
        user.nickname = nickname
        db.commit()
    return {"ok": True}

@router.get("/my/explanations/problems")
def my_explanations_problems(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    from models import Problem, Explanation
    rows = db.execute(
        select(Problem)
        .join(Explanation, Explanation.problem_id == Problem.id)
        .where(Explanation.user_id == user.id)
        .group_by(Problem.id)
        .order_by(Problem.id.desc())
    ).scalars().all()
    items = [{"id": p.id, "title": p.title, "qtype": p.qtype} for p in rows]
    return {"items": items}

@router.get("/my/problems")
def my_problems(sort: str = "new", user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    from models import Problem, Explanation
    base = (
        select(
            Problem,
            func.count(Explanation.id).label("ex_cnt"),
        )
        .outerjoin(Explanation, Explanation.problem_id == Problem.id)
        .where(Problem.created_by == user.id)
        .group_by(Problem.id)
    )
    if sort == "likes":
        q = base.order_by(Problem.like_count.desc(), Problem.id.desc())
    elif sort == "ex_cnt":
        q = base.order_by(text("ex_cnt DESC"), Problem.id.desc())
    else:
        q = base.order_by(Problem.id.desc())
    rows = db.execute(q).all()
    items = [
        {
            "id": p.id,
            "title": p.title,
            "qtype": p.qtype,
            "like_count": int(p.like_count or 0),
            "ex_cnt": int(ex_cnt or 0),
        }
        for p, ex_cnt in rows
    ]
    return {"items": items}
