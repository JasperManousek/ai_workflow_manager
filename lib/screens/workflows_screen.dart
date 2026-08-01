import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../workflow/editor/workflow_draft.dart';
import '../workflow/editor/workflow_editor_controller.dart';
import '../workflow/files/workflow_file_reference.dart';

const double _nodeCardWidth = 220;
const double _nodeCardHeight = 136;

class WorkflowsScreen extends StatefulWidget {
  const WorkflowsScreen({super.key});

  @override
  State<WorkflowsScreen> createState() => _WorkflowsScreenState();
}

class _WorkflowsScreenState extends State<WorkflowsScreen> {
  late final WorkflowEditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WorkflowEditorController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Column(
          children: [
            _WorkflowToolbar(
              controller: _controller,
              onValidate: _showValidationResult,
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  _NodePalette(controller: _controller),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _WorkflowCanvas(controller: _controller),
                  ),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 380,
                    child: _NodeInspector(controller: _controller),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showValidationResult() async {
    final result = _controller.buildDefinition();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            result.isValid ? 'Workflow is valid' : 'Workflow needs attention',
          ),
          content: SizedBox(
            width: 520,
            child: result.isValid
                ? Text(
                    'The workflow contains '
                    '${result.definition!.nodes.length} nodes and can be '
                    'converted into an immutable runtime definition.',
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: result.errors.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(result.errors[index])),
                        ],
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _WorkflowToolbar extends StatelessWidget {
  const _WorkflowToolbar({
    required this.controller,
    required this.onValidate,
  });

  final WorkflowEditorController controller;
  final VoidCallback onValidate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 320,
            child: TextFormField(
              key: ValueKey(controller.draft.id),
              initialValue: controller.draft.name,
              decoration: const InputDecoration(
                labelText: 'Workflow name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: controller.renameWorkflow,
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: controller.createNewWorkflow,
            icon: const Icon(Icons.add),
            label: const Text('New workflow'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onValidate,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Validate'),
          ),
        ],
      ),
    );
  }
}

class _NodePalette extends StatelessWidget {
  const _NodePalette({required this.controller});

  final WorkflowEditorController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add node',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _PaletteButton(
              icon: Icons.description_outlined,
              label: 'Write File',
              onPressed: () => controller.addNode(
                WorkflowNodeDraftType.writeFile,
              ),
            ),
            const SizedBox(height: 8),
            _PaletteButton(
              icon: Icons.call_merge,
              label: 'Combine Text',
              onPressed: () => controller.addNode(
                WorkflowNodeDraftType.combineText,
              ),
            ),
            const SizedBox(height: 8),
            _PaletteButton(
              icon: Icons.alt_route,
              label: 'Counter Decision',
              onPressed: () => controller.addNode(
                WorkflowNodeDraftType.counterDecision,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Start and End are created automatically. Drag flow handles '
              'to connect nodes. Use the mouse wheel to zoom and drag the '
              'empty background to move around the canvas.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PaletteButton extends StatelessWidget {
  const _PaletteButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(label),
      ),
    );
  }
}

enum _RuntimeConnectionKind {
  next,
  continueBranch,
  finishedBranch,
}

class _ConnectionDragState {
  const _ConnectionDragState({
    required this.sourceNodeId,
    required this.kind,
    required this.currentPosition,
  });

  final String sourceNodeId;
  final _RuntimeConnectionKind kind;
  final Offset currentPosition;

  _ConnectionDragState movedTo(Offset position) {
    return _ConnectionDragState(
      sourceNodeId: sourceNodeId,
      kind: kind,
      currentPosition: position,
    );
  }
}

class _NodeDragState {
  const _NodeDragState({
    required this.nodeId,
    required this.lastScenePosition,
  });

  final String nodeId;
  final Offset lastScenePosition;

  _NodeDragState movedTo(Offset position) {
    return _NodeDragState(
      nodeId: nodeId,
      lastScenePosition: position,
    );
  }
}

