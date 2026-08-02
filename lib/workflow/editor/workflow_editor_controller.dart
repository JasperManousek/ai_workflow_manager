import 'package:flutter/foundation.dart';

import '../files/workflow_file_reference.dart';
import 'workflow_draft.dart';

enum WorkflowNodeDraftType {
  writeFile,
  combineText,
  counterDecision,
}

class WorkflowEditorController extends ChangeNotifier {
  WorkflowEditorController({WorkflowDraft? initialDraft})
    : draft = initialDraft ?? _createInitialDraft() {
    _nextNodeNumber = _nextNodeNumberFor(draft);
  }

  WorkflowDraft draft;
  String? selectedNodeId = 'start';
  int _nextNodeNumber = 1;

  WorkflowNodeDraft? get selectedNode {
    final selectedId = selectedNodeId;
    if (selectedId == null) {
      return null;
    }

    for (final node in draft.nodes) {
      if (node.id == selectedId) {
        return node;
      }
    }

    return null;
  }


  void loadWorkflow(WorkflowDraft workflow) {
    draft = workflow;
    selectedNodeId = null;
    for (final node in workflow.nodes) {
      if (node is StartNodeDraft) {
        selectedNodeId = node.id;
        break;
      }
    }
    _nextNodeNumber = _nextNodeNumberFor(workflow);
    notifyListeners();
  }

  void createNewWorkflow() {
    draft = _createInitialDraft();
    selectedNodeId = 'start';
    _nextNodeNumber = 1;
    notifyListeners();
  }

  void renameWorkflow(String name) {
    draft.name = name;
    notifyListeners();
  }

  void selectNode(String? nodeId) {
    selectedNodeId = nodeId;
    notifyListeners();
  }

  void addNode(WorkflowNodeDraftType type) {
    final nodeNumber = _nextNodeNumber++;
    final id = 'node-$nodeNumber';
    final position = _nextPosition(nodeNumber);

    final node = switch (type) {
      WorkflowNodeDraftType.writeFile => WriteFileNodeDraft(
        id: id,
        name: 'Write File $nodeNumber',
        position: position,
        output: WorkflowFileDraft(
          storage: WorkflowStorage.execution,
          relativePath: '',
          format: WorkflowFileFormat.plainText,
        ),
      ),
      WorkflowNodeDraftType.combineText => CombineTextNodeDraft(
        id: id,
        name: 'Combine Text $nodeNumber',
        position: position,
        inputs: [
          WorkflowFileDraft(
            storage: WorkflowStorage.source,
            relativePath: '',
            format: WorkflowFileFormat.plainText,
          ),
          WorkflowFileDraft(
            storage: WorkflowStorage.source,
            relativePath: '',
            format: WorkflowFileFormat.plainText,
          ),
        ],
        output: WorkflowFileDraft(
          storage: WorkflowStorage.execution,
          relativePath: '',
          format: WorkflowFileFormat.plainText,
        ),
      ),
      WorkflowNodeDraftType.counterDecision => CounterDecisionNodeDraft(
        id: id,
        name: 'Counter $nodeNumber',
        position: position,
      ),
    };

    draft.nodes.add(node);
    selectedNodeId = node.id;
    notifyListeners();
  }

  void removeSelectedNode() {
    final node = selectedNode;
    if (node == null || node is StartNodeDraft || node is EndNodeDraft) {
      return;
    }

    draft.nodes.removeWhere((candidate) => candidate.id == node.id);
    _clearConnectionsTo(node.id);
    selectedNodeId = null;
    notifyListeners();
  }

  void moveNode(
    String nodeId,
    double dx,
    double dy, {
    required double canvasWidth,
    required double canvasHeight,
    required double nodeWidth,
    required double nodeHeight,
  }) {
    final node = _nodeById(nodeId);
    if (node == null) {
      return;
    }

    final nextPosition = node.position.movedBy(dx, dy);
    node.position = WorkflowNodePosition(
      x: nextPosition.x
          .clamp(0, canvasWidth - nodeWidth)
          .toDouble(),
      y: nextPosition.y
          .clamp(0, canvasHeight - nodeHeight)
          .toDouble(),
    );
    notifyListeners();
  }

