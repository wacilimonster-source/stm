class RecentChat {
  final String fileName;
  final String fileId;
  final String? avatar;
  final String characterName;
  final String? previewMessage;
  final int? messageCount;
  final String? lastMessage;
  final DateTime? lastUpdated;

  RecentChat({
    required this.fileName,
    required this.fileId,
    this.avatar,
    required this.characterName,
    this.previewMessage,
    this.messageCount,
    this.lastMessage,
    this.lastUpdated,
  });

  factory RecentChat.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar'] as String?;
    final fileName = json['file_name'] ?? '';
    final fileId =
        json['file_id'] ?? fileName.toString().replaceAll('.jsonl', '');
    final characterName =
        avatar != null && avatar.isNotEmpty
            ? avatar.replaceAll('.png', '')
            : fileName.toString().replaceAll('.jsonl', '');
    return RecentChat(
      fileName: fileName,
      fileId: fileId,
      avatar: avatar,
      characterName: characterName,
      previewMessage: json['mes'] ?? json['preview_message'],
      messageCount: json['message_count'],
      lastMessage: json['last_mes'],
    );
  }
}