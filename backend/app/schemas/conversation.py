from datetime import datetime

from pydantic import BaseModel, Field


class ConversationCreateRequest(BaseModel):
    target_user_id: str = Field(..., description="Target user UUID for 1-to-1 conversation")


class ConversationParticipant(BaseModel):
    id: str
    display_name: str


class LastMessageSummary(BaseModel):
    id: str
    sender_id: str
    content: str
    created_at: datetime


class ConversationResponse(BaseModel):
    id: str
    created_at: datetime
    updated_at: datetime
    other_participant: ConversationParticipant
    last_message: LastMessageSummary | None = None
    unread_count: int = 0
