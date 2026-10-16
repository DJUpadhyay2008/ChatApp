import json

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    ENVIRONMENT: str = Field(default="development", description="development | staging | production")
    PORT: int = Field(default=8000, description="Port to listen on")
    HOST: str = Field(default="0.0.0.0", description="Host to bind to")
    LOG_LEVEL: str = Field(default="info", description="Logging level")

    # Supabase credentials
    SUPABASE_URL: str = Field(default="https://placeholder.supabase.co", description="Supabase project URL")
    SUPABASE_ANON_KEY: str = Field(default="placeholder-anon-key", description="Supabase publishable anon key")
    SUPABASE_SERVICE_ROLE_KEY: str = Field(default="placeholder-service-role-key", description="Supabase privileged service role key")

    # JWT Verification
    SUPABASE_JWT_AUDIENCE: str = Field(default="authenticated", description="JWT audience claim")
    SUPABASE_JWT_ISSUER: str | None = Field(default=None, description="Optional JWT issuer check (defaults to {SUPABASE_URL}/auth/v1)")
    SUPABASE_JWT_SECRET: str | None = Field(default=None, description="Optional HMAC secret if using HS256")

    # CORS
    ALLOWED_ORIGINS: list[str] | str = Field(
        default=["http://localhost:3000", "http://localhost:8080", "http://127.0.0.1:3000"],
        description="Allowed CORS origins"
    )

    # Admin config
    ADMIN_EMAIL: str = Field(default="admin@example.com", description="Designated administrator email")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore"
    )

    @field_validator("ALLOWED_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: str | list[str]) -> list[str]:
        if isinstance(v, str):
            if v.startswith("[") and v.endswith("]"):
                try:
                    return json.loads(v)
                except Exception:
                    pass
            return [i.strip() for i in v.split(",") if i.strip()]
        return v

    @property
    def jwt_issuer(self) -> str:
        if self.SUPABASE_JWT_ISSUER:
            return self.SUPABASE_JWT_ISSUER.rstrip("/")
        return f"{self.SUPABASE_URL.rstrip('/')}/auth/v1"

    @property
    def jwks_url(self) -> str:
        return f"{self.SUPABASE_URL.rstrip('/')}/auth/v1/.well-known/jwks.json"


settings = Settings()
