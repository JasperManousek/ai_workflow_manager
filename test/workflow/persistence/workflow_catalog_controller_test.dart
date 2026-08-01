import 'package:ai_workflow_manager/workflow/editor/workflow_editor_controller.dart';
import 'package:ai_workflow_manager/workflow/persistence/workflow_catalog_controller.dart';
import 'package:ai_workflow_manager/workflow/persistence/workflow_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late WorkflowStore store;
  late WorkflowCatalogController catalog;
  late WorkflowEditorController editor;

  setUp(() async {
    store = await WorkflowStore.openInMemory();
    catalog = WorkflowCatalogController(store: store);
    editor = WorkflowEditorController();
  });

  tearDown(() async {
    catalog.dispose();
    editor.dispose();
    await store.close();
  });

  test('saving a draft does not create an execution version', () async {
    await catalog.saveWorkflow(editor.draft);

    expect(catalog.hasUnsavedChanges(editor.draft), isFalse);
    expect(catalog.hasChangesSinceCurrentVersion(editor.draft), isTrue);
    expect(catalog.selectedVersionNumber, isNull);
    expect(catalog.workflows.single.currentVersionNumber, isNull);
  });

  test('creating a run version marks the saved draft as versioned', () async {
    final version = await catalog.createVersionForRun(editor.draft);

    expect(version.versionNumber, 1);
    expect(catalog.hasUnsavedChanges(editor.draft), isFalse);
    expect(catalog.hasChangesSinceCurrentVersion(editor.draft), isFalse);
    expect(catalog.selectedVersionNumber, 1);
  });
}
