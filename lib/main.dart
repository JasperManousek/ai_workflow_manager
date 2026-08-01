import 'package:flutter/material.dart';

import 'screens/workflows_screen.dart';
import 'workflow/persistence/workflow_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final workflowStore = await WorkflowStore.openDefault();
    runApp(AiCoordinatorApp(workflowStore: workflowStore));
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
                  'Workflow storage could not be opened.',
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
    required this.workflowStore,
    super.key,
  });

  final WorkflowStore workflowStore;

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
      home: MainScreen(workflowStore: workflowStore),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({
    required this.workflowStore,
    super.key,
  });

  final WorkflowStore workflowStore;

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
                icon: Icon(Icons.account_tree),
                text: 'runs',
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
            WorkflowsScreen(workflowStore: workflowStore),
            const RunsTab(),
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

class RunsTab extends StatelessWidget {
  const RunsTab({super.key});

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
