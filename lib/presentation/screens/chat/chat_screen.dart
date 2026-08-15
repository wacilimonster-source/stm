import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String avatarUrl;
  final String fileId;
  final String characterName;

  const ChatScreen({
    super.key,
    required this.avatarUrl,
    required this.fileId,
    required this.characterName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider(_params()).notifier).loadHistory();
    });
  }

  ChatParams _params() => ChatParams(
        avatarUrl: widget.avatarUrl,
        fileName: widget.fileId,
      );

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final params = _params();
    final chatState = ref.watch(chatProvider(params));
    final worldInfoName = ref.watch(selectedWorldInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.characterName),
        actions: [
          if (worldInfoName != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Chip(
                  avatar: const Icon(Icons.book, size: 16),
                  label: Text(
                    worldInfoName,
                    style: theme.textTheme.bodySmall,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 56,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '开始对话吧',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chatState.messages[index];
                      return _MessageBubble(
                        message: msg,
                        onLongPress: () {
                          _showMessageMenu(context, ref, params, index, msg);
                        },
                      );
                    },
                  ),
          ),
          if (chatState.isGenerating)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text('正在生成...', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu_book_outlined),
                    tooltip: '切换世界书',
                    onPressed: () => _showWorldInfoPicker(context),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        hintText: '输入消息...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(ref),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: '重新生成',
                    onPressed: chatState.isGenerating
                        ? null
                        : () => ref
                            .read(chatProvider(params).notifier)
                            .regenerate(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: chatState.isGenerating
                        ? null
                        : () => _sendMessage(ref),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageMenu(
    BuildContext context,
    WidgetRef ref,
    ChatParams params,
    int index,
    dynamic msg,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制内容'),
              onTap: () async {
                Navigator.pop(context);
                await _copyToClipboard(msg.content);
              },
            ),
            if (index > 0)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('删除此消息'),
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(chatProvider(params).notifier)
                      .removeMessageAt(index);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制')),
      );
    }
  }

  void _showWorldInfoPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const _WorldInfoPicker(),
    );
  }

  void _sendMessage(WidgetRef ref) {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    ref.read(chatProvider(_params()).notifier).sendMessage(text);
  }
}

class _MessageBubble extends StatelessWidget {
  final dynamic message;
  final VoidCallback onLongPress;

  const _MessageBubble({
    required this.message,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isUser
                ? theme.colorScheme.primary
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.content,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : theme.textTheme.bodyLarge?.color,
                ),
              ),
              if (message.thinking != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '💭 ${message.thinking}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WorldInfoPicker extends ConsumerStatefulWidget {
  const _WorldInfoPicker();

  @override
  ConsumerState<_WorldInfoPicker> createState() => _WorldInfoPickerState();
}

class _WorldInfoPickerState extends ConsumerState<_WorldInfoPicker> {
  List<Map<String, dynamic>>? _worldInfos;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final connection = ref.read(connectionProvider);
    if (connection.client == null) return;
    final list = await connection.client!.getWorldInfoList();
    if (mounted) {
      setState(() => _worldInfos = list);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(selectedWorldInfoProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '切换世界书',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('不使用世界书'),
            trailing: current == null ? const Icon(Icons.check) : null,
            onTap: () {
              ref.read(selectedWorldInfoProvider.notifier).state = null;
              Navigator.pop(context);
            },
          ),
          if (_worldInfos == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _worldInfos!.length,
                itemBuilder: (context, index) {
                  final wi = _worldInfos![index];
                  final name = wi['name'] ?? '';
                  return ListTile(
                    leading: const Icon(Icons.book_outlined),
                    title: Text(name),
                    trailing:
                        current == name ? const Icon(Icons.check) : null,
                    onTap: () {
                      ref.read(selectedWorldInfoProvider.notifier).state = name;
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}