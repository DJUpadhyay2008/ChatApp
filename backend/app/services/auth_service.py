import logging
from typing import Any

from app.core.database import get_service_supabase_client, get_user_supabase_client
from app.schemas.user import UserProfile, UserSummary

logger = logging.getLogger("auth_service")


class AuthService:
    @staticmethod
    def get_user_profile(user_id: str, jwt_token: str) -> UserProfile | None:
        """
        Retrieves user profile using user-scoped client so RLS applies.
        """
        client = get_user_supabase_client(jwt_token)
        res = client.table("profiles").select("*").eq("id", user_id).execute()
        if not res.data:
            return None
        item = res.data[0]
        return UserProfile(
            id=item["id"],
            display_name=item["display_name"],
            is_approved=item["is_approved"],
            is_admin=item["is_admin"],
            created_at=item["created_at"],
        )

    @staticmethod
    def list_approved_users(current_user_id: str, jwt_token: str) -> list[UserSummary]:
        """
        Lists other approved members so the user can initiate a 1-to-1 conversation.
        """
        client = get_user_supabase_client(jwt_token)
        res = (
            client.table("profiles")
            .select("id, display_name")
            .eq("is_approved", True)
            .neq("id", current_user_id)
            .order("display_name")
            .execute()
        )
        return [UserSummary(id=row["id"], display_name=row["display_name"]) for row in res.data]

    @staticmethod
    def set_user_approval(target_user_id: str, approve: bool) -> dict[str, Any]:
        """
        Administrative function: approves or revokes an account.
        Uses the privileged service role client because normal users cannot modify is_approved.
        """
        service_client = get_service_supabase_client()
        res = (
            service_client.table("profiles")
            .update({"is_approved": approve})
            .eq("id", target_user_id)
            .execute()
        )
        if not res.data:
            raise ValueError(f"User {target_user_id} not found")
        return res.data[0]


auth_service = AuthService()
