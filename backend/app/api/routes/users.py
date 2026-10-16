
from fastapi import APIRouter, Depends

from app.api.deps import get_current_approved_user, get_current_user_claims
from app.core.security import UserClaims
from app.schemas.auth import AuthStatusResponse
from app.schemas.user import UserProfile, UserSummary
from app.services.auth_service import auth_service

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=AuthStatusResponse)
async def get_my_status(
    auth_data: tuple[UserClaims, str] = Depends(get_current_user_claims)
):
    """
    Returns current user's profile and approval status.
    Allows unapproved users to verify whether their account is pending approval.
    """
    claims, token = auth_data
    try:
        profile = auth_service.get_user_profile(claims.user_id, token)
    except Exception:
        profile = None

    is_approved = profile.is_approved if profile else False
    is_admin = profile.is_admin if profile else False
    display_name = profile.display_name if profile else (claims.email or "Member")

    return AuthStatusResponse(
        authenticated=True,
        user_id=claims.user_id,
        email=claims.email,
        is_approved=is_approved,
        is_admin=is_admin,
        display_name=display_name,
    )


@router.get("", response_model=list[UserSummary])
async def list_approved_members(
    approved_user: tuple[UserProfile, str] = Depends(get_current_approved_user)
):
    """
    Lists all other approved members for initiating private 1-on-1 conversations.
    Restricted to approved members only.
    """
    profile, token = approved_user
    return auth_service.list_approved_users(profile.id, token)
