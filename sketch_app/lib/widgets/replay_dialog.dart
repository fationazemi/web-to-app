import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../canvas/sketch_painter.dart';
import '../canvas/timelapse.dart';
import '../models/layer.dart';
import '../models/stroke.dart';
import 'sketch_canvas.dart';

/// Plays the drawing back stroke by stroke.
Future<void> showReplayDialog(BuildContext context, CanvasController controller) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _Replay(controller: controller),
      ),
    ),
  );
}

class _Replay extends StatefulWidget {
  const _Replay({required this.controller});

  final CanvasController controller;

  @override
  State<_Replay> createState() => _ReplayState();
}

class _ReplayState extends State<_Replay> with SingleTickerProviderStateMixin {
  late final int _total = Timelapse.strokeCount(widget.controller.layers);
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (400 + _total * 60).clamp(1500, 12000)),
  )..forward();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
          child: Row(
            children: [
              const Text('Replay', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.replay_rounded),
                tooltip: 'Play again',
                onPressed: () => _anim.forward(from: 0),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: AspectRatio(
            aspectRatio: SketchCanvas.aspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, _) {
                  final count = (Curves.easeInOut.transform(_anim.value) * _total).round();
                  return CustomPaint(
                    painter: _ReplayPainter(
                      layers: Timelapse.partial(widget.controller.layers, count),
                      template: widget.controller.template,
                      paperColor: widget.controller.paperColor,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReplayPainter extends CustomPainter {
  const _ReplayPainter({required this.layers, required this.template, required this.paperColor});

  final List<Layer> layers;
  final CanvasTemplate template;
  final Color paperColor;

  @override
  void paint(Canvas canvas, Size size) {
    paintDrawing(
      canvas,
      size,
      layers: layers,
      template: template,
      paperColor: paperColor,
      templateInk: templateInkFor(paperColor),
    );
  }

  @override
  bool shouldRepaint(_ReplayPainter oldDelegate) => true;
}
