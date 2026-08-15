import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../chat/chat_screen.dart';

class CharactersTab extends ConsumerWidget {
  const CharactersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charactersAsync = ref.watch(charactersProvider);

    return charactersAsync.when(
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
          child: ListView.builder(
            itemCount: characters.length,
            itemBuilder: (context, index) {
              final char = characters[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: char.avatar.isNotEmpty
                      ? NetworkImage(char.avatar)
                      : null,
                  child: char.avatar.isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(char.name),
                subtitle: Text(
                  char.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        avatarUrl: '${char.name}.png',
                        fileName: 'default',
                        characterName: char.name,
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
