import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'application_data_directory.dart';
import '../workflow/editor/workflow_draft.dart';
import '../workflow/persistence/workflow_draft_codec.dart';
import '../workspace/workspace.dart';

class ApplicationStore {
  ApplicationStore._(this._database);

  static const int _databaseVersion = 2;
  static const String _databaseFileName = 'workflows.sqlite3';

  final Database _database;

  static Future<ApplicationStore> openDefault({
    Directory? applicationDataDirectory,
  }) async {
    sqfliteFfiInit();

    final directory =
        applicationDataDirectory ?? defaultApplicationDataDirectory();
    await directory.create(recursive: true);

    final database = await databaseFactoryFfi.openDatabase(
      path.join(directory.path, _databaseFileName),
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
      ),
    );

    return ApplicationStore._(database);
  }

  static Future<ApplicationStore> openInMemory() async {
    sqfliteFfiInit();

    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
      ),
    );

    return ApplicationStore._(database);
  }

  Future<List<SavedWorkflowSummary>> listWorkflows() async {
    final rows = await _database.rawQuery('''
      SELECT
        workflows.id,
        workflows.name,
        workflows.updated_at,
        workflow_versions.version_number
      FROM workflows
      LEFT JOIN workflow_versions
        ON workflow_versions.id = workflows.current_version_id
      ORDER BY workflows.updated_at DESC, workflows.name COLLATE NOCASE
    ''');

    return rows.map(SavedWorkflowSummary.fromRow).toList(growable: false);
  }

  Future<SavedWorkflowDraft> saveDraft(WorkflowDraft draft) async {
    final snapshotJson = WorkflowDraftCodec.encode(draft);
    final now = DateTime.now().toUtc();

    await _database.transaction((transaction) async {
      await _upsertDraft(
        transaction,
        draft: draft,
        snapshotJson: snapshotJson,
        now: now,
      );
    });

    return SavedWorkflowDraft(
      workflowId: draft.id,
      snapshotJson: snapshotJson,
      updatedAt: now,
    );
  }

  Future<SavedWorkflowVersion> createVersion(WorkflowDraft draft) async {
    final snapshotJson = WorkflowDraftCodec.encode(draft);
    final now = DateTime.now().toUtc();
    final nowText = now.toIso8601String();

    return _database.transaction((transaction) async {
      await _upsertDraft(
        transaction,
        draft: draft,
        snapshotJson: snapshotJson,
        now: now,
      );

      final workflowRows = await transaction.query(
        'workflows',
        columns: ['current_version_id'],
        where: 'id = ?',
        whereArgs: [draft.id],
        limit: 1,
      );
      final currentVersionId =
          workflowRows.single['current_version_id'] as int?;

      if (currentVersionId != null) {
        final currentRows = await transaction.query(
          'workflow_versions',
          columns: ['version_number', 'snapshot_json', 'created_at'],
          where: 'id = ?',
          whereArgs: [currentVersionId],
          limit: 1,
        );

        if (currentRows.isNotEmpty) {
          final row = currentRows.single;
          final currentSnapshotJson = _normalizeWorkflowSnapshot(
            row['snapshot_json'] as String,
          );

          if (currentSnapshotJson == snapshotJson) {
            return SavedWorkflowVersion(
              workflowId: draft.id,
              versionId: currentVersionId,
              versionNumber: row['version_number'] as int,
              snapshotJson: snapshotJson,
              createdAt: DateTime.parse(row['created_at'] as String),
              createdNewVersion: false,
            );
          }
        }
      }

      final versionRows = await transaction.rawQuery(
        '''
        SELECT COALESCE(MAX(version_number), 0) AS max_version
        FROM workflow_versions
        WHERE workflow_id = ?
        ''',
        [draft.id],
      );
      final versionNumber = (versionRows.single['max_version'] as int) + 1;
      final versionId = await transaction.insert('workflow_versions', {
        'workflow_id': draft.id,
        'version_number': versionNumber,
        'snapshot_json': snapshotJson,
        'created_at': nowText,
      });

      await transaction.update(
        'workflows',
        {
          'current_version_id': versionId,
          'updated_at': nowText,
        },
        where: 'id = ?',
        whereArgs: [draft.id],
      );

      return SavedWorkflowVersion(
        workflowId: draft.id,
        versionId: versionId,
        versionNumber: versionNumber,
        snapshotJson: snapshotJson,
        createdAt: now,
        createdNewVersion: true,
      );
    });
  }

  Future<LoadedWorkflow> loadWorkflow(String workflowId) async {
    final rows = await _database.rawQuery(
      '''
      SELECT
        workflows.draft_json,
        workflow_versions.id AS version_id,
        workflow_versions.version_number,
        workflow_versions.snapshot_json,
        workflow_versions.created_at AS version_created_at
      FROM workflows
      LEFT JOIN workflow_versions
        ON workflow_versions.id = workflows.current_version_id
      WHERE workflows.id = ?
      LIMIT 1
      ''',
      [workflowId],
    );

    if (rows.isEmpty) {
      throw WorkflowNotFoundException(workflowId);
    }

    final row = rows.single;
    final draftSnapshotJson = _normalizeWorkflowSnapshot(
      row['draft_json'] as String,
    );
    final versionId = row['version_id'] as int?;

    SavedWorkflowVersion? version;
    if (versionId != null) {
      final versionSnapshotJson = _normalizeWorkflowSnapshot(
        row['snapshot_json'] as String,
      );
      version = SavedWorkflowVersion(
        workflowId: workflowId,
        versionId: versionId,
        versionNumber: row['version_number'] as int,
        snapshotJson: versionSnapshotJson,
        createdAt: DateTime.parse(row['version_created_at'] as String),
        createdNewVersion: false,
      );
    }

    return LoadedWorkflow(
      draft: WorkflowDraftCodec.decode(draftSnapshotJson),
      draftSnapshotJson: draftSnapshotJson,
      version: version,
    );
  }

  Future<void> deleteWorkflow(String workflowId) async {
    final deleted = await _database.delete(
      'workflows',
      where: 'id = ?',
      whereArgs: [workflowId],
    );

    if (deleted == 0) {
      throw WorkflowNotFoundException(workflowId);
    }
  }

  Future<List<SavedWorkspaceSummary>> listWorkspaces() async {
    final rows = await _database.query(
      'workspaces',
      orderBy: 'updated_at DESC, name COLLATE NOCASE',
    );

    return rows.map(SavedWorkspaceSummary.fromRow).toList(growable: false);
  }

  Future<Workspace> saveWorkspace(Workspace workspace) async {
    final errors = validateWorkspace(workspace);
    if (errors.isNotEmpty) {
      throw InvalidWorkspaceException(errors);
    }

    final nowText = DateTime.now().toUtc().toIso8601String();
    final existing = await _database.query(
      'workspaces',
      columns: ['created_at'],
      where: 'id = ?',
      whereArgs: [workspace.id],
      limit: 1,
    );

    final values = {
      'id': workspace.id,
      'name': workspace.name,
      'source_directory': workspace.sourceDirectoryPath,
      'shared_data_directory': workspace.sharedDataDirectoryPath,
      'created_at': existing.isEmpty
          ? nowText
          : existing.single['created_at'] as String,
      'updated_at': nowText,
    };

    if (existing.isEmpty) {
      await _database.insert('workspaces', values);
    } else {
      await _database.update(
        'workspaces',
        values,
        where: 'id = ?',
        whereArgs: [workspace.id],
      );
    }

    return workspace;
  }

  Future<Workspace> loadWorkspace(String workspaceId) async {
    final rows = await _database.query(
      'workspaces',
      where: 'id = ?',
      whereArgs: [workspaceId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw WorkspaceNotFoundException(workspaceId);
    }

    return _workspaceFromRow(rows.single);
  }

  Future<void> deleteWorkspace(String workspaceId) async {
    final deleted = await _database.delete(
      'workspaces',
      where: 'id = ?',
      whereArgs: [workspaceId],
    );

    if (deleted == 0) {
      throw WorkspaceNotFoundException(workspaceId);
    }
  }

  Future<void> close() => _database.close();

  static String _normalizeWorkflowSnapshot(String snapshotJson) {
    try {
      return WorkflowDraftCodec.encode(
        WorkflowDraftCodec.decode(snapshotJson),
      );
    } on FormatException {
      return snapshotJson;
    }
  }

  static Future<void> _upsertDraft(
    Transaction transaction, {
    required WorkflowDraft draft,
    required String snapshotJson,
    required DateTime now,
  }) async {
    final nowText = now.toIso8601String();
    final rows = await transaction.query(
      'workflows',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [draft.id],
      limit: 1,
    );

    if (rows.isEmpty) {
      await transaction.insert('workflows', {
        'id': draft.id,
        'name': draft.name,
        'draft_json': snapshotJson,
        'current_version_id': null,
        'created_at': nowText,
        'updated_at': nowText,
      });
      return;
    }

    await transaction.update(
      'workflows',
      {
        'name': draft.name,
        'draft_json': snapshotJson,
        'updated_at': nowText,
      },
      where: 'id = ?',
      whereArgs: [draft.id],
    );
  }

  static Future<void> _createSchema(Database database, int version) async {
    await _createWorkflowSchema(database);
    await _createWorkspaceSchema(database);
  }

  static Future<void> _upgradeSchema(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createWorkspaceSchema(database);
    }
  }

  static Future<void> _createWorkflowSchema(Database database) async {
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
        FOREIGN KEY (workflow_id) REFERENCES workflows(id) ON DELETE CASCADE,
        UNIQUE (workflow_id, version_number)
      )
    ''');

    await database.execute('''
      CREATE INDEX workflow_versions_workflow_id_index
      ON workflow_versions(workflow_id)
    ''');
  }

  static Future<void> _createWorkspaceSchema(Database database) async {
    await database.execute('''
      CREATE TABLE workspaces (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        source_directory TEXT NOT NULL,
        shared_data_directory TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  static Workspace _workspaceFromRow(Map<String, Object?> row) {
    return Workspace(
      id: row['id'] as String,
      name: row['name'] as String,
      sourceDirectoryPath: row['source_directory'] as String,
      sharedDataDirectoryPath: row['shared_data_directory'] as String,
    );
  }
}

