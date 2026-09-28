// Data returned by the Sketch AI assistant.

enum IdeaDifficulty { beginner, intermediate, advanced }

IdeaDifficulty difficultyFromName(String? name) =>
    IdeaDifficulty.values.firstWhere((d) => d.name == name, orElse: () => IdeaDifficulty.beginner);

/// A drawing suggestion with a step-by-step plan.
class DrawingIdea {
  const DrawingIdea({
    required this.title,
    required this.description,
    required this.difficulty,
    required this.minutes,
    required this.steps,
    required this.palette,
  });

  final String title;
  final String description;
  final IdeaDifficulty difficulty;
  final int minutes;
  final List<String> steps;

  /// Suggested colors as `#RRGGBB` strings.
  final List<String> palette;

  factory DrawingIdea.fromJson(Map<String, dynamic> json) => DrawingIdea(
        title: json['title'] as String? ?? 'Untitled idea',
        description: json['description'] as String? ?? '',
        difficulty: difficultyFromName(json['difficulty'] as String?),
        minutes: (json['estimated_minutes'] as num?)?.toInt() ?? 15,
        steps: [for (final s in json['steps'] as List<dynamic>? ?? const []) s.toString()],
        palette: [for (final c in json['palette'] as List<dynamic>? ?? const []) c.toString()],
      );
}

/// What the user told the assistant before asking for ideas.
class IdeaBrief {
  const IdeaBrief({
    this.mood,
    this.minutes = 15,
    this.skill = IdeaDifficulty.beginner,
    this.style,
    this.subject,
  });

  final String? mood;
  final int minutes;
  final IdeaDifficulty skill;
  final String? style;
  final String? subject;

  String describe() {
    final parts = <String>[
      'Time available: about $minutes minutes.',
      'Skill level: ${skill.name}.',
      if (mood != null && mood!.isNotEmpty) 'Mood: $mood.',
      if (style != null && style!.isNotEmpty) 'Preferred style: $style.',
      if (subject != null && subject!.trim().isNotEmpty) 'They mentioned: "${subject!.trim()}".',
    ];
    return parts.join(' ');
  }
}

/// One improvement suggested by the critique.
class Improvement {
  const Improvement({required this.title, required this.detail});

  final String title;
  final String detail;

  factory Improvement.fromJson(Map<String, dynamic> json) => Improvement(
        title: json['title'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
      );
}

/// Feedback on a sketch.
class SketchFeedback {
  const SketchFeedback({
    required this.summary,
    required this.strengths,
    required this.improvements,
    required this.nextExercise,
  });

  final String summary;
  final List<String> strengths;
  final List<Improvement> improvements;
  final String nextExercise;

  factory SketchFeedback.fromJson(Map<String, dynamic> json) => SketchFeedback(
        summary: json['summary'] as String? ?? '',
        strengths: [for (final s in json['strengths'] as List<dynamic>? ?? const []) s.toString()],
        improvements: [
          for (final i in json['improvements'] as List<dynamic>? ?? const [])
            Improvement.fromJson(i as Map<String, dynamic>),
        ],
        nextExercise: json['next_exercise'] as String? ?? '',
      );
}

/// One step of a guided tutorial.
class TutorialStep {
  const TutorialStep({required this.instruction, required this.tip});

  final String instruction;
  final String tip;

  factory TutorialStep.fromJson(Map<String, dynamic> json) => TutorialStep(
        instruction: json['instruction'] as String? ?? '',
        tip: json['tip'] as String? ?? '',
      );
}

class Tutorial {
  const Tutorial({required this.title, required this.steps});

  final String title;
  final List<TutorialStep> steps;

  factory Tutorial.fromJson(Map<String, dynamic> json) => Tutorial(
        title: json['title'] as String? ?? 'Tutorial',
        steps: [
          for (final s in json['steps'] as List<dynamic>? ?? const [])
            TutorialStep.fromJson(s as Map<String, dynamic>),
        ],
      );
}

/// A chat turn.
class ChatMessage {
  const ChatMessage({required this.isUser, required this.text});

  final bool isUser;
  final String text;

  Map<String, dynamic> toApi() => {'role': isUser ? 'user' : 'assistant', 'content': text};
}
