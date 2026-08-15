import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../chat/chat_screen.dart';

class RecentChatsTab extends ConsumerWidget {
  const RecentChatsTab({super.key});

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
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: chat.avatar != null
                      ? NetworkImage(chat.avatar!)
                      : null,
                  child: chat.avatar == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(chat.fileId),
                subtitle: Text(
                  chat.previewMessage ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        avatarUrl: chat.avatar ?? '${chat.fileId}.png',
                        fileName: chat.fileName,
                        characterName: chat.fileId,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }
}
