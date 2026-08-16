import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/recent_chat.dart';
import 'providers.dart';

final recentChatsProvider = FutureProvider<List<RecentChat>>((ref) async {
  final connection = ref.watch(connectionProvider);
  if (connection.status != ConnectionStatus.connected || connection.client == null) {
    return [];
  }

  final data = await connection.client!.getRecentChats();
  return data.map((e) => RecentChat.fromJson(e)).toList();
});

class ChatParams {
  final String avatarUrl;
  final String fileName;

  ChatParams({required this.avatarUrl, required this.fileName});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatParams &&
          avatarUrl == other.avatarUrl &&
          fileName == other.fileName;

  @override
  int get hashCode => avatarUrl.hashCode ^ fileName.hashCode;
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isGenerating;
  final String? error;

  ChatState({
    this.messages = const [],
    this.isGenerating = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isGenerating,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      error: error,
    );
  }
}

final chatProvider =
    StateNotifierProvider.autoDispose.family<ChatNotifier, ChatState, ChatParams>(
  (ref, params) => ChatNotifier(ref, params),
);

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  final ChatParams _params;
  Map<String, dynamic>? _charCard;
  String _currentFileName = '';
  dynamic _client; // 缓存连接，避免 provider 被 dispose 后保存失败

  ChatNotifier(this._ref, this._params) : super(ChatState()) {
    _currentFileName = _params.fileName;
  }

  Future<void> loadHistory({String? greeting}) async {
    final connection = _ref.read(connectionProvider);
    if (connection.client == null) return;

    var messages = <ChatMessage>[];
    if (_params.fileName.isNotEmpty) {
      final data = await connection.client!.getChatHistory(
        _params.avatarUrl,
        _params.fileName,
      );
      messages = data.map((e) => ChatMessage.fromJson(e)).toList();
    }

    if (messages.isEmpty && greeting != null && greeting.isNotEmpty) {
      messages = [
        ChatMessage(
          role: 'assistant',
          name: '',
          isUser: false,
          content: greeting,
          sendDate: DateTime.now(),
        ),
      ];
    }

    state = state.copyWith(messages: messages);
  }

  Future<Map<String, dynamic>?> _getCharacterCard() async {
    final connection = _ref.read(connectionProvider);
    if (connection.client == null || _params.avatarUrl.isEmpty) return null;
    if (_charCard != null) return _charCard;
    try {
      _charCard = await connection.client!.getCharacter(_params.avatarUrl);
    } catch (_) {
      _charCard = {};
    }
    return _charCard;
  }

  Future<List<Map<String, dynamic>>> _buildRequestMessages() async {
    final connection = _ref.read(connectionProvider);
    final messages = <Map<String, dynamic>>[];

    final worldInfoNames =
        _ref.read(selectedWorldInfosProvider)[_params.avatarUrl] ?? const [];
    if (worldInfoNames.isNotEmpty) {
      try {
        final parts = <String>[];
        for (final name in worldInfoNames) {
          final wiData = await connection.client!.getWorldInfo(name);
          final entries = wiData['entries'] as Map<String, dynamic>? ?? {};
          final content = entries.values
              .whereType<Map<String, dynamic>>()
              .where((e) => e['disable'] != true)
              .map((e) => e['content']?.toString() ?? '')
              .where((c) => c.isNotEmpty)
              .join('\n\n');
          if (content.isNotEmpty) {
            parts.add('【$name】\n$content');
          }
        }
        if (parts.isNotEmpty) {
          messages.add({
            'role': 'system',
            'content': '以下是世界设定，请在对话中遵循：\n${parts.join('\n\n')}',
          });
        }
      } catch (_) {}
    }

    final char = await _getCharacterCard();
    final data = char?['data'];
    if (data is Map) {
      final parts = <String>[];
      final name = data['name']?.toString() ?? '';
      if (name.isNotEmpty) parts.add('角色名称：$name');
      for (final field in ['description', 'personality', 'scenario']) {
        final value = data[field]?.toString() ?? '';
        if (value.isNotEmpty) parts.add(value);
      }
      if (parts.isNotEmpty) {
        messages.add({
          'role': 'system',
          'content': '以下是角色设定，请在对话中扮演好这个角色：\n${parts.join('\n\n')}',
        });
      }
    }

    for (final m in state.messages) {
      messages.add({
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.content,
      });
    }
    return messages;
  }

  String _newChatFileName(String characterName) {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    return '$characterName - ${n.year}-${two(n.month)}-${two(n.day)}'
        '@${two(n.hour)}h${two(n.minute)}m${two(n.second)}s'
        '${three(n.millisecond)}ms';
  }

  Future<void> _saveChat() async {
    final client = _client ?? _ref.read(connectionProvider).client;
    if (client == null || _params.avatarUrl.isEmpty) return;

    var fileName = _currentFileName;
    if (fileName.isEmpty) {
      final charName =
          _charCard?['data']?['name']?.toString() ??
          (_params.avatarUrl.isEmpty
              ? '角色'
              : _params.avatarUrl.replaceAll('.png', ''));
      fileName = _newChatFileName(charName);
      _currentFileName = fileName;
    }

    try {
      await client.saveChat(
        _params.avatarUrl,
        fileName,
        state.messages.map((m) => m.toJson()).toList(),
      );
    } catch (_) {}
  }

  Future<void> sendMessage(String content, {bool appendUserMessage = true}) async {
    final connection = _ref.read(connectionProvider);
    if (connection.client == null) return;
    _client = connection.client;

    state = state.copyWith(isGenerating: true);

    if (appendUserMessage) {
      final userMessage = ChatMessage(
        role: 'user',
        name: 'User',
        isUser: true,
        content: content,
        sendDate: DateTime.now(),
      );
      state = state.copyWith(messages: [...state.messages, userMessage]);
    } else {
      final updated = [...state.messages];
      if (updated.isNotEmpty && !updated.last.isUser) {
        updated.removeLast();
      }
      state = state.copyWith(messages: updated);
    }

    try {
      final apiKey = _ref.read(apiKeyProvider);
      final apiModel = _ref.read(apiModelProvider);
      final apiProxy = _ref.read(apiProxyProvider);
      final apiSource = _ref.read(apiSourceProvider);
      final apiCustomUrl = _ref.read(apiCustomUrlProvider);

      final messages = await _buildRequestMessages();

      final body = {
        'chat_completion_source': apiSource,
        'stream': true,
        'messages': messages,
        'include_reasoning': true,
        'temperature': 1.0,
        'top_p': 0.98,
      };

      if (apiSource == 'custom') {
        body['custom_url'] = apiCustomUrl;
      } else if (apiKey != null && apiKey.isNotEmpty) {
        body['reverse_proxy'] =
            (apiProxy != null && apiProxy.isNotEmpty)
                ? apiProxy
                : 'https://api.openai.com/v1';
        body['proxy_password'] = apiKey;
      }

      body['model'] =
          (apiModel != null && apiModel.isNotEmpty)
          ? apiModel
          : 'deepseek-v4-flash';

      String fullResponse = '';
      String thinking = '';
      String? streamError;

      await for (final chunk in connection.client!.sendMessageStream(body)) {
        try {
          final data = json.decode(chunk);
          if (data['error'] != null) {
            streamError = data['error'].toString();
            break;
          }
          final delta = data['choices']?[0]?['delta'];
          final contentDelta = delta?['content'];
          final reasoningDelta =
              delta?['reasoning_content'] ?? delta?['reasoning'];
          if (reasoningDelta is String) {
            thinking += reasoningDelta;
          }
          if (contentDelta is String) {
            fullResponse += contentDelta;
            final lastMessage = ChatMessage(
              role: 'assistant',
              name: 'Assistant',
              isUser: false,
              content: fullResponse,
              sendDate: DateTime.now(),
              thinking: thinking.isEmpty ? null : thinking,
            );
            final updated = [...state.messages];
            if (updated.isNotEmpty && !updated.last.isUser) {
              updated.removeLast();
            }
            state = state.copyWith(messages: [...updated, lastMessage]);
          }
        } catch (_) {}
      }

      if (streamError != null) {
        throw Exception(streamError);
      }

      await _saveChat();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isGenerating: false);
    }
  }

  Future<void> regenerate() async {
    if (state.messages.isEmpty) return;
    if (state.isGenerating) return;

    final last = state.messages.last;
    if (last.isUser) {
      await sendMessage(last.content, appendUserMessage: false);
      return;
    }

    final lastUserMessage = state.messages.lastWhere(
      (m) => m.isUser,
      orElse: () => state.messages.last,
    );

    state = state.copyWith(
      messages: state.messages.take(state.messages.length - 1).toList(),
    );
    await sendMessage(lastUserMessage.content, appendUserMessage: false);
  }

  /// 重新开始对话。deleteCurrent 为 true 时删除服务端当前对话文件；
  /// 删除失败时抛出异常（不清理本地消息）。
  Future<void> startNewChat({required bool deleteCurrent}) async {
    if (deleteCurrent && _currentFileName.isNotEmpty) {
      final client = _client ?? _ref.read(connectionProvider).client;
      if (client == null) return;
      await client.deleteChat(_params.avatarUrl, _currentFileName);
    }
    _currentFileName = '';
    _charCard = null;
    state = ChatState();
  }

  Future<void> removeMessageAt(int index) async {
    if (index < 0 || index >= state.messages.length) return;
    state = state.copyWith(
      messages: [...state.messages]..removeAt(index),
    );
    await _saveChat();
  }
}