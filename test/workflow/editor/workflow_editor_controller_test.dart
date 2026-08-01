import 'package:ai_workflow_manager/workflow/editor/workflow_draft.dart';
import 'package:ai_workflow_manager/workflow/editor/workflow_editor_controller.dart';
import 'package:ai_workflow_manager/workflow/files/workflow_file_reference.dart';
import 'package:ai_workflow_manager/workflow/model/workflow_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts with a valid Start to End workflow', () {
    final controller = WorkflowEditorController();
    addTearDown(controller.dispose);

    final result = controller.buildDefinition();

    expect(result.isValid, isTrue);
    expect(result.definition!.nodes.whereType<StartNode>(), hasLength(1));
    expect(result.definition!.nodes.whereType<EndNode>(), hasLength(1));
  });

  test('builds a configured Write File workflow', () {
    final controller = WorkflowEditorController();
    addTearDown(controller.dispose);

    controller.addNode(WorkflowNodeDraftType.writeFile);
    final writeNode = controller.selectedNode! as WriteFileNodeDraft;
    final startNode = controller.draft.nodes.whereType<StartNodeDraft>().single;

    controller.setStartNextNode(startNode, writeNode.id);
    controller.setNextNode(writeNode, 'end');
    controller.setWriteContent(writeNode, 'Hello workflow');
    writeNode.output.relativePath = 'generated/hello.txt';
    controller.fileChanged();

    final result = controller.buildDefinition();

    expect(result.errors, isEmpty);
    final runtimeNode = result.definition!.nodes.whereType<WriteFileNode>().single;
    expect(runtimeNode.content, 'Hello workflow');
    expect(runtimeNode.output.relativePath, 'generated/hello.txt');
  });

  test('preserves Combine Text input order', () {
    final controller = WorkflowEditorController();
    addTearDown(controller.dispose);

    controller.addNode(WorkflowNodeDraftType.combineText);
    final combineNode = controller.selectedNode! as CombineTextNodeDraft;
    final startNode = controller.draft.nodes.whereType<StartNodeDraft>().single;

    controller.setStartNextNode(startNode, combineNode.id);
    controller.setNextNode(combineNode, 'end');

    combineNode.inputs[0]
      ..storage = WorkflowStorage.source
      ..relativePath = 'second.md'
      ..format = WorkflowFileFormat.markdown;
    combineNode.inputs[1]
      ..storage = WorkflowStorage.source
      ..relativePath = 'first.txt'
      ..format = WorkflowFileFormat.plainText;
    combineNode.output
      ..storage = WorkflowStorage.working
      ..relativePath = 'combined.md'
      ..format = WorkflowFileFormat.markdown;

    final result = controller.buildDefinition();

    expect(result.isValid, isTrue);
    final runtimeNode =
        result.definition!.nodes.whereType<CombineTextNode>().single;
    expect(
      runtimeNode.inputs.map((input) => input.relativePath),
      ['second.md', 'first.txt'],
    );
  });

  test('allows Counter Decision nodes to share a name', () {
    final controller = WorkflowEditorController();
    addTearDown(controller.dispose);

    controller.addNode(WorkflowNodeDraftType.counterDecision);
    final firstCounter = controller.selectedNode! as CounterDecisionNodeDraft;
    controller.addNode(WorkflowNodeDraftType.counterDecision);
    final secondCounter = controller.selectedNode! as CounterDecisionNodeDraft;
    final startNode = controller.draft.nodes.whereType<StartNodeDraft>().single;

    controller.renameNode(firstCounter, 'shared-counter');
    controller.renameNode(secondCounter, 'shared-counter');
    controller.setStartNextNode(startNode, firstCounter.id);
    controller.setCounterContinueNode(firstCounter, secondCounter.id);
    controller.setCounterFinishedNode(firstCounter, 'end');
    controller.setCounterContinueNode(secondCounter, firstCounter.id);
    controller.setCounterFinishedNode(secondCounter, 'end');

    final result = controller.buildDefinition();

    expect(result.isValid, isTrue);
    expect(
      result.definition!.nodes
          .whereType<CounterDecisionNode>()
          .map((node) => node.name),
      ['shared-counter', 'shared-counter'],
    );
  });

  test('clears runtime connections when a node is deleted', () {
    final controller = WorkflowEditorController();
    addTearDown(controller.dispose);

    controller.addNode(WorkflowNodeDraftType.writeFile);
    final writeNode = controller.selectedNode! as WriteFileNodeDraft;
    final startNode = controller.draft.nodes.whereType<StartNodeDraft>().single;
    controller.setStartNextNode(startNode, writeNode.id);

    controller.removeSelectedNode();

    expect(startNode.nextNodeId, isNull);
    expect(controller.buildDefinition().isValid, isFalse);
  });
}
