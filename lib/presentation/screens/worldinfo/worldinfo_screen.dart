import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/worldinfo.dart';
import '../../providers/providers.dart';

class WorldInfoScreen extends ConsumerStatefulWidget {
  final String characterName;

  const WorldInfoScreen({super.key, required this.characterName});

  @override
  ConsumerState<WorldInfoScreen> createState() => _WorldInfoScreenState();
}

class _WorldInfoScreenState extends ConsumerState<WorldInfoScreen> {
  List<Map<String, dynamic>> _worldInfoList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorldInfo();
  }

  Future<void> _loadWorldInfo() async {
    final connection = ref.read(connectionProvider);
    if (connection.client == null) return;

    try {
      final data = await connection.client!.getWorldInfoList();
      setState(() {
        _worldInfoList = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('世界书'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEditDialog(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _worldInfoList.isEmpty
              ? const Center(child: Text('暂无世界书'))
              : ListView.builder(
                  itemCount: _worldInfoList.length,
                  itemBuilder: (context, index) {
                    final wi = _worldInfoList[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(wi['name'] ?? '未命名'),
                        subtitle: Text(wi['extensions']?.toString() ?? ''),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          _showEntriesDialog(context, wi['file_id']);
                        },
                      ),
                    );
                  },
                ),
    );
  }

  void _showEntriesDialog(BuildContext context, String worldName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return WorldInfoEntriesSheet(
            worldName: worldName,
            scrollController: scrollController,
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建世界书'),
        content: const TextField(
          decoration: InputDecoration(
            labelText: '世界书名称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}

class WorldInfoEntriesSheet extends ConsumerStatefulWidget {
  final String worldName;
  final ScrollController scrollController;

  const WorldInfoEntriesSheet({
    super.key,
    required this.worldName,
    required this.scrollController,
  });

  @override
  ConsumerState<WorldInfoEntriesSheet> createState() =>
      _WorldInfoEntriesSheetState();
}

class _WorldInfoEntriesSheetState
    extends ConsumerState<WorldInfoEntriesSheet> {
  WorldInfo? _worldInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final connection = ref.read(connectionProvider);
    if (connection.client == null) return;

    try {
      final data = await connection.client!.getWorldInfo(widget.worldName);
      setState(() {
        _worldInfo = WorldInfo.fromJson(widget.worldName, data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  widget.worldName,
                  style: theme.textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddEntryDialog(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _worldInfo == null || _worldInfo!.entries.isEmpty
                    ? const Center(child: Text('暂无条目'))
                    : ListView.builder(
                        controller: widget.scrollController,
                        itemCount: _worldInfo!.entries.length,
                        itemBuilder: (context, index) {
                          final entry =
                              _worldInfo!.entries.values.toList()[index];
                          return SwitchListTile(
                            title: Text(entry.key.join(', ')),
                            subtitle: Text(
                              entry.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            value: entry.enabled,
                            onChanged: (value) async {
                              final updated = entry.copyWith(enabled: value);
                              // TODO: 调用 API 更新
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showAddEntryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加条目'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(labelText: '关键词（主要）'),
            ),
            SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(labelText: '关键词（次要）'),
            ),
            SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(labelText: '内容'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}
