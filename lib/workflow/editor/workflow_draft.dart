import '../files/workflow_file_reference.dart';
import '../model/workflow_definition.dart';
import '../model/workflow_node.dart';
import '../workflow_validator.dart';

class WorkflowDraft {
  WorkflowDraft({
    required this.id,
    required this.name,
    required List<WorkflowNodeDraft> nodes,
  }) : nodes = nodes;

  final String id;
  String name;
  final List<WorkflowNodeDraft> nodes;

  WorkflowDraftBuildResult buildDefinition() {
    final errors = <String>[];

    if (name.trim().isEmpty) {
      errors.add('Workflow name cannot be empty.');
    } else if (name != name.trim()) {
      errors.add('Workflow name cannot start or end with whitespace.');
    }

    for (final node in nodes) {
      _validateDraftNode(node, errors);
    }

    if (errors.isNotEmpty) {
      return WorkflowDraftBuildResult.invalid(errors);
    }

    final definition = WorkflowDefinition(
      id: id,
      name: name,
      nodes: nodes.map(_buildNode).toList(growable: false),
    );

    try {
      WorkflowValidator.validate(definition);
      return WorkflowDraftBuildResult.valid(definition);
    } on WorkflowValidationException catch (exception) {
      return WorkflowDraftBuildResult.invalid(exception.errors);
    }
  }

  void _validateDraftNode(
    WorkflowNodeDraft node,
    List<String> errors,
  ) {
    if (node.name.trim().isEmpty) {
      errors.add('Node ${node.id} must have a name.');
    } else if (node.name != node.name.trim()) {
      errors.add(
        'Node "${node.name}" cannot start or end with whitespace.',
      );
    }

    switch (node) {
      case StartNodeDraft():
        _requireConnection(node, node.nextNodeId, 'next', errors);
        break;

      case WriteFileNodeDraft():
        _requireConnection(node, node.nextNodeId, 'next', errors);
        _validateOutput(node, node.output, errors);
        break;

      case CombineTextNodeDraft():
        _requireConnection(node, node.nextNodeId, 'next', errors);

        if (node.inputs.length < 2) {
          errors.add(
            'Combine Text node "${node.name}" requires at least two inputs.',
          );
        }

        for (var index = 0; index < node.inputs.length; index++) {
          _validateInput(
            node,
            node.inputs[index],
            'input ${index + 1}',
            errors,
          );
        }

        _validateOutput(node, node.output, errors);
        break;

      case CounterDecisionNodeDraft():
        if (node.limit <= 0) {
          errors.add(
            'Counter Decision node "${node.name}" requires a positive limit.',
          );
        }

        _requireConnection(
          node,
          node.continueNodeId,
          'continue',
          errors,
        );
        _requireConnection(
          node,
          node.finishedNodeId,
          'finished',
          errors,
        );
        break;

      case EndNodeDraft():
        break;
    }
  }

  void _requireConnection(
    WorkflowNodeDraft node,
    String? nodeId,
    String connectionName,
    List<String> errors,
  ) {
    if (nodeId == null || nodeId.isEmpty) {
      errors.add(
        'Node "${node.name}" requires a $connectionName runtime connection.',
      );
    }
  }

  void _validateInput(
    WorkflowNodeDraft node,
    WorkflowFileDraft input,
    String inputName,
    List<String> errors,
  ) {
    if (input.relativePath.trim().isEmpty) {
      errors.add(
        'The $inputName of node "${node.name}" requires a relative path.',
      );
    }
  }

  void _validateOutput(
    WorkflowNodeDraft node,
    WorkflowFileDraft output,
    List<String> errors,
  ) {
    if (output.relativePath.trim().isEmpty) {
      errors.add(
        'The output of node "${node.name}" requires a relative path.',
      );
    }

    if (output.storage == WorkflowStorage.source) {
      errors.add(
        'Node "${node.name}" cannot write to read-only source storage.',
      );
    }
  }

