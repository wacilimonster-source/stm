class WorldInfoEntry {
  final String id;
  final List<String> key;
  final List<String> secondaryKeys;
  final String content;
  final int order;
  final bool enabled;

  WorldInfoEntry({
    required this.id,
    required this.key,
    this.secondaryKeys = const [],
    required this.content,
    this.order = 0,
    this.enabled = true,
  });

  factory WorldInfoEntry.fromJson(String id, Map<String, dynamic> json) {
    return WorldInfoEntry(
      id: id,
      key: (json['key'] as List<dynamic>?)?.cast<String>() ?? [],
      secondaryKeys:
          (json['keysecondary'] as List<dynamic>?)?.cast<String>() ?? [],
      content: json['content'] ?? '',
      order: json['order'] ?? 0,
      enabled: json['disable'] != true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'keysecondary': secondaryKeys,
      'content': content,
      'order': order,
      'disable': !enabled,
      'enabled': enabled,
    };
  }

  WorldInfoEntry copyWith({
    String? id,
    List<String>? key,
    List<String>? secondaryKeys,
    String? content,
    int? order,
    bool? enabled,
  }) {
    return WorldInfoEntry(
      id: id ?? this.id,
      key: key ?? this.key,
      secondaryKeys: secondaryKeys ?? this.secondaryKeys,
      content: content ?? this.content,
      order: order ?? this.order,
      enabled: enabled ?? this.enabled,
    );
  }
}

class WorldInfo {
  final String name;
  final Map<String, WorldInfoEntry> entries;

  WorldInfo({
    required this.name,
    required this.entries,
  });

  factory WorldInfo.fromJson(String name, Map<String, dynamic> json) {
    final entriesMap = <String, WorldInfoEntry>{};
    final entries = json['entries'] as Map<String, dynamic>? ?? {};
    entries.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        entriesMap[key] = WorldInfoEntry.fromJson(key, value);
      }
    });
    return WorldInfo(
      name: json['name'] ?? name,
      entries: entriesMap,
    );
  }

  Map<String, dynamic> toJson() {
    final entriesMap = <String, dynamic>{};
    entries.forEach((key, value) {
      entriesMap[key] = value.toJson();
    });
    return {
      'name': name,
      'entries': entriesMap,
    };
  }
}