  void renameNode(WorkflowNodeDraft node, String name) {
    node.name = name;
    notifyListeners();
  }

  void setNextNode(ActionNodeDraft node, String? nextNodeId) {
    node.nextNodeId = nextNodeId;
    notifyListeners();
  }

  void setStartNextNode(StartNodeDraft node, String? nextNodeId) {
    node.nextNodeId = nextNodeId;
    notifyListeners();
  }

  void setCounterContinueNode(
    CounterDecisionNodeDraft node,
    String? nextNodeId,
  ) {
    node.continueNodeId = nextNodeId;
    notifyListeners();
  }

  void setCounterFinishedNode(
    CounterDecisionNodeDraft node,
    String? nextNodeId,
  ) {
    node.finishedNodeId = nextNodeId;
    notifyListeners();
  }

  void setCounterLimit(CounterDecisionNodeDraft node, int limit) {
    node.limit = limit;
    notifyListeners();
  }

  void setWriteContent(WriteFileNodeDraft node, String content) {
    node.content = content;
    notifyListeners();
  }

  void addCombineInput(CombineTextNodeDraft node) {
    node.inputs.add(
      WorkflowFileDraft(
        storage: WorkflowStorage.source,
        relativePath: '',
        format: WorkflowFileFormat.plainText,
      ),
    );
    notifyListeners();
  }

  void removeCombineInput(CombineTextNodeDraft node, int index) {
    node.inputs.removeAt(index);
    notifyListeners();
  }

  void moveCombineInput(
    CombineTextNodeDraft node,
    int fromIndex,
    int toIndex,
  ) {
    if (toIndex < 0 || toIndex >= node.inputs.length) {
      return;
    }

    final input = node.inputs.removeAt(fromIndex);
    node.inputs.insert(toIndex, input);
    notifyListeners();
  }

  void fileChanged() {
    notifyListeners();
  }

  WorkflowDraftBuildResult buildDefinition() {
    return draft.buildDefinition();
  }

  WorkflowNodeDraft? _nodeById(String nodeId) {
    for (final node in draft.nodes) {
      if (node.id == nodeId) {
        return node;
      }
    }

    return null;
  }

  void _clearConnectionsTo(String removedNodeId) {
    for (final node in draft.nodes) {
      switch (node) {
        case StartNodeDraft():
          if (node.nextNodeId == removedNodeId) {
            node.nextNodeId = null;
          }
          break;

        case ActionNodeDraft():
          if (node.nextNodeId == removedNodeId) {
            node.nextNodeId = null;
          }
          break;

        case CounterDecisionNodeDraft():
          if (node.continueNodeId == removedNodeId) {
            node.continueNodeId = null;
          }
          if (node.finishedNodeId == removedNodeId) {
            node.finishedNodeId = null;
          }
          break;

        case EndNodeDraft():
          break;
      }
    }
  }

  WorkflowNodePosition _nextPosition(int nodeNumber) {
    final column = (nodeNumber - 1) % 3;
    final row = (nodeNumber - 1) ~/ 3;

    return WorkflowNodePosition(
      x: 300 + (column * 250),
      y: 80 + (row * 160),
    );
  }

  static int _nextNodeNumberFor(WorkflowDraft draft) {
    var highestNumber = 0;

    for (final node in draft.nodes) {
      final match = RegExp(r'^node-(\d+)$').firstMatch(node.id);
      if (match == null) {
        continue;
      }

      final number = int.parse(match.group(1)!);
      if (number > highestNumber) {
        highestNumber = number;
      }
    }

    return highestNumber + 1;
  }

  static WorkflowDraft _createInitialDraft() {
    return WorkflowDraft(
      id: 'workflow-${DateTime.now().microsecondsSinceEpoch}',
      name: 'New workflow',
      nodes: [
        StartNodeDraft(
          id: 'start',
          name: 'Start',
          position: const WorkflowNodePosition(x: 40, y: 80),
          nextNodeId: 'end',
        ),
        EndNodeDraft(
          id: 'end',
          name: 'End',
          position: const WorkflowNodePosition(x: 760, y: 80),
        ),
      ],
    );
  }
}