class _WorkflowCanvas extends StatefulWidget {
  const _WorkflowCanvas({required this.controller});

  final WorkflowEditorController controller;

  @override
  State<_WorkflowCanvas> createState() => _WorkflowCanvasState();
}

class _WorkflowCanvasState extends State<_WorkflowCanvas> {
  static const double _sceneWidth = 4000;
  static const double _sceneHeight = 2600;
  static const double _minimumScale = 0.35;
  static const double _maximumScale = 2.5;
  static const double _nodePortInset = 18;

  final GlobalKey _canvasKey = GlobalKey();

  double _scale = 1;
  Offset _panOffset = Offset.zero;
  _ConnectionDragState? _connectionDrag;
  _NodeDragState? _nodeDrag;
  String? _connectionTargetNodeId;

  WorkflowEditorController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Listener(
      key: _canvasKey,
      behavior: HitTestBehavior.translucent,
      onPointerSignal: _handlePointerSignal,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => controller.selectNode(null),
                onPanUpdate: (details) {
                  setState(() {
                    _panOffset += details.delta;
                  });
                },
                child: ColoredBox(
                  color: colorScheme.surfaceContainerLowest,
                ),
              ),
            ),
            Transform.translate(
              offset: _panOffset,
              child: Transform.scale(
                scale: _scale,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: _sceneWidth,
                  height: _sceneHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _WorkflowConnectionsPainter(
                              nodes: controller.draft.nodes,
                              lineColor: colorScheme.outline,
                              continueColor: colorScheme.primary,
                              finishedColor: colorScheme.error,
                              drag: _connectionDrag,
                              highlightedTargetNodeId:
                                  _connectionTargetNodeId,
                            ),
                          ),
                        ),
                      ),
                      for (final node in controller.draft.nodes)
                        Positioned(
                          left: node.position.x - _nodePortInset,
                          top: node.position.y,
                          width: _nodeCardWidth + (_nodePortInset * 2),
                          height: _nodeCardHeight,
                          child: _WorkflowNodeWidget(
                            node: node,
                            selected: controller.selectedNodeId == node.id,
                            highlightedAsTarget:
                                _connectionTargetNodeId == node.id,
                            onSelect: () => controller.selectNode(node.id),
                            onNodeDragStart: (details) =>
                                _startNodeDrag(node, details),
                            onNodeDragUpdate: _updateNodeDrag,
                            onNodeDragEnd: _endNodeDrag,
                            onConnectionDragStart: (kind, details) =>
                                _startConnectionDrag(node, kind, details),
                            onConnectionDragUpdate: _updateConnectionDrag,
                            onConnectionDragEnd: _endConnectionDrag,
                            onConnectionDragCancel: _cancelConnectionDrag,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border.all(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text('${(_scale * 100).round()}%'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }

    final zoomFactor = math.exp(-event.scrollDelta.dy / 500);
    final nextScale = (_scale * zoomFactor)
        .clamp(_minimumScale, _maximumScale)
        .toDouble();

    if ((nextScale - _scale).abs() < 0.001) {
      return;
    }

    final focalPoint = event.localPosition;
    final scenePoint = _viewportToScene(focalPoint);

    setState(() {
      _scale = nextScale;
      _panOffset = focalPoint - (scenePoint * nextScale);
    });
  }

  void _startNodeDrag(
    WorkflowNodeDraft node,
    DragStartDetails details,
  ) {
    controller.selectNode(node.id);
    _nodeDrag = _NodeDragState(
      nodeId: node.id,
      lastScenePosition: _globalToScene(details.globalPosition),
    );
  }

  void _updateNodeDrag(DragUpdateDetails details) {
    final drag = _nodeDrag;
    if (drag == null) {
      return;
    }

    final nextScenePosition = _globalToScene(details.globalPosition);
    final delta = nextScenePosition - drag.lastScenePosition;
    _nodeDrag = drag.movedTo(nextScenePosition);

    controller.moveNode(
      drag.nodeId,
      delta.dx,
      delta.dy,
      canvasWidth: _sceneWidth,
      canvasHeight: _sceneHeight,
      nodeWidth: _nodeCardWidth,
      nodeHeight: _nodeCardHeight,
    );
  }

  void _endNodeDrag(DragEndDetails details) {
    _nodeDrag = null;
  }

  void _startConnectionDrag(
    WorkflowNodeDraft node,
    _RuntimeConnectionKind kind,
    DragStartDetails details,
  ) {
    controller.selectNode(node.id);

    setState(() {
      _connectionDrag = _ConnectionDragState(
        sourceNodeId: node.id,
        kind: kind,
        currentPosition: _outputAnchor(node, kind),
      );
      _connectionTargetNodeId = null;
    });
  }

  void _updateConnectionDrag(DragUpdateDetails details) {
    final drag = _connectionDrag;
    if (drag == null) {
      return;
    }

    final scenePosition = _globalToScene(details.globalPosition);
    final targetNodeId = _targetNodeAt(scenePosition);

    setState(() {
      _connectionDrag = drag.movedTo(scenePosition);
      _connectionTargetNodeId = targetNodeId;
    });
  }

  void _endConnectionDrag(DragEndDetails details) {
    final drag = _connectionDrag;
    final targetNodeId = _connectionTargetNodeId;

    if (drag != null && targetNodeId != null) {
      _connect(drag, targetNodeId);
    }

    _cancelConnectionDrag();
  }

  void _cancelConnectionDrag() {
    if (_connectionDrag == null && _connectionTargetNodeId == null) {
      return;
    }

    setState(() {
      _connectionDrag = null;
      _connectionTargetNodeId = null;
    });
  }

  void _connect(_ConnectionDragState drag, String targetNodeId) {
    final sourceNode = _nodeById(drag.sourceNodeId);
    if (sourceNode == null) {
      return;
    }

    switch (sourceNode) {
      case StartNodeDraft():
        controller.setStartNextNode(sourceNode, targetNodeId);
      case ActionNodeDraft():
        controller.setNextNode(sourceNode, targetNodeId);
      case CounterDecisionNodeDraft():
        switch (drag.kind) {
          case _RuntimeConnectionKind.continueBranch:
            controller.setCounterContinueNode(sourceNode, targetNodeId);
          case _RuntimeConnectionKind.finishedBranch:
            controller.setCounterFinishedNode(sourceNode, targetNodeId);
          case _RuntimeConnectionKind.next:
            break;
        }
      case EndNodeDraft():
        break;
    }
  }

  WorkflowNodeDraft? _nodeById(String nodeId) {
    for (final node in controller.draft.nodes) {
      if (node.id == nodeId) {
        return node;
      }
    }
    return null;
  }

  String? _targetNodeAt(Offset scenePosition) {
    for (final node in controller.draft.nodes.reversed) {
      if (node is StartNodeDraft) {
        continue;
      }

      final nodeBounds = Rect.fromLTWH(
        node.position.x,
        node.position.y,
        _nodeCardWidth,
        _nodeCardHeight,
      );
      if (nodeBounds.inflate(8).contains(scenePosition)) {
        return node.id;
      }
    }

    return null;
  }

  Offset _globalToScene(Offset globalPosition) {
    final renderObject = _canvasKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      return Offset.zero;
    }

    return _viewportToScene(renderObject.globalToLocal(globalPosition));
  }

  Offset _viewportToScene(Offset viewportPosition) {
    return (viewportPosition - _panOffset) / _scale;
  }
}

