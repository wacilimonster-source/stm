class Character {
  final String name;
  final String description;
  final String avatar;
  final String? personality;
  final String? scenario;
  final String? firstMessage;

  Character({
    required this.name,
    required this.description,
    required this.avatar,
    this.personality,
    this.scenario,
    this.firstMessage,
  });

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      avatar: json['avatar'] ?? '',
      personality: json['personality'],
      scenario: json['scenario'],
      firstMessage: json['first_message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'avatar': avatar,
      'personality': personality,
      'scenario': scenario,
      'first_message': firstMessage,
    };
  }
}
