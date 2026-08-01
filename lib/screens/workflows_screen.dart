import 'package:flutter/material.dart';

import '../workflow/editor/workflow_draft.dart';
import '../workflow/editor/workflow_editor_controller.dart';
import '../workflow/files/workflow_file_reference.dart';

const double _nodeCardWidth = 220;
const double _nodeCardHeight = 112;

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
              'Start and End are created automatically. Select a node to '
              'configure files and runtime connections.',
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

class _WorkflowCanvas extends StatelessWidget {
  const _WorkflowCanvas({required this.controller});

  final WorkflowEditorController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _WorkflowConnectionsPainter(
                      nodes: controller.draft.nodes,
                      lineColor: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                for (final node in controller.draft.nodes)
                  Positioned(
                    left: node.position.x,
                    top: node.position.y,
                    width: _nodeCardWidth,
                    height: _nodeCardHeight,
                    child: GestureDetector(
                      onTap: () => controller.selectNode(node.id),
                      onPanUpdate: (details) {
                        controller.moveNode(
                          node.id,
                          details.delta.dx,
                          details.delta.dy,
                          canvasWidth: constraints.maxWidth,
                          canvasHeight: constraints.maxHeight,
                          nodeWidth: _nodeCardWidth,
                          nodeHeight: _nodeCardHeight,
                        );
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.move,
                        child: _WorkflowNodeCard(
                          node: node,
                          selected: controller.selectedNodeId == node.id,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
      CounterDecisionNodeDraft() => 'Decision · Counter',
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
        _ConnectionField(
          label: 'Next node',
          selectedNodeId: node.nextNodeId,
          nodes: controller.draft.nodes,
          onChanged: (value) => controller.setStartNextNode(node, value),
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
        _ConnectionField(
          label: 'Next node',
          selectedNodeId: node.nextNodeId,
          nodes: controller.draft.nodes,
          onChanged: (value) => controller.setNextNode(node, value),
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
        _ConnectionField(
          label: 'Next node',
          selectedNodeId: node.nextNodeId,
          nodes: controller.draft.nodes,
          onChanged: (value) => controller.setNextNode(node, value),
        ),
      ],
      CounterDecisionNodeDraft() => [
        const Text(
          'Counter nodes with exactly the same name share one internal '
          'counter during a run.',
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
        _ConnectionField(
          label: 'Continue node',
          selectedNodeId: node.continueNodeId,
          nodes: controller.draft.nodes,
          onChanged: (value) =>
              controller.setCounterContinueNode(node, value),
        ),
        const SizedBox(height: 16),
        _ConnectionField(
          label: 'Finished node',
          selectedNodeId: node.finishedNodeId,
          nodes: controller.draft.nodes,
          onChanged: (value) =>
              controller.setCounterFinishedNode(node, value),
        ),
      ],
      EndNodeDraft() => [
        const Text('The workflow completes successfully when it reaches End.'),
      ],
    };
  }
}

class _ConnectionField extends StatelessWidget {
  const _ConnectionField({
    required this.label,
    required this.selectedNodeId,
    required this.nodes,
    required this.onChanged,
  });

  final String label;
  final String? selectedNodeId;
  final List<WorkflowNodeDraft> nodes;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final possibleTargets = nodes
        .where((node) => node is! StartNodeDraft)
        .toList(growable: false);

    return DropdownButtonFormField<String>(
      value: selectedNodeId,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Not connected'),
        ),
        for (final node in possibleTargets)
          DropdownMenuItem<String>(
            value: node.id,
            child: Text('${node.name} (${node.id})'),
          ),
      ],
      onChanged: onChanged,
    );
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

class _WorkflowConnectionsPainter extends CustomPainter {
  _WorkflowConnectionsPainter({
    required this.nodes,
    required this.lineColor,
  });

  final List<WorkflowNodeDraft> nodes;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final nodesById = {for (final node in nodes) node.id: node};
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final node in nodes) {
      for (final targetId in _targetNodeIds(node)) {
        final target = nodesById[targetId];
        if (target == null) {
          continue;
        }

        final start = Offset(
          node.position.x + _nodeCardWidth,
          node.position.y + (_nodeCardHeight / 2),
        );
        final end = Offset(
          target.position.x,
          target.position.y + (_nodeCardHeight / 2),
        );
        final horizontalDistance = (end.dx - start.dx).abs();
        final controlOffset = horizontalDistance.clamp(60, 180).toDouble();

        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..cubicTo(
            start.dx + controlOffset,
            start.dy,
            end.dx - controlOffset,
            end.dy,
            end.dx,
            end.dy,
          );

        canvas.drawPath(path, paint);
        _drawArrow(canvas, paint, end);
      }
    }
  }

  void _drawArrow(Canvas canvas, Paint paint, Offset end) {
    final arrow = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(end.dx - 10, end.dy - 6)
      ..moveTo(end.dx, end.dy)
      ..lineTo(end.dx - 10, end.dy + 6);
    canvas.drawPath(arrow, paint);
  }

  List<String> _targetNodeIds(WorkflowNodeDraft node) {
    return switch (node) {
      StartNodeDraft() => _nonNullNodeIds([node.nextNodeId]),
      ActionNodeDraft() => _nonNullNodeIds([node.nextNodeId]),
      CounterDecisionNodeDraft() => _nonNullNodeIds([
        node.continueNodeId,
        node.finishedNodeId,
      ]),
      EndNodeDraft() => const [],
    };
  }

  List<String> _nonNullNodeIds(List<String?> nodeIds) {
    return nodeIds.whereType<String>().toList(growable: false);
  }

  @override
  bool shouldRepaint(covariant _WorkflowConnectionsPainter oldDelegate) {
    return true;
  }
}