class _WorkflowNodeWidget extends StatelessWidget {
  const _WorkflowNodeWidget({
    required this.node,
    required this.selected,
    required this.highlightedAsTarget,
    required this.onSelect,
    required this.onNodeDragStart,
    required this.onNodeDragUpdate,
    required this.onNodeDragEnd,
    required this.onConnectionDragStart,
    required this.onConnectionDragUpdate,
    required this.onConnectionDragEnd,
    required this.onConnectionDragCancel,
  });

  static const double _portInset = 18;
  static const double _portHitSize = 30;
  static const double _outputPortOverlap = 2;

  final WorkflowNodeDraft node;
  final bool selected;
  final bool highlightedAsTarget;
  final VoidCallback onSelect;
  final GestureDragStartCallback onNodeDragStart;
  final GestureDragUpdateCallback onNodeDragUpdate;
  final GestureDragEndCallback onNodeDragEnd;
  final void Function(
    _RuntimeConnectionKind kind,
    DragStartDetails details,
  ) onConnectionDragStart;
  final GestureDragUpdateCallback onConnectionDragUpdate;
  final GestureDragEndCallback onConnectionDragEnd;
  final VoidCallback onConnectionDragCancel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: _portInset,
          top: 0,
          width: _nodeCardWidth,
          height: _nodeCardHeight,
          child: GestureDetector(
            key: ValueKey('workflow-node-${node.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: onSelect,
            onPanStart: onNodeDragStart,
            onPanUpdate: onNodeDragUpdate,
            onPanEnd: onNodeDragEnd,
            child: MouseRegion(
              cursor: SystemMouseCursors.move,
              child: _WorkflowNodeCard(
                node: node,
                selected: selected,
              ),
            ),
          ),
        ),
        if (node is! StartNodeDraft)
          Positioned(
            left: _portInset - (_portHitSize / 2),
            top: (_nodeCardHeight / 2) - (_portHitSize / 2),
            width: _portHitSize,
            height: _portHitSize,
            child: _FlowPort(
              tooltip: 'Flow input',
              color: highlightedAsTarget
                  ? colorScheme.primary
                  : colorScheme.outline,
              highlighted: highlightedAsTarget,
            ),
          ),
        ..._outputPorts(context),
      ],
    );
  }

  List<Widget> _outputPorts(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return switch (node) {
      StartNodeDraft() || ActionNodeDraft() => [
        _positionedOutputPort(
          centerY: _nodeCardHeight / 2,
          kind: _RuntimeConnectionKind.next,
          tooltip: 'Drag to connect next node',
          color: colorScheme.outline,
        ),
      ],
      CounterDecisionNodeDraft(limit: final limit) => [
        _positionedOutputPort(
          centerY: 42,
          kind: _RuntimeConnectionKind.continueBranch,
          tooltip: 'Continue when count < $limit',
          color: colorScheme.primary,
          label: 'C',
        ),
        _positionedOutputPort(
          centerY: 94,
          kind: _RuntimeConnectionKind.finishedBranch,
          tooltip: 'Finished when count ≥ $limit',
          color: colorScheme.error,
          label: 'F',
        ),
      ],
      EndNodeDraft() => const [],
    };
  }

  Widget _positionedOutputPort({
    required double centerY,
    required _RuntimeConnectionKind kind,
    required String tooltip,
    required Color color,
    String? label,
  }) {
    return Positioned(
      left: _portInset + _nodeCardWidth - _outputPortOverlap,
      top: centerY - (_portHitSize / 2),
      width: _portHitSize,
      height: _portHitSize,
      child: _FlowPort(
        key: ValueKey('flow-output-${node.id}-${kind.name}'),
        tooltip: tooltip,
        color: color,
        label: label,
        onPanStart: (details) => onConnectionDragStart(kind, details),
        onPanUpdate: onConnectionDragUpdate,
        onPanEnd: onConnectionDragEnd,
        onPanCancel: onConnectionDragCancel,
      ),
    );
  }
}

