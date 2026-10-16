from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.security import UserClaims, verify_supabase_token
from app.schemas.user import UserProfile
from app.services.auth_service import auth_service

security_scheme = HTTPBearer(auto_error=False)


async def get_raw_token(
    credentials: HTTPAuthorizationCredentials = Depends(security_scheme),
) -> str:
    if not credentials or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return credentials.credentials


async def get_current_user_claims(token: str = Depends(get_raw_token)) -> tuple[UserClaims, str]:
    try:
        claims = await verify_supabase_token(token)
        return claims, token
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
            headers={"WWW-Authenticate": "Bearer"},
        )


async def get_current_approved_user(
    auth_data: tuple[UserClaims, str] = Depends(get_current_user_claims),
) -> tuple[UserProfile, str]:
    claims, token = auth_data
    try:
        profile = auth_service.get_user_profile(claims.user_id, token)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to query user profile",
        )

    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found. Please log in again.",
        )

    if not profile.is_approved:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is pending administrator approval. Access is restricted to approved members.",
        )

    return profile, token


async def get_current_admin_user(
    auth_data: tuple[UserProfile, str] = Depends(get_current_approved_user),
) -> tuple[UserProfile, str]:
    profile, token = auth_data
    # Admin is either flagged in database or matches configured ADMIN_EMAIL
    if not profile.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Administrative privileges required for this operation",
        )
    return profile, token
