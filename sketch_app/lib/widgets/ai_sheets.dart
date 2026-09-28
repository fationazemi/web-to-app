import 'package:flutter/material.dart';

import '../models/ai.dart';
import '../theme/app_theme.dart';

Color? parseHex(String hex) {
  final clean = hex.replaceAll('#', '').trim();
  if (clean.length != 6) return null;
  final value = int.tryParse(clean, radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}

/// Shows the assistant's feedback on a sketch.
Future<void> showFeedbackSheet(BuildContext context, SketchFeedback feedback) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.accentDeep),
                const SizedBox(width: 8),
                Text('Feedback', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            Text(feedback.summary, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 20),
            _Heading('What works'),
            for (final s in feedback.strengths) _Bullet(icon: Icons.check_circle_outline, text: s),
            const SizedBox(height: 16),
            _Heading('Try now'),
            for (final i in feedback.improvements)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(i.detail, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            if (feedback.nextExercise.isNotEmpty) ...[
              const SizedBox(height: 8),
              _Heading('Next time'),
              _Bullet(icon: Icons.fitness_center_outlined, text: feedback.nextExercise),
            ],
          ],
        ),
      );
    },
  );
}

/// A card presenting one drawing idea.
class IdeaCard extends StatelessWidget {
  const IdeaCard({super.key, required this.idea, required this.onDraw});

  final DrawingIdea idea;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: softShadow(context, blur: 12, y: 4),
      ),
      child: Material(
        color: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: theme.dividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(idea.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              ),
              for (final hex in idea.palette.take(5))
                if (parseHex(hex) != null)
                  Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: parseHex(hex),
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.dividerColor),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 6),
          Text(idea.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: muted),
              const SizedBox(width: 4),
              Text('${idea.minutes} min', style: TextStyle(fontSize: 12, color: muted)),
              const SizedBox(width: 12),
              Icon(Icons.signal_cellular_alt, size: 14, color: muted),
              const SizedBox(width: 4),
              Text(idea.difficulty.name, style: TextStyle(fontSize: 12, color: muted)),
            ],
          ),
          const SizedBox(height: 12),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text('${idea.steps.length} steps', style: theme.textTheme.labelLarge),
              children: [
                for (var i = 0; i < idea.steps.length; i++)
                  _Bullet(number: i + 1, text: idea.steps[i]),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onDraw,
              icon: const Icon(Icons.brush_outlined, size: 18),
              label: const Text('Draw this'),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }
}

/// Compact step-by-step guide shown above the canvas toolbar.
class TutorialGuide extends StatelessWidget {
  const TutorialGuide({
    super.key,
    required this.tutorial,
    required this.index,
    required this.onPrevious,
    required this.onNext,
    required this.onClose,
  });

  final Tutorial tutorial;
  final int index;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = tutorial.steps[index];
    final last = index == tutorial.steps.length - 1;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? AppColors.accent.withValues(alpha: 0.2) : AppColors.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${tutorial.title} · step ${index + 1} of ${tutorial.steps.length}',
                  style: theme.textTheme.labelSmall?.copyWith(color: AppColors.accentDeep),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
              ),
            ],
          ),
          Text(step.instruction, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          if (step.tip.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(step.tip, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65))),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: index == 0 ? null : onPrevious, child: const Text('Back')),
              TextButton(onPressed: last ? onClose : onNext, child: Text(last ? 'Done' : 'Next')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet({this.icon, this.number, required this.text});

  final IconData? icon;
  final int? number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (number != null)
            CircleAvatar(
              radius: 11,
              backgroundColor: theme.colorScheme.primary,
              child: Text('$number', style: TextStyle(fontSize: 11, color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w700)),
            )
          else
            Icon(icon, size: 20, color: AppColors.accentDeep),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
