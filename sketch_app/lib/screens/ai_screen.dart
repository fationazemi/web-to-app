import 'package:flutter/material.dart';

import '../ai/ai_gate.dart';
import '../app.dart';
import '../models/ai.dart';
import '../settings/app_settings.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../widgets/ai_sheets.dart';
import 'canvas_screen.dart';

/// The Sketch AI assistant: an ideas wizard and a chat.
class AiScreen extends StatefulWidget {
  const AiScreen({super.key, this.initialTab = 0, this.chatContext});

  final int initialTab;

  /// Extra context for the chat (e.g. "The user is drawing 'Flower'").
  final String? chatContext;

  static Route<void> route({int initialTab = 0, String? chatContext}) =>
      MaterialPageRoute(builder: (_) => AiScreen(initialTab: initialTab, chatContext: chatContext));

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: AppColors.accentDeep, size: 22),
            const SizedBox(width: 8),
            Text('Sketch AI', style: handStyle(size: 28, color: Theme.of(context).colorScheme.onSurface)),
          ],
        ),
        actions: [
          ListenableBuilder(
            listenable: scope.settings,
            builder: (context, _) {
              final s = scope.settings;
              final label = s.isPro ? 'Pro' : '${s.aiRequestsToday} / ${AppSettings.freeAiRequestsPerDay} today';
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(child: Text(label, style: Theme.of(context).textTheme.labelMedium)),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'What to draw'), Tab(text: 'Chat')],
        ),
      ),
      body: scope.aiConfigured
          ? TabBarView(
              controller: _tabs,
              children: [const _IdeasTab(), _ChatTab(context: widget.chatContext)],
            )
          : const _SetupHint(),
    );
  }
}

class _SetupHint extends StatelessWidget {
  const _SetupHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.key_outlined, size: 48, color: AppColors.accentDeep),
            const SizedBox(height: 16),
            Text('Connect Sketch AI', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Add your Claude API key (or a proxy endpoint) under Settings › Sketch AI to get drawing ideas, step-by-step guides and feedback on your sketches.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Ideas
// -----------------------------------------------------------------------------

class _IdeasTab extends StatefulWidget {
  const _IdeasTab();

  @override
  State<_IdeasTab> createState() => _IdeasTabState();
}

class _IdeasTabState extends State<_IdeasTab> with AutomaticKeepAliveClientMixin {
  static const _moods = ['Calm', 'Playful', 'Dramatic', 'Cozy', 'Curious'];
  static const _times = [5, 15, 30, 60];
  static const _styles = ['Line art', 'Cartoon', 'Realistic', 'Abstract', 'Doodle'];

  String? _mood;
  int _minutes = 15;
  IdeaDifficulty _skill = IdeaDifficulty.beginner;
  String? _style;
  final _subject = TextEditingController();
  List<DrawingIdea>? _ideas;
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _subject.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    setState(() => _loading = true);
    final ideas = await runAi(
      context,
      (ai) => ai.suggestIdeas(IdeaBrief(
        mood: _mood,
        minutes: _minutes,
        skill: _skill,
        style: _style,
        subject: _subject.text,
      )),
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (ideas != null) _ideas = ideas;
    });
  }

  void _draw(DrawingIdea idea) {
    Navigator.of(context).push(CanvasScreen.route(
      initialName: idea.title,
      tutorial: Tutorial(
        title: idea.title,
        steps: [for (final s in idea.steps) TutorialStep(instruction: s, tip: '')],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return ListView(
      padding: Layout.pagePadding(context).copyWith(top: 16, bottom: 32),
      children: [
        Text('What do you feel like?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _moods)
              ChoiceChip(label: Text(m), selected: _mood == m, onSelected: (_) => setState(() => _mood = _mood == m ? null : m)),
          ],
        ),
        const SizedBox(height: 18),
        Text('How much time?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final t in _times)
              ChoiceChip(label: Text('$t min'), selected: _minutes == t, onSelected: (_) => setState(() => _minutes = t)),
          ],
        ),
        const SizedBox(height: 18),
        Text('Your level', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<IdeaDifficulty>(
          segments: [
            for (final d in IdeaDifficulty.values) ButtonSegment(value: d, label: Text(d.name[0].toUpperCase() + d.name.substring(1))),
          ],
          selected: {_skill},
          onSelectionChanged: (s) => setState(() => _skill = s.first),
        ),
        const SizedBox(height: 18),
        Text('Style (optional)', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in _styles)
              ChoiceChip(label: Text(s), selected: _style == s, onSelected: (_) => setState(() => _style = _style == s ? null : s)),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _subject,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Anything in mind? e.g. "my cat", "the sea", "something spooky"',
            filled: true,
            fillColor: theme.cardColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.dividerColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.dividerColor)),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _ask,
          icon: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome_rounded, size: 18),
          label: Text(_loading ? 'Thinking…' : 'Suggest ideas'),
        ),
        if (_ideas != null) ...[
          const SizedBox(height: 28),
          Text('Ideas for you', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final idea in _ideas!) IdeaCard(idea: idea, onDraw: () => _draw(idea)),
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Chat
// -----------------------------------------------------------------------------

class _ChatTab extends StatefulWidget {
  const _ChatTab({this.context});

  final String? context;

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> with AutomaticKeepAliveClientMixin {
  static const _quick = [
    'What can I draw in 10 minutes?',
    'Give me a beginner exercise',
    'I feel stuck. Help!',
    'How do I draw hands?',
  ];

  final List<ChatMessage> _messages = [];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  String _pending = '';
  bool _streaming = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _streaming) return;
    _input.clear();
    setState(() {
      _messages.add(ChatMessage(isUser: true, text: trimmed));
      _streaming = true;
      _pending = '';
    });
    _scrollDown();
    final reply = await runAi(context, (ai) async {
      final buffer = StringBuffer();
      await for (final chunk in ai.chat(List.of(_messages), context: widget.context)) {
        buffer.write(chunk);
        if (mounted) setState(() => _pending = buffer.toString());
        _scrollDown();
      }
      return buffer.toString();
    });
    if (!mounted) return;
    setState(() {
      _streaming = false;
      if (reply != null && reply.isNotEmpty) {
        _messages.add(ChatMessage(isUser: false, text: reply));
      } else if (_messages.isNotEmpty && _messages.last.isUser) {
        // The request failed: let the user retry without a dangling turn.
        _messages.removeLast();
      }
      _pending = '';
    });
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final side = Layout.pagePadding(context, maxWidth: Layout.narrowContentMaxWidth);
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty && !_streaming
              ? ListView(
                  padding: side.copyWith(top: 24),
                  children: [
                    Text('Ask me anything about drawing.', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final q in _quick) ActionChip(label: Text(q), onPressed: () => _send(q)),
                      ],
                    ),
                  ],
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: side.copyWith(top: 16, bottom: 16),
                  itemCount: _messages.length + (_streaming ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == _messages.length) {
                      return _Bubble(text: _pending.isEmpty ? '…' : _pending, isUser: false);
                    }
                    final m = _messages[i];
                    return _Bubble(text: m.text, isUser: m.isUser);
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: side.copyWith(top: 8, bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: InputDecoration(
                      hintText: 'Message Sketch AI',
                      filled: true,
                      fillColor: theme.cardColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: theme.dividerColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: theme.dividerColor)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _streaming ? null : () => _send(_input.text),
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: isUser ? scheme.primary : theme.cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser ? null : Border.all(color: theme.dividerColor),
        ),
        child: SelectableText(
          text,
          style: TextStyle(color: isUser ? scheme.onPrimary : scheme.onSurface, height: 1.4),
        ),
      ),
    );
  }
}
