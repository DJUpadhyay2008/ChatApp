import logging

from app.core.database import get_user_supabase_client
from app.schemas.conversation import (
    ConversationParticipant,
    ConversationResponse,
    LastMessageSummary,
)
from app.schemas.message import MessagePageResponse, MessageResponse

logger = logging.getLogger("chat_service")


class ChatService:
    @staticmethod
    def get_user_conversations(current_user_id: str, jwt_token: str) -> list[ConversationResponse]:
        """
        Retrieves all 1-to-1 conversations for the current user,
        including the other participant's profile and the most recent message.
        """
        client = get_user_supabase_client(jwt_token)

        # 1. Fetch conversations the user is a member of
        members_res = (
            client.table("conversation_members")
            .select("conversation_id")
            .eq("user_id", current_user_id)
            .execute()
        )
        conv_ids = [m["conversation_id"] for m in members_res.data]
        if not conv_ids:
            return []

        # 2. Fetch conversation records
        conv_res = (
            client.table("conversations")
            .select("id, created_at, updated_at")
            .in_("id", conv_ids)
            .order("updated_at", desc=True)
            .execute()
        )

        # 3. Fetch all members for these conversations to identify the other participant
        all_members_res = (
            client.table("conversation_members")
            .select("conversation_id, user_id, profiles(id, display_name)")
            .in_("conversation_id", conv_ids)
            .execute()
        )

        # Map conversation_id -> other participant
        other_participants: dict[str, ConversationParticipant] = {}
        for row in all_members_res.data:
            c_id = row["conversation_id"]
            u_id = row["user_id"]
            if u_id != current_user_id:
                prof = row.get("profiles") or {}
                other_participants[c_id] = ConversationParticipant(
                    id=u_id,
                    display_name=prof.get("display_name", "Member")
                )

        # 4. Fetch the latest message for each conversation
        conversations: list[ConversationResponse] = []
        for conv in conv_res.data:
            c_id = conv["id"]
            other_p = other_participants.get(
                c_id, ConversationParticipant(id="unknown", display_name="Unknown")
            )

            # Get latest message
            latest_msg_res = (
                client.table("messages")
                .select("id, sender_id, content, created_at")
                .eq("conversation_id", c_id)
                .order("created_at", desc=True)
                .limit(1)
                .execute()
            )

            last_msg = None
            if latest_msg_res.data:
                m = latest_msg_res.data[0]
                last_msg = LastMessageSummary(
                    id=m["id"],
                    sender_id=m["sender_id"],
                    content=m["content"],
                    created_at=m["created_at"],
                )

            conversations.append(
                ConversationResponse(
                    id=c_id,
                    created_at=conv["created_at"],
                    updated_at=conv["updated_at"],
                    other_participant=other_p,
                    last_message=last_msg,
                    unread_count=0,
                )
            )

        return conversations

    @staticmethod
    def create_or_get_conversation(current_user_id: str, target_user_id: str, jwt_token: str) -> str:
        """
        Creates or returns an existing 1-on-1 conversation.
        Calls the secure database function create_or_get_direct_conversation.
        """
        if current_user_id == target_user_id:
            raise ValueError("Cannot create a conversation with yourself")

        client = get_user_supabase_client(jwt_token)
        # Call PostgreSQL RPC
        rpc_res = client.rpc(
            "create_or_get_direct_conversation",
            {"target_user_id": target_user_id}
        ).execute()

        if rpc_res.data:
            return str(rpc_res.data)
        raise ValueError("Failed to create or retrieve conversation")

    @staticmethod
    def verify_conversation_membership(conversation_id: str, user_id: str, jwt_token: str) -> bool:
        """
        Checks if user is an approved member of the conversation.
        """
        client = get_user_supabase_client(jwt_token)
        res = (
            client.table("conversation_members")
            .select("conversation_id")
            .eq("conversation_id", conversation_id)
            .eq("user_id", user_id)
            .execute()
        )
        return len(res.data) > 0

    @staticmethod
    def get_conversation_participants(conversation_id: str, jwt_token: str) -> list[str]:
        """
        Returns the user IDs of the participants in this conversation.
        """
        client = get_user_supabase_client(jwt_token)
        res = (
            client.table("conversation_members")
            .select("user_id")
            .eq("conversation_id", conversation_id)
            .execute()
        )
        return [row["user_id"] for row in res.data]

    @staticmethod
    def get_messages(
        conversation_id: str,
        user_id: str,
        jwt_token: str,
        limit: int = 30,
        cursor: str | None = None
    ) -> MessagePageResponse:
        """
        Cursor-based pagination for messages in a conversation.
        Cursor is a timestamp ISO string or message ID.
        """
        client = get_user_supabase_client(jwt_token)

        query = (
            client.table("messages")
            .select("id, conversation_id, sender_id, content, created_at")
            .eq("conversation_id", conversation_id)
            .order("created_at", desc=True)
            .limit(limit + 1)
        )

        if cursor:
            # Query messages older than cursor
            query = query.lt("created_at", cursor)

        res = query.execute()
        raw_msgs = res.data or []

        has_more = len(raw_msgs) > limit
        items = raw_msgs[:limit]

        next_cursor = None
        if items and has_more:
            next_cursor = items[-1]["created_at"]

        messages = [
            MessageResponse(
                id=item["id"],
                conversation_id=item["conversation_id"],
                sender_id=item["sender_id"],
                content=item["content"],
                created_at=item["created_at"],
            )
            for item in items
        ]

        return MessagePageResponse(
            messages=messages,
            has_more=has_more,
            next_cursor=next_cursor,
        )

    @staticmethod
    def save_message(
        conversation_id: str,
        sender_id: str,
        content: str,
        jwt_token: str,
        client_message_id: str | None = None,
    ) -> MessageResponse:
        """
        Inserts a message into the database.
        RLS enforces that sender_id == auth.uid() and that the user is a member of the conversation.
        """
        client = get_user_supabase_client(jwt_token)
        payload = {
            "conversation_id": conversation_id,
            "sender_id": sender_id,
            "content": content,
        }
        res = client.table("messages").insert(payload).execute()
        if not res.data:
            raise ValueError("Failed to persist message")

        msg = res.data[0]
        return MessageResponse(
            id=msg["id"],
            conversation_id=msg["conversation_id"],
            sender_id=msg["sender_id"],
            content=msg["content"],
            created_at=msg["created_at"],
            client_message_id=client_message_id,
        )


chat_service = ChatService()
