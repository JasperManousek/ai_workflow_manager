import 'workflow_node.dart';

class WorkflowDefinition {
  WorkflowDefinition({
    required this.id,
    required this.name,
    required List<WorkflowNode> nodes,
  }) : nodes = List.unmodifiable(nodes);

  final String id;
  final String name;
  final List<WorkflowNode> nodes;
}
