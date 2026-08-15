import 'package:flutter/material.dart';
import 'update_service.dart';

Future<void> checkUpdateAndDownload(BuildContext context, UpdateService service) async {
  try {
    final update = await service.checkUpdate();
    if (!context.mounted) return;

    if (update == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已是最新版本')),
      );
      return;
    }

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

    if (confirmed != true || !context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _DownloadDialog(
        service: service,
        update: update,
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查更新失败: $e')),
      );
    }
  }
}

class _DownloadDialog extends StatefulWidget {
  final UpdateService service;
  final UpdateInfo update;

  const _DownloadDialog({required this.service, required this.update});

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  double _progress = 0;
  bool _finished = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    try {
      await widget.service.downloadUpdate(
        widget.update.downloadUrl,
        widget.update.version,
        (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
      );
      if (mounted) {
        setState(() => _finished = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_finished ? '下载完成' : '下载中 v${widget.update.version}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Text(
              '下载失败: $_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else ...[
            LinearProgressIndicator(value: _finished ? 1 : _progress),
            const SizedBox(height: 12),
            Text(
              _finished
                  ? '请手动安装 APK'
                  : '${(_progress * 100).toStringAsFixed(1)}%',
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}