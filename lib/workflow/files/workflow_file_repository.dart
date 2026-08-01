import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'workflow_file_access_event.dart';
import 'workflow_file_reference.dart';
import 'workflow_file_roots.dart';

class WorkflowFileRepository {
  WorkflowFileRepository({
    required this.roots,
    required this.nodeId,
    required this.nodeExecutionId,
    required this.onEvent,
  }) {
    if (nodeId.trim().isEmpty) {
      throw ArgumentError.value(
        nodeId,
        'nodeId',
        'The node ID cannot be empty.',
      );
    }

    if (nodeExecutionId.trim().isEmpty) {
      throw ArgumentError.value(
        nodeExecutionId,
        'nodeExecutionId',
        'The node execution ID cannot be empty.',
      );
    }
  }

  final WorkflowFileRoots roots;

  final String nodeId;
  final String nodeExecutionId;

  final WorkflowFileAccessEventSink onEvent;

  Future<bool> exists(
    WorkflowFileReference reference,
  ) async {
    await _emit(
      operation: WorkflowFileOperation.inspect,
      phase: WorkflowFileAccessPhase.started,
      reference: reference,
    );

    late bool fileExists;

    try {
      final file = await _fileForAccess(
        reference,
        writing: false,
      );

      fileExists = await file.exists();
    } catch (error, stackTrace) {
      final exception = _normalizeException(
        error: error,
        operationDescription: 'inspect',
        reference: reference,
      );

      await _emit(
        operation: WorkflowFileOperation.inspect,
        phase: WorkflowFileAccessPhase.failed,
        reference: reference,
        errorMessage: exception.message,
      );

      Error.throwWithStackTrace(
        exception,
        stackTrace,
      );
    }

    await _emit(
      operation: WorkflowFileOperation.inspect,
      phase: WorkflowFileAccessPhase.completed,
      reference: reference,
      exists: fileExists,
    );

    return fileExists;
  }

  Future<String> readText(
    WorkflowFileReference reference,
  ) async {
    await _emit(
      operation: WorkflowFileOperation.read,
      phase: WorkflowFileAccessPhase.started,
      reference: reference,
    );

    late String content;
    late int sizeBytes;

    try {
      final file = await _fileForAccess(
        reference,
        writing: false,
      );

      if (!await file.exists()) {
        throw WorkflowFileAccessException(
          'The ${reference.storage.name} file '
          '"${reference.relativePath}" does not exist.',
        );
      }

      final bytes = await file.readAsBytes();

      content = utf8.decode(bytes);
      sizeBytes = bytes.length;
    } catch (error, stackTrace) {
      final exception = _normalizeException(
        error: error,
        operationDescription: 'read',
        reference: reference,
      );

      await _emit(
        operation: WorkflowFileOperation.read,
        phase: WorkflowFileAccessPhase.failed,
        reference: reference,
        errorMessage: exception.message,
      );

      Error.throwWithStackTrace(
        exception,
        stackTrace,
      );
    }

    await _emit(
      operation: WorkflowFileOperation.read,
      phase: WorkflowFileAccessPhase.completed,
      reference: reference,
      sizeBytes: sizeBytes,
    );

    return content;
  }

  Future<Object?> readJson(
    WorkflowFileReference reference,
  ) async {
    _requireJsonFormat(reference);

    final content = await readText(reference);

    try {
      return jsonDecode(content);
    } on FormatException catch (error) {
      throw WorkflowFileAccessException(
        'The ${reference.storage.name} file '
        '"${reference.relativePath}" contains invalid JSON: '
        '${error.message}',
      );
    }
  }

  Future<void> writeText(
    WorkflowFileReference reference,
    String content,
  ) async {
    await _emit(
      operation: WorkflowFileOperation.write,
      phase: WorkflowFileAccessPhase.started,
      reference: reference,
    );

    final bytes = utf8.encode(content);

    late bool replacedExisting;

    try {
      final file = await _fileForAccess(
        reference,
        writing: true,
      );

      await file.parent.create(
        recursive: true,
      );

      // Check again after directory creation. This ensures that no
      // newly encountered path component is a symbolic link.
      await _ensureNoSymbolicLinks(
        reference: reference,
        resolvedPath: file.path,
      );

      replacedExisting = await file.exists();

      await file.writeAsBytes(
        bytes,
        mode: FileMode.write,
        flush: true,
      );
    } catch (error, stackTrace) {
      final exception = _normalizeException(
        error: error,
        operationDescription: 'write',
        reference: reference,
      );

      await _emit(
        operation: WorkflowFileOperation.write,
        phase: WorkflowFileAccessPhase.failed,
        reference: reference,
        errorMessage: exception.message,
      );

      Error.throwWithStackTrace(
        exception,
        stackTrace,
      );
    }

    await _emit(
      operation: WorkflowFileOperation.write,
      phase: WorkflowFileAccessPhase.completed,
      reference: reference,
      sizeBytes: bytes.length,
      replacedExisting: replacedExisting,
    );
  }

