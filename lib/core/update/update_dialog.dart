import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
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
  String? _savedPath;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    try {
      final path = await widget.service.downloadUpdate(
        widget.update.downloadUrl,
        widget.update.version,
        (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
      );
      if (mounted) {
        setState(() {
          _finished = true;
          _savedPath = path;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  Future<void> _install() async {
    if (_savedPath == null) return;
    setState(() => _opening = true);
    final result = await OpenFilex.open(_savedPath!);
    if (mounted) {
      setState(() => _opening = false);
      if (result.type != ResultType.done && result.type != ResultType.noAppToOpen) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开安装界面失败: ${result.message}')),
        );
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
                  ? '已保存到：\n$_savedPath'
                  : '${(_progress * 100).toStringAsFixed(1)}%',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      actions: [
        if (_finished && _error == null) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后安装'),
          ),
          FilledButton(
            onPressed: _opening ? null : _install,
            child: _opening
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('立即安装'),
          ),
        ] else
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
      ],
    );
  }
}