class _FlowPort extends StatelessWidget {
  const _FlowPort({
    super.key,
    required this.tooltip,
    required this.color,
    this.highlighted = false,
    this.label,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.onPanCancel,
  });

  final String tooltip;
  final Color color;
  final bool highlighted;
  final String? label;
  final GestureDragStartCallback? onPanStart;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragEndCallback? onPanEnd;
  final VoidCallback? onPanCancel;

  @override
  Widget build(BuildContext context) {
    final port = Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: highlighted ? 20 : 16,
        height: highlighted ? 20 : 16,
        decoration: BoxDecoration(
          color: highlighted ? color : Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        alignment: Alignment.center,
        child: label == null
            ? null
            : Text(
                label!,
                style: TextStyle(
                  color: highlighted
                      ? Theme.of(context).colorScheme.onPrimary
                      : color,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );

    if (onPanStart == null) {
      return Tooltip(message: tooltip, child: port);
    }

    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: onPanStart,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          onPanCancel: onPanCancel,
          child: port,
        ),
      ),
    );
  }
}

class _WorkflowNodeCard extends StatelessWidget {
  const _WorkflowNodeCard({
    required this.node,
    required this.selected,
  });

  final WorkflowNodeDraft node;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: selected ? 6 : 2,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              child: Icon(_iconFor(node)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _labelFor(node),
                    maxLines: node is CounterDecisionNodeDraft ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(WorkflowNodeDraft node) {
    return switch (node) {
      StartNodeDraft() => Icons.play_arrow,
      WriteFileNodeDraft() => Icons.description_outlined,
      CombineTextNodeDraft() => Icons.call_merge,
      CounterDecisionNodeDraft() => Icons.alt_route,
      EndNodeDraft() => Icons.stop,
    };
  }

  String _labelFor(WorkflowNodeDraft node) {
    return switch (node) {
      StartNodeDraft() => 'Start',
      WriteFileNodeDraft() => 'Action · Write File',
      CombineTextNodeDraft() => 'Action · Combine Text',
      CounterDecisionNodeDraft() =>
        'Decision · increments on each visit\n'
        'Continue: count < ${node.limit}\n'
        'Finished: count ≥ ${node.limit}',
      EndNodeDraft() => 'End',
    };
  }
}

class _NodeInspector extends StatelessWidget {
  const _NodeInspector({required this.controller});

