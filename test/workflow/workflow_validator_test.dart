import 'package:ai_workflow_manager/workflow/files/workflow_file_reference.dart';
import 'package:ai_workflow_manager/workflow/model/workflow_definition.dart';
import 'package:ai_workflow_manager/workflow/model/workflow_node.dart';
import 'package:ai_workflow_manager/workflow/workflow_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const firstInput = WorkflowFileReference(
    storage: WorkflowStorage.source,
    relativePath: 'first.md',
    format: WorkflowFileFormat.markdown,
  );

  const secondInput = WorkflowFileReference(
    storage: WorkflowStorage.source,
    relativePath: 'second.txt',
    format: WorkflowFileFormat.plainText,
  );

  const output = WorkflowFileReference(
    storage: WorkflowStorage.working,
    relativePath: 'combined.md',
    format: WorkflowFileFormat.markdown,
  );

  test('accepts the initial supported node types', () {
    final workflow = WorkflowDefinition(
      id: 'workflow-1',
      name: 'Initial workflow',
      nodes: [
        StartNode(
          id: 'start',
          name: 'Start',
          nextNodeId: 'write',
        ),
        WriteFileNode(
          id: 'write',
          name: 'Write introduction',
          content: 'Introduction\n',
          output: const WorkflowFileReference(
            storage: WorkflowStorage.working,
            relativePath: 'introduction.md',
            format: WorkflowFileFormat.markdown,
          ),
          nextNodeId: 'combine',
        ),
        CombineTextNode(
          id: 'combine',
          name: 'Combine documents',
          inputs: const [firstInput, secondInput],
          output: output,
          nextNodeId: 'counter',
        ),
        CounterDecisionNode(
          id: 'counter',
          name: 'review-loop',
          limit: 2,
          continueNodeId: 'combine',
          finishedNodeId: 'end',
        ),
        EndNode(
          id: 'end',
          name: 'End',
        ),
      ],
    );

    expect(
      () => WorkflowValidator.validate(workflow),
      returnsNormally,
    );
  });

  test('allows duplicate node names', () {
    final workflow = WorkflowDefinition(
      id: 'workflow-1',
      name: 'Shared counter names',
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
          continueNodeId: 'counter-1',
          finishedNodeId: 'end',
        ),
        EndNode(
          id: 'end',
          name: 'End',
        ),
      ],
    );

    expect(
      () => WorkflowValidator.validate(workflow),
      returnsNormally,
    );
  });

  test('rejects duplicate node IDs', () {
    final workflow = WorkflowDefinition(
      id: 'workflow-1',
      name: 'Duplicate IDs',
      nodes: [
        StartNode(
          id: 'same-id',
          name: 'Start',
          nextNodeId: 'same-id',
        ),
        EndNode(
          id: 'same-id',
          name: 'End',
        ),
      ],
    );

    expect(
      () => WorkflowValidator.validate(workflow),
      throwsA(
        isA<WorkflowValidationException>().having(
          (exception) => exception.errors,
          'errors',
          contains('Node ID "same-id" is used more than once.'),
        ),
      ),
    );
  });

  test('requires exactly one Start and one End node', () {
    final workflow = WorkflowDefinition(
      id: 'workflow-1',
      name: 'Missing boundaries',
      nodes: const [],
    );

    expect(
      () => WorkflowValidator.validate(workflow),
      throwsA(
        isA<WorkflowValidationException>().having(
          (exception) => exception.errors,
          'errors',
          allOf(
            contains(
              'A workflow must contain exactly one Start node, but found 0.',
            ),
            contains(
              'A workflow must contain exactly one End node, but found 0.',
            ),
          ),
        ),
      ),
    );
  });

  test('rejects missing runtime targets', () {
    final workflow = WorkflowDefinition(
      id: 'workflow-1',
      name: 'Missing target',
      nodes: [
        StartNode(
          id: 'start',
          name: 'Start',
          nextNodeId: 'missing',
        ),
        EndNode(
          id: 'end',
          name: 'End',
        ),
      ],
    );

    expect(
      () => WorkflowValidator.validate(workflow),
      throwsA(
        isA<WorkflowValidationException>().having(
          (exception) => exception.errors.join('\n'),
          'errors',
          contains('connects to missing node ID "missing"'),
        ),
      ),
    );
  });

  test('rejects unreachable nodes', () {
    final workflow = WorkflowDefinition(
      id: 'workflow-1',
      name: 'Unreachable node',
      nodes: [
        StartNode(
          id: 'start',
          name: 'Start',
          nextNodeId: 'end',
        ),
        WriteFileNode(
          id: 'unused',
          name: 'Unused writer',
          content: 'Unused',
          output: output,
          nextNodeId: 'end',
        ),
        EndNode(
          id: 'end',
          name: 'End',
        ),
      ],
    );

    expect(
      () => WorkflowValidator.validate(workflow),
      throwsA(
        isA<WorkflowValidationException>().having(
          (exception) => exception.errors.join('\n'),
          'errors',
          contains('Unused writer'),
        ),
      ),
    );
  });

  test('requires at least two Combine Text inputs', () {
    final workflow = WorkflowDefinition(
      id: 'workflow-1',
      name: 'Invalid combine',
      nodes: [
        StartNode(
          id: 'start',
          name: 'Start',
          nextNodeId: 'combine',
        ),
        CombineTextNode(
          id: 'combine',
          name: 'Combine documents',
          inputs: const [firstInput],
          output: output,
          nextNodeId: 'end',
        ),
        EndNode(
          id: 'end',
          name: 'End',
        ),
      ],
    );

    expect(
      () => WorkflowValidator.validate(workflow),
      throwsA(
        isA<WorkflowValidationException>().having(
          (exception) => exception.errors.join('\n'),
          'errors',
          contains('must have at least two input files'),
        ),
      ),
    );
  });

  test('rejects action output in source storage', () {
    final workflow = WorkflowDefinition(
      id: 'workflow-1',
      name: 'Source write',
      nodes: [
        StartNode(
          id: 'start',
          name: 'Start',
          nextNodeId: 'write',
        ),
        WriteFileNode(
          id: 'write',
          name: 'Write source',
          content: 'Not allowed',
          output: const WorkflowFileReference(
            storage: WorkflowStorage.source,
            relativePath: 'source.md',
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

    expect(
      () => WorkflowValidator.validate(workflow),
      throwsA(
        isA<WorkflowValidationException>().having(
          (exception) => exception.errors.join('\n'),
          'errors',
          contains('read-only source storage'),
        ),
      ),
    );
  });

  test('reserves the internal working directory for the runner', () {
    final workflow = WorkflowDefinition(
      id: 'workflow-1',
      name: 'Internal path collision',
      nodes: [
        StartNode(
          id: 'start',
          name: 'Start',
          nextNodeId: 'write',
        ),
        WriteFileNode(
          id: 'write',
          name: 'Write internal path',
          content: 'Not allowed',
          output: const WorkflowFileReference(
            storage: WorkflowStorage.working,
            relativePath: '.workflow_internal/counters/manual.json',
            format: WorkflowFileFormat.json,
          ),
          nextNodeId: 'end',
        ),
        EndNode(
          id: 'end',
          name: 'End',
        ),
      ],
    );

    expect(
      () => WorkflowValidator.validate(workflow),
      throwsA(
        isA<WorkflowValidationException>().having(
          (exception) => exception.errors.join('\n'),
          'errors',
          contains('reserved working path'),
        ),
      ),
    );
  });
}
