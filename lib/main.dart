import 'package:flutter/material.dart';

import 'screens/workflows_screen.dart';

void main() {
  runApp(const AiCoordinatorApp());
}

class AiCoordinatorApp extends StatelessWidget {
  const AiCoordinatorApp({super.key});

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
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

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
              )
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ChatTab(),
            WorkflowsScreen(),
            RunsTab(),
            NodesTab(),
            SettingsTab(),
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