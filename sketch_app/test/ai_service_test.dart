import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sketch/ai/ai_service.dart';
import 'package:sketch/models/ai.dart';

void main() {
  const config = AiConfig(apiKey: 'sk-test');

  http.Response ok(Map<String, dynamic> structured) => http.Response(
        jsonEncode({
          'stop_reason': 'end_turn',
          'content': [
            {'type': 'text', 'text': jsonEncode(structured)}
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );

  test('suggestIdeas sends the right request and parses ideas', () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return ok({
        'ideas': [
          {
            'title': 'Paper boat',
            'description': 'A boat on a puddle.',
            'difficulty': 'beginner',
            'estimated_minutes': 10,
            'steps': ['Draw a trapezoid', 'Add a sail'],
            'palette': ['#1E88E5', '#FFFFFF'],
          }
        ]
      });
    });
    final service = AiService(config: config, client: client);
    final ideas = await service.suggestIdeas(const IdeaBrief(mood: 'calm', minutes: 10, subject: 'water'));

    expect(ideas, hasLength(1));
    expect(ideas.single.title, 'Paper boat');
    expect(ideas.single.difficulty, IdeaDifficulty.beginner);
    expect(ideas.single.steps, hasLength(2));

    final req = captured!;
    expect(req.url.toString(), 'https://api.anthropic.com/v1/messages');
    expect(req.headers['x-api-key'], 'sk-test');
    expect(req.headers['anthropic-version'], '2023-06-01');
    expect(req.headers['anthropic-beta'], 'server-side-fallback-2026-07-01');
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    expect(body['model'], 'claude-opus-5');
    expect(body['fallbacks'], 'default');
    expect(body['output_config']['format']['type'], 'json_schema');
    expect(body['output_config']['effort'], 'medium');
    expect(body.containsKey('thinking'), isFalse);
    expect(body['messages'][0]['content'], contains('calm'));
    expect(body['messages'][0]['content'], contains('water'));
  });

  test('critique sends the image as base64 and parses feedback', () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return ok({
        'summary': 'Nice start.',
        'strengths': ['Confident lines'],
        'improvements': [
          {'title': 'Contrast', 'detail': 'Darken the shadow side.'}
        ],
        'next_exercise': 'Draw ten cubes.',
      });
    });
    final service = AiService(config: config, client: client);
    final png = Uint8List.fromList([1, 2, 3]);
    final feedback = await service.critique(png, title: 'Cube');

    expect(feedback.summary, 'Nice start.');
    expect(feedback.improvements.single.title, 'Contrast');
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    final content = body['messages'][0]['content'] as List<dynamic>;
    expect(content[0]['type'], 'image');
    expect(content[0]['source']['media_type'], 'image/png');
    expect(content[0]['source']['data'], base64Encode(png));
    expect(content[1]['text'], contains('Cube'));
  });

  test('tutorial parses steps', () async {
    final client = MockClient((_) async => ok({
          'title': 'A cat',
          'steps': [
            {'instruction': 'Draw a circle for the head.', 'tip': 'Keep it light.'},
            {'instruction': 'Add two triangles for ears.', 'tip': 'Same size.'},
          ]
        }));
    final tutorial = await AiService(config: config, client: client).tutorial('a cat');
    expect(tutorial.title, 'A cat');
    expect(tutorial.steps, hasLength(2));
    expect(tutorial.steps.first.instruction, contains('circle'));
  });

  test('chat streams text deltas from SSE', () async {
    final sse = [
      'event: message_start',
      'data: {"type":"message_start","message":{"id":"msg_1"}}',
      '',
      'event: content_block_delta',
      'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Draw "}}',
      '',
      'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"a cat."}}',
      '',
      'data: {"type":"message_delta","delta":{"stop_reason":"end_turn"}}',
      '',
      'data: {"type":"message_stop"}',
    ].join('\n');
    http.BaseRequest? captured;
    final client = MockClient.streaming((request, bodyStream) async {
      captured = request;
      return http.StreamedResponse(Stream.value(utf8.encode(sse)), 200);
    });
    final service = AiService(config: config, client: client);
    final chunks = await service.chat(const [ChatMessage(isUser: true, text: 'What now?')]).toList();
    expect(chunks.join(), 'Draw a cat.');
    expect(captured!.headers['x-api-key'], 'sk-test');
  });

  test('refusals and HTTP errors surface as AiException', () async {
    final refusing = MockClient((_) async => http.Response(
          jsonEncode({'stop_reason': 'refusal', 'content': []}),
          200,
        ));
    expect(
      () => AiService(config: config, client: refusing).tutorial('x'),
      throwsA(isA<AiException>().having((e) => e.message, 'message', contains('declined'))),
    );

    final unauthorized = MockClient((_) async => http.Response(
          jsonEncode({
            'error': {'type': 'authentication_error', 'message': 'invalid x-api-key'}
          }),
          401,
        ));
    expect(
      () => AiService(config: config, client: unauthorized).tutorial('x'),
      throwsA(isA<AiException>().having((e) => e.statusCode, 'status', 401)),
    );
  });

  test('proxy mode sends the app token and device id instead of a key', () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return ok({'title': 'x', 'steps': []});
    });
    const proxy = AiConfig(endpoint: 'https://sketch-proxy.example.com', appToken: 'app-token', deviceId: 'device-1234');
    await AiService(config: proxy, client: client).tutorial('a cat');
    expect(captured!.url.toString(), 'https://sketch-proxy.example.com/v1/messages');
    expect(captured!.headers['x-sketch-token'], 'app-token');
    expect(captured!.headers['x-sketch-device'], 'device-1234');
    expect(captured!.headers.containsKey('x-api-key'), isFalse);
  });

  test('a proxy endpoint needs no API key', () {
    const proxy = AiConfig(endpoint: 'https://sketch-proxy.example.com/');
    expect(proxy.isConfigured, isTrue);
    expect(proxy.messagesUri.toString(), 'https://sketch-proxy.example.com/v1/messages');
    expect(const AiConfig().isConfigured, isFalse);
  });
}
