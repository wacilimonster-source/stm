import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

class SillyTavernClient {
  late final Dio _dio;
  final CookieJar _cookieJar = CookieJar();
  final String baseUrl;
  String? _csrfToken;

  String avatarUrl(String avatarFileName) {
    return '$baseUrl/characters/$avatarFileName';
  }

  SillyTavernClient({required this.baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 5),
      headers: {
        'Content-Type': 'application/json',
      },
    ));
    _dio.interceptors.add(CookieManager(_cookieJar));
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_csrfToken != null) {
            options.headers['X-CSRF-Token'] = _csrfToken;
          }
          handler.next(options);
        },
      ),
    );
  }

  Future<bool> checkConnection() async {
    try {
      final response = await _dio.get('/');
      if (response.statusCode != 200) {
        return false;
      }
      await _fetchCsrfToken();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _fetchCsrfToken() async {
    try {
      final response = await _dio.get('/csrf-token');
      final data = response.data;
      if (data is Map && data['token'] != null) {
        final token = data['token'].toString();
        _csrfToken = token == 'disabled' ? null : token;
      }
    } catch (e) {
      _csrfToken = null;
    }
  }

  Future<void> login({String handle = 'default', String password = ''}) async {
    try {
      await _dio.post('/api/users/public/login', data: {
        'handle': handle,
        'password': password,
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return;
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCharacters() async {
    final response = await _dio.post('/api/characters/all');
    if (response.data is List) {
      return (response.data as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> getCharacter(String avatarUrl) async {
    final response = await _dio.post('/api/characters/get', data: {
      'avatar_url': avatarUrl,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getRecentChats({int max = 20}) async {
    final response = await _dio.post('/api/chats/recent', data: {
      'max': max,
      'pinned': [],
    });
    if (response.data is List) {
      return (response.data as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getChats(String avatarUrl) async {
    final response = await _dio.post('/api/characters/chats', data: {
      'avatar_url': avatarUrl,
    });
    if (response.data is List) {
      return (response.data as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getChatHistory(
      String avatarUrl, String fileName) async {
    final response = await _dio.post('/api/chats/get', data: {
      'avatar_url': avatarUrl,
      'file_name': fileName,
    });
    if (response.data is List) {
      return (response.data as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<void> saveChat(
    String avatarUrl,
    String fileName,
    List<Map<String, dynamic>> messages,
  ) async {
    await _dio.post('/api/chats/save', data: {
      'avatar_url': avatarUrl,
      'file_name': fileName,
      'chat': messages,
    });
  }

  Stream<String> sendMessageStream(Map<String, dynamic> body) async* {
    try {
      final response = await _dio.post(
        '/api/backends/chat-completions/generate',
        data: body,
        options: Options(responseType: ResponseType.stream),
      );

      final data = response.data;
      Stream<List<int>> byteStream;
      if (data is ResponseBody) {
        byteStream = data.stream;
      } else if (data is Stream<List<int>>) {
        byteStream = data;
      } else if (data is List<int>) {
        byteStream = Stream.value(data);
      } else {
        throw Exception('不支持的流响应类型: ${data.runtimeType}');
      }

      String buffer = '';
      var done = false;

      await for (final text
          in byteStream.map<List<int>>((c) => c).transform(utf8.decoder)) {
        buffer += text;

        while (buffer.contains('\n')) {
          final lineEnd = buffer.indexOf('\n');
          final line = buffer.substring(0, lineEnd).trim();
          buffer = buffer.substring(lineEnd + 1);
          if (line.startsWith('data:')) {
            final data = line.substring(5).trim();
            if (data == '[DONE]') {
              done = true;
              break;
            }
            yield data;
          }
        }
        if (done) break;
      }

      if (!done && buffer.trim().isNotEmpty) {
        final tail = buffer.trim();
        if (tail.startsWith('data:')) {
          final data = tail.substring(5).trim();
          if (data != '[DONE]') yield data;
        }
      }
    } catch (e) {
      yield jsonEncode({'error': e.toString()});
    }
  }

  Future<Map<String, dynamic>> sendMessageNonStream(
      Map<String, dynamic> body) async {
    final response = await _dio.post(
      '/api/backends/chat-completions/generate',
      data: body,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteChat(String avatarUrl, String fileId) async {
    await _dio.post('/api/chats/delete', data: {
      'avatar_url': avatarUrl,
      'chatfile': fileId,
    });
  }

  Future<void> deleteCharacter(String avatarUrl, {bool deleteChats = true}) async {
    await _dio.post('/api/characters/delete', data: {
      'avatar_url': avatarUrl,
      'delete_chats': deleteChats,
    });
  }

  Future<List<Map<String, dynamic>>> getWorldInfoList() async {
    final response = await _dio.post('/api/worldinfo/list');
    if (response.data is List) {
      return (response.data as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> getWorldInfo(String name) async {
    final response = await _dio.post('/api/worldinfo/get', data: {
      'name': name,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> saveWorldInfo(String name, Map<String, dynamic> data) async {
    await _dio.post('/api/worldinfo/edit', data: {
      'name': name,
      'data': data,
    });
  }

  Future<void> deleteWorldInfo(String name) async {
    await _dio.post('/api/worldinfo/delete', data: {
      'name': name,
    });
  }

  Future<List<String>> getAvailableModels(
    String source, {
    String? customUrl,
  }) async {
    try {
      final response = await _dio.post(
        '/api/backends/chat-completions/status',
        data: {
          'chat_completion_source': source,
          if (source == 'custom') 'custom_url': customUrl,
        },
      );
      final data = response.data;
      if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map((m) => m['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
      }
    } catch (e) {
      // 该源未配置 key 或不可用
    }
    return [];
  }
}
