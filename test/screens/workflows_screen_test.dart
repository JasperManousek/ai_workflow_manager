import 'package:ai_workflow_manager/screens/workflows_screen.dart';
import 'package:ai_workflow_manager/storage/application_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ApplicationStore store;

  setUp(() async {
    store = await ApplicationStore.openInMemory();
  });

  tearDown(() async {
    await store.close();
  });

  Future<void> pumpWorkflowsScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkflowsScreen(applicationStore: store),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }


  testWidgets('saved workflow can be reopened from the sidebar', (
    tester,
  ) async {
    await pumpWorkflowsScreen(tester);

    await tester.tap(find.text('Write File'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('workflow-node-node-1')),
      findsOneWidget,
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = (await store.listWorkflows()).single;
    expect(saved.currentVersionNumber, isNull);

    await tester.tap(find.text('New workflow'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('workflow-node-node-1')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(ValueKey('saved-workflow-${saved.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workflow-node-node-1')),
      findsOneWidget,
    );
  });

  testWidgets('Counter Decision can be selected, edited, and moved', (
    tester,
  ) async {
    await pumpWorkflowsScreen(tester);

    await tester.tap(find.text('Counter Decision'));
    await tester.pump();

    final counterCard = find.byKey(
      const ValueKey('workflow-node-node-1'),
    );
    expect(counterCard, findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('workflow-node-start')));
    await tester.pump();
    expect(find.text('Counter limit'), findsNothing);

    final selectionGesture = await tester.startGesture(
      tester.getCenter(counterCard),
    );
    await tester.pump();
    expect(find.text('Counter limit'), findsOneWidget);
    await selectionGesture.up();
    await tester.pump();

    expect(find.textContaining('Continue: count < 3'), findsWidgets);
    expect(find.textContaining('Finished: count ≥ 3'), findsWidgets);

    final before = tester.getTopLeft(counterCard);
    await tester.drag(counterCard, const Offset(60, 40));
    await tester.pump();
    final after = tester.getTopLeft(counterCard);

    expect(after.dx, greaterThan(before.dx));
    expect(after.dy, greaterThan(before.dy));
  });

  testWidgets('Counter Decision branch handles create connections', (
    tester,
  ) async {
    await pumpWorkflowsScreen(tester);

    await tester.tap(find.text('Counter Decision'));
    await tester.pump();

    final continuePort = find.byKey(
      const ValueKey('flow-output-node-1-continueBranch'),
    );
    final endNode = find.byKey(const ValueKey('workflow-node-end'));

    expect(continuePort, findsOneWidget);
    expect(endNode, findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(continuePort),
    );
    await gesture.moveTo(tester.getCenter(endNode));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(find.text('End (end)'), findsOneWidget);
  });

  testWidgets('A node remains draggable after it overlaps End', (
    tester,
  ) async {
    await pumpWorkflowsScreen(tester);

    await tester.tap(find.text('Write File'));
    await tester.pump();

    final writeNode = find.byKey(
      const ValueKey('workflow-node-node-1'),
    );
    final endNode = find.byKey(const ValueKey('workflow-node-end'));

    final firstStart = tester.getCenter(writeNode);
    final endCenter = tester.getCenter(endNode);
    await tester.dragFrom(firstStart, endCenter - firstStart);
    await tester.pump();

    final overlappedPosition = tester.getTopLeft(writeNode);
    final endPosition = tester.getTopLeft(endNode);
    expect(
      (overlappedPosition - endPosition).distance,
      lessThan(2),
    );

    await tester.drag(writeNode, const Offset(-140, 90));
    await tester.pump();

    final movedPosition = tester.getTopLeft(writeNode);
    expect(movedPosition.dx, lessThan(overlappedPosition.dx));
    expect(movedPosition.dy, greaterThan(overlappedPosition.dy));
  });
  testWidgets('Dragging empty canvas pans every node', (tester) async {
    await pumpWorkflowsScreen(tester);

    final canvas = find.byKey(const ValueKey('workflow-canvas'));
    final startNode = find.byKey(const ValueKey('workflow-node-start'));

    final before = tester.getTopLeft(startNode);
    final emptyPoint = tester.getTopLeft(canvas) + const Offset(500, 650);
    await tester.dragFrom(emptyPoint, const Offset(90, 60));
    await tester.pump();

    final after = tester.getTopLeft(startNode);
    expect(after.dx, closeTo(before.dx + 90, 1));
    expect(after.dy, closeTo(before.dy + 60, 1));
  });

}
