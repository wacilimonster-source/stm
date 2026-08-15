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

final chatHistoryProvider = FutureProvider.family<List<ChatMessage>, ChatParams>(
  (ref, params) async {
    final connection = ref.watch(connectionProvider);
    if (connection.status != ConnectionStatus.connected ||
        connection.client == null) {
      return [];
    }

    final data = await connection.client!.getChatHistory(
      params.avatarUrl,
      params.fileName,
    );
    return data.map((e) => ChatMessage.fromJson(e)).toList();
  },
);

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
    StateNotifierProvider.family<ChatNotifier, ChatState, ChatParams>(
  (ref, params) => ChatNotifier(ref, params),
);

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  final ChatParams _params;

  ChatNotifier(this._ref, this._params) : super(ChatState());

  Future<void> loadHistory() async {
    final connection = _ref.read(connectionProvider);
    if (connection.client == null) return;

    final data = await connection.client!.getChatHistory(
      _params.avatarUrl,
      _params.fileName,
    );
    state = state.copyWith(
      messages: data.map((e) => ChatMessage.fromJson(e)).toList(),
    );
  }

  Future<void> sendMessage(String content) async {
    final connection = _ref.read(connectionProvider);
    if (connection.client == null) return;

    state = state.copyWith(isGenerating: true);

    final userMessage = ChatMessage(
      role: 'user',
      name: 'User',
      isUser: true,
      content: content,
      sendDate: DateTime.now(),
    );

    state = state.copyWith(messages: [...state.messages, userMessage]);

    try {
      final body = {
        'chat_completion_source': 'openai',
        'stream': true,
        'messages': [
          {'role': 'user', 'content': content}
        ],
      };

      final worldInfoNames = _ref
          .read(selectedWorldInfosProvider)[_params.avatarUrl] ?? const [];
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
            (body['messages'] as List).insert(0, {
              'role': 'system',
              'content': '以下是世界设定，请在对话中遵循：\n${parts.join('\n\n')}',
            });
          }
        } catch (_) {}
      }

      String fullResponse = '';
      String? thinking;

      await for (final chunk in connection.client!.sendMessageStream(body)) {
        try {
          final data = json.decode(chunk);
          final delta = data['choices']?[0]?['delta']?['content'];
          if (delta != null && delta is String) {
            fullResponse += delta;
            final lastMessage = ChatMessage(
              role: 'assistant',
              name: 'Assistant',
              isUser: false,
              content: fullResponse,
              sendDate: DateTime.now(),
              thinking: thinking,
            );
            state = state.copyWith(messages: [
              ...state.messages,
              if (state.messages.isEmpty || state.messages.last.isUser) lastMessage
              else state.messages.removeLast(),
              lastMessage,
            ]);
          }
        } catch (_) {}
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isGenerating: false);
    }
  }

  Future<void> regenerate() async {
    if (state.messages.isEmpty) return;

    final lastUserMessage = state.messages.lastWhere(
      (m) => m.isUser,
      orElse: () => state.messages.last,
    );

    state = state.copyWith(
      messages: state.messages
          .where((m) => m != state.messages.last)
          .toList(),
    );
    await sendMessage(lastUserMessage.content);
  }

  void removeMessageAt(int index) {
    if (index < 0 || index >= state.messages.length) return;
    state = state.copyWith(
      messages: [...state.messages]..removeAt(index),
    );
  }
}
