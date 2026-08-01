import 'package:ai_workflow_manager/workflow/editor/workflow_draft.dart';
import 'package:ai_workflow_manager/workflow/files/workflow_file_reference.dart';
import 'package:ai_workflow_manager/workflow/persistence/workflow_draft_codec.dart';
import 'package:ai_workflow_manager/workflow/persistence/workflow_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late WorkflowStore store;

  setUp(() async {
    store = await WorkflowStore.openInMemory();
  });

  tearDown(() async {
    await store.close();
  });

  test('saves and reloads the complete editable workflow draft', () async {
    final draft = _completeDraft();

    final saved = await store.saveDraft(draft);
    final loaded = await store.loadWorkflow(draft.id);

    expect(saved.workflowId, draft.id);
    expect(
      WorkflowDraftCodec.encode(loaded.draft),
      WorkflowDraftCodec.encode(draft),
    );
    expect(loaded.version, isNull);
  });

  test('reuses the current run version when the snapshot is unchanged', () async {
    final draft = _completeDraft();

    final first = await store.createVersion(draft);
    final second = await store.createVersion(draft);

    expect(first.versionNumber, 1);
    expect(first.createdNewVersion, isTrue);
    expect(second.versionNumber, 1);
    expect(second.createdNewVersion, isFalse);
  });

  test('creates the next immutable run version after a change', () async {
    final draft = _completeDraft();

    await store.createVersion(draft);
    draft.name = 'Renamed workflow';
    await store.saveDraft(draft);
    final second = await store.createVersion(draft);
    final summaries = await store.listWorkflows();

    expect(second.versionNumber, 2);
    expect(second.createdNewVersion, isTrue);
    expect(summaries, hasLength(1));
    expect(summaries.single.name, 'Renamed workflow');
    expect(summaries.single.currentVersionNumber, 2);
  });

  test('deleting a workflow removes it from the catalog', () async {
    final draft = _completeDraft();
    await store.saveDraft(draft);

    await store.deleteWorkflow(draft.id);

    expect(await store.listWorkflows(), isEmpty);
    await expectLater(
      store.loadWorkflow(draft.id),
      throwsA(isA<WorkflowNotFoundException>()),
    );
  });
}

WorkflowDraft _completeDraft() {
  return WorkflowDraft(
    id: 'workflow-1',
    name: 'Stored workflow',
    nodes: [
      StartNodeDraft(
        id: 'start',
        name: 'Start',
        position: const WorkflowNodePosition(x: 10, y: 20),
        nextNodeId: 'node-1',
      ),
      WriteFileNodeDraft(
        id: 'node-1',
        name: 'Write prompt',
        position: const WorkflowNodePosition(x: 120, y: 20),
        content: 'Hello',
        output: WorkflowFileDraft(
          storage: WorkflowStorage.working,
          relativePath: 'prompt.md',
          format: WorkflowFileFormat.markdown,
        ),
        nextNodeId: 'node-2',
      ),
      CombineTextNodeDraft(
        id: 'node-2',
        name: 'Combine',
        position: const WorkflowNodePosition(x: 360, y: 20),
        inputs: [
          WorkflowFileDraft(
            storage: WorkflowStorage.source,
            relativePath: 'source.txt',
            format: WorkflowFileFormat.plainText,
          ),
          WorkflowFileDraft(
            storage: WorkflowStorage.working,
            relativePath: 'prompt.md',
            format: WorkflowFileFormat.markdown,
          ),
        ],
        output: WorkflowFileDraft(
          storage: WorkflowStorage.working,
          relativePath: 'combined.md',
          format: WorkflowFileFormat.markdown,
        ),
        nextNodeId: 'node-3',
      ),
      CounterDecisionNodeDraft(
        id: 'node-3',
        name: 'loop',
        position: const WorkflowNodePosition(x: 600, y: 20),
        limit: 4,
        continueNodeId: 'node-2',
        finishedNodeId: 'end',
      ),
      EndNodeDraft(
        id: 'end',
        name: 'End',
        position: const WorkflowNodePosition(x: 840, y: 20),
      ),
    ],
  );
}
