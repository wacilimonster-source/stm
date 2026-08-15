import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/character.dart';
import 'providers.dart';

final charactersProvider = FutureProvider<List<Character>>((ref) async {
  final connection = ref.watch(connectionProvider);
  if (connection.status != ConnectionStatus.connected || connection.client == null) {
    return [];
  }

  final data = await connection.client!.getCharacters();
  return data.map((e) => Character.fromJson(e)).toList();
});

final selectedCharacterProvider = StateProvider<Character?>((ref) => null);
