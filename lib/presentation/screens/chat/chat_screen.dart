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
  String? _resolvedFileId;
  bool _resolving = false;
  Map<String, dynamic>? _charData;
  bool _charLoaded = false;

  @override
  void initState() {
    super.initState();
    _resolvedFileId = widget.fileId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initChat();
      _loadServerWorldBinding();
    });
  }

  ChatParams _params() => ChatParams(
        avatarUrl: widget.avatarUrl,
        fileName: _resolvedFileId ?? '',
      );

  Future<Map<String, dynamic>?> _loadCharacterData() async {
    final connection = ref.read(connectionProvider);
    final client = connection.client;
    if (client == null || widget.avatarUrl.isEmpty) return null;
    if (_charLoaded) return _charData;
    try {
      _charData = await client.getCharacter(widget.avatarUrl);
    } catch (_) {
      _charData = {};
    }
    _charLoaded = true;
    return _charData;
  }

  Future<void> _initChat() async {
    final connection = ref.read(connectionProvider);
    final client = connection.client;
    if (client == null || widget.avatarUrl.isEmpty) return;

    if (_resolvedFileId == null || _resolvedFileId!.isEmpty) {
      setState(() => _resolving = true);
      try {
        final chats = await client.getChats(widget.avatarUrl);
        if (chats.isNotEmpty) {
          final latest = chats.first;
          final fileId = latest['file_id'] ?? latest['file_name'];
          if (fileId != null) {
            setState(() {
              _resolvedFileId = fileId.toString().replaceAll('.jsonl', '');
            });
          }
        }
      } catch (_) {}
      if (mounted) setState(() => _resolving = false);
    }

    final charData = await _loadCharacterData();
    final firstMes = charData?['data']?['first_mes'];
    final greeting = firstMes is String && firstMes.isNotEmpty ? firstMes : null;
    if (mounted) {
      ref.read(chatProvider(_params()).notifier).loadHistory(greeting: greeting);
    }
  }

  Future<void> _loadServerWorldBinding() async {
    final charData = await _loadCharacterData();
    if (mounted) {
      final world = charData?['data']?['extensions']?['world'];
      final selections = ref.read(selectedWorldInfosProvider);
      if (world is String &&
          world.isNotEmpty &&
          !selections.containsKey(widget.avatarUrl)) {
        ref.read(selectedWorldInfosProvider.notifier).state = {
          ...selections,
          widget.avatarUrl: [world],
        };
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

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
    final selectedNames =
        ref.watch(selectedWorldInfosProvider)[widget.avatarUrl] ?? const [];

    ref.listen(chatProvider(params), (prev, next) {
      final prevCount = prev?.messages.length ?? 0;
      if (next.messages.length != prevCount) {
        _scrollToBottom();
      }
      if (next.error != null && next.error != prev?.error) {
        _showError(next.error!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.characterName),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: '世界书',
            onPressed: () => _showWorldInfoPicker(context),
          ),
          if (selectedNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  '${selectedNames.length}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _resolving
                ? const Center(child: CircularProgressIndicator())
                : chatState.messages.isEmpty
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('生成失败：$message'),
        backgroundColor: Theme.of(context).colorScheme.error,
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
      builder: (context) => _WorldInfoPicker(avatarUrl: widget.avatarUrl),
    );
  }

  void _sendMessage(WidgetRef ref) {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    ref.read(chatProvider(_params()).notifier).sendMessage(text);
    _scrollToBottom();
  }
}

class _MessageBubble extends StatefulWidget {
  final dynamic message;
  final VoidCallback onLongPress;

  const _MessageBubble({
    required this.message,
    required this.onLongPress,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _thinkingExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = widget.message;
    final isUser = message.isUser;
    final hasThinking = message.thinking != null && message.thinking!.isNotEmpty;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
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
              if (hasThinking) ...[
                InkWell(
                  onTap: () => setState(
                    () => _thinkingExpanded = !_thinkingExpanded,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.psychology_outlined,
                          size: 16,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _thinkingExpanded ? '收起思考' : '思考过程',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          _thinkingExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 16,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_thinkingExpanded) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      message.thinking,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color
                            ?.withOpacity(0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              Text(
                message.content,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : theme.textTheme.bodyLarge?.color,
                ),
              ),
              if (message.sendDate != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.sendDate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: isUser
                        ? Colors.white70
                        : theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}';
  }
}

class _WorldInfoPicker extends ConsumerStatefulWidget {
  final String avatarUrl;

  const _WorldInfoPicker({required this.avatarUrl});

  @override
  ConsumerState<_WorldInfoPicker> createState() => _WorldInfoPickerState();
}

class _WorldInfoPickerState extends ConsumerState<_WorldInfoPicker> {
  List<Map<String, dynamic>>? _worldInfos;
  Set<String> _selected = {};
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _selected = Set.of(
      ref.read(selectedWorldInfosProvider)[widget.avatarUrl] ?? const [],
    );
    _load();
  }

  Future<void> _load() async {
    final connection = ref.read(connectionProvider);
    if (connection.client == null) {
      setState(() => _loadError = '未连接服务器');
      return;
    }
    setState(() => _loadError = null);
    try {
      final list = await connection.client!.getWorldInfoList();
      if (mounted) {
        setState(() => _worldInfos = list);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = '加载失败：$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '选择世界书（可多选）',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Flexible(
            child: _loadError != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () => setState(() {
                            _worldInfos = null;
                            _loadError = null;
                          }),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  )
                : _worldInfos == null
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _worldInfos!.length,
                    itemBuilder: (context, index) {
                      final wi = _worldInfos![index];
                      final name = wi['name'] ?? '';
                      return CheckboxListTile(
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        value: _selected.contains(name),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selected.add(name);
                            } else {
                              _selected.remove(name);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ref.read(selectedWorldInfosProvider.notifier).state = {
                    ...ref.read(selectedWorldInfosProvider),
                    widget.avatarUrl: _selected.toList(),
                  };
                  Navigator.pop(context);
                },
                child: const Text('确定'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}