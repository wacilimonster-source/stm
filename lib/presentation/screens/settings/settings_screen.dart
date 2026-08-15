import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/update/update_service.dart';
import '../providers/providers.dart';
import 'welcome/welcome_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _updateService = UpdateService();
  bool _isCheckingUpdate = false;
  bool _isDownloading = false;
  double _downloadProgress = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ref.watch(isDarkModeProvider);
    final connection = ref.watch(connectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          _SectionTitle('外观'),
          SwitchListTile(
            title: const Text('深色模式'),
            value: isDark,
            onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
          ),
          const Divider(),
          _SectionTitle('连接'),
          ListTile(
            title: const Text('服务器地址'),
            subtitle: Text(connection.client?.baseUrl ?? '未连接'),
          ),
          ListTile(
            title: const Text('断开连接'),
            onTap: () async {
              await ref.read(connectionProvider.notifier).disconnect();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const WelcomeScreen(),
                  ),
                  (route) => false,
                );
              }
            },
          ),
          const Divider(),
          _SectionTitle('更新'),
          ListTile(
            title: const Text('检查更新'),
            leading: const Icon(Icons.system_update),
            trailing: _isCheckingUpdate
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isCheckingUpdate ? null : _checkUpdate,
          ),
          if (_isDownloading) ...[
            ListTile(
              title: Text('下载中 ${(_downloadProgress * 100).toStringAsFixed(1)}%'),
              subtitle: LinearProgressIndicator(value: _downloadProgress),
            ),
          ],
          const Divider(),
          _SectionTitle('关于'),
          const ListTile(
            title: Text('版本'),
            subtitle: Text('1.0.0'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkUpdate() async {
    setState(() => _isCheckingUpdate = true);

    try {
      final update = await _updateService.checkUpdate();

      if (!mounted) return;

      if (update != null) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('发现新版本 v${update.version}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('发现新版本，是否下载？'),
                if (update.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    update.releaseNotes,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('下载'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          _downloadUpdate(update);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已是最新版本')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  Future<void> _downloadUpdate(UpdateInfo update) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      await update_service.downloadUpdate(
        update.downloadUrl,
        update.version,
        (received, total) {
          if (total > 0 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('下载完成，请手动安装 APK')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
