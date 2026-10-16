import json

import pytest
from starlette.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.main import app
from tests.conftest import create_test_jwt


def test_websocket_auth_failure_rejected():
    client = TestClient(app)
    # Connecting with invalid token query parameter
    with (
        pytest.raises(WebSocketDisconnect) as excinfo,
        client.websocket_connect("/ws?token=invalid-token"),
    ):
        pass
    assert excinfo.value.code == 401 or excinfo.value.code == 4001


def test_websocket_auth_success_and_ping_pong():
    token = create_test_jwt(sub="ws-test-user")
    client = TestClient(app)

    with client.websocket_connect(f"/ws?token={token}") as websocket:
        # Send a ping message
        websocket.send_text(json.dumps({"type": "ping"}))
        # Receive pong response
        response = websocket.receive_text()
        data = json.loads(response)
        assert data.get("type") == "pong"