  final WorkflowEditorController controller;

  @override
  Widget build(BuildContext context) {
    final node = controller.selectedNode;

    if (node == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Select a node to edit its configuration.'),
        ),
      );
    }

    return ListView(
      key: ValueKey(node.id),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Node configuration',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (node is! StartNodeDraft && node is! EndNodeDraft)
              IconButton(
                tooltip: 'Delete node',
                onPressed: controller.removeSelectedNode,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: node.name,
          decoration: const InputDecoration(
            labelText: 'Node name',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => controller.renameNode(node, value),
        ),
        const SizedBox(height: 16),
        ..._configurationFields(context, node),
      ],
    );
  }

  List<Widget> _configurationFields(
    BuildContext context,
    WorkflowNodeDraft node,
  ) {
    return switch (node) {
      StartNodeDraft() => [
        const _ConnectionInstructions(),
        const SizedBox(height: 12),
        _ConnectionSummary(
          label: 'Next node',
          targetNodeId: node.nextNodeId,
          nodes: controller.draft.nodes,
          onClear: () => controller.setStartNextNode(node, null),
        ),
      ],
      WriteFileNodeDraft() => [
        TextFormField(
          initialValue: node.content,
          minLines: 5,
          maxLines: 12,
          decoration: const InputDecoration(
            labelText: 'Text to write',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => controller.setWriteContent(node, value),
        ),
        const SizedBox(height: 16),
        _FileReferenceEditor(
          title: 'Output file',
          file: node.output,
          isOutput: true,
          onChanged: () => controller.fileChanged(),
        ),
        const SizedBox(height: 16),
        const _ConnectionInstructions(),
        const SizedBox(height: 12),
        _ConnectionSummary(
          label: 'Next node',
          targetNodeId: node.nextNodeId,
          nodes: controller.draft.nodes,
          onClear: () => controller.setNextNode(node, null),
        ),
      ],
      CombineTextNodeDraft() => [
        Text(
          'Input files',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < node.inputs.length; index++) ...[
          _CombineInputEditor(
            index: index,
            inputCount: node.inputs.length,
            input: node.inputs[index],
            onChanged: () => controller.fileChanged(),
            onMoveUp: () => controller.moveCombineInput(
              node,
              index,
              index - 1,
            ),
            onMoveDown: () => controller.moveCombineInput(
              node,
              index,
              index + 1,
            ),
            onRemove: () => controller.removeCombineInput(node, index),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: () => controller.addCombineInput(node),
          icon: const Icon(Icons.add),
          label: const Text('Add input file'),
        ),
        const SizedBox(height: 20),
        _FileReferenceEditor(
          title: 'Output file',
          file: node.output,
          isOutput: true,
          onChanged: () => controller.fileChanged(),
        ),
        const SizedBox(height: 16),
        const _ConnectionInstructions(),
        const SizedBox(height: 12),
        _ConnectionSummary(
          label: 'Next node',
          targetNodeId: node.nextNodeId,
          nodes: controller.draft.nodes,
          onClear: () => controller.setNextNode(node, null),
        ),
      ],
      CounterDecisionNodeDraft() => [
        Text(
          'Every visit increments the internal counter named "${node.name}". '
          'Counter nodes with exactly the same name share that counter during '
          'the run.',
        ),
        const SizedBox(height: 8),
        Text(
          'After incrementing: Continue is selected while the new count is '
          'less than ${node.limit}. Finished is selected when the new count '
          'is ${node.limit} or greater.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: node.limit.toString(),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Counter limit',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            controller.setCounterLimit(node, int.tryParse(value) ?? 0);
          },
        ),
        const SizedBox(height: 16),
        const _ConnectionInstructions(
          message: 'Drag C for Continue or F for Finished to a target node.',
        ),
        const SizedBox(height: 12),
        _ConnectionSummary(
          label: 'Continue: count < ${node.limit}',
          targetNodeId: node.continueNodeId,
          nodes: controller.draft.nodes,
          onClear: () => controller.setCounterContinueNode(node, null),
        ),
        const SizedBox(height: 12),
        _ConnectionSummary(
          label: 'Finished: count ≥ ${node.limit}',
          targetNodeId: node.finishedNodeId,
          nodes: controller.draft.nodes,
          onClear: () => controller.setCounterFinishedNode(node, null),
        ),
      ],
      EndNodeDraft() => [
        const Text('The workflow completes successfully when it reaches End.'),
      ],
    };
  }
}

