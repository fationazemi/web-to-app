import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sketch/app.dart';
import 'package:sketch/data/drawing_repository.dart';
import 'package:sketch/screens/ai_screen.dart';
import 'package:sketch/settings/app_settings.dart';

void main() {
  Widget app({required http.Client client, bool configured = true}) {
    final settings = AppSettings();
    if (configured) settings.setAiApiKey('sk-test');
    return SketchApp(settings: settings, repository: DrawingRepository(), aiClient: client);
  }

  testWidgets('asks for setup when no key is configured', (tester) async {
    await tester.pumpWidget(app(client: MockClient((_) async => http.Response('', 500)), configured: false));
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sketch AI').first);
    await tester.pumpAndSettle();
    expect(find.text('Connect Sketch AI'), findsOneWidget);
  });

  testWidgets('ideas wizard renders suggestions from the API', (tester) async {
    // Tall viewport so the whole wizard and the results render without scrolling.
    tester.view.physicalSize = const Size(600, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['messages'][0]['content'], contains('Playful'));
      return http.Response(
        jsonEncode({
          'stop_reason': 'end_turn',
          'content': [
            {
              'type': 'text',
              'text': jsonEncode({
                'ideas': [
                  {
                    'title': 'Dancing teapot',
                    'description': 'A teapot mid-twirl.',
                    'difficulty': 'beginner',
                    'estimated_minutes': 15,
                    'steps': ['Draw the body', 'Add the spout'],
                    'palette': ['#E53935'],
                  }
                ]
              }),
            }
          ],
        }),
        200,
      );
    });
    await tester.pumpWidget(app(client: client));
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sketch AI').first);
    await tester.pumpAndSettle();
    expect(find.byType(AiScreen), findsOneWidget);

    await tester.tap(find.text('Playful'));
    await tester.pump();
    await tester.tap(find.text('Suggest ideas'));
    await tester.pumpAndSettle();

    expect(find.text('Dancing teapot'), findsOneWidget);
    expect(find.text('Draw this'), findsOneWidget);
    expect(find.textContaining('1 / 5 today'), findsOneWidget);

    // "Draw this" opens the editor with the idea as a step-by-step guide.
    await tester.tap(find.text('Draw this'));
    await tester.pumpAndSettle();
    expect(find.textContaining('step 1 of 2'), findsOneWidget);
    expect(find.text('Draw the body'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Add the spout'), findsOneWidget);
  });
}
