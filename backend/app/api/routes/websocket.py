import json
import logging

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect

from app.core.security import verify_supabase_token
from app.services.realtime_service import connection_manager

logger = logging.getLogger("websocket")
router = APIRouter(tags=["WebSocket"])


@router.websocket("/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    token: str = Query(..., description="Supabase Auth JWT access token"),
):
    """
    Realtime WebSocket connection for authenticated users.
    Verifies JWT token prior to accepting the connection.
    Delivers live message broadcasts and supports keep-alive ping/pong.
    """
    user_id = None
    try:
        claims = await verify_supabase_token(token)
        user_id = claims.user_id
    except Exception as e:
        logger.warning("Rejected WebSocket connection: invalid auth token (%s)", str(e))
        await websocket.close(code=4001, reason="Invalid or expired token")
        return

    # Accept connection and register user session
    await connection_manager.connect(user_id, websocket)

    try:
        while True:
            # Listen for client keep-alive pings or client events
            text_data = await websocket.receive_text()
            try:
                msg = json.loads(text_data)
                msg_type = msg.get("type")
                if msg_type == "ping":
                    await websocket.send_text(json.dumps({"type": "pong"}))
            except json.JSONDecodeError:
                pass
    except WebSocketDisconnect:
        connection_manager.disconnect(user_id, websocket)
    except Exception as e:
        logger.error("WebSocket error for user %s: %s", user_id, str(e))
        connection_manager.disconnect(user_id, websocket)
