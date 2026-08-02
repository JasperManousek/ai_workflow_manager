import 'dart:io';

import 'package:ai_workflow_manager/screens/workspaces_screen.dart';
import 'package:ai_workflow_manager/storage/application_store.dart';
import 'package:ai_workflow_manager/workflow/editor/workflow_draft.dart';
import 'package:ai_workflow_manager/workflow/files/workflow_file_reference.dart';
import 'package:ai_workflow_manager/workspace/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late ApplicationStore store;
  late Directory temporaryDirectory;
  late Directory sourceDirectory;
  late Directory sharedDirectory;
  late Directory runsDirectory;

  setUp(() async {
    store = await ApplicationStore.openInMemory();
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'workspace-screen-test-',
    );
    sourceDirectory = await Directory(
      path.join(temporaryDirectory.path, 'source'),
    ).create();
    sharedDirectory = await Directory(
      path.join(temporaryDirectory.path, 'shared'),
    ).create();
    runsDirectory = Directory(path.join(temporaryDirectory.path, 'runs'));
  });

  tearDown(() async {
    await store.close();
    await temporaryDirectory.delete(recursive: true);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspacesScreen(
            applicationStore: store,
            runsRoot: runsDirectory,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('creates and selects a workspace with stable persisted paths', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('new-workspace-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('workspace-name-field')),
      'Adatia development',
    );
    await tester.enterText(
      find.byKey(const ValueKey('workspace-source-field')),
      sourceDirectory.path,
    );
    await tester.enterText(
      find.byKey(const ValueKey('workspace-shared-field')),
      sharedDirectory.path,
    );
    await tester.tap(find.byKey(const ValueKey('save-workspace-button')));
    await tester.pumpAndSettle();

    final saved = (await store.listWorkspaces()).single;
    expect(saved.id, startsWith('workspace-'));
    expect(saved.name, 'Adatia development');
    expect(saved.sourceDirectoryPath, sourceDirectory.path);
    expect(saved.sharedDataDirectoryPath, sharedDirectory.path);

    expect(find.text('Adatia development'), findsWidgets);
    expect(
      find.byKey(const ValueKey('workspace-source-path')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('workspace-shared-path')),
      findsOneWidget,
    );
  });

  testWidgets('executes a saved workflow with workspace shared data', (
    tester,
  ) async {
    const workspaceId = 'workspace-test';
    await store.saveWorkspace(
      Workspace(
        id: workspaceId,
        name: 'Test workspace',
        sourceDirectoryPath: sourceDirectory.path,
        sharedDataDirectoryPath: sharedDirectory.path,
      ),
    );
    await store.saveDraft(_workspaceWriteWorkflow());

    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('workspace-$workspaceId')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('workspace-workflow-selector')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Write workspace result · draft only').last);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('run-workspace-workflow-button')),
    );
    await tester.pumpAndSettle();

    expect(
      await File(path.join(sharedDirectory.path, 'result.txt')).readAsString(),
      'workspace result',
    );
    expect(find.text('Write workspace result completed'), findsOneWidget);
    expect(find.text('Workspace files changed'), findsOneWidget);
    expect(find.text('• result.txt'), findsOneWidget);
  });
}

WorkflowDraft _workspaceWriteWorkflow() {
  return WorkflowDraft(
    id: 'workflow-workspace-write',
    name: 'Write workspace result',
    nodes: [
      StartNodeDraft(
        id: 'start',
        name: 'Start',
        position: const WorkflowNodePosition(x: 0, y: 0),
        nextNodeId: 'write',
      ),
      WriteFileNodeDraft(
        id: 'write',
        name: 'Write result',
        position: const WorkflowNodePosition(x: 200, y: 0),
        content: 'workspace result',
        output: WorkflowFileDraft(
          storage: WorkflowStorage.workspace,
          relativePath: 'result.txt',
          format: WorkflowFileFormat.plainText,
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
}
