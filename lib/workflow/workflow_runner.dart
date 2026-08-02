import 'dart:convert';

import 'package:path/path.dart' as path;

import 'files/workflow_file_access_event.dart';
import 'files/workflow_file_reference.dart';
import 'files/workflow_file_repository.dart';
import 'files/workflow_file_roots.dart';
import 'model/workflow_definition.dart';
import 'model/workflow_node.dart';
import 'workflow_validator.dart';

class WorkflowRunner {
  WorkflowRunner({
    required this.roots,
    this.onNodeStarted,
    this.onFileAccessEvent = _ignoreFileAccessEvent,
  });

  final WorkflowFileRoots roots;
  final void Function(String nodeId, String nodeName)? onNodeStarted;
  final WorkflowFileAccessEventSink onFileAccessEvent;

  Future<void> run(WorkflowDefinition workflow) async {
    WorkflowValidator.validate(workflow);

    final nodesById = {
      for (final node in workflow.nodes) node.id: node,
    };

    WorkflowNode currentNode = workflow.nodes.whereType<StartNode>().single;
    var nodeExecutionSequence = 0;

    while (true) {
      nodeExecutionSequence++;
      final nodeExecutionId = 'node-execution-$nodeExecutionSequence';

      try {
        onNodeStarted?.call(currentNode.id, currentNode.name);

        if (currentNode is StartNode) {
          currentNode = nodesById[currentNode.nextNodeId]!;
          continue;
        }

        if (currentNode is EndNode) {
          return;
        }

        final repository = WorkflowFileRepository(
          roots: roots,
          nodeId: currentNode.id,
          nodeExecutionId: nodeExecutionId,
          onEvent: onFileAccessEvent,
        );

        if (currentNode is WriteFileNode) {
          await repository.writeText(
            currentNode.output,
            currentNode.content,
          );

          currentNode = nodesById[currentNode.nextNodeId]!;
          continue;
        }

        if (currentNode is CombineTextNode) {
          final combinedContent = StringBuffer();

          for (final input in currentNode.inputs) {
            combinedContent.write(
              await repository.readText(input),
            );
          }

          await repository.writeText(
            currentNode.output,
            combinedContent.toString(),
          );

          currentNode = nodesById[currentNode.nextNodeId]!;
          continue;
        }

        if (currentNode is CounterDecisionNode) {
          final shouldContinue = await _incrementCounter(
            currentNode,
            repository,
          );

          final nextNodeId = shouldContinue
              ? currentNode.continueNodeId
              : currentNode.finishedNodeId;

          currentNode = nodesById[nextNodeId]!;
          continue;
        }

        throw StateError(
          'Unsupported node type "${currentNode.runtimeType}".',
        );
      } catch (error, stackTrace) {
        final exception = WorkflowExecutionException(
          nodeId: currentNode.id,
          nodeName: currentNode.name,
          nodeExecutionId: nodeExecutionId,
          cause: error,
        );

        Error.throwWithStackTrace(exception, stackTrace);
      }
    }
  }

  Future<bool> _incrementCounter(
    CounterDecisionNode node,
    WorkflowFileRepository repository,
  ) async {
    final reference = WorkflowFileReference(
      storage: WorkflowStorage.execution,
      relativePath: path.join(
        workflowInternalDirectoryName,
        'counters',
        '${_encodeCounterName(node.name)}.json',
      ),
      format: WorkflowFileFormat.json,
    );

    var currentValue = 0;

    if (await repository.exists(reference)) {
      final storedValue = await repository.readJson(reference);
      currentValue = _readCounterValue(
        node.name,
        storedValue,
      );
    }

    final newValue = currentValue + 1;

    await repository.writeJson(
      reference,
      {'value': newValue},
    );

    return newValue < node.limit;
  }

  int _readCounterValue(
    String counterName,
    Object? storedValue,
  ) {
    if (storedValue is Map<String, dynamic>) {
      final value = storedValue['value'];

      if (value is int && value >= 0) {
        return value;
      }
    }

    throw WorkflowCounterStateException(
      'The internal state for counter "$counterName" is invalid.',
    );
  }

  String _encodeCounterName(String name) {
    return base64Url.encode(utf8.encode(name)).replaceAll('=', '');
  }
}

Future<void> _ignoreFileAccessEvent(WorkflowFileAccessEvent event) async {}

class WorkflowExecutionException implements Exception {
  const WorkflowExecutionException({
    required this.nodeId,
    required this.nodeName,
    required this.nodeExecutionId,
    required this.cause,
  });

  final String nodeId;
  final String nodeName;
  final String nodeExecutionId;
  final Object cause;

  @override
  String toString() {
    return 'WorkflowExecutionException: node "$nodeName" ($nodeId), '
        'execution "$nodeExecutionId" failed: $cause';
  }
}

class WorkflowCounterStateException implements Exception {
  const WorkflowCounterStateException(this.message);

  final String message;

  @override
  String toString() {
    return 'WorkflowCounterStateException: $message';
  }
}
