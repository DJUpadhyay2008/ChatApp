import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/network/ws_client.dart';
import '../../shared/widgets/initials_avatar.dart';
import '../../shared/widgets/error_view.dart';
import 'chat_controller.dart';
import 'message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String recipientName;
  final String recipientId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.recipientName,
    required this.recipientId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    // When reversed, maxScrollExtent corresponds to the top of the chat (oldest messages)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref
          .read(chatNotifierProvider(widget.conversationId).notifier)
          .loadOlderMessages();
    }
  }

  void _sendMessage() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;

    ref
        .read(chatNotifierProvider(widget.conversationId).notifier)
        .sendMessage(text);
    _textController.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(chatNotifierProvider(widget.conversationId));
    final currentUserId = ref.watch(authNotifierProvider).user?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            InitialsAvatar(name: widget.recipientName, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipientName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    state.wsStatus == WsStatus.connected
                        ? 'Online'
                        : state.wsStatus == WsStatus.connecting
                            ? 'Connecting...'
                            : 'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      color: state.wsStatus == WsStatus.connected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Reconnection Banner
            if (state.wsStatus != WsStatus.connected)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                color: Colors.amber.withOpacity(0.2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.amber),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      state.wsStatus == WsStatus.connecting
                          ? 'Reconnecting to chat server...'
                          : 'Disconnected from live updates. Retrying...',
                      style: const TextStyle(fontSize: 12, color: Colors.amber),
                    ),
                  ],
                ),
              ),

            // Message List
            Expanded(
              child: _buildMessagesList(state, currentUserId),
            ),

            // Bottom Input Bar
            _buildInputBar(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(ChatState state, String currentUserId) {
    if (state.isLoading && state.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.messages.isEmpty) {
      return ErrorViewWidget(
        message: state.errorMessage!,
        onRetry: () => ref
            .read(chatNotifierProvider(widget.conversationId).notifier)
            .loadInitialMessages(),
      );
    }

    if (state.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline,
                  size: 36, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              Text(
                'This is the start of your private conversation with ${widget.recipientName}.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.outline, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Newest messages at bottom
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: state.messages.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (state.isLoadingMore && index == state.messages.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final msg = state.messages[index];
        final isMe = msg.senderId == currentUserId;

        return MessageBubble(
          key: ValueKey(msg.id),
          message: msg,
          isMe: isMe,
        );
      },
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.dividerTheme.color ?? Colors.transparent,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): _sendMessage,
              },
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) {
                  _sendMessage();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              tooltip: 'Send Message',
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
