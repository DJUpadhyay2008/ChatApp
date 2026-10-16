class Conversation {
  final String id;
  final String otherParticipantId;
  final String otherParticipantName;
  final String? lastMessageContent;
  final DateTime? lastMessageTime;
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.otherParticipantId,
    required this.otherParticipantName,
    this.lastMessageContent,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final other = json['other_participant'] as Map<String, dynamic>? ?? {};
    final lastMsg = json['last_message'] as Map<String, dynamic>?;

    return Conversation(
      id: json['id'] ?? '',
      otherParticipantId: other['id'] ?? '',
      otherParticipantName: other['display_name'] ?? 'Member',
      lastMessageContent: lastMsg?['content'],
      lastMessageTime: lastMsg != null && lastMsg['created_at'] != null
          ? DateTime.tryParse(lastMsg['created_at'])?.toLocal()
          : null,
      unreadCount: json['unread_count'] ?? 0,
    );
  }
}
