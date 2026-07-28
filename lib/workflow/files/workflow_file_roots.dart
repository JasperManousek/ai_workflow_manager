import 'dart:io';

import 'workflow_file_reference.dart';

class WorkflowFileRoots {
  WorkflowFileRoots({
    required this.source,
    required this.working,
    required this.persistent,
  });

  final Directory source;
  final Directory working;
  final Directory persistent;

  Directory rootFor(WorkflowStorage storage) {
    switch (storage) {
      case WorkflowStorage.source:
        return source;

      case WorkflowStorage.working:
        return working;

      case WorkflowStorage.persistent:
        return persistent;
    }
  }
}