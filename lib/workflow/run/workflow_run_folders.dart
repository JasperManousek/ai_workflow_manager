import 'dart:io';

import 'package:path/path.dart' as path;

class WorkflowRunFolders {
  const WorkflowRunFolders({
    required this.root,
    required this.working,
    required this.logs,
    required this.persistentPlaceholder,
  });

  final Directory root;
  final Directory working;
  final Directory logs;
  final Directory persistentPlaceholder;
}

Directory defaultWorkflowRunsRoot() {
  final environment = Platform.environment;
  late final String basePath;

  if (Platform.isLinux) {
    basePath = environment['XDG_DATA_HOME'] ??
        path.join(environment['HOME'] ?? Directory.systemTemp.path, '.local', 'share');
  } else if (Platform.isMacOS) {
    basePath = path.join(
      environment['HOME'] ?? Directory.systemTemp.path,
      'Library',
      'Application Support',
    );
  } else if (Platform.isWindows) {
    basePath = environment['LOCALAPPDATA'] ??
        environment['APPDATA'] ??
        Directory.systemTemp.path;
  } else {
    basePath = Directory.systemTemp.path;
  }

  return Directory(
    path.join(basePath, 'ai_workflow_manager', 'runs'),
  );
}

Future<WorkflowRunFolders> createWorkflowRunFolders({
  required Directory runsRoot,
  required String workflowId,
}) async {
  final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
  final safeWorkflowId = _safePathSegment(workflowId);
  final root = Directory(
    path.join(runsRoot.path, 'run-$timestamp-$safeWorkflowId'),
  );
  final working = Directory(path.join(root.path, 'work'));
  final logs = Directory(path.join(root.path, 'logs'));
  final persistentPlaceholder = Directory(
    path.join(root.path, 'persistent-unavailable'),
  );

  await working.create(recursive: true);
  await logs.create(recursive: true);
  await persistentPlaceholder.create(recursive: true);

  return WorkflowRunFolders(
    root: root,
    working: working,
    logs: logs,
    persistentPlaceholder: persistentPlaceholder,
  );
}

String _safePathSegment(String value) {
  final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  if (safe.isEmpty) {
    return 'workflow';
  }

  return safe.length <= 80 ? safe : safe.substring(0, 80);
}
