import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sketch/app.dart';
import 'package:sketch/data/drawing_repository.dart';
import 'package:sketch/settings/app_settings.dart';
import 'package:sketch/widgets/sketch_canvas.dart';

void main() {
  // Neither store is loaded, so no platform channels are touched.
  Widget app() => SketchApp(settings: AppSettings(), repository: DrawingRepository());

  testWidgets('home shows the hero card, templates and tip', (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('Good ideas\nstart here.'), findsOneWidget);
    expect(find.text('Start Drawing'), findsOneWidget);
    expect(find.text('Blank Canvas'), findsOneWidget);
    expect(find.text('Dots'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Small sketches today'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Small sketches today'), findsOneWidget);
  });

  testWidgets('drawing a stroke enables undo and shows the tools', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('Start Drawing'));
    await tester.pumpAndSettle();

    expect(find.text('Pen'), findsOneWidget);
    expect(find.text('Brush'), findsOneWidget);
    expect(find.text('Eraser'), findsOneWidget);
    expect(find.text('Fill'), findsOneWidget);
    expect(find.text('Clear Canvas'), findsOneWidget);
    expect(find.text('Start drawing'), findsOneWidget);

    final center = tester.getCenter(find.byType(SketchCanvas));
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(40, 30));
    await gesture.moveBy(const Offset(40, 30));
    await gesture.up();
    await tester.pumpAndSettle();

    // The hint fades out once the canvas has content.
    final hint = tester.widget<AnimatedOpacity>(
      find.ancestor(of: find.text('Start drawing'), matching: find.byType(AnimatedOpacity)),
    );
    expect(hint.opacity, 0);

    // Leaving with unsaved changes asks to save.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Save your sketch?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Start Drawing'), findsOneWidget);
  });

  testWidgets('keyboard shortcuts undo and switch tools', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('Start Drawing'));
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(SketchCanvas));
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(50, 20));
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pump();
    final brushLabel = tester.widget<Text>(find.text('Brush'));
    expect(brushLabel.style?.color, Theme.of(tester.element(find.text('Brush'))).colorScheme.onPrimary);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    final hint = tester.widget<AnimatedOpacity>(
      find.ancestor(of: find.text('Start drawing'), matching: find.byType(AnimatedOpacity)),
    );
    expect(hint.opacity, 1);
  });

  testWidgets('wide screens use a navigation rail and a side toolbar', (tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(BottomAppBar), findsNothing);

    await tester.tap(find.text('Start Drawing'));
    await tester.pumpAndSettle();
    // Side toolbar: the canvas and the tool strip sit side by side.
    final canvasRect = tester.getRect(find.byType(SketchCanvas));
    final toolsRect = tester.getRect(find.text('Clear Canvas'));
    expect(toolsRect.left, greaterThan(canvasRect.right));
  });

  testWidgets('bottom navigation switches tabs', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('My Drawings'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing here yet'), findsOneWidget);

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('PROMPT OF THE DAY'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Upgrade to Sketch Pro'), findsOneWidget);
  });
}
