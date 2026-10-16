import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/auth/auth_service.dart';
import '../../shared/models/conversation.dart';
import '../../shared/widgets/initials_avatar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_view.dart';
import '../chat/chat_screen.dart';
import 'conversation_controller.dart';

class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key});

  @override
  ConsumerState<ConversationListScreen> createState() =>
      _ConversationListScreenState();
}

class _ConversationListScreenState
    extends ConsumerState<ConversationListScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(dt.year, dt.month, dt.day);

    if (msgDate == today) {
      return DateFormat('HH:mm').format(dt);
    } else if (today.difference(msgDate).inDays == 1) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d').format(dt);
    }
  }

  void _showNewChatDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          builder: (sheetCtx, scrollController) {
            return Consumer(
              builder: (context, ref, _) {
                final approvedAsync = ref.watch(approvedUsersProvider);

                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          Text(
                            'Select Member',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: approvedAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, _) => ErrorViewWidget(
                          message: err.toString(),
                          onRetry: () => ref.refresh(approvedUsersProvider),
                        ),
                        data: (users) {
                          if (users.isEmpty) {
                            return const Center(
                              child: Text('No other approved members found.'),
                            );
                          }
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final u = users[index];
                              return ListTile(
                                leading: InitialsAvatar(name: u.displayName),
                                title: Text(u.displayName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: const Text('Approved Member'),
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  try {
                                    final convId = await ref
                                        .read(conversationNotifierProvider
                                            .notifier)
                                        .createConversation(u.id);

                                    if (!context.mounted) return;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatScreen(
                                          conversationId: convId,
                                          recipientName: u.displayName,
                                          recipientId: u.id,
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('Failed to start chat: $e')),
                                    );
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationNotifierProvider);
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search conversations...',
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: (val) {
                  ref
                      .read(conversationNotifierProvider.notifier)
                      .setSearchQuery(val);
                },
              )
            : const Text(
                'Private Chat',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  ref
                      .read(conversationNotifierProvider.notifier)
                      .setSearchQuery('');
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: InitialsAvatar(
              name: user?.displayName ?? 'Me',
              radius: 16,
            ),
            onSelected: (val) {
              if (val == 'logout') {
                ref.read(authNotifierProvider.notifier).signOut();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'Member',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (user?.email != null)
                      Text(
                        user!.email!,
                        style: TextStyle(
                            fontSize: 12, color: theme.colorScheme.outline),
                      ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(conversationNotifierProvider.notifier).loadConversations(),
        child: _buildBody(state, theme),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewChatDialog,
        tooltip: 'New Chat',
        child: const Icon(Icons.chat_bubble_outline),
      ),
    );
  }

  Widget _buildBody(ConversationListState state, ThemeData theme) {
    if (state.isLoading && state.conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.conversations.isEmpty) {
      return ErrorViewWidget(
        message: state.errorMessage!,
        onRetry: () =>
            ref.read(conversationNotifierProvider.notifier).loadConversations(),
      );
    }

    final filtered = state.filteredConversations;

    if (filtered.isEmpty) {
      if (state.searchQuery.isNotEmpty) {
        return const Center(child: Text('No matching conversations found.'));
      }
      return EmptyStateWidget(
        icon: Icons.forum_outlined,
        title: 'No conversations yet',
        message:
            'Tap the button below to start a private chat with an approved member.',
        action: FilledButton.icon(
          onPressed: _showNewChatDialog,
          icon: const Icon(Icons.add),
          label: const Text('Start Conversation'),
        ),
      );
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final conv = filtered[index];
        final formattedTime = _formatTime(conv.lastMessageTime);

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: InitialsAvatar(
            name: conv.otherParticipantName,
            radius: 24,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  conv.otherParticipantName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (formattedTime.isNotEmpty)
                Text(
                  formattedTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              conv.lastMessageContent ?? 'No messages yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.outline,
                fontSize: 14,
              ),
            ),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  conversationId: conv.id,
                  recipientName: conv.otherParticipantName,
                  recipientId: conv.otherParticipantId,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
