from datetime import UTC, datetime

import pytest

from app.core.security import verify_supabase_token
from app.schemas.user import UserProfile
from app.services.auth_service import auth_service
from tests.conftest import create_test_jwt


def test_health_check(client):
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "environment" in data


@pytest.mark.asyncio
async def test_token_verification_success(valid_token):
    claims = await verify_supabase_token(valid_token)
    assert claims.user_id == "user-123"
    assert claims.email == "user123@example.com"


@pytest.mark.asyncio
async def test_token_verification_expired(expired_token):
    with pytest.raises(ValueError, match="Token has expired"):
        await verify_supabase_token(expired_token)


@pytest.mark.asyncio
async def test_token_verification_invalid_audience(invalid_audience_token):
    with pytest.raises(ValueError, match="Token audience is invalid"):
        await verify_supabase_token(invalid_audience_token)


@pytest.mark.asyncio
async def test_token_verification_missing_kid():
    # Token without valid kid in jwks
    bad_token = create_test_jwt(kid="nonexistent-key")
    with pytest.raises(ValueError, match="Unable to find signing key"):
        await verify_supabase_token(bad_token)


def test_users_me_unapproved_account(client, monkeypatch):
    token = create_test_jwt(sub="pending-user", email="pending@example.com")

    # Mock auth_service.get_user_profile to return unapproved user
    unapproved_profile = UserProfile(
        id="pending-user",
        display_name="Pending Member",
        is_approved=False,
        is_admin=False,
        created_at=datetime.now(UTC),
    )
    monkeypatch.setattr(auth_service, "get_user_profile", lambda uid, tok: unapproved_profile)

    # Calling /users/me should succeed and clearly show is_approved=False
    resp = client.get("/users/me", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["authenticated"] is True
    assert data["is_approved"] is False

    # Calling a protected approved endpoint like /conversations must return 403 Forbidden
    conv_resp = client.get("/conversations", headers={"Authorization": f"Bearer {token}"})
    assert conv_resp.status_code == 403
    assert "pending administrator approval" in conv_resp.json()["detail"]


def test_admin_approval_endpoint_protection(client, monkeypatch):
    regular_token = create_test_jwt(sub="regular-user", email="regular@example.com")
    admin_token = create_test_jwt(sub="admin-user", email="admin@example.com")

    regular_profile = UserProfile(
        id="regular-user",
        display_name="Regular Member",
        is_approved=True,
        is_admin=False,
        created_at=datetime.now(UTC),
    )
    admin_profile = UserProfile(
        id="admin-user",
        display_name="Admin Member",
        is_approved=True,
        is_admin=True,
        created_at=datetime.now(UTC),
    )

    def mock_profile(uid, tok):
        if uid == "admin-user":
            return admin_profile
        return regular_profile

    monkeypatch.setattr(auth_service, "get_user_profile", mock_profile)
    monkeypatch.setattr(auth_service, "set_user_approval", lambda target_user_id, approve: {"id": target_user_id, "is_approved": approve})

    # Non-admin attempting to approve another user must get 403 Forbidden
    resp = client.post(
        "/admin/approve-user",
        headers={"Authorization": f"Bearer {regular_token}"},
        json={"user_id": "target-user", "approve": True},
    )
    assert resp.status_code == 403

    # Admin user succeeds
    admin_resp = client.post(
        "/admin/approve-user",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"user_id": "target-user", "approve": True},
    )
    assert admin_resp.status_code == 200
    assert admin_resp.json()["status"] == "success"
    assert admin_resp.json()["is_approved"] is True
