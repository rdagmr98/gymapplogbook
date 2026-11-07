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
  final names = exerciseNames.toSet();
  DateTime? latest;
  for (final h in history) {
    final d = inWorkout(h, dayName, names) ? DateTime.tryParse('${h['date']}') : null;
    if (d != null && (latest == null || d.isAfter(latest))) latest = d;
  }
  return latest;
}

/// La voce di storico [h] appartiene all'allenamento [dayName]? Decide il suo `dayName`, non l'esercizio
/// (un esercizio può stare in più allenamenti). Voci vecchie senza `dayName`: per nome esercizio.
bool inWorkout(Object? h, String dayName, Set<String> exerciseNames) {
  if (h is! Map) return false;
  final dn = h['dayName'];
  return dn is String ? dn.trim().toLowerCase() == dayName.trim().toLowerCase() : exerciseNames.contains(h['exercise']);
}

/// Punteggio di una serie per dire quale prestazione è migliore: il peso conta più delle reps,
/// che decidono a parità di peso. 230×8 batte 220×10: è il salto della doppia progressione.
/// A corpo libero (peso 0) contano le reps.
// ponytail: reps = 1/300 del peso (come il coach), regge salti ≥2,5 kg fino a ~380 kg; alzare 300 per i micro-dischi.
double setScore(num w, num r) => w > 0 ? w * (1 + r / 300) : r.toDouble();

/// Serie migliore secondo [setScore] tra voci `{'w':…, 'r':…}` dello storico; null se non ce ne sono.
({double w, int r, double score})? bestSet(Iterable? series) {
  ({double w, int r, double score})? best;
  for (final s in series ?? const []) {
    if (s is! Map) continue;
    final w = ((s['w'] ?? 0) as num).toDouble(), r = ((s['r'] ?? 0) as num).toInt();
    final sc = setScore(w, r);
    if (best == null || sc > best.score) best = (w: w, r: r, score: sc);
  }
  return best;
}
