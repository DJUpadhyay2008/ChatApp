import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/network/api_client.dart';
import '../../core/network/ws_client.dart';
import '../../core/config/env.dart';
import '../../shared/models/message.dart';

class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? nextCursor;
  final String? errorMessage;
  final WsStatus wsStatus;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.nextCursor,
    this.errorMessage,
    this.wsStatus = WsStatus.disconnected,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? nextCursor,
    String? errorMessage,
    WsStatus? wsStatus,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      errorMessage: errorMessage,
      wsStatus: wsStatus ?? this.wsStatus,
    );
  }
}

final chatNotifierProvider = StateNotifierProvider.family
    .autoDispose<ChatNotifier, ChatState, String>((ref, conversationId) {
  final authNotifier = ref.watch(authNotifierProvider.notifier);
  final currentUserId = ref.watch(authNotifierProvider).user?.id ?? '';
  return ChatNotifier(conversationId, currentUserId, authNotifier);
});

class ChatNotifier extends StateNotifier<ChatState> {
  final String conversationId;
  final String currentUserId;
  final AuthNotifier _authNotifier;
  WsClient? _wsClient;

  ChatNotifier(this.conversationId, this.currentUserId, this._authNotifier)
      : super(const ChatState()) {
    init();
  }

  ApiClient _getApiClient() {
    return ApiClient(
      baseUrl: Env.apiBaseUrl,
      getToken: () => _authNotifier.getCurrentToken(),
    );
  }

  void init() {
    loadInitialMessages();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    _wsClient = WsClient(
      getToken: () => _authNotifier.getCurrentToken(),
      onMessageReceived: (message) {
        if (message.conversationId == conversationId) {
          handleIncomingMessage(message);
        }
      },
      onStatusChanged: (status) {
        if (mounted) {
          state = state.copyWith(wsStatus: status);
        }
      },
    );
    _wsClient?.connect();
  }

  Future<void> loadInitialMessages() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final client = _getApiClient();
      final data =
          await client.get('/conversations/$conversationId/messages?limit=30');

      final rawList = data['messages'] as List? ?? [];
      final msgs = rawList.map((j) => Message.fromJson(j)).toList();
      final hasMore = data['has_more'] as bool? ?? false;
      final nextCursor = data['next_cursor'] as String?;

      state = state.copyWith(
        messages: msgs,
        hasMore: hasMore,
        nextCursor: nextCursor,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> loadOlderMessages() async {
    if (state.isLoadingMore || !state.hasMore || state.nextCursor == null)
      return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final client = _getApiClient();
      final cursorParam = Uri.encodeComponent(state.nextCursor!);
      final data = await client.get(
        '/conversations/$conversationId/messages?limit=30&cursor=$cursorParam',
      );

      final rawList = data['messages'] as List? ?? [];
      final olderMsgs = rawList.map((j) => Message.fromJson(j)).toList();
      final hasMore = data['has_more'] as bool? ?? false;
      final nextCursor = data['next_cursor'] as String?;

      state = state.copyWith(
        messages: [...state.messages, ...olderMsgs],
        hasMore: hasMore,
        nextCursor: nextCursor,
        isLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final clientMsgId =
        '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(99999)}';

    // Optimistic local message insertion
    final optimisticMessage = Message(
      id: clientMsgId,
      conversationId: conversationId,
      senderId: currentUserId,
      content: trimmed,
      createdAt: DateTime.now(),
      clientMessageId: clientMsgId,
      isSending: true,
    );

    state = state.copyWith(messages: [optimisticMessage, ...state.messages]);

    try {
      final client = _getApiClient();
      final data = await client.post(
        '/conversations/$conversationId/messages',
        body: {
          'content': trimmed,
          'client_message_id': clientMsgId,
        },
      );

      final serverMessage = Message.fromJson(data);

      // Replace optimistic message with confirmed server message
      final updated = state.messages.map((m) {
        if (m.clientMessageId == clientMsgId) {
          return serverMessage;
        }
        return m;
      }).toList();

      state = state.copyWith(messages: updated);
    } catch (e) {
      // Rollback or mark failed
      final reverted = state.messages
          .where((m) => m.clientMessageId != clientMsgId)
          .toList();
      state = state.copyWith(
          messages: reverted, errorMessage: 'Failed to send: $e');
    }
  }

  void handleIncomingMessage(Message message) {
    // Check if message already exists (e.g. sent by me and confirmed, or already delivered)
    final exists = state.messages.any(
      (m) =>
          m.id == message.id ||
          (message.clientMessageId != null &&
              m.clientMessageId == message.clientMessageId),
    );

    if (!exists) {
      state = state.copyWith(messages: [message, ...state.messages]);
    }
  }

  @override
  void dispose() {
    _wsClient?.dispose();
    super.dispose();
  }
}
