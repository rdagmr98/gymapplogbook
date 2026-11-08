typedef ProgressionPlan = ({double kg, int reps, int target, bool aumento, int? provaReps});

/// Doppia progressione su una serie, confrontata con la stessa serie della volta scorsa.
/// Propone sempre un passo avanti, che la ruota mostra già impostato:
/// - target+2 raggiunto -> peso + [step], reps di nuovo al target ([aumento]);
/// - altrimenti -> stesso peso e una rep in più della volta scorsa ([provaReps]);
/// - peso alzato oggi sulla serie prima -> stesso aumento qui, reps al target.
/// [todayPrevKg] = peso della serie precedente fatta oggi (null se è la prima),
/// [lastPrevKg] = peso di quella stessa serie la volta scorsa, [step] = salto di peso abituale ([weightStep]).
ProgressionPlan progressionPlan({
  required int target,
  required double lastKg,
  required int lastReps,
  double? todayPrevKg,
  double lastPrevKg = 0,
  double step = 2.5,
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
  final prova = !raised && !aumento && lastReps > 0 ? lastReps + 1 : null;
  return (
    kg: aumento ? lastKg + step : (kg > 0 || lastReps > 0 ? kg : 20.0),
    reps: prova ?? target,
    target: target,
    aumento: aumento,
    provaReps: prova,
  );
}

/// Salto di peso abituale di [exercise]: la differenza più piccola tra i pesi usati nello storico
/// (dischi, pile delle macchine, manubri). 2,5 kg se lo storico non basta.
double weightStep(Iterable history, String exercise) {
  final ws = <double>{};
  for (final h in history) {
    if (h is! Map || h['exercise'] != exercise) continue;
    for (final s in (h['series'] as List?) ?? const []) {
      final w = s is Map ? ((s['w'] ?? 0) as num).toDouble() : 0.0;
      if (w > 0) ws.add((w * 100).roundToDouble() / 100);
    }
  }
  final l = ws.toList()..sort();
  var step = double.infinity;
  for (var i = 1; i < l.length; i++) {
    if (l[i] - l[i - 1] < step) step = l[i] - l[i - 1];
  }
  return step.isFinite ? step.clamp(0.5, 10.0) : 2.5;
}

/// Andamento di sessioni dello stesso allenamento, in ordine di data ({esercizio: punteggio serie migliore}):
/// parte da 100 e a ogni sessione cambia come la somma degli esercizi IN COMUNE con la sessione prima.
/// Così sostituire, aggiungere o togliere un esercizio dalla scheda non sposta l'andamento.
List<double> chainIndex(List<Map<String, double>> sessions) {
  final out = <double>[];
  for (var i = 0; i < sessions.length; i++) {
    var c = 0.0, p = 0.0;
    if (i > 0) {
      sessions[i].forEach((ex, v) {
        final pv = sessions[i - 1][ex];
        if (pv != null) {
          c += v;
          p += pv;
        }
      });
    }
    out.add(i == 0 ? 100 : (p > 0 ? out.last * c / p : out.last));
  }
  return out;
}

/// Punteggio per i grafici di ogni sessione: [chainIndex] fatto a parte per ogni giorno della scheda.
/// [ex] = {sessione: {esercizio: punteggio}}, [date] = data ISO, [day] = giorno della scheda.
Map<String, double> sessionIndex(Map<String, Map<String, double>> ex, Map<String, String> date, Map<String, String> day) {
  final byDay = <String, List<String>>{};
  for (final s in ex.keys) {
    byDay.putIfAbsent(day[s] ?? '', () => []).add(s);
  }
  final out = <String, double>{};
  for (final l in byDay.values) {
    l.sort((a, b) => (date[a] ?? '').compareTo(date[b] ?? ''));
    final idx = chainIndex([for (final s in l) ex[s]!]);
    for (var i = 0; i < l.length; i++) {
      out[l[i]] = idx[i];
    }
  }
  return out;
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
