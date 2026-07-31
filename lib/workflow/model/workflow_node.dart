import '../files/workflow_file_reference.dart';

abstract class WorkflowNode {
  WorkflowNode({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

final class StartNode extends WorkflowNode {
  StartNode({
    required super.id,
    required super.name,
    required this.nextNodeId,
  });

  final String nextNodeId;
}

abstract class ActionNode extends WorkflowNode {
  ActionNode({
    required super.id,
    required super.name,
    required List<WorkflowFileReference> inputs,
    required List<WorkflowFileReference> outputs,
    required this.nextNodeId,
  }) : inputs = List.unmodifiable(inputs),
       outputs = List.unmodifiable(outputs);

  final List<WorkflowFileReference> inputs;
  final List<WorkflowFileReference> outputs;
  final String nextNodeId;
}

final class WriteFileNode extends ActionNode {
  WriteFileNode({
    required String id,
    required String name,
    required this.content,
    required WorkflowFileReference output,
    required String nextNodeId,
  }) : super(
         id: id,
         name: name,
         inputs: const [],
         outputs: [output],
         nextNodeId: nextNodeId,
       );

  final String content;

  WorkflowFileReference get output => outputs.single;
}

final class CombineTextNode extends ActionNode {
  CombineTextNode({
    required String id,
    required String name,
    required List<WorkflowFileReference> inputs,
    required WorkflowFileReference output,
    required String nextNodeId,
  }) : super(
         id: id,
         name: name,
         inputs: inputs,
         outputs: [output],
         nextNodeId: nextNodeId,
       );

  WorkflowFileReference get output => outputs.single;
}

abstract class DecisionNode extends WorkflowNode {
  DecisionNode({
    required super.id,
    required super.name,
    required List<WorkflowFileReference> inputs,
    required this.firstNextNodeId,
    required this.secondNextNodeId,
  }) : inputs = List.unmodifiable(inputs);

  final List<WorkflowFileReference> inputs;
  final String firstNextNodeId;
  final String secondNextNodeId;
}

final class CounterDecisionNode extends DecisionNode {
  CounterDecisionNode({
    required String id,
    required String name,
    required this.limit,
    required String continueNodeId,
    required String finishedNodeId,
  }) : super(
         id: id,
         name: name,
         inputs: const [],
         firstNextNodeId: continueNodeId,
         secondNextNodeId: finishedNodeId,
       );

  final int limit;

  String get continueNodeId => firstNextNodeId;
  String get finishedNodeId => secondNextNodeId;
}

final class EndNode extends WorkflowNode {
  EndNode({
    required super.id,
    required super.name,
  });
}
