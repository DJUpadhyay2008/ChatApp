from datetime import UTC, datetime

import pytest

from app.schemas.message import MessagePageResponse, MessageResponse
from app.schemas.user import UserProfile
from app.services.auth_service import auth_service
from app.services.chat_service import chat_service
from tests.conftest import create_test_jwt


@pytest.fixture
def mock_approved_user(monkeypatch):
    profile = UserProfile(
        id="user-alice",
        display_name="Alice",
        is_approved=True,
        is_admin=False,
        created_at=datetime.now(UTC),
    )
    monkeypatch.setattr(auth_service, "get_user_profile", lambda uid, tok: profile)
    return profile


def test_cannot_create_conversation_with_self(client, mock_approved_user):
    token = create_test_jwt(sub="user-alice")
    resp = client.post(
        "/conversations",
        headers={"Authorization": f"Bearer {token}"},
        json={"target_user_id": "user-alice"},
    )
    assert resp.status_code == 400
    assert "Cannot create a conversation with yourself" in resp.json()["detail"]


def test_unauthorized_conversation_messages_read(client, mock_approved_user, monkeypatch):
    token = create_test_jwt(sub="user-alice")

    # Mock verify_conversation_membership to return False (Alice is NOT a member)
    monkeypatch.setattr(chat_service, "verify_conversation_membership", lambda cid, uid, tok: False)

    resp = client.get(
        "/conversations/conv-bob-and-charlie/messages",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 403
    assert "not a member of this conversation" in resp.json()["detail"]


def test_unauthorized_message_send(client, mock_approved_user, monkeypatch):
    token = create_test_jwt(sub="user-alice")

    # Mock verify_conversation_membership to return False
    monkeypatch.setattr(chat_service, "verify_conversation_membership", lambda cid, uid, tok: False)

    resp = client.post(
        "/conversations/conv-bob-and-charlie/messages",
        headers={"Authorization": f"Bearer {token}"},
        json={"content": "Hello unauthorized eavesdropping!"},
    )
    assert resp.status_code == 403
    assert "not a member of this conversation" in resp.json()["detail"]


def test_empty_message_validation_rejected(client, mock_approved_user, monkeypatch):
    token = create_test_jwt(sub="user-alice")
    monkeypatch.setattr(chat_service, "verify_conversation_membership", lambda cid, uid, tok: True)

    # Empty whitespace content
    resp = client.post(
        "/conversations/conv-123/messages",
        headers={"Authorization": f"Bearer {token}"},
        json={"content": "   "},
    )
    assert resp.status_code == 422


def test_oversized_message_rejected(client, mock_approved_user, monkeypatch):
    token = create_test_jwt(sub="user-alice")
    monkeypatch.setattr(chat_service, "verify_conversation_membership", lambda cid, uid, tok: True)

    # Content length > 4000
    huge_content = "a" * 4001
    resp = client.post(
        "/conversations/conv-123/messages",
        headers={"Authorization": f"Bearer {token}"},
        json={"content": huge_content},
    )
    assert resp.status_code == 422


def test_send_and_paginate_messages(client, mock_approved_user, monkeypatch):
    token = create_test_jwt(sub="user-alice")
    now = datetime.now(UTC)

    # Mock membership to True
    monkeypatch.setattr(chat_service, "verify_conversation_membership", lambda cid, uid, tok: True)
    monkeypatch.setattr(
        chat_service, "get_conversation_participants", lambda cid, tok: ["user-alice", "user-bob"]
    )

    # Mock save_message
    saved_msg = MessageResponse(
        id="msg-101",
        conversation_id="conv-123",
        sender_id="user-alice",
        content="Hello Bob!",
        created_at=now,
        client_message_id="client-uuid-1",
    )
    monkeypatch.setattr(chat_service, "save_message", lambda **kwargs: saved_msg)

    # Test POST
    post_resp = client.post(
        "/conversations/conv-123/messages",
        headers={"Authorization": f"Bearer {token}"},
        json={"content": "Hello Bob!", "client_message_id": "client-uuid-1"},
    )
    assert post_resp.status_code == 200
    assert post_resp.json()["id"] == "msg-101"
    assert post_resp.json()["content"] == "Hello Bob!"

    # Test GET messages with cursor pagination
    page_resp = MessagePageResponse(
        messages=[saved_msg],
        has_more=False,
        next_cursor=None,
    )
    monkeypatch.setattr(chat_service, "get_messages", lambda **kwargs: page_resp)

    get_resp = client.get(
        "/conversations/conv-123/messages?limit=20",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert get_resp.status_code == 200
    body = get_resp.json()
    assert len(body["messages"]) == 1
    assert body["messages"][0]["id"] == "msg-101"
    assert body["has_more"] is False
