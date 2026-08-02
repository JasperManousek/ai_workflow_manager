import 'dart:io';

import 'package:path/path.dart' as path;

import '../../storage/application_data_directory.dart';

class WorkflowRunFolders {
  const WorkflowRunFolders({
    required this.root,
    required this.execution,
    required this.logs,
    required this.workspacePlaceholder,
  });

  final Directory root;
  final Directory execution;
  final Directory logs;
  final Directory workspacePlaceholder;
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
  final execution = Directory(path.join(root.path, 'work'));
  final logs = Directory(path.join(root.path, 'logs'));
  final workspacePlaceholder = Directory(
    path.join(root.path, 'workspace-unavailable'),
  );

  await execution.create(recursive: true);
  await logs.create(recursive: true);
  await workspacePlaceholder.create(recursive: true);

  return WorkflowRunFolders(
    root: root,
    execution: execution,
    logs: logs,
    workspacePlaceholder: workspacePlaceholder,
  );
}

String _safePathSegment(String value) {
  final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  if (safe.isEmpty) {
    return 'workflow';
  }

  return safe.length <= 80 ? safe : safe.substring(0, 80);
}
