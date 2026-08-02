import 'dart:io';

import 'package:flutter/foundation.dart';

import '../files/workflow_file_access_event.dart';
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
  final Set<String> _workspaceFilesChanged = <String>{};

  WorkflowRunStatus status = WorkflowRunStatus.idle;
  String? workflowName;
  int? workflowVersionNumber;
  String? activeNodeId;
  String? activeNodeName;
  String? latestActivity;
  Directory? runDirectory;
  String? failureMessage;

  bool get isActive =>
      status == WorkflowRunStatus.preparing ||
      status == WorkflowRunStatus.running;

  List<String> get workspaceFilesChanged =>
      List<String>.unmodifiable(_workspaceFilesChanged);

  Future<void> run({
    required WorkflowDefinition workflow,
    required Directory sourceDirectory,
    Directory? workspaceDirectory,
    int? workflowVersionNumber,
  }) async {
    if (isActive) {
      return;
    }

    status = WorkflowRunStatus.preparing;
    workflowName = workflow.name;
    this.workflowVersionNumber = workflowVersionNumber;
    activeNodeId = null;
    activeNodeName = null;
    latestActivity = 'Preparing execution.';
    runDirectory = null;
    failureMessage = null;
    _workspaceFilesChanged.clear();
    notifyListeners();

    try {
      if (!await sourceDirectory.exists()) {
        throw WorkflowRunPreparationException(
          'The source directory does not exist: ${sourceDirectory.path}',
        );
      }

      if (workspaceDirectory != null &&
          !await workspaceDirectory.exists()) {
        throw WorkflowRunPreparationException(
          'The workspace shared-data directory does not exist: '
          '${workspaceDirectory.path}',
        );
      }

      _requireWorkspaceForSharedReferences(
        workflow,
        workspaceDirectory: workspaceDirectory,
      );

      final folders = await createWorkflowRunFolders(
        runsRoot: _runsRoot,
        workflowId: workflow.id,
      );

      runDirectory = folders.root;
      status = WorkflowRunStatus.running;
      latestActivity = 'Execution started.';
      notifyListeners();

      final runner = WorkflowRunner(
        roots: WorkflowFileRoots(
          source: sourceDirectory,
          execution: folders.execution,
          workspace: workspaceDirectory ?? folders.workspacePlaceholder,
        ),
        onNodeStarted: (nodeId, nodeName) {
          activeNodeId = nodeId;
          activeNodeName = nodeName;
          latestActivity = 'Running node "$nodeName".';
          notifyListeners();
        },
        onFileAccessEvent: _handleFileAccessEvent,
      );

      await runner.run(workflow);

      status = WorkflowRunStatus.completed;
      activeNodeId = null;
      activeNodeName = null;
      latestActivity = 'Execution completed.';
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

      latestActivity = failureMessage;
      status = WorkflowRunStatus.failed;
      notifyListeners();
    }
  }

  void clear() {
    if (isActive) {
      return;
    }

    status = WorkflowRunStatus.idle;
    workflowName = null;
    workflowVersionNumber = null;
    activeNodeId = null;
    activeNodeName = null;
    latestActivity = null;
    runDirectory = null;
    failureMessage = null;
    _workspaceFilesChanged.clear();
    notifyListeners();
  }

  void _handleFileAccessEvent(WorkflowFileAccessEvent event) {
    if (event.phase == WorkflowFileAccessPhase.started) {
      latestActivity = switch (event.operation) {
        WorkflowFileOperation.read =>
          'Reading ${_displayReference(event.reference)}.',
        WorkflowFileOperation.write =>
          'Writing ${_displayReference(event.reference)}.',
        WorkflowFileOperation.inspect =>
          'Checking ${_displayReference(event.reference)}.',
      };
    } else if (event.phase == WorkflowFileAccessPhase.completed &&
        event.operation == WorkflowFileOperation.write) {
      latestActivity = 'Wrote ${_displayReference(event.reference)}.';

      if (event.reference.storage == WorkflowStorage.workspace) {
        _workspaceFilesChanged.add(event.reference.relativePath);
      }
    } else if (event.phase == WorkflowFileAccessPhase.failed) {
      latestActivity = 'Failed to access '
          '${_displayReference(event.reference)}.';
    }

    notifyListeners();
  }

  String _displayReference(WorkflowFileReference reference) {
    final scope = switch (reference.storage) {
      WorkflowStorage.source => 'source',
      WorkflowStorage.workspace => 'workspace',
      WorkflowStorage.execution => 'execution',
    };

    return '$scope:${reference.relativePath}';
  }

  void _requireWorkspaceForSharedReferences(
    WorkflowDefinition workflow, {
    required Directory? workspaceDirectory,
  }) {
    if (workspaceDirectory != null) {
      return;
    }

    for (final node in workflow.nodes) {
      Iterable<WorkflowFileReference> references = const [];

      if (node is ActionNode) {
        references = [...node.inputs, ...node.outputs];
      } else if (node is DecisionNode) {
        references = node.inputs;
      }

      for (final reference in references) {
        if (reference.storage == WorkflowStorage.workspace) {
          throw const WorkflowRunPreparationException(
            'Workspace shared storage is available only when the workflow '
            'is executed from a workspace.',
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
