
from fastapi import APIRouter, Depends, HTTPException, status

from app.api.deps import get_current_admin_user
from app.schemas.user import UserApprovalRequest, UserProfile
from app.services.auth_service import auth_service

router = APIRouter(prefix="/admin", tags=["Admin"])


@router.post("/approve-user")
async def set_user_approval_status(
    req: UserApprovalRequest,
    admin_user: tuple[UserProfile, str] = Depends(get_current_admin_user),
):
    """
    Administrative endpoint to approve or revoke a user account.
    Restricted strictly to administrators.
    """
    admin_profile, _ = admin_user
    try:
        updated = auth_service.set_user_approval(
            target_user_id=req.user_id,
            approve=req.approve,
        )
        return {
            "status": "success",
            "user_id": req.user_id,
            "is_approved": updated.get("is_approved"),
        }
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Admin action failed: {e!s}",
        )
