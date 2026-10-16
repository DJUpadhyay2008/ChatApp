import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.routes import admin, conversations, health, messages, users, websocket
from app.core.config import settings
from app.core.security import jwks_manager

# Configure logging
logging.basicConfig(
    level=settings.LOG_LEVEL.upper(),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("main")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting Private Chat Backend in %s mode", settings.ENVIRONMENT)
    # Eagerly refresh JWKS signing keys if possible
    try:
        await jwks_manager.refresh_keys()
    except Exception as e:
        logger.warning("JWKS pre-fetch skipped: %s", str(e))
    yield
    logger.info("Shutting down Private Chat Backend")


app = FastAPI(
    title="Private Chat App API",
    description="Secure, lightweight, invitation-only private messaging API",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.ENVIRONMENT != "production" else None,
    redoc_url=None,
)

# CORS Middleware - Restrict to allowed origins, prevent wildcard with credentials
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_origin_regex=r"^https://.*\.vercel\.app$",
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error("Unhandled exception processing %s %s: %s", request.method, request.url.path, str(exc), exc_info=True)
    # Never expose stack traces or internal secrets in response
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "An internal server error occurred. Please try again later."},
    )


# Include Routers
app.include_router(health.router)
app.include_router(users.router)
app.include_router(conversations.router)
app.include_router(messages.router)
app.include_router(admin.router)
app.include_router(websocket.router)
