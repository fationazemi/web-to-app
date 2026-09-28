import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/ai.dart';
import 'prompts.dart';

/// Thrown when the assistant cannot answer.
class AiException implements Exception {
  const AiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// How to reach the Claude API. In development the key lives on the device;
/// for a store release point [endpoint] at a small proxy that holds the key
/// (see README) and leave [apiKey] empty.
class AiConfig {
  const AiConfig({
    this.endpoint = defaultEndpoint,
    this.apiKey = '',
    this.model = defaultModel,
  });

  static const String defaultEndpoint = 'https://api.anthropic.com';
  static const String defaultModel = 'claude-opus-5';

  final String endpoint;
  final String apiKey;
  final String model;

  bool get isConfigured => apiKey.isNotEmpty || endpoint != defaultEndpoint;

  Uri get messagesUri => Uri.parse('${endpoint.replaceAll(RegExp(r'/+$'), '')}/v1/messages');
}

/// Talks to the Claude Messages API over plain HTTP.
///
/// Every request opts into Anthropic's server-side refusal fallback, so a
/// declined request is retried on a fallback model instead of failing.
class AiService {
  AiService({required this.config, http.Client? client}) : _client = client ?? http.Client();

  static const String apiVersion = '2023-06-01';
  static const String fallbackBeta = 'server-side-fallback-2026-07-01';
  static const Duration timeout = Duration(seconds: 120);

  final AiConfig config;
  final http.Client _client;

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        'anthropic-version': apiVersion,
        'anthropic-beta': fallbackBeta,
        if (config.apiKey.isNotEmpty) 'x-api-key': config.apiKey,
      };

  Map<String, dynamic> _body({
    required String system,
    required List<Map<String, dynamic>> messages,
    String effort = 'medium',
    Map<String, dynamic>? schema,
    bool stream = false,
    int maxTokens = 4096,
  }) =>
      {
        'model': config.model,
        'max_tokens': maxTokens,
        'system': system,
        'messages': messages,
        'fallbacks': 'default',
        'output_config': {
          'effort': effort,
          if (schema != null) 'format': {'type': 'json_schema', 'schema': schema},
        },
        if (stream) 'stream': true,
      };

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Future<List<DrawingIdea>> suggestIdeas(IdeaBrief brief) async {
    final json = await _requestJson(
      system: AiPrompts.ideas,
      messages: [
        {'role': 'user', 'content': 'Suggest what I should draw. ${brief.describe()}'}
      ],
      schema: _ideasSchema,
    );
    return [
      for (final idea in json['ideas'] as List<dynamic>? ?? const [])
        DrawingIdea.fromJson(idea as Map<String, dynamic>),
    ];
  }

