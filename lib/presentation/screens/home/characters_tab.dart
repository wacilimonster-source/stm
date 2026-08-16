import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../providers/characters_provider.dart';
import '../chat/chat_screen.dart';

class CharactersTab extends ConsumerWidget {
  final String avatarBaseUrl;

  const CharactersTab({super.key, required this.avatarBaseUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charactersAsync = ref.watch(charactersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('角色'),
      ),
      body: charactersAsync.when(
      data: (characters) {
        if (characters.isEmpty) {
          return const Center(
            child: Text('暂无角色'),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(charactersProvider);
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemCount: characters.length,
            itemBuilder: (context, index) {
              final char = characters[index];
              final avatarUrl = char.avatar.isNotEmpty
                  ? '$avatarBaseUrl/characters/${char.avatar}'
                  : null;

              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          avatarUrl: char.avatar,
                          fileId: '',
                          characterName: char.name,
                        ),
                      ),
                    );
                  },
                  onLongPress: () {
                    _showCharacterMenu(context, ref, char, avatarBaseUrl);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SizedBox(
                          width: double.infinity,
                          child: avatarUrl != null
                              ? Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.person, size: 48),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.person, size: 48),
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          char.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  void _showCharacterMenu(
    BuildContext context,
    WidgetRef ref,
    dynamic char,
    String avatarBaseUrl,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('开始对话'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      avatarUrl: char.avatar,
                      fileId: '',
                      characterName: char.name,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除角色'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteCharacter(context, ref, char);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCharacter(
    BuildContext context,
    WidgetRef ref,
    dynamic char,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除角色'),
        content: Text('确定删除角色「${char.name}」吗？\n将同时删除该角色的所有对话。'),
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

    if (confirmed != true) return;

    final connection = ref.read(connectionProvider);
    if (connection.client == null) return;

    try {
      await connection.client!.deleteCharacter(char.avatar);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('角色已删除')),
        );
      }
      ref.invalidate(charactersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }
}
