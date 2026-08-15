import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../providers/chat_provider.dart';
import '../chat/chat_screen.dart';

class RecentChatsTab extends ConsumerWidget {
  final String avatarBaseUrl;

  const RecentChatsTab({super.key, required this.avatarBaseUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentChatsAsync = ref.watch(recentChatsProvider);

    return recentChatsAsync.when(
      data: (chats) {
        if (chats.isEmpty) {
          return const Center(
            child: Text('暂无最近对话'),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(recentChatsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final avatarUrl = chat.avatar != null && chat.avatar!.isNotEmpty
                  ? '$avatarBaseUrl/characters/${chat.avatar}'
                  : null;
              final characterName = chat.fileId.replaceAll('.jsonl', '');

              return Dismissible(
                key: ValueKey('chat_${chat.avatar}_${chat.fileId}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.error,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) => _confirmDeleteChat(context, ref, chat),
                onDismissed: (_) {
                  ref.invalidate(recentChatsProvider);
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(
                      characterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (chat.previewMessage != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            chat.previewMessage!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (chat.messageCount != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${chat.messageCount} 条消息',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                    isThreeLine: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            avatarUrl: chat.avatar ?? '${chat.fileId}.png',
                            fileId: chat.fileId,
                            characterName: characterName,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Future<bool> _confirmDeleteChat(
    BuildContext context,
    WidgetRef ref,
    dynamic chat,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定删除「${chat.fileId.replaceAll('.jsonl', '')}」的这段对话吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    final connection = ref.read(connectionProvider);
    if (connection.client == null) return false;

    try {
      await connection.client!.deleteChat(
        chat.avatar ?? '${chat.fileId}.png',
        chat.fileId,
      );
      ref.invalidate(recentChatsProvider);
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
      return false;
    }
  }
}