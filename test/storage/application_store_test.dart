import 'dart:io';

import 'package:ai_workflow_manager/workflow/editor/workflow_draft.dart';
import 'package:ai_workflow_manager/workflow/files/workflow_file_reference.dart';
import 'package:ai_workflow_manager/workflow/persistence/workflow_draft_codec.dart';
import 'package:ai_workflow_manager/storage/application_store.dart';
import 'package:ai_workflow_manager/workspace/workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late ApplicationStore store;
  Directory? migrationDirectory;

  setUp(() async {
    store = await ApplicationStore.openInMemory();
  });

  tearDown(() async {
    await store.close();
    final directory = migrationDirectory;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
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

  test('saves, reloads, and updates a workspace without changing its ID', () async {
    const workspace = Workspace(
      id: 'workspace-1',
      name: 'Adatia',
      sourceDirectoryPath: '/projects/adatia/source',
      sharedDataDirectoryPath: '/projects/adatia/shared',
    );

    await store.saveWorkspace(workspace);
    final loaded = await store.loadWorkspace(workspace.id);
    final updated = workspace.copyWith(name: 'Adatia development');
    await store.saveWorkspace(updated);
    final summaries = await store.listWorkspaces();

    expect(loaded.id, workspace.id);
    expect(loaded.name, 'Adatia');
    expect(summaries, hasLength(1));
    expect(summaries.single.id, workspace.id);
    expect(summaries.single.name, 'Adatia development');
  });

  test('deleting a workspace only removes the database record', () async {
    const workspace = Workspace(
      id: 'workspace-1',
      name: 'Adatia',
      sourceDirectoryPath: '/projects/adatia/source',
      sharedDataDirectoryPath: '/projects/adatia/shared',
    );
    await store.saveWorkspace(workspace);

    await store.deleteWorkspace(workspace.id);

    expect(await store.listWorkspaces(), isEmpty);
    await expectLater(
      store.loadWorkspace(workspace.id),
      throwsA(isA<WorkspaceNotFoundException>()),
    );
  });

  test('rejects a workspace that uses the same directory twice', () async {
    const workspace = Workspace(
      id: 'workspace-1',
      name: 'Invalid',
      sourceDirectoryPath: '/projects/adatia',
      sharedDataDirectoryPath: '/projects/adatia',
    );

    await expectLater(
      store.saveWorkspace(workspace),
      throwsA(isA<InvalidWorkspaceException>()),
    );
  });

  test('upgrades an existing workflow database with workspace storage', () async {
    await store.close();
    final directory = await Directory.systemTemp.createTemp(
      'application-store-upgrade-',
    );
    migrationDirectory = directory;

    sqfliteFfiInit();
    final database = await databaseFactoryFfi.openDatabase(
      path.join(directory.path, 'workflows.sqlite3'),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE workflows (
              id TEXT PRIMARY KEY NOT NULL,
              name TEXT NOT NULL,
              draft_json TEXT NOT NULL,
              current_version_id INTEGER,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await database.execute('''
            CREATE TABLE workflow_versions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              workflow_id TEXT NOT NULL,
              version_number INTEGER NOT NULL,
              snapshot_json TEXT NOT NULL,
              created_at TEXT NOT NULL,
              FOREIGN KEY (workflow_id)
                REFERENCES workflows(id) ON DELETE CASCADE,
              UNIQUE (workflow_id, version_number)
            )
          ''');
          await database.execute('''
            CREATE INDEX workflow_versions_workflow_id_index
            ON workflow_versions(workflow_id)
          ''');
        },
      ),
    );

    final now = DateTime.now().toUtc().toIso8601String();
    final legacySnapshot = WorkflowDraftCodec.encode(
      _completeDraft(),
    ).replaceAll('"execution"', '"working"');
    await database.insert('workflows', {
      'id': 'workflow-1',
      'name': 'Stored workflow',
      'draft_json': legacySnapshot,
      'current_version_id': null,
      'created_at': now,
      'updated_at': now,
    });
    final versionId = await database.insert('workflow_versions', {
      'workflow_id': 'workflow-1',
      'version_number': 1,
      'snapshot_json': legacySnapshot,
      'created_at': now,
    });
    await database.update(
      'workflows',
      {'current_version_id': versionId},
      where: 'id = ?',
      whereArgs: ['workflow-1'],
    );
    await database.close();

    store = await ApplicationStore.openDefault(
      applicationDataDirectory: directory,
    );

    final loaded = await store.loadWorkflow('workflow-1');
    final reusedVersion = await store.createVersion(loaded.draft);

    expect(await store.listWorkflows(), hasLength(1));
    expect(await store.listWorkspaces(), isEmpty);
    expect(loaded.draftSnapshotJson, contains('"storage":"execution"'));
    expect(loaded.version?.snapshotJson, contains('"storage":"execution"'));
    expect(reusedVersion.versionNumber, 1);
    expect(reusedVersion.createdNewVersion, isFalse);
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
          storage: WorkflowStorage.execution,
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
            storage: WorkflowStorage.execution,
            relativePath: 'prompt.md',
            format: WorkflowFileFormat.markdown,
          ),
        ],
        output: WorkflowFileDraft(
          storage: WorkflowStorage.execution,
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
