import logging
import time
from typing import Any

import httpx
import jwt
from jwt.algorithms import ECAlgorithm, RSAAlgorithm
from pydantic import BaseModel, Field

from app.core.config import settings

logger = logging.getLogger("security")


class UserClaims(BaseModel):
    user_id: str = Field(..., description="Supabase Auth UUID")
    email: str | None = None
    role: str = "authenticated"
    raw_claims: dict[str, Any] = Field(default_factory=dict)


class JWKSManager:
    """
    Caches and retrieves public signing keys from Supabase Auth JWKS endpoint.
    Refreshes periodically or on key lookup failure.
    """
    def __init__(self, jwks_url: str, cache_ttl_seconds: int = 3600):
        self.jwks_url = jwks_url
        self.cache_ttl_seconds = cache_ttl_seconds
        self._keys: dict[str, Any] = {}
        self._last_fetched: float = 0

    async def get_key_for_kid(self, kid: str) -> Any | None:
        current_time = time.time()
        # Fetch if cache expired or kid not found
        if not self._keys or (current_time - self._last_fetched > self.cache_ttl_seconds) or (kid not in self._keys):
            await self.refresh_keys()
        return self._keys.get(kid)

    async def refresh_keys(self) -> None:
        if "placeholder" in self.jwks_url:
            return
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(self.jwks_url)
                if resp.status_code == 200:
                    data = resp.json()
                    keys = {}
                    for key_dict in data.get("keys", []):
                        k_id = key_dict.get("kid")
                        k_type = key_dict.get("kty")
                        if not k_id:
                            continue
                        if k_type == "RSA":
                            keys[k_id] = RSAAlgorithm.from_jwk(key_dict)
                        elif k_type == "EC":
                            keys[k_id] = ECAlgorithm.from_jwk(key_dict)
                    self._keys = keys
                    self._last_fetched = time.time()
                    logger.info("JWKS keys refreshed successfully. Found %d keys.", len(self._keys))
                else:
                    logger.warning("Failed to fetch JWKS: HTTP %d", resp.status_code)
        except Exception as e:
            logger.error("Exception fetching JWKS: %s", str(e))


jwks_manager = JWKSManager(settings.jwks_url)


async def verify_supabase_token(token: str) -> UserClaims:
    """
    Verifies Supabase JWT token.
    Supports both JWKS asymmetric signing (RS256, ES256) and HMAC secret (HS256).
    """
    if not token or not token.strip():
        raise ValueError("Missing authentication token")

    try:
        unverified_header = jwt.get_unverified_header(token)
    except Exception as e:
        raise ValueError(f"Invalid token header: {e!s}")

    alg = unverified_header.get("alg")
    kid = unverified_header.get("kid")

    key: Any = None

    if alg in ["RS256", "ES256"] and kid:
        key = await jwks_manager.get_key_for_kid(kid)
        if not key:
            # If not found in cache, attempt one more fresh refresh
            await jwks_manager.refresh_keys()
            key = await jwks_manager.get_key_for_kid(kid)

    if not key and settings.SUPABASE_JWT_SECRET:
        # Fallback to shared secret
        key = settings.SUPABASE_JWT_SECRET

    if not key:
        # In test environments without real Supabase connection, allow mocking or raising
        raise ValueError(f"Unable to find signing key for token (alg={alg}, kid={kid})")

    try:
        # Validate claims
        decode_options = {
            "verify_signature": True,
            "verify_aud": bool(settings.SUPABASE_JWT_AUDIENCE),
            "verify_exp": True,
            "verify_iss": False,  # We verify issuer manually below for flexible matching
        }

        payload = jwt.decode(
            token,
            key=key,
            algorithms=[alg] if alg else ["RS256", "ES256", "HS256"],
            audience=settings.SUPABASE_JWT_AUDIENCE,
            options=decode_options,
        )

        # Issuer check
        if settings.jwt_issuer and "placeholder" not in settings.jwt_issuer:
            iss = payload.get("iss", "").rstrip("/")
            if iss != settings.jwt_issuer:
                raise ValueError("Token issuer mismatch")

        sub = payload.get("sub")
        if not sub:
            raise ValueError("Token missing 'sub' claim")

        return UserClaims(
            user_id=sub,
            email=payload.get("email"),
            role=payload.get("role", "authenticated"),
            raw_claims=payload,
        )
    except jwt.ExpiredSignatureError:
        raise ValueError("Token has expired")
    except jwt.InvalidAudienceError:
        raise ValueError("Token audience is invalid")
    except jwt.PyJWTError as e:
        raise ValueError(f"Token validation failed: {e!s}")
