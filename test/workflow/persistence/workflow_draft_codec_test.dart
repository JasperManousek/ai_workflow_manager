import 'dart:convert';

import 'package:ai_workflow_manager/workflow/editor/workflow_draft.dart';
import 'package:ai_workflow_manager/workflow/files/workflow_file_reference.dart';
import 'package:ai_workflow_manager/workflow/persistence/workflow_draft_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads legacy working and persistent storage names', () {
    final snapshot = jsonEncode({
      'schemaVersion': 1,
      'id': 'legacy-workflow',
      'name': 'Legacy workflow',
      'nodes': [
        {
          'id': 'start',
          'name': 'Start',
          'position': {'x': 0, 'y': 0},
          'type': 'start',
          'nextNodeId': 'write',
        },
        {
          'id': 'write',
          'name': 'Write shared result',
          'position': {'x': 200, 'y': 0},
          'type': 'writeFile',
          'content': 'content',
          'output': {
            'storage': 'persistent',
            'relativePath': 'result.md',
            'format': 'markdown',
          },
          'nextNodeId': 'end',
        },
        {
          'id': 'combine',
          'name': 'Combine',
          'position': {'x': 400, 'y': 0},
          'type': 'combineText',
          'inputs': [
            {
              'storage': 'working',
              'relativePath': 'temporary.md',
              'format': 'markdown',
            },
            {
              'storage': 'persistent',
              'relativePath': 'shared.md',
              'format': 'markdown',
            },
          ],
          'output': {
            'storage': 'working',
            'relativePath': 'combined.md',
            'format': 'markdown',
          },
          'nextNodeId': 'end',
        },
        {
          'id': 'end',
          'name': 'End',
          'position': {'x': 600, 'y': 0},
          'type': 'end',
        },
      ],
    });

    final draft = WorkflowDraftCodec.decode(snapshot);
    final write = draft.nodes.whereType<WriteFileNodeDraft>().single;
    final combine = draft.nodes.whereType<CombineTextNodeDraft>().single;

    expect(write.output.storage, WorkflowStorage.workspace);
    expect(combine.inputs[0].storage, WorkflowStorage.execution);
    expect(combine.inputs[1].storage, WorkflowStorage.workspace);
    expect(combine.output.storage, WorkflowStorage.execution);
  });

  test('encodes the current workspace and execution storage names', () {
    final draft = WorkflowDraft(
      id: 'workflow',
      name: 'Workflow',
      nodes: [
        StartNodeDraft(
          id: 'start',
          name: 'Start',
          position: const WorkflowNodePosition(x: 0, y: 0),
          nextNodeId: 'write',
        ),
        WriteFileNodeDraft(
          id: 'write',
          name: 'Write',
          position: const WorkflowNodePosition(x: 200, y: 0),
          content: 'content',
          output: WorkflowFileDraft(
            storage: WorkflowStorage.workspace,
            relativePath: 'result.md',
            format: WorkflowFileFormat.markdown,
          ),
          nextNodeId: 'end',
        ),
        EndNodeDraft(
          id: 'end',
          name: 'End',
          position: const WorkflowNodePosition(x: 400, y: 0),
        ),
      ],
    );

    final encoded = WorkflowDraftCodec.encode(draft);

    expect(encoded, contains('"storage":"workspace"'));
    expect(encoded, isNot(contains('"storage":"persistent"')));
  });
}
