import 'package:flutter/material.dart';

import 'screens/workflows_screen.dart';
import 'screens/workspaces_screen.dart';
import 'storage/application_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final applicationStore = await ApplicationStore.openDefault();
    runApp(AiCoordinatorApp(applicationStore: applicationStore));
  } catch (error) {
    runApp(_StorageStartupFailureApp(error: error));
  }
}

class _StorageStartupFailureApp extends StatelessWidget {
  const _StorageStartupFailureApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storage_outlined, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Application storage could not be opened.',
                  style: TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 8),
                SelectableText(error.toString()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AiCoordinatorApp extends StatelessWidget {
  const AiCoordinatorApp({
    required this.applicationStore,
    super.key,
  });

  final ApplicationStore applicationStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Coordinator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: MainScreen(applicationStore: applicationStore),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({
    required this.applicationStore,
    super.key,
  });

  final ApplicationStore applicationStore;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AI Coordinator'),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.chat),
                text: 'Chat',
              ),
              Tab(
                icon: Icon(Icons.account_tree),
                text: 'Workflows',
              ),
              Tab(
                icon: Icon(Icons.workspaces_outline),
                text: 'Workspaces',
              ),
              Tab(
                icon: Icon(Icons.account_tree),
                text: 'Nodes',
              ),
              Tab(
                icon: Icon(Icons.help),
                text: 'settings',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const ChatTab(),
            WorkflowsScreen(applicationStore: applicationStore),
            WorkspacesScreen(applicationStore: applicationStore),
            const NodesTab(),
            const SettingsTab(),
          ],
        ),
      ),
    );
  }
}

class ChatTab extends StatelessWidget {
  const ChatTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'The chat interface will go here.',
        style: TextStyle(fontSize: 20),
      ),
    );
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Application settings will go here.',
        style: TextStyle(fontSize: 20),
      ),
    );
  }
}

class NodesTab extends StatelessWidget {
  const NodesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Application settings will go here.',
        style: TextStyle(fontSize: 20),
      ),
    );
  }
}
