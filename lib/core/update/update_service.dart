import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static const String _owner = 'wacilimonster-source';
  static const String _repo = 'stm';
  static const String currentVersion = '1.3.0';

  final Dio _dio;

  UpdateService() : _dio = Dio();

  Future<UpdateInfo?> checkUpdate() async {
    try {
      final response = await _dio.get(
        'https://api.github.com/repos/$_owner/$_repo/releases/latest',
        options: Options(
          headers: {
            'Accept': 'application/vnd.github.v3+json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final latestVersion = (data['tag_name'] as String?)?.replaceFirst('v', '') ?? '0.0.0';
        final downloadUrl = _extractApkUrl(data['assets'] as List<dynamic>);

        if (_compareVersion(latestVersion, currentVersion) > 0 && downloadUrl != null) {
          return UpdateInfo(
            version: latestVersion,
            downloadUrl: downloadUrl,
            releaseNotes: data['body'] as String? ?? '',
          );
        }
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
  }

  String? _extractApkUrl(List<dynamic> assets) {
    for (final asset in assets) {
      if (asset['name']?.toString().endsWith('.apk') == true) {
        return asset['browser_download_url'] as String;
      }
    }
    return null;
  }

  int _compareVersion(String latest, String current) {
    final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (var i = 0; i < 3; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return 1;
      if (l < c) return -1;
    }
    return 0;
  }

  Future<String> downloadUpdate(
    String url,
    String version,
    void Function(int received, int total)? onProgress,
  ) async {
    final dir = await getExternalStorageDirectory();
    final savePath = dir == null
        ? 'update_$version.apk'
        : '${dir.path}/update_$version.apk';

    await _dio.download(
      url,
      savePath,
      onReceiveProgress: onProgress,
    );
    return savePath;
  }
}

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}