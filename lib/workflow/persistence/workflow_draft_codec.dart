import 'dart:convert';

import '../editor/workflow_draft.dart';
import '../files/workflow_file_reference.dart';

class WorkflowDraftCodec {
  const WorkflowDraftCodec._();

  static const int currentSchemaVersion = 1;

  static String encode(WorkflowDraft draft) {
    return jsonEncode({
      'schemaVersion': currentSchemaVersion,
      'id': draft.id,
      'name': draft.name,
      'nodes': draft.nodes.map(_encodeNode).toList(growable: false),
    });
  }

  static WorkflowDraft decode(String source) {
    final decoded = jsonDecode(source);
    final root = _requireMap(decoded, 'workflow snapshot');
    final schemaVersion = _requireInt(root['schemaVersion'], 'schemaVersion');

    if (schemaVersion != currentSchemaVersion) {
      throw FormatException(
        'Unsupported workflow snapshot schema version $schemaVersion.',
      );
    }

    final nodesValue = root['nodes'];
    if (nodesValue is! List) {
      throw const FormatException('Workflow snapshot nodes must be a list.');
    }

    return WorkflowDraft(
      id: _requireString(root['id'], 'id'),
      name: _requireString(root['name'], 'name'),
      nodes: nodesValue
          .map((value) => _decodeNode(_requireMap(value, 'node')))
          .toList(growable: false),
    );
  }

  static Map<String, Object?> _encodeNode(WorkflowNodeDraft node) {
    final common = <String, Object?>{
      'id': node.id,
      'name': node.name,
      'position': {
        'x': node.position.x,
        'y': node.position.y,
      },
    };

    return switch (node) {
      StartNodeDraft() => {
        ...common,
        'type': 'start',
        'nextNodeId': node.nextNodeId,
      },
      WriteFileNodeDraft() => {
        ...common,
        'type': 'writeFile',
        'content': node.content,
        'output': _encodeFile(node.output),
        'nextNodeId': node.nextNodeId,
      },
      CombineTextNodeDraft() => {
        ...common,
        'type': 'combineText',
        'inputs': node.inputs.map(_encodeFile).toList(growable: false),
        'output': _encodeFile(node.output),
        'nextNodeId': node.nextNodeId,
      },
      CounterDecisionNodeDraft() => {
        ...common,
        'type': 'counterDecision',
        'limit': node.limit,
        'continueNodeId': node.continueNodeId,
        'finishedNodeId': node.finishedNodeId,
      },
      EndNodeDraft() => {
        ...common,
        'type': 'end',
      },
    };
  }

  static WorkflowNodeDraft _decodeNode(Map<String, dynamic> value) {
    final id = _requireString(value['id'], 'node.id');
    final name = _requireString(value['name'], 'node.name');
    final positionValue = _requireMap(value['position'], 'node.position');
    final position = WorkflowNodePosition(
      x: _requireDouble(positionValue['x'], 'node.position.x'),
      y: _requireDouble(positionValue['y'], 'node.position.y'),
    );

    return switch (_requireString(value['type'], 'node.type')) {
      'start' => StartNodeDraft(
        id: id,
        name: name,
        position: position,
        nextNodeId: _optionalString(value['nextNodeId'], 'node.nextNodeId'),
      ),
      'writeFile' => WriteFileNodeDraft(
        id: id,
        name: name,
        position: position,
        content: _requireString(value['content'], 'node.content'),
        output: _decodeFile(_requireMap(value['output'], 'node.output')),
        nextNodeId: _optionalString(value['nextNodeId'], 'node.nextNodeId'),
      ),
      'combineText' => CombineTextNodeDraft(
        id: id,
        name: name,
        position: position,
        inputs: _decodeFiles(value['inputs'], 'node.inputs'),
        output: _decodeFile(_requireMap(value['output'], 'node.output')),
        nextNodeId: _optionalString(value['nextNodeId'], 'node.nextNodeId'),
      ),
      'counterDecision' => CounterDecisionNodeDraft(
        id: id,
        name: name,
        position: position,
        limit: _requireInt(value['limit'], 'node.limit'),
        continueNodeId: _optionalString(
          value['continueNodeId'],
          'node.continueNodeId',
        ),
        finishedNodeId: _optionalString(
          value['finishedNodeId'],
          'node.finishedNodeId',
        ),
      ),
      'end' => EndNodeDraft(
        id: id,
        name: name,
        position: position,
      ),
      final type => throw FormatException('Unknown workflow node type "$type".'),
    };
  }

  static Map<String, Object?> _encodeFile(WorkflowFileDraft file) {
    return {
      'storage': file.storage.name,
      'relativePath': file.relativePath,
      'format': file.format.name,
    };
  }

  static WorkflowFileDraft _decodeFile(Map<String, dynamic> value) {
    return WorkflowFileDraft(
      storage: _enumByName(
        WorkflowStorage.values,
        _requireString(value['storage'], 'file.storage'),
        'storage',
      ),
      relativePath: _requireString(value['relativePath'], 'file.relativePath'),
      format: _enumByName(
        WorkflowFileFormat.values,
        _requireString(value['format'], 'file.format'),
        'format',
      ),
    );
  }

  static List<WorkflowFileDraft> _decodeFiles(
    Object? value,
    String fieldName,
  ) {
    if (value is! List) {
      throw FormatException('$fieldName must be a list.');
    }

    return value
        .map((item) => _decodeFile(_requireMap(item, fieldName)))
        .toList(growable: false);
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    String name,
    String fieldName,
  ) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }

    throw FormatException('Unknown $fieldName value "$name".');
  }

  static Map<String, dynamic> _requireMap(Object? value, String fieldName) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    throw FormatException('$fieldName must be an object.');
  }

  static String _requireString(Object? value, String fieldName) {
    if (value is String) {
      return value;
    }

    throw FormatException('$fieldName must be a string.');
  }

  static String? _optionalString(Object? value, String fieldName) {
    if (value == null || value is String) {
      return value as String?;
    }

    throw FormatException('$fieldName must be a string or null.');
  }

  static int _requireInt(Object? value, String fieldName) {
    if (value is int) {
      return value;
    }

    throw FormatException('$fieldName must be an integer.');
  }

  static double _requireDouble(Object? value, String fieldName) {
    if (value is num) {
      return value.toDouble();
    }

    throw FormatException('$fieldName must be a number.');
  }
}
