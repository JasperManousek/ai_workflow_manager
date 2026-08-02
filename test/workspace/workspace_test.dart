import 'package:ai_workflow_manager/workspace/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated workspace IDs are stable-looking and unique', () {
    final first = createWorkspaceId();
    final second = createWorkspaceId();

    expect(
      first,
      matches(
        RegExp(
          r'^workspace-[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
          r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(second, isNot(first));
  });

  test('workspace validation requires a name and two absolute paths', () {
    const workspace = Workspace(
      id: 'workspace-1',
      name: '',
      sourceDirectoryPath: 'relative/source',
      sharedDataDirectoryPath: 'relative/shared',
    );

    final errors = validateWorkspace(workspace);

    expect(errors, contains('Workspace name cannot be empty.'));
    expect(errors, contains('Source directory must be an absolute path.'));
    expect(
      errors,
      contains('Shared data directory must be an absolute path.'),
    );
  });
}
