import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/worldinfo.dart';
import '../../providers/providers.dart';

final worldInfoListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final connection = ref.watch(connectionProvider);
  if (connection.status != ConnectionStatus.connected || connection.client == null) {
    return [];
  }
  return connection.client!.getWorldInfoList();
});

class WorldInfoScreen extends ConsumerStatefulWidget {
  const WorldInfoScreen({super.key});

  @override
  ConsumerState<WorldInfoScreen> createState() => _WorldInfoScreenState();
}

class _WorldInfoScreenState extends ConsumerState<WorldInfoScreen> {
  @override
  Widget build(BuildContext context) {
    final worldInfosAsync = ref.watch(worldInfoListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('世界书'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建世界书',
            onPressed: () => _createWorldInfo(context),
          ),
        ],
      ),
      body: worldInfosAsync.when(
        data: (worldInfos) {
          if (worldInfos.isEmpty) {
            return const Center(child: Text('暂无世界书\n点击右上角 + 新建', textAlign: TextAlign.center));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(worldInfoListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: worldInfos.length,
              itemBuilder: (context, index) {
                final wi = worldInfos[index];
                final name = wi['name'] ?? '';
                final entryCount =
                    (wi['extensions']?['world_info']?['entries'] as Map<String, dynamic>?)?.length ??
                        wi['entry_count'] ??
                        0;
                return Dismissible(
                  key: ValueKey('wi_$name'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) => _confirmDelete(context, name),
                  onDismissed: (_) => ref.invalidate(worldInfoListProvider),
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.book_outlined),
                      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('$entryCount 个条目'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WorldInfoEntriesScreen(name: name),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<void> _createWorldInfo(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建世界书'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '世界书名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final connection = ref.read(connectionProvider);
    if (connection.client == null) return;

    try {
      await connection.client!.saveWorldInfo(name, {'entries': <String, dynamic>{}});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已创建「$name」')),
      );
      ref.invalidate(worldInfoListProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建失败: $e')),
      );
    }
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除世界书'),
        content: Text('确定删除「$name」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    final connection = ref.read(connectionProvider);
    if (connection.client == null) return false;

    try {
      await connection.client!.deleteWorldInfo(name);
      ref.invalidate(worldInfoListProvider);
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
      return false;
    }
  }
}

class WorldInfoEntriesScreen extends ConsumerStatefulWidget {
  final String name;

  const WorldInfoEntriesScreen({super.key, required this.name});

  @override
  ConsumerState<WorldInfoEntriesScreen> createState() => _WorldInfoEntriesScreenState();
}

class _WorldInfoEntriesScreenState extends ConsumerState<WorldInfoEntriesScreen> {
  FutureProvider<WorldInfo>? _provider;

  FutureProvider<WorldInfo> _getProvider() {
    return _provider ??= FutureProvider<WorldInfo>((ref) async {
      final connection = ref.watch(connectionProvider);
      if (connection.client == null) return WorldInfo(name: widget.name, entries: {});
      final data = await connection.client!.getWorldInfo(widget.name);
      return WorldInfo.fromJson(widget.name, data);
    });
  }

  @override
  Widget build(BuildContext context) {
    final worldInfoAsync = ref.watch(_getProvider());

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新增条目',
            onPressed: () => _createEntry(context),
          ),
        ],
      ),
      body: worldInfoAsync.when(
        data: (worldInfo) {
          final entries = worldInfo.entries.values.toList()
            ..sort((a, b) => a.order.compareTo(b.order));
          if (entries.isEmpty) {
            return const Center(child: Text('暂无条目\n点击右上角 + 新增', textAlign: TextAlign.center));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Dismissible(
                key: ValueKey('entry_${widget.name}_${entry.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.error,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) => _confirmDeleteEntry(context, worldInfo, entry),
                onDismissed: (_) => ref.invalidate(_getProvider()),
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: Switch(
                      value: entry.enabled,
                      onChanged: (value) async {
                        await _saveEntry(worldInfo, entry.copyWith(enabled: value));
                        ref.invalidate(_getProvider());
                      },
                    ),
                    title: Text(
                      entry.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '顺序: ${entry.order}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WorldInfoEntryEditScreen(
                            worldInfoName: widget.name,
                            entry: entry,
                          ),
                        ),
                      ).then((_) => ref.invalidate(_getProvider()));
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<void> _createEntry(BuildContext context) async {
    final connection = ref.read(connectionProvider);
    if (connection.client == null) return;

    try {
      final data = await connection.client!.getWorldInfo(widget.name);
      final worldInfo = WorldInfo.fromJson(widget.name, data);

      var maxId = 0;
      for (final id in worldInfo.entries.keys) {
        final parsed = int.tryParse(id);
        if (parsed != null && parsed >= maxId) maxId = parsed + 1;
      }
      final newId = maxId.toString();

      final entry = WorldInfoEntry(id: newId, key: const [], content: '');
      await _saveEntry(worldInfo, entry);
      ref.invalidate(_getProvider());

      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorldInfoEntryEditScreen(
            worldInfoName: widget.name,
            entry: entry,
          ),
        ),
      ).then((_) => ref.invalidate(_getProvider()));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('新增失败: $e')),
      );
    }
  }

  Future<bool> _confirmDeleteEntry(
    BuildContext context,
    WorldInfo worldInfo,
    WorldInfoEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除条目'),
        content: const Text('确定删除此条目吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    final newEntries = Map<String, WorldInfoEntry>.from(worldInfo.entries)
      ..remove(entry.id);
    final ok = await _saveEntry(
      WorldInfo(name: worldInfo.name, entries: newEntries),
      null,
    );
    ref.invalidate(_getProvider());
    return ok;
  }

  Future<bool> _saveEntry(
    WorldInfo worldInfo,
    WorldInfoEntry? entry,
  ) async {
    final connection = ref.read(connectionProvider);
    if (connection.client == null) return false;

    final entries = Map<String, WorldInfoEntry>.from(worldInfo.entries);
    if (entry != null) {
      entries[entry.id] = entry;
    }

    final data = {
      'entries': entries.map((key, value) => MapEntry(key, value.toJson())),
    };

    try {
      await connection.client!.saveWorldInfo(widget.name, data);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
      return false;
    }
  }
}

class WorldInfoEntryEditScreen extends ConsumerStatefulWidget {
  final String worldInfoName;
  final WorldInfoEntry entry;

  const WorldInfoEntryEditScreen({
    super.key,
    required this.worldInfoName,
    required this.entry,
  });

  @override
  ConsumerState<WorldInfoEntryEditScreen> createState() => _WorldInfoEntryEditScreenState();
}

class _WorldInfoEntryEditScreenState extends ConsumerState<WorldInfoEntryEditScreen> {
  late final TextEditingController _contentController;
  late final TextEditingController _orderController;
  late final TextEditingController _keyController;
  late final TextEditingController _secondaryKeyController;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.entry.content);
    _orderController = TextEditingController(text: widget.entry.order.toString());
    _keyController = TextEditingController(text: widget.entry.key.join(', '));
    _secondaryKeyController = TextEditingController(
      text: widget.entry.secondaryKeys.join(', '),
    );
    _enabled = widget.entry.enabled;
  }

  @override
  void dispose() {
    _contentController.dispose();
    _orderController.dispose();
    _keyController.dispose();
    _secondaryKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry.id.isEmpty ? '新增条目' : '编辑条目'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('启用此条目'),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _orderController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '插入顺序',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keyController,
            decoration: const InputDecoration(
              labelText: '触发关键词（逗号分隔）',
              hintText: '如：魔法, 剑, 城堡',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _secondaryKeyController,
            decoration: const InputDecoration(
              labelText: '次级关键词（可选，逗号分隔）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: '内容',
              hintText: '输入世界设定内容...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _splitKeys(String text) {
    return text
        .split(RegExp(r'[,，]'))
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();
  }

  Future<void> _save() async {
    final connection = ref.read(connectionProvider);
    final client = connection.client;
    if (client == null) return;

    try {
      final data = await client.getWorldInfo(widget.worldInfoName);
      final worldInfo = WorldInfo.fromJson(widget.worldInfoName, data);

      final updated = widget.entry.copyWith(
        content: _contentController.text.trim(),
        order: int.tryParse(_orderController.text.trim()) ?? widget.entry.order,
        enabled: _enabled,
        key: _splitKeys(_keyController.text),
        secondaryKeys: _splitKeys(_secondaryKeyController.text),
      );

      final entries = Map<String, WorldInfoEntry>.from(worldInfo.entries);
      entries[updated.id] = updated;

      await client.saveWorldInfo(widget.worldInfoName, {
        'entries': entries.map((key, value) => MapEntry(key, value.toJson())),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }
}