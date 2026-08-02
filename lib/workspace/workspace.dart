import 'dart:math';

import 'package:path/path.dart' as path;

final class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    required this.sourceDirectoryPath,
    required this.sharedDataDirectoryPath,
  });

  final String id;
  final String name;
  final String sourceDirectoryPath;
  final String sharedDataDirectoryPath;

  Workspace copyWith({
    String? name,
    String? sourceDirectoryPath,
    String? sharedDataDirectoryPath,
  }) {
    return Workspace(
      id: id,
      name: name ?? this.name,
      sourceDirectoryPath:
          sourceDirectoryPath ?? this.sourceDirectoryPath,
      sharedDataDirectoryPath:
          sharedDataDirectoryPath ?? this.sharedDataDirectoryPath,
    );
  }
}

String createWorkspaceId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();

  return 'workspace-${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

List<String> validateWorkspace(Workspace workspace) {
  final errors = <String>[];

  if (workspace.id.trim().isEmpty) {
    errors.add('Workspace ID cannot be empty.');
  }

  if (workspace.name.trim().isEmpty) {
    errors.add('Workspace name cannot be empty.');
  } else if (workspace.name != workspace.name.trim()) {
    errors.add('Workspace name cannot start or end with whitespace.');
  }

  _validateAbsoluteDirectoryPath(
    workspace.sourceDirectoryPath,
    label: 'Source directory',
    errors: errors,
  );
  _validateAbsoluteDirectoryPath(
    workspace.sharedDataDirectoryPath,
    label: 'Shared data directory',
    errors: errors,
  );

  if (workspace.sourceDirectoryPath.trim().isNotEmpty &&
      workspace.sharedDataDirectoryPath.trim().isNotEmpty &&
      path.equals(
        path.normalize(workspace.sourceDirectoryPath),
        path.normalize(workspace.sharedDataDirectoryPath),
      )) {
    errors.add(
      'Source and shared data must use different directories.',
    );
  }

  return errors;
}

void _validateAbsoluteDirectoryPath(
  String value, {
  required String label,
  required List<String> errors,
}) {
  if (value.trim().isEmpty) {
    errors.add('$label cannot be empty.');
    return;
  }

  if (value != value.trim()) {
    errors.add('$label cannot start or end with whitespace.');
  }

  if (!path.isAbsolute(value)) {
    errors.add('$label must be an absolute path.');
  }
}

class InvalidWorkspaceException implements Exception {
  InvalidWorkspaceException(List<String> errors)
    : errors = List.unmodifiable(errors);

  final List<String> errors;

  @override
  String toString() => errors.join('\n');
}
