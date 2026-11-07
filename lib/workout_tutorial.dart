import 'package:flutter/material.dart';
import 'app_l.dart';

/// Tutorial corto: una pagina con i 3 concetti, poi la prova guidata
/// (il riquadro che spiega ogni passo è in WorkoutEngine, demoMode).
class WorkoutTutorial extends StatefulWidget {
  final Color accentColor;
  final VoidCallback onComplete;
  final Future<void> Function()? onStartDemo;

  const WorkoutTutorial({
    super.key,
    required this.accentColor,
    required this.onComplete,
    this.onStartDemo,
  });

  @override
  State<WorkoutTutorial> createState() => _WorkoutTutorialState();
}

class _WorkoutTutorialState extends State<WorkoutTutorial> {
  bool _demoCompleted = false;
  bool _loading = false;

  Future<void> _startDemo() async {
    if (_loading) return;
    if (widget.onStartDemo == null) {
      widget.onComplete();
      return;
    }
    setState(() => _loading = true);
    await widget.onStartDemo!();
    if (mounted) {
      setState(() {
        _loading = false;
        _demoCompleted = true;
      });
    }
  }

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _dark ? const Color(0xFF0E0E10) : const Color(0xFFF2F2F7);
  Color get _fg => _dark ? Colors.white : Colors.black87;
  Color get _muted => _dark ? Colors.white60 : Colors.black54;
  Color get _card => _dark ? const Color(0xFF1C1C1E) : Colors.white;

  Widget _badge(Color accent, IconData icon, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withAlpha(_dark ? 30 : 40)),
    child: Icon(icon, color: accent, size: size * 0.48),
  );

  Widget _button(String label, VoidCallback? onPressed) => SizedBox(
    width: double.infinity,
    height: 54,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: widget.accentColor,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onPressed,
      child: _loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
          : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    if (_demoCompleted) {
      return Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(children: [
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _badge(accent, Icons.check_rounded, 112),
                  const SizedBox(height: 32),
                  Text(AppL.tutorialCompleteTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _fg, fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text(AppL.tutorialCompleteBody,
                      textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 15, height: 1.4)),
                ]),
              ),
              _button(AppL.startRealWorkout, widget.onComplete),
            ]),
          ),
        ),
      );
    }

    final steps = [
      (Icons.fitness_center_rounded, AppL.tutorialStep1Title, AppL.tutorialStep2Body),
      (Icons.timer_outlined, AppL.tutorialStep3Title, AppL.tutorialStep3Body),
      (Icons.history_rounded, AppL.tutorialMemoryTitle, AppL.tutorialMemoryBody),
    ];
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: TextButton(
                onPressed: widget.onComplete,
                child: Text(AppL.skip, style: TextStyle(color: _muted, fontSize: 14)),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Column(children: [
                _badge(accent, Icons.fitness_center_rounded, 88),
                const SizedBox(height: 20),
                Text(AppL.welcomeTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _fg, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 8),
                Text(AppL.tutorialSubtitle,
                    textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 15, height: 1.4)),
                const SizedBox(height: 28),
                for (int i = 0; i < steps.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _badge(accent, steps[i].$1, 44),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${i + 1}. ${steps[i].$2}',
                              style: TextStyle(color: _fg, fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(steps[i].$3, style: TextStyle(color: _muted, fontSize: 13, height: 1.35)),
                        ]),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(children: [
              Text(AppL.tutorialDemoTitle,
                  textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 13)),
              const SizedBox(height: 12),
              _button(AppL.tutorialStartDemo, _loading ? null : _startDemo),
            ]),
          ),
        ]),
      ),
    );
  }
}
