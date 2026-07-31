import 'package:path/path.dart' as path;

import 'files/workflow_file_reference.dart';
import 'model/workflow_definition.dart';
import 'model/workflow_node.dart';

const String workflowInternalDirectoryName = '.workflow_internal';

class WorkflowValidator {
  const WorkflowValidator._();

  static void validate(WorkflowDefinition workflow) {
    final errors = <String>[];

    _validateRequiredText(workflow.id, 'Workflow ID', errors);
    _validateRequiredText(workflow.name, 'Workflow name', errors);

    final nodesById = <String, WorkflowNode>{};
    final duplicateNodeIds = <String>{};

    for (final node in workflow.nodes) {
      _validateRequiredText(node.id, 'Node ID', errors);
      _validateRequiredText(
        node.name,
        'Name of node "${node.id}"',
        errors,
      );

      if (nodesById.containsKey(node.id)) {
        duplicateNodeIds.add(node.id);
      } else {
        nodesById[node.id] = node;
      }

      _validateNode(node, errors);
    }

    for (final duplicateNodeId in duplicateNodeIds) {
      errors.add('Node ID "$duplicateNodeId" is used more than once.');
    }

    final startNodes = workflow.nodes.whereType<StartNode>().toList();
    final endNodes = workflow.nodes.whereType<EndNode>().toList();

    if (startNodes.length != 1) {
      errors.add(
        'A workflow must contain exactly one Start node, but found '
        '${startNodes.length}.',
      );
    }

    if (endNodes.length != 1) {
      errors.add(
        'A workflow must contain exactly one End node, but found '
        '${endNodes.length}.',
      );
    }

    if (duplicateNodeIds.isEmpty) {
      _validateRuntimeConnections(
        workflow.nodes,
        nodesById,
        errors,
      );

      if (startNodes.length == 1) {
        _validateReachability(
          startNodes.single,
          workflow.nodes,
          nodesById,
          errors,
        );
      }
    }

    if (errors.isNotEmpty) {
      throw WorkflowValidationException(errors);
    }
  }

  static void _validateNode(
    WorkflowNode node,
    List<String> errors,
  ) {
    switch (node) {
      case StartNode():
        return;

      case WriteFileNode():
        _validateTextOutput(node.output, node, errors);
        return;

      case CombineTextNode():
        if (node.inputs.length < 2) {
          errors.add(
            'Combine Text node "${node.name}" must have at least two '
            'input files.',
          );
        }

        for (final input in node.inputs) {
          _validateTextFormat(input, node, 'input', errors);
          _validateUserFileReference(input, node, errors);
        }

        _validateTextOutput(node.output, node, errors);
        return;

      case CounterDecisionNode():
        if (node.limit <= 0) {
          errors.add(
            'Counter Decision node "${node.name}" must have a positive '
            'limit.',
          );
        }
        return;

      case EndNode():
        return;

      default:
        errors.add(
          'Node "${node.name}" has unsupported type '
          '"${node.runtimeType}".',
        );
    }
  }

  static void _validateTextOutput(
    WorkflowFileReference output,
    WorkflowNode node,
    List<String> errors,
  ) {
    _validateTextFormat(output, node, 'output', errors);
    _validateUserFileReference(output, node, errors);

    if (output.storage == WorkflowStorage.source) {
      errors.add(
        'Node "${node.name}" cannot write output '
        '"${output.relativePath}" to read-only source storage.',
      );
    }
  }

  static void _validateTextFormat(
    WorkflowFileReference reference,
    WorkflowNode node,
    String role,
    List<String> errors,
  ) {
    if (reference.format != WorkflowFileFormat.plainText &&
        reference.format != WorkflowFileFormat.markdown) {
      errors.add(
        'The $role file "${reference.relativePath}" of node '
        '"${node.name}" must be plain text or Markdown.',
      );
    }
  }

  static void _validateUserFileReference(
    WorkflowFileReference reference,
    WorkflowNode node,
    List<String> errors,
  ) {
    if (reference.storage != WorkflowStorage.working) {
      return;
    }

    final normalizedPath = path.normalize(reference.relativePath);
    final segments = path.split(normalizedPath);

    if (segments.isNotEmpty &&
        segments.first == workflowInternalDirectoryName) {
      errors.add(
        'Node "${node.name}" cannot use the reserved working path '
        '"${reference.relativePath}".',
      );
    }
  }

  static void _validateRuntimeConnections(
    List<WorkflowNode> nodes,
    Map<String, WorkflowNode> nodesById,
    List<String> errors,
  ) {
    for (final node in nodes) {
      for (final nextNodeId in _outgoingNodeIds(node)) {
        if (!nodesById.containsKey(nextNodeId)) {
          errors.add(
            'Node "${node.name}" connects to missing node ID '
            '"$nextNodeId".',
          );
        }
      }
    }
  }

  static void _validateReachability(
    StartNode startNode,
    List<WorkflowNode> nodes,
    Map<String, WorkflowNode> nodesById,
    List<String> errors,
  ) {
    final reachableNodeIds = <String>{};
    final remainingNodeIds = <String>[startNode.id];

    while (remainingNodeIds.isNotEmpty) {
      final nodeId = remainingNodeIds.removeLast();

      if (!reachableNodeIds.add(nodeId)) {
        continue;
      }

      final node = nodesById[nodeId];
      if (node == null) {
        continue;
      }

      for (final nextNodeId in _outgoingNodeIds(node)) {
        if (nodesById.containsKey(nextNodeId)) {
          remainingNodeIds.add(nextNodeId);
        }
      }
    }

    for (final node in nodes) {
      if (!reachableNodeIds.contains(node.id)) {
        errors.add(
          'Node "${node.name}" (${node.id}) is not reachable from Start.',
        );
      }
    }
  }

  static List<String> _outgoingNodeIds(WorkflowNode node) {
    switch (node) {
      case StartNode():
        return [node.nextNodeId];

      case ActionNode():
        return [node.nextNodeId];

      case DecisionNode():
        return [
          node.firstNextNodeId,
          node.secondNextNodeId,
        ];

      case EndNode():
        return const [];

      default:
        return const [];
    }
  }

  static void _validateRequiredText(
    String value,
    String fieldName,
    List<String> errors,
  ) {
    if (value.trim().isEmpty) {
      errors.add('$fieldName cannot be empty.');
      return;
    }

    if (value != value.trim()) {
      errors.add('$fieldName cannot start or end with whitespace.');
    }
  }
}

class WorkflowValidationException implements Exception {
  WorkflowValidationException(List<String> errors)
    : errors = List.unmodifiable(errors);

  final List<String> errors;

  @override
  String toString() {
    return 'WorkflowValidationException:\n${errors.join('\n')}';
  }
}
