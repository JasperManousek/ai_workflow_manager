import 'package:ai_workflow_manager/screens/workflows_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Counter Decision can be selected, edited, and moved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WorkflowsScreen())),
    );

    await tester.tap(find.text('Counter Decision'));
    await tester.pump();

    final counterCard = find.byKey(
      const ValueKey('workflow-node-node-1'),
    );
    expect(counterCard, findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('workflow-node-start')));
    await tester.pump();
    expect(find.text('Counter limit'), findsNothing);

    await tester.tap(counterCard);
    await tester.pump();
    expect(find.text('Counter limit'), findsOneWidget);
    expect(find.textContaining('Continue: count < 3'), findsWidgets);
    expect(find.textContaining('Finished: count ≥ 3'), findsWidgets);

    final before = tester.getTopLeft(counterCard);
    await tester.drag(counterCard, const Offset(60, 40));
    await tester.pump();
    final after = tester.getTopLeft(counterCard);

    expect(after.dx, greaterThan(before.dx));
    expect(after.dy, greaterThan(before.dy));
  });
}
