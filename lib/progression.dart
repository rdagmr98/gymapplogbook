typedef ProgressionPlan = ({double kg, int reps, int target, bool aumento, int? provaReps});

/// Massimale stimato di una serie (formula di Epley): mette sulla stessa scala serie con pesi e reps diversi.
double e1rm(num w, num r) => w * (1 + r / 30);

/// Reps di riferimento della serie [s] (da 1) della volta scorsa ([kg]×[reps]): una serie dopo allo stesso peso,
/// fatta più stanchi, dice che questa ne regge almeno altrettante (80×10 poi 80×12: la prima ne regge 12).
/// Bug utente del 2026-11-27: la prima serie non proponeva nulla. Le piramidi (pesi diversi) non contano.
int refReps(List<Map> last, int s, double kg, int reps) {
  var best = reps;
  for (final m in last.skip(s)) {
    final w = ((m['w'] ?? m['weight'] ?? 0) as num).toDouble();
    final r = ((m['r'] ?? m['reps'] ?? 0) as num).toInt();
    if (w == kg && r > best) best = r;
  }
  return best;
}

/// Proposta per una serie. Le serie non sono indipendenti (richiesta dell'utente del 2026-11-15):
/// - forza di oggi su questa serie = massimale della stessa serie la volta scorsa ([lastKg]×[lastReps]),
///   corretto da come è andata oggi la serie prima rispetto alla serie prima della volta scorsa
///   ([todayPrevKg]×[todayPrevReps] contro [lastPrevKg]×[lastPrevReps]): 80×10 invece di 80×8 alza la serie dopo;
/// - reps fattibili oggi col peso della volta scorsa >= target+2 -> peso + [step], reps al target ([aumento]);
///   sotto target-2 -> peso più basso con cui si fanno le reps del target; altrimenti stesso peso e una rep
///   in più di quelle fattibili ([provaReps]);
/// - serie senza storico: dalla serie prima di oggi con 2 reps in meno di fatica (80×8 -> 10 reps con 70).
/// [step] = salto di peso abituale ([weightStep]); i pesi proposti restano sulla griglia del peso di partenza.
ProgressionPlan progressionPlan({
  required int target,
  required double lastKg,
  required int lastReps,
  double? todayPrevKg,
  int todayPrevReps = 0,
  double lastPrevKg = 0,
  int lastPrevReps = 0,
  double step = 2.5,
}) {
  final tKg = todayPrevKg ?? 0;
  // peso per [reps] reps con massimale [e], per difetto sulla griglia di [ref]
  double weightFor(double e, int reps, double ref) {
    final w = ref - ((ref - e / (1 + reps / 30)) / step - 1e-6).ceil() * step;
    return w > 0 ? w : ref;
  }

  ProgressionPlan plan(double kg, int reps, {bool aumento = false, int? prova}) =>
      (kg: kg, reps: reps, target: target, aumento: aumento, provaReps: prova);

  if (lastKg > 0 && lastReps > 0) {
    // ponytail: correzione limitata a ±15%, una serie prima andata storta non stravolge la proposta
    final f = tKg > 0 && todayPrevReps > 0 && lastPrevKg > 0 && lastPrevReps > 0
        ? (e1rm(tKg, todayPrevReps) / e1rm(lastPrevKg, lastPrevReps)).clamp(0.85, 1.15)
        : 1.0;
    final e = e1rm(lastKg, lastReps) * f;
    final r = (30 * (e / lastKg - 1) + 1e-6).floor(); // reps fattibili oggi col peso della volta scorsa
    if (r >= target + 2) return plan(lastKg + step, target, aumento: true);
    if (r < target - 2) return plan(weightFor(e, target, lastKg), target);
    return plan(lastKg, r + 1, prova: r + 1);
  }
  if (lastKg <= 0 && lastReps > 0) return plan(0, lastReps + 1, prova: lastReps + 1); // corpo libero
  if (tKg > 0 && todayPrevReps > 0) {
    return plan(weightFor(e1rm(tKg, todayPrevReps > 3 ? todayPrevReps - 2 : 1), target, tKg), target);
  }
  return plan(tKg > 0 ? tKg : 20.0, target);
}

/// Record personali di [sessionId]: esercizi di [done] la cui serie migliore ([bestSet]) batte la migliore
/// di tutte le sessioni prima nello [history]. Un esercizio mai fatto prima non è un record.
List<({String exercise, double w, int r})> sessionRecords(Iterable history, Iterable<Map> done, String sessionId) {
  final out = <({String exercise, double w, int r})>[];
  for (final ex in done) {
    final c = bestSet(ex['series'] as List?);
    final p = bestSet([
      for (final h in history)
        if (h is Map && h['exercise'] == ex['exercise'] && h['session_id'] != sessionId) ...?(h['series'] as List?),
    ]);
    if (c != null && p != null && c.score > p.score) out.add((exercise: '${ex['exercise']}', w: c.w, r: c.r));
  }
  return out;
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
  // ponytail: tetto 5 kg: con pochi pesi diversi nello storico (70 e 80) il salto più piccolo era 10 e proponeva +14%;
  // un attrezzo con salti davvero più grandi si corregge a mano sulla ruota.
  return step.isFinite ? step.clamp(0.5, 5.0) : 2.5;
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

/// Giorni rinominati tra la scheda di prima e quella nuova ({giorno: nomi esercizi}): un giorno sparito
/// e uno nuovo con almeno metà degli esercizi in comune (contando il più corto) sono lo stesso allenamento.
/// Ritorna {vecchio: nuovo}, così storico e microciclo seguono il nome nuovo.
Map<String, String> renamedDays(Map<String, Set<String>> before, Map<String, Set<String>> after) {
  String k(String s) => s.trim().toLowerCase();
  final oldKeys = {for (final d in before.keys) k(d)};
  final newKeys = {for (final d in after.keys) k(d)};
  final out = <String, String>{};
  for (final n in after.entries) {
    if (oldKeys.contains(k(n.key))) continue;
    String? best;
    var bestC = 0;
    for (final o in before.entries) {
      if (newKeys.contains(k(o.key)) || out.containsKey(o.key)) continue;
      final c = o.value.intersection(n.value).length;
      final shorter = o.value.length < n.value.length ? o.value.length : n.value.length;
      if (c > bestC && c * 2 >= shorter) {
        best = o.key;
        bestC = c;
      }
    }
    if (best != null) out[best] = n.key;
  }
  return out;
}

/// Applica [renamedDays] al campo `dayName` delle voci di storico. Ritorna quante ne ha cambiate.
int renameDaysInHistory(Iterable history, Map<String, String> renamed) {
  final m = {for (final e in renamed.entries) e.key.trim().toLowerCase(): e.value};
  var n = 0;
  for (final h in history) {
    final dn = h is Map ? h['dayName'] : null;
    final to = dn is String ? m[dn.trim().toLowerCase()] : null;
    if (to != null) {
      h['dayName'] = to;
      n++;
    }
  }
  return n;
}
