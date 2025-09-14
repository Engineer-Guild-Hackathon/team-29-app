from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import select
from core.db import get_db
from models import Category

router = APIRouter(prefix="/categories", tags=["categories"])

@router.get("/tree")
def cat_tree(db: Session = Depends(get_db)):
    parents = db.execute(
        select(Category).where(Category.parent_id == None).order_by(Category.id)
    ).scalars().all()
    def to_dict(cat: Category):
        return {"id": cat.id, "name": cat.name,
                "children":[{"id": c.id, "name": c.name,
                             "children":[{"id": g.id,"name": g.name} for g in c.children]} for c in cat.children]}
    return [to_dict(p) for p in parents]