  Future<SketchFeedback> critique(Uint8List png, {String? title}) async {
    final json = await _requestJson(
      system: AiPrompts.critique,
      messages: [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {'type': 'base64', 'media_type': 'image/png', 'data': base64Encode(png)},
            },
            {
              'type': 'text',
              'text': title == null || title.isEmpty
                  ? 'Here is my sketch. What do you think, and how can I improve it?'
                  : 'Here is my sketch "$title". What do you think, and how can I improve it?',
            },
          ],
        }
      ],
      schema: _critiqueSchema,
    );
    return SketchFeedback.fromJson(json);
  }

  Future<Tutorial> tutorial(String subject) async {
    final json = await _requestJson(
      system: AiPrompts.tutorial,
      messages: [
        {'role': 'user', 'content': 'Teach me to draw: ${subject.trim()}'}
      ],
      schema: _tutorialSchema,
    );
    return Tutorial.fromJson(json);
  }

  /// Streams the assistant's reply to [history] (oldest first, ending with
  /// the user's newest message) as text chunks.
  Stream<String> chat(List<ChatMessage> history, {String? context}) async* {
    final messages = [for (final m in history) m.toApi()];
    final system = context == null || context.isEmpty ? AiPrompts.chat : '${AiPrompts.chat}\n\nContext: $context';
    final request = http.Request('POST', config.messagesUri)
      ..headers.addAll(_headers)
      ..body = jsonEncode(_body(system: system, messages: messages, effort: 'low', stream: true, maxTokens: 2048));

    final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(timeout);
    } on TimeoutException {
      throw const AiException('The assistant took too long to answer.');
    } catch (e) {
      throw AiException('Could not reach the assistant: $e');
    }
    if (response.statusCode != 200) {
      throw AiException(await _errorMessage(response.statusCode, await response.stream.bytesToString()),
          statusCode: response.statusCode);
    }

    await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty) continue;
      final event = jsonDecode(payload) as Map<String, dynamic>;
      switch (event['type']) {
        case 'content_block_delta':
          final delta = event['delta'] as Map<String, dynamic>? ?? const {};
          if (delta['type'] == 'text_delta') yield delta['text'] as String? ?? '';
        case 'message_delta':
          final stop = (event['delta'] as Map<String, dynamic>?)?['stop_reason'];
          if (stop == 'refusal') throw const AiException('The assistant declined to answer that.');
        case 'error':
          final error = event['error'] as Map<String, dynamic>? ?? const {};
          throw AiException(error['message'] as String? ?? 'Streaming error');
      }
    }
  }

  void dispose() => _client.close();

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _requestJson({
    required String system,
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> schema,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(config.messagesUri, headers: _headers, body: jsonEncode(_body(system: system, messages: messages, schema: schema)))
          .timeout(timeout);
    } on TimeoutException {
      throw const AiException('The assistant took too long to answer.');
    } catch (e) {
      throw AiException('Could not reach the assistant: $e');
    }
    if (response.statusCode != 200) {
      throw AiException(await _errorMessage(response.statusCode, response.body), statusCode: response.statusCode);
    }
    final message = jsonDecode(response.body) as Map<String, dynamic>;
    final stopReason = message['stop_reason'];
    if (stopReason == 'refusal') throw const AiException('The assistant declined to answer that.');
    if (stopReason == 'max_tokens') throw const AiException('The answer was cut off. Please try again.');
    final text = [
      for (final block in message['content'] as List<dynamic>? ?? const [])
        if ((block as Map<String, dynamic>)['type'] == 'text') block['text'] as String? ?? '',
    ].join();
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw const AiException('The assistant returned an unexpected answer.');
    }
  }

  Future<String> _errorMessage(int status, String body) async {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      final message = error?['message'] as String?;
      if (message != null && message.isNotEmpty) return message;
    } catch (_) {}
    return switch (status) {
      401 => 'The API key was rejected. Check it in Settings.',
      429 => 'Too many requests right now. Try again in a moment.',
      >= 500 => 'The assistant is temporarily unavailable.',
      _ => 'Request failed ($status).',
    };
  }

  // JSON schemas for structured outputs. Every object sets
  // additionalProperties: false as the API requires.

  static const Map<String, dynamic> _ideasSchema = {
    'type': 'object',
    'properties': {
      'ideas': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string'},
            'description': {'type': 'string'},
            'difficulty': {
              'type': 'string',
              'enum': ['beginner', 'intermediate', 'advanced']
            },
            'estimated_minutes': {'type': 'integer'},
            'steps': {
              'type': 'array',
              'items': {'type': 'string'}
            },
            'palette': {
              'type': 'array',
              'items': {'type': 'string'}
            },
          },
          'required': ['title', 'description', 'difficulty', 'estimated_minutes', 'steps', 'palette'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['ideas'],
    'additionalProperties': false,
  };

  static const Map<String, dynamic> _critiqueSchema = {
    'type': 'object',
    'properties': {
      'summary': {'type': 'string'},
      'strengths': {
        'type': 'array',
        'items': {'type': 'string'}
      },
      'improvements': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string'},
            'detail': {'type': 'string'},
          },
          'required': ['title', 'detail'],
          'additionalProperties': false,
        },
      },
      'next_exercise': {'type': 'string'},
    },
    'required': ['summary', 'strengths', 'improvements', 'next_exercise'],
    'additionalProperties': false,
  };

  static const Map<String, dynamic> _tutorialSchema = {
    'type': 'object',
    'properties': {
      'title': {'type': 'string'},
      'steps': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'instruction': {'type': 'string'},
            'tip': {'type': 'string'},
          },
          'required': ['instruction', 'tip'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['title', 'steps'],
    'additionalProperties': false,
  };
}
