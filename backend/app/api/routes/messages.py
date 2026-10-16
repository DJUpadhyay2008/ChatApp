
from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.deps import get_current_approved_user
from app.schemas.message import (
    MessageCreateRequest,
    MessagePageResponse,
    MessageResponse,
)
from app.schemas.user import UserProfile
from app.services.chat_service import chat_service
from app.services.realtime_service import connection_manager

router = APIRouter(prefix="/conversations/{conversation_id}/messages", tags=["Messages"])


@router.get("", response_model=MessagePageResponse)
async def get_messages(
    conversation_id: str,
    limit: int = Query(default=30, ge=1, le=100),
    cursor: str | None = Query(default=None, description="Timestamp ISO string cursor for older messages"),
    approved_user: tuple[UserProfile, str] = Depends(get_current_approved_user),
):
    """
    Returns cursor-paginated messages in a conversation.
    Strictly verifies that the caller is a participant of the conversation.
    """
    profile, token = approved_user

    # Verify conversation membership
    is_member = chat_service.verify_conversation_membership(conversation_id, profile.id, token)
    if not is_member:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this conversation",
        )

    try:
        return chat_service.get_messages(
            conversation_id=conversation_id,
            user_id=profile.id,
            jwt_token=token,
            limit=limit,
            cursor=cursor,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch messages: {e!s}",
        )


@router.post("", response_model=MessageResponse)
async def send_message(
    conversation_id: str,
    req: MessageCreateRequest,
    approved_user: tuple[UserProfile, str] = Depends(get_current_approved_user),
):
    """
    Sends and persists a new message in the conversation.
    Verifies membership, persists to PostgreSQL with RLS, and broadcasts in realtime.
    """
    profile, token = approved_user

    # Verify membership
    is_member = chat_service.verify_conversation_membership(conversation_id, profile.id, token)
    if not is_member:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this conversation",
        )

    # Persist message
    try:
        message = chat_service.save_message(
            conversation_id=conversation_id,
            sender_id=profile.id,
            content=req.content,
            jwt_token=token,
            client_message_id=req.client_message_id,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to persist message: {e!s}",
        )

    # Get conversation participants to broadcast to
    try:
        participants = chat_service.get_conversation_participants(conversation_id, token)
        await connection_manager.broadcast_new_message(participants, message)
    except Exception:
        # Realtime broadcast failure does not undo persisted message
        pass

    return message
