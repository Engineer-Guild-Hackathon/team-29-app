from fastapi import APIRouter

from . import answers, explanations, interactions, manage, model_answers, retrieval

router = APIRouter(prefix="/problems", tags=["problems"])

router.include_router(manage.router)
router.include_router(retrieval.router)
router.include_router(explanations.router)
router.include_router(answers.router)
router.include_router(interactions.router)
router.include_router(model_answers.router)