  Future<void> writeJson(
    WorkflowFileReference reference,
    Object? value,
  ) async {
    _requireJsonFormat(reference);

    late String content;

    try {
      content = '${const JsonEncoder.withIndent('  ').convert(value)}\n';
    } on JsonUnsupportedObjectError catch (error) {
      throw WorkflowFileAccessException(
        'The value for "${reference.relativePath}" '
        'cannot be encoded as JSON: $error',
      );
    }

    await writeText(
      reference,
      content,
    );
  }

  Future<File> _fileForAccess(
    WorkflowFileReference reference, {
    required bool writing,
  }) async {
    if (writing &&
        reference.storage == WorkflowStorage.source) {
      throw WorkflowFileAccessException(
        'Source files are read-only. '
        'Cannot write "${reference.relativePath}".',
      );
    }

    final resolvedPath = _resolvePath(reference);

    await _ensureNoSymbolicLinks(
      reference: reference,
      resolvedPath: resolvedPath,
    );

    return File(resolvedPath);
  }

  String _resolvePath(
    WorkflowFileReference reference,
  ) {
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

    final rootPath = _normalizedRootPath(
      reference.storage,
    );

    final resolvedPath = path.normalize(
      path.join(
        rootPath,
        relativePath,
      ),
    );

    if (!path.isWithin(rootPath, resolvedPath)) {
      throw WorkflowFileAccessException(
        'The path "$relativePath" escapes the '
        '${reference.storage.name} directory.',
      );
    }

    return resolvedPath;
  }

  String _normalizedRootPath(
    WorkflowStorage storage,
  ) {
    return path.normalize(
      roots.rootFor(storage).absolute.path,
    );
  }

  Future<void> _ensureNoSymbolicLinks({
    required WorkflowFileReference reference,
    required String resolvedPath,
  }) async {
    final rootPath = _normalizedRootPath(
      reference.storage,
    );

    final relativePath = path.relative(
      resolvedPath,
      from: rootPath,
    );

    var currentPath = rootPath;

    for (final segment in path.split(relativePath)) {
      currentPath = path.join(
        currentPath,
        segment,
      );

      final entityType = await FileSystemEntity.type(
        currentPath,
        followLinks: false,
      );

      if (entityType == FileSystemEntityType.link) {
        throw WorkflowFileAccessException(
          'The path "${reference.relativePath}" '
          'contains a symbolic link. '
          'Workflow file access through symbolic links is not allowed.',
        );
      }

      if (entityType == FileSystemEntityType.notFound) {
        // Later path components cannot exist when this one is missing.
        // They will be created normally for writable storage.
        return;
      }
    }
  }

  void _requireJsonFormat(
    WorkflowFileReference reference,
  ) {
    if (reference.format != WorkflowFileFormat.json) {
      throw WorkflowFileAccessException(
        'The file "${reference.relativePath}" is declared as '
        '${reference.format.name}, not JSON.',
      );
    }
  }

  WorkflowFileAccessException _normalizeException({
    required Object error,
    required String operationDescription,
    required WorkflowFileReference reference,
  }) {
    if (error is WorkflowFileAccessException) {
      return error;
    }

    if (error is FileSystemException) {
      return WorkflowFileAccessException(
        'Could not $operationDescription the '
        '${reference.storage.name} file '
        '"${reference.relativePath}": ${error.message}',
      );
    }

    if (error is FormatException) {
      return WorkflowFileAccessException(
        'Could not $operationDescription the '
        '${reference.storage.name} file '
        '"${reference.relativePath}": '
        'the file is not valid UTF-8 text.',
      );
    }

    return WorkflowFileAccessException(
      'Unexpected error while trying to '
      '$operationDescription the '
      '${reference.storage.name} file '
      '"${reference.relativePath}": $error',
    );
  }

  Future<void> _emit({
    required WorkflowFileOperation operation,
    required WorkflowFileAccessPhase phase,
    required WorkflowFileReference reference,
    int? sizeBytes,
    bool? replacedExisting,
    bool? exists,
    String? errorMessage,
  }) async {
    await onEvent(
      WorkflowFileAccessEvent(
        timestampUtc: DateTime.now().toUtc(),
        nodeId: nodeId,
        nodeExecutionId: nodeExecutionId,
        operation: operation,
        phase: phase,
        reference: reference,
        sizeBytes: sizeBytes,
        replacedExisting: replacedExisting,
        exists: exists,
        errorMessage: errorMessage,
      ),
    );
  }
}

class WorkflowFileAccessException implements Exception {
  const WorkflowFileAccessException(
    this.message,
  );

  final String message;

  @override
  String toString() {
    return 'WorkflowFileAccessException: $message';
  }
}