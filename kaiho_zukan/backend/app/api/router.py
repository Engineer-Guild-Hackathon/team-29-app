from fastapi import APIRouter
from . import auth, me, categories, problems, explanations, review, leaderboard

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(me.router)
api_router.include_router(categories.router)
api_router.include_router(problems.router)
api_router.include_router(explanations.router)
api_router.include_router(review.router)
api_router.include_router(leaderboard.router)
