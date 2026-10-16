from pydantic import BaseModel


class AuthStatusResponse(BaseModel):
    authenticated: bool
    user_id: str
    email: str | None = None
    is_approved: bool
    is_admin: bool
    display_name: str
