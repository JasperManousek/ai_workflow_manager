import 'dart:io';

import 'workflow_file_reference.dart';

class WorkflowFileRoots {
  WorkflowFileRoots({
    required this.source,
    required this.execution,
    required this.workspace,
  });

  final Directory source;
  final Directory execution;
  final Directory workspace;

  Directory rootFor(WorkflowStorage storage) {
    switch (storage) {
      case WorkflowStorage.source:
        return source;

      case WorkflowStorage.execution:
        return execution;

      case WorkflowStorage.workspace:
        return workspace;
    }
  }
}