class _ConnectionInstructions extends StatelessWidget {
  const _ConnectionInstructions({
    this.message =
        'Drag the flow handle on the right side of the node to another node.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.drag_indicator, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    );
  }
}

class _ConnectionSummary extends StatelessWidget {
  const _ConnectionSummary({
    required this.label,
    required this.targetNodeId,
    required this.nodes,
    required this.onClear,
  });

  final String label;
  final String? targetNodeId;
  final List<WorkflowNodeDraft> nodes;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final target = _targetNode();

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: targetNodeId == null
            ? null
            : IconButton(
                tooltip: 'Remove connection',
                onPressed: onClear,
                icon: const Icon(Icons.link_off),
              ),
      ),
      child: Text(
        target == null
            ? 'Not connected'
            : '${target.name} (${target.id})',
      ),
    );
  }

  WorkflowNodeDraft? _targetNode() {
    final id = targetNodeId;
    if (id == null) {
      return null;
    }

    for (final node in nodes) {
      if (node.id == id) {
        return node;
      }
    }

    return null;
  }
}

class _CombineInputEditor extends StatelessWidget {
  const _CombineInputEditor({
    required this.index,
    required this.inputCount,
    required this.input,
    required this.onChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final int index;
  final int inputCount;
  final WorkflowFileDraft input;
  final VoidCallback onChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text('Input ${index + 1}')),
                IconButton(
                  tooltip: 'Move up',
                  onPressed: index == 0 ? null : onMoveUp,
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'Move down',
                  onPressed: index == inputCount - 1 ? null : onMoveDown,
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: 'Remove input',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            _FileReferenceEditor(
              title: null,
              file: input,
              isOutput: false,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _FileReferenceEditor extends StatelessWidget {
  const _FileReferenceEditor({
    required this.title,
    required this.file,
    required this.isOutput,
    required this.onChanged,
  });

  final String? title;
  final WorkflowFileDraft file;
  final bool isOutput;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final storageOptions = isOutput
        ? const [WorkflowStorage.working, WorkflowStorage.persistent]
        : WorkflowStorage.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Text(title!, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
        ],
        DropdownButtonFormField<WorkflowStorage>(
          value: file.storage,
          decoration: const InputDecoration(
            labelText: 'Storage',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final storage in storageOptions)
              DropdownMenuItem(
                value: storage,
                child: Text(_storageLabel(storage)),
              ),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            file.storage = value;
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey(file),
          initialValue: file.relativePath,
          decoration: const InputDecoration(
            labelText: 'Relative path',
            hintText: 'folder/file.md',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            file.relativePath = value;
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<WorkflowFileFormat>(
          value: file.format,
          decoration: const InputDecoration(
            labelText: 'Format',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: WorkflowFileFormat.plainText,
              child: Text('Plain text'),
            ),
            DropdownMenuItem(
              value: WorkflowFileFormat.markdown,
              child: Text('Markdown'),
            ),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            file.format = value;
            onChanged();
          },
        ),
      ],
    );
  }

  String _storageLabel(WorkflowStorage storage) {
    return switch (storage) {
      WorkflowStorage.source => 'Source (read-only)',
      WorkflowStorage.working => 'Working',
      WorkflowStorage.persistent => 'Persistent',
    };
  }
}

class _RuntimeConnectionLink {
  const _RuntimeConnectionLink({
    required this.source,
    required this.targetNodeId,
    required this.kind,
  });

  final WorkflowNodeDraft source;
  final String targetNodeId;
  final _RuntimeConnectionKind kind;
}

class _WorkflowConnectionsPainter extends CustomPainter {
  _WorkflowConnectionsPainter({
    required this.nodes,
    required this.lineColor,
    required this.continueColor,
    required this.finishedColor,
    required this.drag,
    required this.highlightedTargetNodeId,
  });

  final List<WorkflowNodeDraft> nodes;
  final Color lineColor;
  final Color continueColor;
  final Color finishedColor;
  final _ConnectionDragState? drag;
  final String? highlightedTargetNodeId;

  @override
  void paint(Canvas canvas, Size size) {
    final nodesById = {for (final node in nodes) node.id: node};

    for (final node in nodes) {
      for (final link in _linksFrom(node)) {
        final target = nodesById[link.targetNodeId];
        if (target == null) {
          continue;
        }

        _drawConnection(
          canvas,
          start: _outputAnchor(link.source, link.kind),
          end: _inputAnchor(target) - const Offset(8, 0),
          color: _colorFor(link.kind),
        );
      }
    }

    final activeDrag = drag;
    if (activeDrag == null) {
      return;
    }

    final source = nodesById[activeDrag.sourceNodeId];
    if (source == null) {
      return;
    }

    var previewEnd = activeDrag.currentPosition;
    final highlightedTarget = nodesById[highlightedTargetNodeId];
    if (highlightedTarget != null) {
      previewEnd = _inputAnchor(highlightedTarget) - const Offset(8, 0);
    }

    _drawConnection(
      canvas,
      start: _outputAnchor(source, activeDrag.kind),
      end: previewEnd,
      color: _colorFor(activeDrag.kind),
    );
  }

  void _drawConnection(
    Canvas canvas, {
    required Offset start,
    required Offset end,
    required Color color,
  }) {
    final horizontalDistance = (end.dx - start.dx).abs();
    final controlOffset = horizontalDistance.clamp(60, 180).toDouble();
    final firstControl = Offset(start.dx + controlOffset, start.dy);
    final secondControl = Offset(end.dx - controlOffset, end.dy);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        firstControl.dx,
        firstControl.dy,
        secondControl.dx,
        secondControl.dy,
        end.dx,
        end.dy,
      );

    canvas.drawPath(path, paint);
    _drawArrow(canvas, paint, secondControl, end);
  }

  void _drawArrow(
    Canvas canvas,
    Paint paint,
    Offset previousPoint,
    Offset end,
  ) {
    final direction = end - previousPoint;
    final distance = direction.distance;
    if (distance == 0) {
      return;
    }

    final unit = direction / distance;
    final perpendicular = Offset(-unit.dy, unit.dx);
    final arrowBase = end - (unit * 10);
    final arrow = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        arrowBase.dx + (perpendicular.dx * 6),
        arrowBase.dy + (perpendicular.dy * 6),
      )
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        arrowBase.dx - (perpendicular.dx * 6),
        arrowBase.dy - (perpendicular.dy * 6),
      );

