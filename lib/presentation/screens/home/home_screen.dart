import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import 'recent_chats_tab.dart';
import 'characters_tab.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(connectionProvider).client;

    return Scaffold(
      appBar: AppBar(
        title: const Text('掌上酒馆'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '最近对话'),
            Tab(text: '角色列表'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RecentChatsTab(
            avatarBaseUrl: client?.baseUrl ?? '',
          ),
          CharactersTab(
            avatarBaseUrl: client?.baseUrl ?? '',
          ),
        ],
      ),
    );
  }
}
