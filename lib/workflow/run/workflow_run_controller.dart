import 'dart:io';

import 'package:flutter/foundation.dart';

import '../files/workflow_file_reference.dart';
import '../files/workflow_file_roots.dart';
import '../model/workflow_definition.dart';
import '../model/workflow_node.dart';
import '../workflow_runner.dart';
import 'workflow_run_folders.dart';

enum WorkflowRunStatus {
  idle,
  preparing,
  running,
  completed,
  failed,
}

class WorkflowRunController extends ChangeNotifier {
  WorkflowRunController({Directory? runsRoot})
    : _runsRoot = runsRoot ?? defaultWorkflowRunsRoot();

  final Directory _runsRoot;

  WorkflowRunStatus status = WorkflowRunStatus.idle;
  String? activeNodeId;
  String? activeNodeName;
  Directory? runDirectory;
  String? failureMessage;

  bool get isActive =>
      status == WorkflowRunStatus.preparing ||
      status == WorkflowRunStatus.running;

  Future<void> run({
    required WorkflowDefinition workflow,
    required Directory sourceDirectory,
  }) async {
    if (isActive) {
      return;
    }

    status = WorkflowRunStatus.preparing;
    activeNodeId = null;
    activeNodeName = null;
    runDirectory = null;
    failureMessage = null;
    notifyListeners();

    try {
      if (!await sourceDirectory.exists()) {
        throw WorkflowRunPreparationException(
          'The selected source directory does not exist: '
          '${sourceDirectory.path}',
        );
      }

      _rejectPersistentReferences(workflow);

      final folders = await createWorkflowRunFolders(
        runsRoot: _runsRoot,
        workflowId: workflow.id,
      );

      runDirectory = folders.root;
      status = WorkflowRunStatus.running;
      notifyListeners();

      final runner = WorkflowRunner(
        roots: WorkflowFileRoots(
          source: sourceDirectory,
          working: folders.working,
          persistent: folders.persistentPlaceholder,
        ),
        onNodeStarted: (nodeId, nodeName) {
          activeNodeId = nodeId;
          activeNodeName = nodeName;
          notifyListeners();
        },
      );

      await runner.run(workflow);

      status = WorkflowRunStatus.completed;
      activeNodeId = null;
      activeNodeName = null;
      notifyListeners();
    } catch (error) {
      if (error is WorkflowExecutionException) {
        activeNodeId = error.nodeId;
        activeNodeName = error.nodeName;
        failureMessage = 'Node "${error.nodeName}" failed: ${error.cause}';
      } else {
        activeNodeId = null;
        activeNodeName = null;
        failureMessage = error.toString();
      }

      status = WorkflowRunStatus.failed;
      notifyListeners();
    }
  }

  void clear() {
    if (isActive) {
      return;
    }

    status = WorkflowRunStatus.idle;
    activeNodeId = null;
    activeNodeName = null;
    runDirectory = null;
    failureMessage = null;
    notifyListeners();
  }

  void _rejectPersistentReferences(WorkflowDefinition workflow) {
    for (final node in workflow.nodes) {
      Iterable<WorkflowFileReference> references = const [];

      if (node is ActionNode) {
        references = [...node.inputs, ...node.outputs];
      } else if (node is DecisionNode) {
        references = node.inputs;
      }

      for (final reference in references) {
        if (reference.storage == WorkflowStorage.persistent) {
          throw const WorkflowRunPreparationException(
            'Persistent storage cannot be executed yet because source '
            'contexts have not been implemented. Use Source or Working '
            'storage for this workflow.',
          );
        }
      }
    }
  }
}

class WorkflowRunPreparationException implements Exception {
  const WorkflowRunPreparationException(this.message);

  final String message;

  @override
  String toString() => 'WorkflowRunPreparationException: $message';
}
