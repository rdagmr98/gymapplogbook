typedef ProgressionPlan = ({double kg, int reps, int target, bool aumento, int? provaReps});

/// Doppia progressione su una serie, confrontata con la stessa serie della volta scorsa.
/// - reps fatte oltre il target -> le ripropone (e suggerisce di provarne una in più);
/// - target+2 raggiunto -> suggerisce di aumentare il peso;
/// - peso alzato oggi sulla serie prima -> stesso aumento qui, reps di nuovo al target.
/// [todayPrevKg] = peso della serie precedente fatta oggi (null se è la prima),
/// [lastPrevKg] = peso di quella stessa serie la volta scorsa.
ProgressionPlan progressionPlan({
  required int target,
  required double lastKg,
  required int lastReps,
  double? todayPrevKg,
  double lastPrevKg = 0,
}) {
  var kg = lastKg;
  if (todayPrevKg != null) {
    if (lastKg <= 0) {
      kg = todayPrevKg;
    } else if (todayPrevKg > lastPrevKg) {
      kg = lastKg + todayPrevKg - lastPrevKg;
    }
  }
  final raised = lastKg > 0 && kg > lastKg;
  final aumento = !raised && lastKg > 0 && lastReps >= target + 2;
  return (
    kg: kg > 0 || lastReps > 0 ? kg : 20.0,
    reps: raised || lastReps <= target ? target : lastReps,
    target: target,
    aumento: aumento,
    provaReps: !raised && !aumento && lastReps >= target ? lastReps + 1 : null,
  );
}

/// Ultima volta che è stato fatto l'allenamento [dayName]: conta la sessione intera (campo `dayName`
/// delle voci di storico), non i singoli esercizi, così un esercizio in comune tra due allenamenti
/// non sposta il suggerimento. Voci vecchie senza `dayName`: ripiego sul nome esercizio.
DateTime? lastTrainedDate(Iterable history, String dayName, Iterable<String> exerciseNames) {
  final key = dayName.trim().toLowerCase();
  final names = exerciseNames.toSet();
  DateTime? latest;
  for (final h in history) {
    if (h is! Map) continue;
    final dn = h['dayName'];
    final match = dn is String ? dn.trim().toLowerCase() == key : names.contains(h['exercise']);
    final d = match ? DateTime.tryParse('${h['date']}') : null;
    if (d != null && (latest == null || d.isAfter(latest))) latest = d;
  }
  return latest;
}
