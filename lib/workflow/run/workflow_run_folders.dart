import 'dart:io';

import 'package:path/path.dart' as path;

import '../../storage/application_data_directory.dart';

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
  return Directory(
    path.join(defaultApplicationDataDirectory().path, 'runs'),
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
