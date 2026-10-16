import json
import logging

from fastapi import WebSocket

from app.schemas.message import MessageResponse

logger = logging.getLogger("realtime_service")


class ConnectionManager:
    """
    Manages active WebSocket connections for online users.
    Single-instance in-memory connection routing suitable for 7-8 members on Render free tier.
    Designed with a clean interface that can be backed by Redis Pub/Sub if scaled horizontally.
    """
    def __init__(self):
        # Mapping: user_id -> set of active WebSockets (supports multiple tabs / devices)
        self.active_connections: dict[str, set[WebSocket]] = {}

    async def connect(self, user_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = set()
        self.active_connections[user_id].add(websocket)
        logger.info("WebSocket connected for user %s. Total sessions: %d", user_id, len(self.active_connections[user_id]))

    def disconnect(self, user_id: str, websocket: WebSocket) -> None:
        if user_id in self.active_connections:
            self.active_connections[user_id].discard(websocket)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]
        logger.info("WebSocket disconnected for user %s", user_id)

    async def send_personal_message(self, message: dict, websocket: WebSocket) -> None:
        try:
            await websocket.send_text(json.dumps(message))
        except Exception as e:
            logger.warning("Failed to send message to websocket: %s", str(e))

    async def broadcast_to_users(self, user_ids: list[str], event_type: str, data: dict) -> None:
        """
        Sends an event to specific authorized user IDs.
        """
        payload = json.dumps({"type": event_type, "data": data})
        for uid in user_ids:
            connections = self.active_connections.get(uid, set()).copy()
            for ws in connections:
                try:
                    await ws.send_text(payload)
                except Exception as e:
                    logger.warning("Error broadcasting to user %s: %s", uid, str(e))

    async def broadcast_new_message(self, participant_ids: list[str], message: MessageResponse) -> None:
        """
        Broadcasts an authenticated, persisted message to authorized conversation participants.
        """
        data = message.model_dump(mode="json")
        await self.broadcast_to_users(participant_ids, event_type="new_message", data=data)


connection_manager = ConnectionManager()
