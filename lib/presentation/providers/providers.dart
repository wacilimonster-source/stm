import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/storage/local_storage.dart';
import '../../core/api/client.dart';
import '../../core/theme/app_theme.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class ConnectionState {
  final ConnectionStatus status;
  final String? errorMessage;
  final SillyTavernClient? client;

  ConnectionState({
    this.status = ConnectionStatus.disconnected,
    this.errorMessage,
    this.client,
  });

  ConnectionState copyWith({
    ConnectionStatus? status,
    String? errorMessage,
    SillyTavernClient? client,
  }) {
    return ConnectionState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      client: client ?? this.client,
    );
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final localStorageProvider = Provider<LocalStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalStorage(prefs);
});

final connectionProvider =
    StateNotifierProvider<ConnectionNotifier, ConnectionState>((ref) {
  return ConnectionNotifier(ref.watch(localStorageProvider));
});

class ConnectionNotifier extends StateNotifier<ConnectionState> {
  final LocalStorage _storage;

  ConnectionNotifier(this._storage) : super(ConnectionState()) {
    _init();
  }

  Future<void> _init() async {
    final savedUrl = _storage.serverUrl;
    if (savedUrl != null && savedUrl.isNotEmpty) {
      await connect(savedUrl);
    }
  }

  Future<void> connect(String url) async {
    state = state.copyWith(status: ConnectionStatus.connecting);

    try {
      var normalized = url.trim();
      if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
        normalized = 'http://$normalized';
      }
      final client = SillyTavernClient(baseUrl: normalized);
      final isConnected = await client.checkConnection();

      if (isConnected) {
        await client.login();
        await _storage.setServerUrl(normalized);
        state = ConnectionState(
          status: ConnectionStatus.connected,
          client: client,
        );
      } else {
        state = ConnectionState(
          status: ConnectionStatus.error,
          errorMessage: '无法连接到服务器',
        );
      }
    } catch (e) {
      state = ConnectionState(
        status: ConnectionStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> disconnect() async {
    await _storage.clearServerUrl();
    state = ConnectionState(status: ConnectionStatus.disconnected);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) {
  final storage = ref.watch(localStorageProvider);
  return ThemeNotifier(storage);
});

class ThemeNotifier extends StateNotifier<bool> {
  final LocalStorage _storage;

  ThemeNotifier(this._storage) : super(_storage.isDarkMode);

  Future<void> toggle() async {
    state = !state;
    await _storage.setDarkMode(state);
  }
}

final isDarkModeProvider = Provider<bool>((ref) {
  return ref.watch(themeProvider);
});

final themeDataProvider = Provider<ThemeData>((ref) {
  final isDark = ref.watch(isDarkModeProvider);
  return isDark ? AppTheme.darkTheme : AppTheme.lightTheme;
});

class ActiveChat {
  final String avatar;
  final String fileId;
  final String characterName;

  ActiveChat({
    required this.avatar,
    required this.fileId,
    required this.characterName,
  });
}

final activeChatProvider = StateProvider<ActiveChat?>((ref) => null);

final shellTabIndexProvider = StateProvider<int>((ref) => 0);

final selectedWorldInfoProvider = StateProvider<String?>((ref) => null);
