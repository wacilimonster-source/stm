import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/update/update_dialog.dart';
import '../../../core/update/update_service.dart';
import '../../providers/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _updateService = UpdateService();
  bool _isCheckingUpdate = false;
  final _apiKeyController = TextEditingController();
  final _apiModelController = TextEditingController();
  final _apiProxyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storage = ref.read(localStorageProvider);
      _apiKeyController.text = storage.apiKey ?? '';
      _apiModelController.text = storage.apiModel ?? '';
      _apiProxyController.text = storage.apiProxy ?? '';
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiModelController.dispose();
    _apiProxyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final connection = ref.watch(connectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            children: [
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text('深色模式'),
                trailing: Switch(
                  value: isDark,
                  onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            children: [
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: const Text('服务器地址'),
                subtitle: Text(connection.client?.baseUrl ?? '未连接'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.link_off),
                title: const Text('断开连接'),
                onTap: () async {
                  await ref.read(connectionProvider.notifier).disconnect();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'AI 配置（可选，用于生成对话）',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    hintText: '服务端未配置时在此填写',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _saveApiConfig(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _apiModelController,
                  decoration: const InputDecoration(
                    labelText: '模型名称',
                    hintText: '如 gpt-4o-mini / deepseek-chat',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _saveApiConfig(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _apiProxyController,
                  decoration: const InputDecoration(
                    labelText: 'API 地址',
                    hintText: '默认 https://api.openai.com/v1',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _saveApiConfig(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: _saveApiConfig,
                    child: const Text('保存配置'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            children: [
              ListTile(
                leading: const Icon(Icons.system_update_outlined),
                title: const Text('检查更新'),
                trailing: _isCheckingUpdate
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _isCheckingUpdate ? null : _checkUpdate,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('版本'),
                subtitle: Text(UpdateService.currentVersion),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveApiConfig() async {
    final storage = ref.read(localStorageProvider);
    await storage.setApiKey(_apiKeyController.text.trim());
    await storage.setApiModel(_apiModelController.text.trim());
    await storage.setApiProxy(_apiProxyController.text.trim());
    ref.invalidate(apiKeyProvider);
    ref.invalidate(apiModelProvider);
    ref.invalidate(apiProxyProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
    }
  }

  Future<void> _checkUpdate() async {
    setState(() => _isCheckingUpdate = true);

    try {
      await checkUpdateAndDownload(context, _updateService);
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;

  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }
}