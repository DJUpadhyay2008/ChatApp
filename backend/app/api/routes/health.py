from datetime import UTC, datetime

from fastapi import APIRouter

from app.core.config import settings

router = APIRouter(tags=["Health"])


@router.get("/health")
async def health_check():
    """
    Health check endpoint for Render, monitoring, and uptime checks.
    """
    return {
        "status": "healthy",
        "service": "private-chat-backend",
        "environment": settings.ENVIRONMENT,
        "timestamp": datetime.now(UTC).isoformat(),
    }
