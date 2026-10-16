import logging

from supabase import Client, create_client

from app.core.config import settings

logger = logging.getLogger("database")

# Privileged service role client instance (cached)
_service_client: Client | None = None


def get_service_supabase_client() -> Client:
    """
    Returns a privileged Supabase client using SUPABASE_SERVICE_ROLE_KEY.
    CAUTION: Bypasses RLS. Strictly restricted to administrative provisioning and user approval.
    """
    global _service_client
    if _service_client is None:
        _service_client = create_client(
            supabase_url=settings.SUPABASE_URL,
            supabase_key=settings.SUPABASE_SERVICE_ROLE_KEY
        )
    return _service_client


def get_user_supabase_client(user_token: str) -> Client:
    """
    Returns a user-scoped Supabase client that sends the user's JWT in the Authorization header.
    PostgreSQL Row Level Security (RLS) is strictly enforced for all queries made with this client.
    """
    client: Client = create_client(
        supabase_url=settings.SUPABASE_URL,
        supabase_key=settings.SUPABASE_ANON_KEY
    )
    # Set the user's JWT on postgrest client
    client.postgrest.auth(user_token)
    return client
