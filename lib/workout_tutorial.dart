import 'package:flutter/material.dart';

/// Tutorial interattivo per il primo workout.
/// Se [demoWorkoutBuilder] è fornito, il tasto "Inizia la prova" avvia il
/// vero WorkoutEngine in demoMode (senza salvare dati); al termine torna qui
/// e viene chiamato [onComplete] per chiudere il tutorial.
class WorkoutTutorial extends StatefulWidget {
  final Color accentColor;
  final VoidCallback onComplete;

  /// Builder che restituisce il vero WorkoutEngine configurato in demoMode.
  /// Fornito da main.dart per evitare l'import circolare.
  final WidgetBuilder? demoWorkoutBuilder;

  const WorkoutTutorial({
    super.key,
    required this.accentColor,
    required this.onComplete,
    this.demoWorkoutBuilder,
  });

  @override
  State<WorkoutTutorial> createState() => _WorkoutTutorialState();
}

class _WorkoutTutorialState extends State<WorkoutTutorial> {
  bool _launching = false;

  Future<void> _startDemo(BuildContext ctx) async {
    if (_launching) return;
    setState(() => _launching = true);
    if (widget.demoWorkoutBuilder != null) {
      await Navigator.push<void>(
        ctx,
        MaterialPageRoute<void>(builder: widget.demoWorkoutBuilder!),
      );
    }
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: widget.onComplete,
                  child: const Text(
                    'Salta',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Benvenuto in GymLogbook! 💪',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Scopri come funziona l'app con un allenamento rapido a corpo libero.\n"
                'Nessun dato verrà salvato — è solo una prova!',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 28),
              // Workflow step-by-step guide
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withAlpha(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Come funziona ogni serie',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _stepCompact(accent, '1', '💪 Esegui la serie', 'Prima il ferro! Fai le tue ripetizioni.'),
                    const SizedBox(height: 8),
                    _stepCompact(accent, '2', '📝 Registra peso e reps', 'Solo DOPO la serie, inserisci i valori e premi Conferma.'),
                    const SizedBox(height: 8),
                    _stepCompact(accent, '3', '⏱️ Timer automatico', 'Il recupero parte da solo in background.'),
                    const SizedBox(height: 8),
                    _stepCompact(accent, '4', '🔁 Prossima serie', 'A fine recupero l\'app ti avvisa. Ripeti!'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _step(
                accent,
                Icons.navigate_next,
                'Naviga tra gli esercizi',
                'Usa le frecce in alto per passare da un esercizio all\'altro durante l\'allenamento.',
              ),
              const SizedBox(height: 16),
              _step(
                accent,
                Icons.bar_chart,
                'L\'app ricorda i tuoi pesi',
                'La prossima volta che fai lo stesso esercizio, vedrai i pesi usati '
                    'nell\'ultima sessione. GymLogbook tiene traccia di tutto.',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _launching ? null : () => _startDemo(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: accent.withAlpha(120),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _launching
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Inizia la prova 🏋️',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepCompact(Color accent, String number, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withAlpha(40),
            border: Border.all(color: accent.withAlpha(120)),
          ),
          child: Center(
            child: Text(number, style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(body, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _step(Color accent, IconData icon, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withAlpha(30),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: accent.withAlpha(90)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: accent, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
