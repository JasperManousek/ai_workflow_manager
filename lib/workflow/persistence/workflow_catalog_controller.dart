import 'package:flutter/foundation.dart';

import '../editor/workflow_draft.dart';
import 'workflow_draft_codec.dart';
import '../../storage/application_store.dart';

class WorkflowCatalogController extends ChangeNotifier {
  WorkflowCatalogController({required this.store});

  final ApplicationStore store;

  List<SavedWorkflowSummary> workflows = const [];
  String? selectedWorkflowId;
  int? selectedVersionNumber;
  bool isBusy = false;
  String? errorMessage;
  String? _savedDraftSnapshotJson;
  String? _currentVersionSnapshotJson;

  Future<void> refresh() async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();

    try {
      workflows = await store.listWorkflows();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<SavedWorkflowDraft> saveWorkflow(WorkflowDraft draft) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();

    try {
      final savedDraft = await store.saveDraft(draft);
      selectedWorkflowId = draft.id;
      _savedDraftSnapshotJson = savedDraft.snapshotJson;
      workflows = await store.listWorkflows();
      return savedDraft;
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<SavedWorkflowVersion> createVersionForRun(
    WorkflowDraft draft,
  ) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();

    try {
      final version = await store.createVersion(draft);
      selectedWorkflowId = draft.id;
      selectedVersionNumber = version.versionNumber;
      _savedDraftSnapshotJson = version.snapshotJson;
      _currentVersionSnapshotJson = version.snapshotJson;
      workflows = await store.listWorkflows();
      return version;
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<WorkflowDraft> openWorkflow(String workflowId) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();

    try {
      final loaded = await store.loadWorkflow(workflowId);
      selectedWorkflowId = workflowId;
      selectedVersionNumber = loaded.version?.versionNumber;
      _savedDraftSnapshotJson = loaded.draftSnapshotJson;
      _currentVersionSnapshotJson = loaded.version?.snapshotJson;
      return loaded.draft;
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> deleteWorkflow(String workflowId) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();

    try {
      await store.deleteWorkflow(workflowId);
      workflows = await store.listWorkflows();

      if (selectedWorkflowId == workflowId) {
        startNewWorkflow();
      }
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  bool hasUnsavedChanges(WorkflowDraft draft) {
    return _savedDraftSnapshotJson == null ||
        WorkflowDraftCodec.encode(draft) != _savedDraftSnapshotJson;
  }

  bool hasChangesSinceCurrentVersion(WorkflowDraft draft) {
    return _currentVersionSnapshotJson == null ||
        WorkflowDraftCodec.encode(draft) != _currentVersionSnapshotJson;
  }

  void startNewWorkflow() {
    selectedWorkflowId = null;
    selectedVersionNumber = null;
    _savedDraftSnapshotJson = null;
    _currentVersionSnapshotJson = null;
    notifyListeners();
  }
}
