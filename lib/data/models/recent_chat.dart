class RecentChat {
  final String fileName;
  final String fileId;
  final String? avatar;
  final String? previewMessage;
  final int? messageCount;
  final String? lastMessage;
  final DateTime? lastUpdated;

  RecentChat({
    required this.fileName,
    required this.fileId,
    this.avatar,
    this.previewMessage,
    this.messageCount,
    this.lastMessage,
    this.lastUpdated,
  });

  factory RecentChat.fromJson(Map<String, dynamic> json) {
    return RecentChat(
      fileName: json['file_name'] ?? '',
      fileId: json['file_id'] ?? json['file_name']?.replaceAll('.jsonl', '') ?? '',
      avatar: json['avatar'],
      previewMessage: json['preview_message'] ?? json['last_mes'],
      messageCount: json['message_count'],
      lastMessage: json['last_mes'],
    );
  }
}
