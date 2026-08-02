import 'package:flutter/foundation.dart';

import '../storage/application_store.dart';
import 'workspace.dart';

class WorkspaceCatalogController extends ChangeNotifier {
  WorkspaceCatalogController({required this.store});

  final ApplicationStore store;

  List<SavedWorkspaceSummary> workspaces = const [];
  Workspace? selectedWorkspace;
  bool isBusy = false;
  String? errorMessage;

  Future<void> refresh() async {
    await _perform(() async {
      workspaces = await store.listWorkspaces();

      final selectedId = selectedWorkspace?.id;
      if (selectedId != null &&
          !workspaces.any((workspace) => workspace.id == selectedId)) {
        selectedWorkspace = null;
      }
    });
  }

  Future<void> selectWorkspace(String workspaceId) async {
    await _perform(() async {
      selectedWorkspace = await store.loadWorkspace(workspaceId);
    });
  }

  Future<void> saveWorkspace(Workspace workspace) async {
    await _perform(() async {
      selectedWorkspace = await store.saveWorkspace(workspace);
      workspaces = await store.listWorkspaces();
    });
  }

  Future<void> deleteWorkspace(String workspaceId) async {
    await _perform(() async {
      await store.deleteWorkspace(workspaceId);
      workspaces = await store.listWorkspaces();

      if (selectedWorkspace?.id == workspaceId) {
        selectedWorkspace = null;
      }
    });
  }

  Future<void> _perform(Future<void> Function() action) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();

    try {
      await action();
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
