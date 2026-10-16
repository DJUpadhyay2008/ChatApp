from datetime import datetime

from pydantic import BaseModel, Field, field_validator


class MessageCreateRequest(BaseModel):
    content: str = Field(..., max_length=4000, description="Text message content")
    client_message_id: str | None = Field(default=None, description="Client deduplication ID")

    @field_validator("content")
    @classmethod
    def validate_content_not_empty(cls, v: str) -> str:
        trimmed = v.strip()
        if not trimmed:
            raise ValueError("Message content cannot be empty or only whitespace")
        if len(v) > 4000:
            raise ValueError("Message exceeds maximum allowed length of 4000 characters")
        return v


class MessageResponse(BaseModel):
    id: str
    conversation_id: str
    sender_id: str
    content: str
    created_at: datetime
    client_message_id: str | None = None


class MessagePageResponse(BaseModel):
    messages: list[MessageResponse]
    has_more: bool
    next_cursor: str | None = None
