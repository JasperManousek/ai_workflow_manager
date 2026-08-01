import 'dart:async';

import 'workflow_file_reference.dart';

typedef WorkflowFileAccessEventSink = FutureOr<void> Function(
  WorkflowFileAccessEvent event,
);

enum WorkflowFileOperation {
  inspect,
  read,
  write,
}

enum WorkflowFileAccessPhase {
  started,
  completed,
  failed,
}

class WorkflowFileAccessEvent {
  const WorkflowFileAccessEvent({
    required this.timestampUtc,
    required this.nodeId,
    required this.nodeExecutionId,
    required this.operation,
    required this.phase,
    required this.reference,
    this.sizeBytes,
    this.replacedExisting,
    this.exists,
    this.errorMessage,
  });

  final DateTime timestampUtc;

  final String nodeId;
  final String nodeExecutionId;

  final WorkflowFileOperation operation;
  final WorkflowFileAccessPhase phase;

  final WorkflowFileReference reference;

  final int? sizeBytes;
  final bool? replacedExisting;
  final bool? exists;
  final String? errorMessage;

  Map<String, Object?> toJson() {
    return {
      'eventType': 'fileAccess',
      'timestampUtc': timestampUtc.toIso8601String(),
      'nodeId': nodeId,
      'nodeExecutionId': nodeExecutionId,
      'operation': operation.name,
      'phase': phase.name,
      'storage': reference.storage.name,
      'relativePath': reference.relativePath,
      'format': reference.format.name,
      if (sizeBytes != null) 'sizeBytes': sizeBytes,
      if (replacedExisting != null)
        'replacedExisting': replacedExisting,
      if (exists != null) 'exists': exists,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }
}