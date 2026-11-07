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
