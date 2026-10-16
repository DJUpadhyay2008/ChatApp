
from fastapi import APIRouter, Depends, HTTPException, status

from app.api.deps import get_current_approved_user
from app.schemas.conversation import ConversationCreateRequest, ConversationResponse
from app.schemas.user import UserProfile
from app.services.chat_service import chat_service

router = APIRouter(prefix="/conversations", tags=["Conversations"])


@router.get("", response_model=list[ConversationResponse])
async def get_conversations(
    approved_user: tuple[UserProfile, str] = Depends(get_current_approved_user)
):
    """
    Returns all 1-to-1 conversations for the authenticated approved user.
    """
    profile, token = approved_user
    try:
        return chat_service.get_user_conversations(profile.id, token)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch conversations: {e!s}"
        )


@router.post("", response_model=dict)
async def create_conversation(
    req: ConversationCreateRequest,
    approved_user: tuple[UserProfile, str] = Depends(get_current_approved_user)
):
    """
    Creates or retrieves an existing 1-to-1 conversation with the target approved user.
    Enforces the single conversation invariant.
    """
    profile, token = approved_user
    try:
        conv_id = chat_service.create_or_get_conversation(
            current_user_id=profile.id,
            target_user_id=req.target_user_id,
            jwt_token=token,
        )
        return {"conversation_id": conv_id}
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error initiating conversation: {e!s}",
        )
