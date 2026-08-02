import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../storage/application_store.dart';
import '../workflow/persistence/workflow_catalog_controller.dart';
import '../workflow/run/workflow_run_controller.dart';
import '../workspace/workspace.dart';
import '../workspace/workspace_catalog_controller.dart';

class WorkspacesScreen extends StatefulWidget {
  const WorkspacesScreen({
    required this.applicationStore,
    this.runsRoot,
    super.key,
  });

  final ApplicationStore applicationStore;
  final Directory? runsRoot;

  @override
  State<WorkspacesScreen> createState() => _WorkspacesScreenState();
}

class _WorkspacesScreenState extends State<WorkspacesScreen> {
  late final WorkspaceCatalogController _workspaceController;
  late final WorkflowCatalogController _workflowController;
  late final WorkflowRunController _runController;
  late final Listenable _screenListenable;

  String? _selectedWorkflowId;

  bool get _isBusy =>
      _workspaceController.isBusy || _workflowController.isBusy;

  @override
  void initState() {
    super.initState();
    _workspaceController = WorkspaceCatalogController(
      store: widget.applicationStore,
    );
    _workflowController = WorkflowCatalogController(
      store: widget.applicationStore,
    );
    _runController = WorkflowRunController(runsRoot: widget.runsRoot);
    _screenListenable = Listenable.merge([
      _workspaceController,
      _workflowController,
      _runController,
    ]);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _workspaceController.dispose();
    _workflowController.dispose();
    _runController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _screenListenable,
      builder: (context, child) {
        return Column(
          children: [
            _buildToolbar(),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 320,
                    child: _buildWorkspaceList(),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: _buildWorkspaceDetails()),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          FilledButton.icon(
            key: const ValueKey('new-workspace-button'),
            onPressed: _isBusy || _runController.isActive
                ? null
                : () => unawaited(_createWorkspace()),
            icon: const Icon(Icons.add),
            label: const Text('New workspace'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refresh workspaces and workflows',
            onPressed: _isBusy || _runController.isActive
                ? null
                : () => unawaited(_refresh()),
            icon: const Icon(Icons.refresh),
          ),
          const Spacer(),
          if (_isBusy || _runController.isActive)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceList() {
    if (_workspaceController.workspaces.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No workspaces yet.\n\nA workspace remembers a source directory '
            'and a shared data directory.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _workspaceController.workspaces.length,
      itemBuilder: (context, index) {
        final workspace = _workspaceController.workspaces[index];
        final selected =
            _workspaceController.selectedWorkspace?.id == workspace.id;

        return ListTile(
          key: ValueKey('workspace-${workspace.id}'),
          selected: selected,
          leading: const Icon(Icons.workspaces_outline),
          title: Text(workspace.name),
          subtitle: Text(
            workspace.sourceDirectoryPath,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: _isBusy || _runController.isActive
              ? null
              : () => unawaited(_selectWorkspace(workspace.id)),
        );
      },
    );
  }

  Widget _buildWorkspaceDetails() {
    final workspace = _workspaceController.selectedWorkspace;
    if (workspace == null) {
      return const Center(
        child: Text('Select a workspace to view it and execute workflows.'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      workspace.name,
                      key: const ValueKey('workspace-detail-name'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isBusy || _runController.isActive
                        ? null
                        : () => unawaited(_editWorkspace(workspace)),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _isBusy || _runController.isActive
                        ? null
                        : () => unawaited(_deleteWorkspace(workspace)),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(
                workspace.id,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 28),
              _DirectoryDetail(
                label: 'Source directory',
                description: 'Read-only material available to every workflow '
                    'execution in this workspace.',
                path: workspace.sourceDirectoryPath,
                valueKey: const ValueKey('workspace-source-path'),
              ),
              const SizedBox(height: 24),
              _DirectoryDetail(
                label: 'Shared data directory',
                description: 'Durable writable data shared by workflows '
                    'executed in this workspace.',
                path: workspace.sharedDataDirectoryPath,
                valueKey: const ValueKey('workspace-shared-path'),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 24),
              _buildWorkflowExecutionSection(workspace),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkflowExecutionSection(Workspace workspace) {
    final selectedWorkflowId = _validSelectedWorkflowId();
    final workflows = _workflowController.workflows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Execute a workflow',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'The selected workflow reads from the source directory, can read '
          'and write shared workspace data, and receives a fresh isolated '
          'execution directory.',
        ),
        const SizedBox(height: 20),
        if (workflows.isEmpty)
          const Text(
            'No saved workflows are available. Create and save one in the '
            'Workflows tab first.',
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('workspace-workflow-selector'),
                  value: selectedWorkflowId,
                  decoration: const InputDecoration(
                    labelText: 'Workflow',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final workflow in workflows)
                      DropdownMenuItem(
                        value: workflow.id,
                        child: Text(
                          workflow.currentVersionNumber == null
                              ? '${workflow.name} · draft only'
                              : '${workflow.name} · version '
                                  '${workflow.currentVersionNumber}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _isBusy || _runController.isActive
                      ? null
                      : (value) {
                          setState(() {
                            _selectedWorkflowId = value;
                          });
                        },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                key: const ValueKey('run-workspace-workflow-button'),
                onPressed: selectedWorkflowId == null ||
                        _isBusy ||
                        _runController.isActive
                    ? null
                    : () => unawaited(
                        _runSelectedWorkflow(workspace, selectedWorkflowId),
                      ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run'),
              ),
            ],
          ),
        const SizedBox(height: 24),
        _buildExecutionStatus(),
      ],
    );
  }

  Widget _buildExecutionStatus() {
    if (_runController.status == WorkflowRunStatus.idle) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('No workflow execution started in this workspace.'),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    late final IconData icon;
    late final String title;
    late final Color color;

    switch (_runController.status) {
      case WorkflowRunStatus.idle:
        icon = Icons.info_outline;
        title = 'Idle';
        color = colorScheme.outline;
        break;
      case WorkflowRunStatus.preparing:
        icon = Icons.hourglass_top;
        title = 'Preparing execution';
        color = colorScheme.primary;
        break;
      case WorkflowRunStatus.running:
        icon = Icons.play_circle_outline;
        title = 'Running ${_runController.workflowName ?? 'workflow'}';
        color = colorScheme.primary;
        break;
      case WorkflowRunStatus.completed:
        icon = Icons.check_circle_outline;
        title = '${_runController.workflowName ?? 'Workflow'} completed';
        color = colorScheme.primary;
        break;
      case WorkflowRunStatus.failed:
        icon = Icons.error_outline;
        title = '${_runController.workflowName ?? 'Workflow'} failed';
        color = colorScheme.error;
        break;
    }

    final version = _runController.workflowVersionNumber;
    final changedFiles = _runController.workspaceFilesChanged;

    return Container(
      key: const ValueKey('workspace-execution-status'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        border: Border.all(color: color.withAlpha(90)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                  ),
                ),
                if (version != null) ...[
                  const SizedBox(height: 4),
                  Text('Workflow version $version'),
                ],
                if (_runController.activeNodeName != null) ...[
                  const SizedBox(height: 4),
                  Text('Current node: ${_runController.activeNodeName}'),
                ],
                if (_runController.latestActivity != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _runController.latestActivity!,
                    key: const ValueKey('workspace-latest-activity'),
                  ),
                ],
                if (_runController.runDirectory != null) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    'Execution folder: '
                    '${_runController.runDirectory!.path}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (changedFiles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Workspace files changed',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  for (final file in changedFiles) Text('• $file'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _validSelectedWorkflowId() {
    final selected = _selectedWorkflowId;
    if (selected == null) {
      return null;
    }

    return _workflowController.workflows.any(
      (workflow) => workflow.id == selected,
    )
        ? selected
        : null;
  }

  Future<void> _refresh() async {
    try {
      await Future.wait([
        _workspaceController.refresh(),
        _workflowController.refresh(),
      ]);

      if (mounted && _validSelectedWorkflowId() == null) {
        setState(() {
          _selectedWorkflowId = null;
        });
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _selectWorkspace(String workspaceId) async {
    if (_runController.isActive) {
      return;
    }

    try {
      await _workspaceController.selectWorkspace(workspaceId);
      _runController.clear();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _runSelectedWorkflow(
    Workspace workspace,
    String workflowId,
  ) async {
    try {
      final draft = await _workflowController.openWorkflow(workflowId);
      final result = draft.buildDefinition();

      if (!result.isValid) {
        await _showWorkflowErrors(result.errors);
        return;
      }

      final version = await _workflowController.createVersionForRun(draft);

      await _runController.run(
        workflow: result.definition!,
        sourceDirectory: Directory(workspace.sourceDirectoryPath),
        workspaceDirectory: Directory(workspace.sharedDataDirectoryPath),
        workflowVersionNumber: version.versionNumber,
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _showWorkflowErrors(List<String> errors) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Workflow cannot be executed'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: SelectableText(errors.map((error) => '• $error').join('\n')),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createWorkspace() async {
    final workspace = await _showWorkspaceDialog();
    if (workspace == null) {
      return;
    }

    await _saveWorkspace(workspace);
  }

  Future<void> _editWorkspace(Workspace workspace) async {
    final updated = await _showWorkspaceDialog(existing: workspace);
    if (updated == null) {
      return;
    }

    await _saveWorkspace(updated);
  }

  Future<void> _saveWorkspace(Workspace workspace) async {
    final previousWorkspaceId = _workspaceController.selectedWorkspace?.id;

    try {
      await _workspaceController.saveWorkspace(workspace);

      if (previousWorkspaceId != workspace.id) {
        _runController.clear();
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteWorkspace(Workspace workspace) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete workspace?'),
          content: Text(
            'Delete "${workspace.name}" from the application?\n\n'
            'The source and shared data directories will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _workspaceController.deleteWorkspace(workspace.id);
      _runController.clear();
    } catch (error) {
      _showError(error);
    }
  }

  Future<Workspace?> _showWorkspaceDialog({Workspace? existing}) async {
    final workspaceId = existing?.id ?? createWorkspaceId();
    final nameController = TextEditingController(text: existing?.name ?? '');
    final sourceController = TextEditingController(
      text: existing?.sourceDirectoryPath ?? '',
    );
    final sharedController = TextEditingController(
      text: existing?.sharedDataDirectoryPath ?? '',
    );

    try {
      return await showDialog<Workspace>(
        context: context,
        builder: (dialogContext) {
          String? validationMessage;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> chooseDirectory(
                TextEditingController controller,
                String buttonText,
              ) async {
                final selectedPath = await getDirectoryPath(
                  initialDirectory:
                      controller.text.isEmpty ? null : controller.text,
                  confirmButtonText: buttonText,
                  canCreateDirectories: true,
                );

                if (selectedPath != null && dialogContext.mounted) {
                  setDialogState(() {
                    controller.text = selectedPath;
                    validationMessage = null;
                  });
                }
              }

              Future<void> submit() async {
                final name = nameController.text.trim();
                final sourcePath = sourceController.text.trim();
                final sharedPath = sharedController.text.trim();
                final workspace = existing == null
                    ? Workspace(
                        id: workspaceId,
                        name: name,
                        sourceDirectoryPath: sourcePath,
                        sharedDataDirectoryPath: sharedPath,
                      )
                    : existing.copyWith(
                        name: name,
                        sourceDirectoryPath: sourcePath,
                        sharedDataDirectoryPath: sharedPath,
                      );
                final errors = validateWorkspace(workspace);

                if (errors.isEmpty &&
                    !await Directory(workspace.sourceDirectoryPath).exists()) {
                  errors.add('The source directory does not exist.');
                }
                if (errors.isEmpty &&
                    !await Directory(
                      workspace.sharedDataDirectoryPath,
                    ).exists()) {
                  errors.add('The shared data directory does not exist.');
                }

                if (errors.isNotEmpty) {
                  setDialogState(() {
                    validationMessage = errors.join('\n');
                  });
                  return;
                }

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(workspace);
                }
              }

              return AlertDialog(
                title: Text(
                  existing == null ? 'New workspace' : 'Edit workspace',
                ),
                content: SizedBox(
                  width: 680,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          key: const ValueKey('workspace-name-field'),
                          controller: nameController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            hintText: 'Adatia development',
                          ),
                        ),
                        const SizedBox(height: 20),
                        _DirectoryField(
                          fieldKey: const ValueKey(
                            'workspace-source-field',
                          ),
                          label: 'Source directory',
                          controller: sourceController,
                          onBrowse: () => unawaited(
                            chooseDirectory(
                              sourceController,
                              'Use source directory',
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _DirectoryField(
                          fieldKey: const ValueKey(
                            'workspace-shared-field',
                          ),
                          label: 'Shared data directory',
                          controller: sharedController,
                          onBrowse: () => unawaited(
                            chooseDirectory(
                              sharedController,
                              'Use shared data directory',
                            ),
                          ),
                        ),
                        if (validationMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            validationMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    key: const ValueKey('save-workspace-button'),
                    onPressed: () => unawaited(submit()),
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      sourceController.dispose();
      sharedController.dispose();
    }
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }
}

class _DirectoryDetail extends StatelessWidget {
  const _DirectoryDetail({
    required this.label,
    required this.description,
    required this.path,
    required this.valueKey,
  });

  final String label;
  final String description;
  final String path;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(description),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(path, key: valueKey),
        ),
      ],
    );
  }
}

class _DirectoryField extends StatelessWidget {
  const _DirectoryField({
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.onBrowse,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            key: fieldKey,
            controller: controller,
            decoration: InputDecoration(labelText: label),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onBrowse,
          icon: const Icon(Icons.folder_open),
          label: const Text('Browse'),
        ),
      ],
    );
  }
}
