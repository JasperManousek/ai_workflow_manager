import 'dart:io';

import 'package:ai_workflow_manager/workflow/files/workflow_file_reference.dart';
import 'package:ai_workflow_manager/workflow/model/workflow_definition.dart';
import 'package:ai_workflow_manager/workflow/model/workflow_node.dart';
import 'package:ai_workflow_manager/workflow/run/workflow_run_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory temporaryDirectory;
  late Directory sourceDirectory;
  late Directory workspaceDirectory;
  late Directory runsRoot;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'workflow-run-controller-test-',
    );
    sourceDirectory = Directory(
      path.join(temporaryDirectory.path, 'source'),
    );
    workspaceDirectory = Directory(
      path.join(temporaryDirectory.path, 'workspace'),
    );
    runsRoot = Directory(path.join(temporaryDirectory.path, 'runs'));
    await sourceDirectory.create();
    await workspaceDirectory.create();
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('executes a workflow and creates isolated execution data', () async {
    final controller = WorkflowRunController(runsRoot: runsRoot);
    final visitedNodeIds = <String>[];

    controller.addListener(() {
      final activeNodeId = controller.activeNodeId;
      if (activeNodeId != null &&
          (visitedNodeIds.isEmpty || visitedNodeIds.last != activeNodeId)) {
        visitedNodeIds.add(activeNodeId);
      }
    });

    await controller.run(
      workflow: _writeFileWorkflow(
        outputStorage: WorkflowStorage.execution,
      ),
      sourceDirectory: sourceDirectory,
      workflowVersionNumber: 3,
    );

    expect(controller.status, WorkflowRunStatus.completed);
    expect(controller.failureMessage, isNull);
    expect(controller.workflowVersionNumber, 3);
    expect(visitedNodeIds, ['start', 'write', 'end']);

    final runDirectory = controller.runDirectory;
    expect(runDirectory, isNotNull);
    expect(
      await File(
        path.join(runDirectory!.path, 'work', 'result.txt'),
      ).readAsString(),
      'generated content',
    );
  });

  test('creates a separate execution directory every time', () async {
    final controller = WorkflowRunController(runsRoot: runsRoot);
    final workflow = _writeFileWorkflow(
      outputStorage: WorkflowStorage.execution,
    );

    await controller.run(
      workflow: workflow,
      sourceDirectory: sourceDirectory,
    );
    final firstRunPath = controller.runDirectory!.path;

    await controller.run(
      workflow: workflow,
      sourceDirectory: sourceDirectory,
    );
    final secondRunPath = controller.runDirectory!.path;

    expect(secondRunPath, isNot(equals(firstRunPath)));
    expect(await Directory(firstRunPath).exists(), isTrue);
    expect(await Directory(secondRunPath).exists(), isTrue);
  });

  test('reports the node that failed during execution', () async {
    final controller = WorkflowRunController(runsRoot: runsRoot);

    await controller.run(
      workflow: WorkflowDefinition(
        id: 'missing-source-workflow',
        name: 'Missing source workflow',
        nodes: [
          StartNode(
            id: 'start',
            name: 'Start',
            nextNodeId: 'combine',
          ),
          CombineTextNode(
            id: 'combine',
            name: 'Combine missing files',
            inputs: [
              const WorkflowFileReference(
                storage: WorkflowStorage.source,
                relativePath: 'missing-one.txt',
                format: WorkflowFileFormat.plainText,
              ),
              const WorkflowFileReference(
                storage: WorkflowStorage.source,
                relativePath: 'missing-two.txt',
                format: WorkflowFileFormat.plainText,
              ),
            ],
            output: const WorkflowFileReference(
              storage: WorkflowStorage.execution,
              relativePath: 'combined.txt',
              format: WorkflowFileFormat.plainText,
            ),
            nextNodeId: 'end',
          ),
          EndNode(id: 'end', name: 'End'),
        ],
      ),
      sourceDirectory: sourceDirectory,
    );

    expect(controller.status, WorkflowRunStatus.failed);
    expect(controller.activeNodeId, 'combine');
    expect(controller.activeNodeName, 'Combine missing files');
    expect(controller.failureMessage, contains('missing-one.txt'));
  });

  test('requires a workspace for workspace shared references', () async {
    final controller = WorkflowRunController(runsRoot: runsRoot);

    await controller.run(
      workflow: _writeFileWorkflow(
        outputStorage: WorkflowStorage.workspace,
      ),
      sourceDirectory: sourceDirectory,
    );

    expect(controller.status, WorkflowRunStatus.failed);
    expect(controller.runDirectory, isNull);
    expect(controller.failureMessage, contains('executed from a workspace'));
  });

  test('writes workspace data and reports the changed file', () async {
    final controller = WorkflowRunController(runsRoot: runsRoot);

    await controller.run(
      workflow: _writeFileWorkflow(
        outputStorage: WorkflowStorage.workspace,
      ),
      sourceDirectory: sourceDirectory,
      workspaceDirectory: workspaceDirectory,
    );

    expect(controller.status, WorkflowRunStatus.completed);
    expect(
      await File(path.join(workspaceDirectory.path, 'result.txt')).readAsString(),
      'generated content',
    );
    expect(controller.workspaceFilesChanged, ['result.txt']);
    expect(controller.latestActivity, 'Execution completed.');
  });
}

WorkflowDefinition _writeFileWorkflow({
  required WorkflowStorage outputStorage,
}) {
  return WorkflowDefinition(
    id: 'write-file-workflow',
    name: 'Write file workflow',
    nodes: [
      StartNode(
        id: 'start',
        name: 'Start',
        nextNodeId: 'write',
      ),
      WriteFileNode(
        id: 'write',
        name: 'Write result',
        content: 'generated content',
        output: WorkflowFileReference(
          storage: outputStorage,
          relativePath: 'result.txt',
          format: WorkflowFileFormat.plainText,
        ),
        nextNodeId: 'end',
      ),
      EndNode(id: 'end', name: 'End'),
    ],
  );
}