class SavedWorkflowSummary {
  const SavedWorkflowSummary({
    required this.id,
    required this.name,
    required this.currentVersionNumber,
    required this.updatedAt,
  });

  factory SavedWorkflowSummary.fromRow(Map<String, Object?> row) {
    return SavedWorkflowSummary(
      id: row['id'] as String,
      name: row['name'] as String,
      currentVersionNumber: row['version_number'] as int?,
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  final String id;
  final String name;
  final int? currentVersionNumber;
  final DateTime updatedAt;
}

class SavedWorkflowDraft {
  const SavedWorkflowDraft({
    required this.workflowId,
    required this.snapshotJson,
    required this.updatedAt,
  });

  final String workflowId;
  final String snapshotJson;
  final DateTime updatedAt;
}

class SavedWorkflowVersion {
  const SavedWorkflowVersion({
    required this.workflowId,
    required this.versionId,
    required this.versionNumber,
    required this.snapshotJson,
    required this.createdAt,
    required this.createdNewVersion,
  });

  final String workflowId;
  final int versionId;
  final int versionNumber;
  final String snapshotJson;
  final DateTime createdAt;
  final bool createdNewVersion;
}

class LoadedWorkflow {
  const LoadedWorkflow({
    required this.draft,
    required this.draftSnapshotJson,
    required this.version,
  });

  final WorkflowDraft draft;
  final String draftSnapshotJson;
  final SavedWorkflowVersion? version;
}

class WorkflowNotFoundException implements Exception {
  const WorkflowNotFoundException(this.workflowId);

  final String workflowId;

  @override
  String toString() => 'Workflow "$workflowId" was not found.';
}

class SavedWorkspaceSummary {
  const SavedWorkspaceSummary({
    required this.id,
    required this.name,
    required this.sourceDirectoryPath,
    required this.sharedDataDirectoryPath,
    required this.updatedAt,
  });

  factory SavedWorkspaceSummary.fromRow(Map<String, Object?> row) {
    return SavedWorkspaceSummary(
      id: row['id'] as String,
      name: row['name'] as String,
      sourceDirectoryPath: row['source_directory'] as String,
      sharedDataDirectoryPath: row['shared_data_directory'] as String,
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  final String id;
  final String name;
  final String sourceDirectoryPath;
  final String sharedDataDirectoryPath;
  final DateTime updatedAt;
}

class WorkspaceNotFoundException implements Exception {
  const WorkspaceNotFoundException(this.workspaceId);

  final String workspaceId;

  @override
  String toString() => 'Workspace "$workspaceId" was not found.';
}