    canvas.drawPath(arrow, paint);
  }

  Iterable<_RuntimeConnectionLink> _linksFrom(WorkflowNodeDraft node) sync* {
    switch (node) {
      case StartNodeDraft():
        final targetNodeId = node.nextNodeId;
        if (targetNodeId != null) {
          yield _RuntimeConnectionLink(
            source: node,
            targetNodeId: targetNodeId,
            kind: _RuntimeConnectionKind.next,
          );
        }
      case ActionNodeDraft():
        final targetNodeId = node.nextNodeId;
        if (targetNodeId != null) {
          yield _RuntimeConnectionLink(
            source: node,
            targetNodeId: targetNodeId,
            kind: _RuntimeConnectionKind.next,
          );
        }
      case CounterDecisionNodeDraft():
        final continueNodeId = node.continueNodeId;
        if (continueNodeId != null) {
          yield _RuntimeConnectionLink(
            source: node,
            targetNodeId: continueNodeId,
            kind: _RuntimeConnectionKind.continueBranch,
          );
        }

        final finishedNodeId = node.finishedNodeId;
        if (finishedNodeId != null) {
          yield _RuntimeConnectionLink(
            source: node,
            targetNodeId: finishedNodeId,
            kind: _RuntimeConnectionKind.finishedBranch,
          );
        }
      case EndNodeDraft():
        break;
    }
  }

  Color _colorFor(_RuntimeConnectionKind kind) {
    return switch (kind) {
      _RuntimeConnectionKind.next => lineColor,
      _RuntimeConnectionKind.continueBranch => continueColor,
      _RuntimeConnectionKind.finishedBranch => finishedColor,
    };
  }

  @override
  bool shouldRepaint(covariant _WorkflowConnectionsPainter oldDelegate) {
    return true;
  }
}

Offset _inputAnchor(WorkflowNodeDraft node) {
  return Offset(
    node.position.x,
    node.position.y + (_nodeCardHeight / 2),
  );
}

Offset _outputAnchor(
  WorkflowNodeDraft node,
  _RuntimeConnectionKind kind,
) {
  final centerY = switch (kind) {
    _RuntimeConnectionKind.next => _nodeCardHeight / 2,
    _RuntimeConnectionKind.continueBranch => 42.0,
    _RuntimeConnectionKind.finishedBranch => 94.0,
  };

  const outputPortCenterOffset =
      _WorkflowNodeWidget._portHitSize / 2 -
      _WorkflowNodeWidget._outputPortOverlap;

  return Offset(
    node.position.x + _nodeCardWidth + outputPortCenterOffset,
    node.position.y + centerY,
  );
}
