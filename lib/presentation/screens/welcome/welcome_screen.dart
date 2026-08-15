import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/update/update_dialog.dart';
import '../../../core/update/update_service.dart';
import '../../providers/providers.dart';
import '../home/home_screen.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _urlController = TextEditingController();
  final _updateService = UpdateService();
  bool _isConnecting = false;
  bool _isCheckingUpdate = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isConnecting = true);

    final notifier = ref.read(connectionProvider.notifier);
    await notifier.connect(url);

    final state = ref.read(connectionProvider);
    if (state.status == ConnectionStatus.connected && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }

    if (mounted) {
      setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: _isCheckingUpdate
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update),
            tooltip: '检查更新',
            onPressed: _isCheckingUpdate
                ? null
                : () async {
                    setState(() => _isCheckingUpdate = true);
                    await checkUpdateAndDownload(context, _updateService);
                    if (mounted) {
                      setState(() => _isCheckingUpdate = false);
                    }
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_bar,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                '掌上酒馆',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              Text(
                '请输入 SillyTavern 服务器地址',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  hintText: 'http://192.168.1.100:8000',
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
              ),
              if (connectionState.status == ConnectionStatus.error) ...[
                const SizedBox(height: 16),
                Text(
                  connectionState.errorMessage ?? '连接失败',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isConnecting ? null : _connect,
                  child: _isConnecting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('连接服务器'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '局域网内访问，无需公网IP',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
