enum WorkflowStorage {
  source,
  working,
  persistent,
}

enum WorkflowFileFormat {
  plainText,
  markdown,
  json,
}

class WorkflowFileReference {
  const WorkflowFileReference({
    required this.storage,
    required this.relativePath,
    required this.format,
  });

  final WorkflowStorage storage;
  final String relativePath;
  final WorkflowFileFormat format;

  @override
  String toString() {
    return '${storage.name}:$relativePath';
  }
}