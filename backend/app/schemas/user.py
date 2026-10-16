from datetime import datetime

from pydantic import BaseModel, Field


class UserProfile(BaseModel):
    id: str
    display_name: str
    is_approved: bool
    is_admin: bool
    created_at: datetime


class UserSummary(BaseModel):
    id: str
    display_name: str


class UserApprovalRequest(BaseModel):
    user_id: str = Field(..., description="Target user UUID to approve or revoke")
    approve: bool = Field(default=True, description="True to approve, False to revoke")