  WorkflowNode _buildNode(WorkflowNodeDraft node) {
    return switch (node) {
      StartNodeDraft() => StartNode(
        id: node.id,
        name: node.name,
        nextNodeId: node.nextNodeId!,
      ),
      WriteFileNodeDraft() => WriteFileNode(
        id: node.id,
        name: node.name,
        content: node.content,
        output: node.output.toReference(),
        nextNodeId: node.nextNodeId!,
      ),
      CombineTextNodeDraft() => CombineTextNode(
        id: node.id,
        name: node.name,
        inputs: node.inputs
            .map((input) => input.toReference())
            .toList(growable: false),
        output: node.output.toReference(),
        nextNodeId: node.nextNodeId!,
      ),
      CounterDecisionNodeDraft() => CounterDecisionNode(
        id: node.id,
        name: node.name,
        limit: node.limit,
        continueNodeId: node.continueNodeId!,
        finishedNodeId: node.finishedNodeId!,
      ),
      EndNodeDraft() => EndNode(
        id: node.id,
        name: node.name,
      ),
    };
  }
}

class WorkflowDraftBuildResult {
  WorkflowDraftBuildResult.valid(this.definition) : errors = const [];

  WorkflowDraftBuildResult.invalid(List<String> errors)
    : definition = null,
      errors = List.unmodifiable(errors);

  final WorkflowDefinition? definition;
  final List<String> errors;

  bool get isValid => definition != null;
}

class WorkflowNodePosition {
  const WorkflowNodePosition({
    required this.x,
    required this.y,
  });

  final double x;
  final double y;

  WorkflowNodePosition movedBy(double dx, double dy) {
    return WorkflowNodePosition(
      x: x + dx,
      y: y + dy,
    );
  }
}

sealed class WorkflowNodeDraft {
  WorkflowNodeDraft({
    required this.id,
    required this.name,
    required this.position,
  });

  final String id;
  String name;
  WorkflowNodePosition position;
}

final class StartNodeDraft extends WorkflowNodeDraft {
  StartNodeDraft({
    required super.id,
    required super.name,
    required super.position,
    this.nextNodeId,
  });

  String? nextNodeId;
}

sealed class ActionNodeDraft extends WorkflowNodeDraft {
  ActionNodeDraft({
    required super.id,
    required super.name,
    required super.position,
    this.nextNodeId,
  });

  String? nextNodeId;
}

final class WriteFileNodeDraft extends ActionNodeDraft {
  WriteFileNodeDraft({
    required super.id,
    required super.name,
    required super.position,
    required this.output,
    this.content = '',
    super.nextNodeId,
  });

  String content;
  final WorkflowFileDraft output;
}

final class CombineTextNodeDraft extends ActionNodeDraft {
  CombineTextNodeDraft({
    required super.id,
    required super.name,
    required super.position,
    required List<WorkflowFileDraft> inputs,
    required this.output,
    super.nextNodeId,
  }) : inputs = inputs;

  final List<WorkflowFileDraft> inputs;
  final WorkflowFileDraft output;
}

sealed class DecisionNodeDraft extends WorkflowNodeDraft {
  DecisionNodeDraft({
    required super.id,
    required super.name,
    required super.position,
  });
}

final class CounterDecisionNodeDraft extends DecisionNodeDraft {
  CounterDecisionNodeDraft({
    required super.id,
    required super.name,
    required super.position,
    this.limit = 3,
    this.continueNodeId,
    this.finishedNodeId,
  });

  int limit;
  String? continueNodeId;
  String? finishedNodeId;
}

final class EndNodeDraft extends WorkflowNodeDraft {
  EndNodeDraft({
    required super.id,
    required super.name,
    required super.position,
  });
}

class WorkflowFileDraft {
  WorkflowFileDraft({
    required this.storage,
    required this.relativePath,
    required this.format,
  });

  WorkflowStorage storage;
  String relativePath;
  WorkflowFileFormat format;

  WorkflowFileReference toReference() {
    return WorkflowFileReference(
      storage: storage,
      relativePath: relativePath,
      format: format,
    );
  }
}
