import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/network/api_client.dart';
import '../../core/config/env.dart';
import '../../shared/models/conversation.dart';
import '../../shared/models/user_profile.dart';

class ConversationListState {
  final List<Conversation> conversations;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;

  const ConversationListState({
    this.conversations = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
  });

  List<Conversation> get filteredConversations {
    if (searchQuery.trim().isEmpty) return conversations;
    final q = searchQuery.toLowerCase();
    return conversations
        .where((c) =>
            c.otherParticipantName.toLowerCase().contains(q) ||
            (c.lastMessageContent?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  ConversationListState copyWith({
    List<Conversation>? conversations,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
  }) {
    return ConversationListState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final conversationNotifierProvider =
    StateNotifierProvider<ConversationNotifier, ConversationListState>((ref) {
  final authNotifier = ref.watch(authNotifierProvider.notifier);
  return ConversationNotifier(authNotifier);
});

class ConversationNotifier extends StateNotifier<ConversationListState> {
  final AuthNotifier _authNotifier;

  ConversationNotifier(this._authNotifier)
      : super(const ConversationListState()) {
    loadConversations();
  }

  ApiClient _getApiClient() {
    return ApiClient(
      baseUrl: Env.apiBaseUrl,
      getToken: () => _authNotifier.getCurrentToken(),
    );
  }

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final client = _getApiClient();
      final data = await client.get('/conversations');
      if (data is List) {
        final list = data.map((json) => Conversation.fromJson(json)).toList();
        state = state.copyWith(conversations: list, isLoading: false);
      } else {
        state = state.copyWith(conversations: [], isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<String> createConversation(String targetUserId) async {
    final client = _getApiClient();
    final res = await client.post('/conversations', body: {
      'target_user_id': targetUserId,
    });
    final convId = res['conversation_id'] as String;
    await loadConversations();
    return convId;
  }
}

final approvedUsersProvider = FutureProvider<List<UserProfile>>((ref) async {
  final authNotifier = ref.watch(authNotifierProvider.notifier);
  final client = ApiClient(
    baseUrl: Env.apiBaseUrl,
    getToken: () => authNotifier.getCurrentToken(),
  );
  final data = await client.get('/users');
  if (data is List) {
    return data.map((j) => UserProfile.fromJson(j)).toList();
  }
  return [];
});
