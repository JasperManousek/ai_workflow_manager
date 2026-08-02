import 'dart:io';

import 'package:ai_workflow_manager/workflow/files/workflow_file_access_event.dart';
import 'package:ai_workflow_manager/workflow/files/workflow_file_reference.dart';
import 'package:ai_workflow_manager/workflow/files/workflow_file_roots.dart';
import 'package:ai_workflow_manager/workflow/model/workflow_definition.dart';
import 'package:ai_workflow_manager/workflow/model/workflow_node.dart';
import 'package:ai_workflow_manager/workflow/workflow_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory testDirectory;
  late WorkflowFileRoots roots;
  late List<WorkflowFileAccessEvent> events;
  late WorkflowRunner runner;

  setUp(() {
    testDirectory = Directory.systemTemp.createTempSync(
      'workflow_runner_test_',
    );

    roots = WorkflowFileRoots(
      source: Directory(path.join(testDirectory.path, 'source'))
        ..createSync(),
      execution: Directory(path.join(testDirectory.path, 'execution'))
        ..createSync(),
      workspace: Directory(path.join(testDirectory.path, 'workspace'))
        ..createSync(),
    );

    events = [];
    runner = WorkflowRunner(
      roots: roots,
      onFileAccessEvent: events.add,
    );
  });

  tearDown(() {
    if (testDirectory.existsSync()) {
      testDirectory.deleteSync(recursive: true);
    }
  });

  test('Write File writes configured text to its output', () async {
    final workflow = WorkflowDefinition(
      id: 'workflow-1',
      name: 'Write file',
      nodes: [
        StartNode(
          id: 'start',
          name: 'Start',
          nextNodeId: 'write',
        ),
        WriteFileNode(
          id: 'write',
          name: 'Write greeting',
          content: 'Hello from the workflow.\n',
          output: const WorkflowFileReference(
            storage: WorkflowStorage.execution,
            relativePath: 'generated/greeting.md',
            format: WorkflowFileFormat.markdown,
          ),
          nextNodeId: 'end',
        ),
        EndNode(
          id: 'end',
          name: 'End',
        ),
      ],
    );

    await runner.run(workflow);

    final output = File(
      path.join(
        roots.execution.path,
        'generated',
        'greeting.md',
      ),
    );

    expect(
      await output.readAsString(),
      'Hello from the workflow.\n',
    );
  });

  test('Combine Text concatenates every input in user-defined order', () async {
    await File(path.join(roots.source.path, 'first.md')).writeAsString(
      'First\n',
    );
    await File(path.join(roots.source.path, 'second.txt')).writeAsString(
      'Second\n',
    );
    await File(path.join(roots.source.path, 'third.md')).writeAsString(
      'Third\n',
    );

    final workflow = WorkflowDefinition(
      id: 'workflow-1',
      name: 'Combine text',
      nodes: [
        StartNode(
          id: 'start',
          name: 'Start',
          nextNodeId: 'combine',
        ),
        CombineTextNode(
          id: 'combine',
          name: 'Combine documents',
          inputs: const [
            WorkflowFileReference(
              storage: WorkflowStorage.source,
              relativePath: 'third.md',
              format: WorkflowFileFormat.markdown,
            ),
            WorkflowFileReference(
              storage: WorkflowStorage.source,
              relativePath: 'first.md',
              format: WorkflowFileFormat.markdown,
            ),
            WorkflowFileReference(
              storage: WorkflowStorage.source,
              relativePath: 'second.txt',
              format: WorkflowFileFormat.plainText,
            ),
          ],
          output: const WorkflowFileReference(
            storage: WorkflowStorage.execution,
            relativePath: 'combined.md',
            format: WorkflowFileFormat.markdown,
          ),
          nextNodeId: 'end',
        ),
        EndNode(
          id: 'end',
          name: 'End',
        ),
      ],
    );

    await runner.run(workflow);

    final output = File(path.join(roots.execution.path, 'combined.md'));

    expect(
      await output.readAsString(),
      'Third\nFirst\nSecond\n',
    );
  });

  test('Counter Decision nodes with the same name share one counter', () async {
    final workflow = WorkflowDefinition(
      id: 'workflow-1',
      name: 'Shared counter',
      nodes: [
        StartNode(
          id: 'start',
          name: 'Start',
          nextNodeId: 'counter-1',
        ),
        CounterDecisionNode(
          id: 'counter-1',
          name: 'shared-counter',
          limit: 2,
          continueNodeId: 'counter-2',
          finishedNodeId: 'end',
        ),
        CounterDecisionNode(
          id: 'counter-2',
          name: 'shared-counter',
          limit: 2,
          continueNodeId: 'write-separate',
          finishedNodeId: 'write-shared',
        ),
        WriteFileNode(
          id: 'write-separate',
          name: 'Separate result',
          content: 'separate',
          output: const WorkflowFileReference(
            storage: WorkflowStorage.execution,
            relativePath: 'result.txt',
            format: WorkflowFileFormat.plainText,
          ),
          nextNodeId: 'end',
        ),
        WriteFileNode(
          id: 'write-shared',
          name: 'Shared result',
          content: 'shared',
          output: const WorkflowFileReference(
            storage: WorkflowStorage.execution,
            relativePath: 'result.txt',
            format: WorkflowFileFormat.plainText,
          ),
          nextNodeId: 'end',
        ),
        EndNode(
          id: 'end',
          name: 'End',
        ),
      ],
    );

    await runner.run(workflow);

    final output = File(path.join(roots.execution.path, 'result.txt'));

    expect(await output.readAsString(), 'shared');
  });

  test('a looping Counter Decision gets a new execution ID per visit', () async {
    final workflow = WorkflowDefinition(
      id: 'workflow-1',
      name: 'Counter loop',
      nodes: [
        StartNode(
          id: 'start',
          name: 'Start',
          nextNodeId: 'counter',
        ),
        CounterDecisionNode(
          id: 'counter',
          name: 'loop-counter',
          limit: 3,
          continueNodeId: 'counter',
          finishedNodeId: 'end',
        ),
        EndNode(
          id: 'end',
          name: 'End',
        ),
      ],
    );

    await runner.run(workflow);

    final executionIds = events
        .where((event) => event.nodeId == 'counter')
        .map((event) => event.nodeExecutionId)
        .toSet();

    expect(executionIds, hasLength(3));
  });

  test('wraps node failures with node execution context', () async {
    final workflow = WorkflowDefinition(
      id: 'workflow-1',
      name: 'Missing input',
      nodes: [
        StartNode(
          id: 'start',
          name: 'Start',
          nextNodeId: 'combine',
        ),
        CombineTextNode(
          id: 'combine',
          name: 'Combine missing files',
          inputs: const [
            WorkflowFileReference(
              storage: WorkflowStorage.source,
              relativePath: 'missing-1.md',
              format: WorkflowFileFormat.markdown,
            ),
            WorkflowFileReference(
              storage: WorkflowStorage.source,
              relativePath: 'missing-2.md',
              format: WorkflowFileFormat.markdown,
            ),
          ],
          output: const WorkflowFileReference(
            storage: WorkflowStorage.execution,
            relativePath: 'combined.md',
            format: WorkflowFileFormat.markdown,
          ),
          nextNodeId: 'end',
        ),
        EndNode(
          id: 'end',
          name: 'End',
        ),
      ],
    );

    await expectLater(
      runner.run(workflow),
      throwsA(
        isA<WorkflowExecutionException>()
            .having(
              (exception) => exception.nodeId,
              'nodeId',
              'combine',
            )
            .having(
              (exception) => exception.cause.toString(),
              'cause',
              contains('missing-1.md'),
            ),
      ),
    );
  });
}
