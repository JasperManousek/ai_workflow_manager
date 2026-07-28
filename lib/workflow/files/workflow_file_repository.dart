import 'dart:io';

import 'package:path/path.dart' as path;

import 'workflow_file_reference.dart';
import 'workflow_file_roots.dart';

class WorkflowFileRepository {
  WorkflowFileRepository({
    required this.roots,
  });

  final WorkflowFileRoots roots;

  File resolve(WorkflowFileReference reference) {
    final relativePath = reference.relativePath;

    if (relativePath.trim().isEmpty) {
      throw const WorkflowFileAccessException(
        'A workflow file path cannot be empty.',
      );
    }

    if (path.isAbsolute(relativePath)) {
      throw WorkflowFileAccessException(
        'The path "$relativePath" must be relative.',
      );
    }

    final rootPath = path.normalize(
      roots.rootFor(reference.storage).absolute.path,
    );

    final resolvedPath = path.normalize(
      path.join(rootPath, relativePath),
    );

    if (!path.isWithin(rootPath, resolvedPath)) {
      throw WorkflowFileAccessException(
        'The path "$relativePath" escapes the '
        '${reference.storage.name} directory.',
      );
    }

    return File(resolvedPath);
  }

  Future<String> readText(
  WorkflowFileReference reference,
) async {
  final file = resolve(reference);

  if (!await file.exists()) {
    throw WorkflowFileAccessException(
      'The ${reference.storage.name} file '
      '"${reference.relativePath}" does not exist.',
    );
  }

  try {
    return await file.readAsString();
  } on FileSystemException catch (error) {
    throw WorkflowFileAccessException(
      'Could not read the ${reference.storage.name} file '
      '"${reference.relativePath}": ${error.message}',
    );
  }
}
}

class WorkflowFileAccessException implements Exception {
  const WorkflowFileAccessException(this.message);

  final String message;

  @override
  String toString() {
    return 'WorkflowFileAccessException: $message';
  }
}