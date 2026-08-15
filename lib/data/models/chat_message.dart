class ChatMessage {
  final String role;
  final String name;
  final bool isUser;
  final String content;
  final DateTime? sendDate;
  final String? thinking;

  ChatMessage({
    required this.role,
    required this.name,
    required this.isUser,
    required this.content,
    this.sendDate,
    this.thinking,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] ?? (json['is_user'] == true ? 'user' : 'assistant'),
      name: json['name'] ?? '',
      isUser: json['is_user'] ?? false,
      content: json['mes'] ?? json['content'] ?? '',
      sendDate: json['send_date'] != null
          ? DateTime.tryParse(json['send_date'])
          : null,
      thinking: json['thinking'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'name': name,
      'is_user': isUser,
      'mes': content,
      'send_date': sendDate?.toIso8601String(),
      'thinking': thinking,
    };
  }
}
