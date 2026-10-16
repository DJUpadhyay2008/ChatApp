import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/shared/models/user_profile.dart';
import 'package:chat_app/shared/models/conversation.dart';
import 'package:chat_app/shared/models/message.dart';

void main() {
  group('Model Serialization Tests', () {
    test('UserProfile deserialization', () {
      final json = {
        'id': 'user-1',
        'display_name': 'Alice Smith',
        'is_approved': true,
        'is_admin': false,
        'email': 'alice@example.com',
      };
      final profile = UserProfile.fromJson(json);
      expect(profile.id, 'user-1');
      expect(profile.displayName, 'Alice Smith');
      expect(profile.isApproved, true);
      expect(profile.isAdmin, false);
      expect(profile.email, 'alice@example.com');
    });

    test('Conversation deserialization', () {
      final json = {
        'id': 'conv-101',
        'other_participant': {
          'id': 'user-2',
          'display_name': 'Bob Jones',
        },
        'last_message': {
          'id': 'msg-1',
          'content': 'Hey there!',
          'created_at': '2026-10-16T12:00:00Z',
        },
        'unread_count': 2,
      };
      final conv = Conversation.fromJson(json);
      expect(conv.id, 'conv-101');
      expect(conv.otherParticipantId, 'user-2');
      expect(conv.otherParticipantName, 'Bob Jones');
      expect(conv.lastMessageContent, 'Hey there!');
      expect(conv.unreadCount, 2);
    });

    test('Message deserialization and copyWith', () {
      final json = {
        'id': 'msg-99',
        'conversation_id': 'conv-101',
        'sender_id': 'user-1',
        'content': 'Testing message',
        'created_at': '2026-10-16T12:30:00Z',
        'client_message_id': 'client-uuid-1',
      };
      final msg = Message.fromJson(json);
      expect(msg.id, 'msg-99');
      expect(msg.content, 'Testing message');
      expect(msg.isSending, false);

      final updated = msg.copyWith(content: 'Edited message', isSending: true);
      expect(updated.content, 'Edited message');
      expect(updated.isSending, true);
    });
  });
}
