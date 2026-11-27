// Banca dati esercizi locali
import 'gif_exercise_catalog.dart';

class ExerciseInfo {
  final String name; // Nome (italiano o inglese)
  final String nameEn; // English name (for YouTube search)
  final String
  category; // 'petto','dorso','spalle','braccia','gambe','glutei','core','cardio','altro'
  final List<String> muscleImages; // filenames in assets/muscle/ (can be empty)
  final String primaryMuscle; // Italian description
  final String secondaryMuscles;
  final String execution; // How to perform (2-4 sentences)
  final String tips; // Coaching tips (1-2 sentences)
  final List<String> aliases; // Nomi alternativi/brevi usati in scheda
  /// Slug esplicito del file GIF (es. 'barbell-curl').
  /// Se null, viene calcolato da name rimuovendo accenti e sostituendo spazi con _.
  final String? gifFilename;

  const ExerciseInfo({
    required this.name,
    required this.nameEn,
    required this.category,
    required this.muscleImages,
    required this.primaryMuscle,
    required this.secondaryMuscles,
    required this.execution,
    required this.tips,
    this.aliases = const [],
    this.gifFilename,
  });

  /// Slug del file GIF da usare come 'assets/gif/$gifSlug.gif'.
  /// Usa gifFilename se esplicito, altrimenti lo calcola dal nome.
  String get gifSlug =>
      gifFilename ??
      name
          .toLowerCase()
          .replaceAll('è', 'e')
          .replaceAll('é', 'e')
          .replaceAll('à', 'a')
          .replaceAll('á', 'a')
          .replaceAll('ì', 'i')
          .replaceAll('í', 'i')
          .replaceAll('ò', 'o')
          .replaceAll('ó', 'o')
          .replaceAll('ù', 'u')
          .replaceAll('ú', 'u')
          .replaceAll("'", '')
          .replaceAll('(', '')
          .replaceAll(')', '')
          .replaceAll(' ', '_');

  /// Controlla se questo esercizio corrisponde a un nome (inclusi alias)
  bool matchesName(String query) {
    final q = normalizeExerciseLookup(query);
    if (normalizeExerciseLookup(name) == q) return true;
    if (normalizeExerciseLookup(nameEn) == q) return true;
    if (normalizeExerciseLookup(gifSlug) == q) return true;
    return aliases.any((a) => normalizeExerciseLookup(a) == q);
  }
}

String normalizeExerciseLookup(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('_', ' ')
    .replaceAll('-', ' ')
    .replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Cerca nel catalogo per nome esatto o alias (case-insensitive)
ExerciseInfo? findExercise(String name) {
  final q = normalizeExerciseLookup(name);
  for (final e in kExerciseCatalog) {
    if (e.matchesName(q)) return e;
  }
  return null;
}

final RegExp _kOtherEquipmentKeywords = RegExp(
  r'\b(cable|machine|kettlebell|band|smith|ez[ -]?bar|trap bar|hex bar|plate|medicine ball|stability ball|swiss ball|bosu|trx|suspension|sled|landmine|leverage|weighted|pulley)\b',
  caseSensitive: false,
);

final RegExp _kBodyweightKeywords = RegExp(
  r'\b(push[ -]?up|pull[ -]?up|chin[ -]?up|sit[ -]?up|v[ -]?up|l[ -]?sit|plank|burpee|crunch|mountain climber|jumping jack|jump rope|box jump|broad jump|bear crawl|superman|bodyweight|air squat|pistol squat|glute bridge|wall sit|side plank|flutter kick|leg raise|hollow hold|inchworm|high knees|star jump|dip)\b',
  caseSensitive: false,
);

/// Classifica l'attrezzo necessario in base al nome esercizio: 'corpo_libero',
/// 'manubri', 'bilanciere', oppure null (attrezzo diverso o non riconoscibile
/// dal nome, es. cavi/macchinari/kettlebell/esercizi generici senza attrezzo
/// citato esplicitamente).
/// ponytail: euristica su name/nameEn, nessun campo equipment nei dati sorgente
/// (ExerciseDB lo aveva ma non è stato portato nel catalogo generato). Il
/// default per gli esercizi non riconosciuti è null (non filtrabile) e non
/// 'corpo_libero', per non mostrare esercizi con manubri/bilanciere sotto il
/// filtro "corpo libero" solo perché il nome non li cita esplicitamente.
String? exerciseEquipment(ExerciseInfo e) {
  final text = '${e.name} ${e.nameEn}'.toLowerCase();
  if (text.contains('dumbbell')) return 'manubri';
  if (text.contains('barbell')) return 'bilanciere';
  if (_kOtherEquipmentKeywords.hasMatch(text)) return null;
  if (_kBodyweightKeywords.hasMatch(text)) return 'corpo_libero';
  return null;
}

const List<ExerciseInfo> kExerciseCatalog = [
  // ── PETTO ──
  ExerciseInfo(
    name: 'Panca Piana',
    nameEn: 'Barbell Bench Press',
    category: 'petto',
    muscleImages: ['petto.png', 'tricipiti.png'],
    primaryMuscle: 'Petto (grande pettorale)',
    secondaryMuscles: 'Tricipiti, Deltoidi anteriori',
    execution:
        'Sdraiati sulla panca piana con gli occhi sotto il bilanciere, pianta bene i piedi a terra, adduci e deprimi le scapole e afferra la barra con presa prona più larga delle spalle. Stacca il bilanciere portandolo sopra lo sterno e abbassalo con controllo fino a toccare il petto basso tenendo i gomiti a circa 45 gradi rispetto al tronco. Spingi con forza verso l\'alto e leggermente indietro fino a tornare sopra le spalle senza perdere l\'assetto scapolare.',
    tips:
        'Mantieni i glutei ben appoggiati alla panca e spingi attivamente con i piedi a terra per creare stabilità. Evita di far rimbalzare la barra sul torace o di aprire completamente i gomiti a 90 gradi.',
    aliases: ['Panca piana', 'Bench press'],
    gifFilename: 'bench-press',
  ),
  ExerciseInfo(
    name: 'Distensioni con Manubri',
    nameEn: 'Dumbbell Bench Press',
    category: 'petto',
    muscleImages: ['petto.png', 'tricipiti.png'],
    primaryMuscle: 'Grande pettorale',
    secondaryMuscles: 'Tricipiti, Deltoidi anteriori',
    execution:
        'Sdraiati sulla panca piana con un manubrio in ciascuna mano, piedi saldi a terra e scapole addotte contro lo schienale, tenendo i pesi ai lati del petto con i gomiti a circa 45 gradi. Spingi entrambi i manubri verso l\'alto lungo un arco convergente fino a portarli vicini sopra lo sterno senza farli urtare. Riabbassa lentamente i pesi fino a raggiungere un buon allungamento pettorale con gli avambracci sempre verticali.',
    tips:
        'Sfrutta la libertà dei manubri per scendere con controllo fino a sentire stirare il pettorale senza forzare la spalla. Non lasciar cadere i gomiti troppo in basso oltre il comfort articolare.',
    aliases: ['Distensioni manubri', 'Distensioni con manubri'],
    gifFilename: 'alternate-dumbbell-bench-press',
  ),
  ExerciseInfo(
    name: 'Croci ai Cavi',
    nameEn: 'Cable Crossover',
    category: 'petto',
    muscleImages: ['petto.png'],
    primaryMuscle: 'Grande pettorale',
    secondaryMuscles: 'Deltoidi anteriori',
    execution:
        'Posizionati in piedi al centro tra due cavi regolati alti, afferra una maniglia per mano e fai un passo avanti assumendo una posizione stabile a piedi sfalsati con busto appena inclinato. Mantenendo i gomiti leggermente flessi e bloccati, porta le braccia ad arco in avanti e verso il basso fino a far incontrare le mani davanti all\'ombelico. Contrai intensamente il petto in chiusura, poi riapri lentamente controllando la tensione costante.',
    tips:
        'Evita di piegare ed estendere i gomiti durante il movimento, altrimenti trasformi le croci in una spinta. Mantieni il petto aperto e le spalle basse senza lasciarti tirare indietro dai cavi.',
    aliases: ['Croci ai cavi'],
    gifFilename: 'cable-crossover',
  ),
  ExerciseInfo(
    name: 'Panca Inclinata',
    nameEn: 'Incline Bench Press',
    category: 'petto',
    muscleImages: ['petto.png', 'tricipiti.png'],
    primaryMuscle: 'Petto superiore (clavicolare)',
    secondaryMuscles: 'Tricipiti, Deltoidi anteriori',
    execution:
        'Regola la panca tra 30 e 45 gradi, sdraiati con piedi saldi a terra e scapole ben incastrate e impugna il bilanciere con presa prona poco più larga delle spalle. Stacca la barra e scendi lentamente verso la parte alta del petto vicino alle clavicole mantenendo i gomiti leggermente chiusi sotto il bilanciere. Spingi con decisione verso l\'alto fino a estendere le braccia concentrando il lavoro sul fascio clavicolare del pettorale.',
    tips:
        'Un\'inclinazione intorno ai 30 gradi colpisce al meglio il petto alto limitando il sovraccarico dei deltoidi anteriori. Non staccare la testa o i glutei dalla panca durante la spinta.',
    aliases: ['Panca inclinata', 'Incline bench press', 'Incline bench', 'Panca alzata'],
    gifFilename: 'incline-barbell-bench-press',
  ),
  ExerciseInfo(
    name: 'Croci con Manubri',
    nameEn: 'Dumbbell Flyes',
    category: 'petto',
    muscleImages: ['petto.png'],
    primaryMuscle: 'Grande pettorale',
    secondaryMuscles: 'Deltoidi anteriori',
    execution:
        'Sdraiati supino sulla panca piana con piedi saldi a terra e scapole retratte, tenendo due manubri sopra il centro del petto con palmi uno di fronte all\'altro e gomiti leggermente piegati. Apri lentamente le braccia lateralmente descrivendo un ampio arco fino a portare i manubri all\'altezza del petto percependo un profondo allungamento pettorale. Richiudi poi le braccia con lo stesso arco fluido come se abbracciassi un tronco fino a contrarre il petto in cima.',
    tips:
        'Conserva sempre lo stesso leggero angolo dei gomiti in apertura e in chiusura per proteggere spalle e bicipiti. Usa carichi moderati evitando di far toccare i manubri con forza in alto.',
    aliases: ['Croci', 'Fly', 'Dumbbell fly', 'Croci manubri', 'Pectoral fly'],
    gifFilename: 'dumbbell-fly',
  ),
  ExerciseInfo(
    name: 'Push-Up',
    nameEn: 'Push-Up',
    category: 'petto',
    muscleImages: ['petto.png', 'tricipiti.png'],
    primaryMuscle: 'Grande pettorale',
    secondaryMuscles: 'Tricipiti, Core, Deltoidi anteriori',
    execution:
        'Assumi la posizione di plank alto a terra appoggiando le mani poco più larghe delle spalle, piedi vicini e corpo rigido in linea retta dalla testa ai talloni. Fletti i gomiti mantenendoli a circa 45 gradi rispetto ai fianchi e scendi con controllo fino a portare il petto a pochi centimetri dal pavimento. Spingi con forza attraverso i palmi estendendo le braccia fino a tornare in alto senza mai perdere la tenuta del core.',
    tips: 'Stringi addome e glutei per impedire al bacino di scendere verso terra o di salire verso l\'alto. Non lasciare cadere la testa in avanti cercando di toccare terra prima col mento che col petto.',
    aliases: ['Flessioni', 'Piegamenti', 'Pushup'],
    gifFilename: 'push-up',
  ),
  ExerciseInfo(
    name: 'Dip alle Parallele',
    nameEn: 'Parallel Bar Dips',
    category: 'petto',
    muscleImages: ['petto.png', 'tricipiti.png'],
    primaryMuscle: 'Grande pettorale (parte bassa)',
    secondaryMuscles: 'Tricipiti, Deltoidi anteriori',
    execution:
        'Sali in appoggio sulle parallele con braccia distese e presa salda, piega leggermente le ginocchia incrociando le caviglie e inclina il busto in avanti di circa 20-30 gradi. Scendi lentamente piegando i gomiti leggermente aperti verso l\'esterno finché le spalle arrivano all\'altezza dei gomiti e senti un chiaro allungamento del pettorale. Spingi con decisione verso l\'alto fino a distendere le braccia mantenendo il tronco proteso avanti.',
    tips:
        'L\'inclinazione in avanti sposta il carico sulla parte bassa del petto, mentre restare verticali isola i tricipiti. Non scendere oltre la tua mobilità di spalla evitando di far ruotare le spalle avanti.',
    aliases: ['Dip', 'Parallele', 'Dips petto'],
    gifFilename: 'chest-dips',
  ),
  // ── DORSO ──
  ExerciseInfo(
    name: 'Stacchi da Terra',
    nameEn: 'Deadlift',
    category: 'dorso',
    muscleImages: ['dorso.png', 'gambe.png', 'glutei.png'],
    primaryMuscle: 'Erettori spinali, Trapezio, Romboidi',
    secondaryMuscles: 'Glutei, Femorali, Core',
    execution:
        'Avvicina gli stinchi al bilanciere con piedi alla larghezza delle anche e barra sopra la metà del piede, abbassa i fianchi, afferra la barra fuori dalle gambe con presa prona o mista e metti in tensione dorsali e core. Apri il petto con schiena perfettamente neutra e spingi forte il pavimento con le gambe tenendo la barra sempre aderente agli stinchi e alle cosce. Estendi insieme ginocchia e anche fino in piedi, poi riabbassa guidando prima i fianchi indietro.',
    tips:
        'Elimina il gioco del bilanciere mettendo in tensione le braccia e la schiena prima di staccare il peso da terra. Non tirare mai con la zona lombare arrotondata e non iperestendere indietro in chiusura.',
    aliases: ['Stacchi', 'Stacco', 'Stacco da terra', 'Deadlift'],
    gifFilename: 'deadlift',
  ),
  ExerciseInfo(
    name: 'Trazioni alla Sbarra',
    nameEn: 'Pull-Up',
    category: 'dorso',
    muscleImages: ['dorso.png', 'bicipiti.png'],
    primaryMuscle: 'Gran dorsale',
    secondaryMuscles: 'Bicipiti, Romboidi, Trapezio medio',
    execution:
        'Appenditi a una sbarra alta con presa prona leggermente più larga delle spalle, braccia completamente distese e gambe ferme con addome e glutei attivi. Inizia la trazione deprimendo e avvicinando le scapole, poi tira il petto verso la sbarra guidando i gomiti verso il basso fino a superare la barra con il mento. Controlla brevemente la chiusura in alto e ridiscendi lentamente fino alla piena estensione controllata delle braccia.',
    tips: 'Pensa a portare i gomiti verso le tasche dei pantaloni anziché tirare solo con le braccia. Evita slanci delle ginocchia e non incassare le spalle verso le orecchie quando arrivi in cima.',
    aliases: ['Trazioni', 'Pull-up', 'Pullup'],
    gifFilename: 'pull-up',
  ),
  ExerciseInfo(
    name: 'Lat Machine',
    nameEn: 'Lat Pulldown',
    category: 'dorso',
    muscleImages: ['dorso.png', 'bicipiti.png'],
    primaryMuscle: 'Gran dorsale',
    secondaryMuscles: 'Bicipiti, Romboidi, Trapezio medio',
    execution:
        'Siediti alla lat machine bloccando le cosce sotto i cuscinetti e impugna la barra larga con presa prona leggermente oltre la larghezza delle spalle a braccia tese. Inclina leggermente indietro il busto aprendo lo sterno e tira la barra verso la parte alta del petto guidando i gomiti dritti verso il basso. Contrai a fondo i gran dorsali per un istante in basso, poi riaccompagna lentamente la barra verso l\'alto fino a pieno allungamento.',
    tips:
        'Non dondolare indietro con la schiena per chiudere la trazione e non portare mai la barra dietro la nuca. Inizia ogni ripetizione abbassando le scapole prima di piegare i gomiti.',
    aliases: ['Pulldown', 'Lat machine', 'Lat pulldown'],
    gifFilename: 'lat-pulldown',
  ),
  ExerciseInfo(
    name: 'Rematore con Bilanciere',
    nameEn: 'Barbell Row',
    category: 'dorso',
    muscleImages: ['dorso.png'],
    primaryMuscle: 'Gran dorsale, Romboidi',
    secondaryMuscles: 'Bicipiti, Trapezio, Erettori spinali',
    execution:
        'Mettiti in piedi con piedi larghi quanto le anche impugnando il bilanciere con presa prona alla larghezza delle spalle, piega leggermente le ginocchia e inclina il busto a circa 45 gradi con schiena piatta. Tira la barra verso la zona dell\'ombelico portando i gomiti indietro vicini ai fianchi e avvicinando con forza le scapole. Fermati un istante in contrazione del dorso, poi riabbassa lentamente il bilanciere fino a braccia distese senza muovere il busto.',
    tips:
        'Tieni il core rigido e lo sguardo leggermente avanti sul pavimento per preservare la curva cervicale. Se ti ritrovi a raddrizzare il tronco a ogni ripetizione, riduci leggermente il carico.',
    aliases: ['Rematore', 'Rematore bilanciere'],
    gifFilename: 'barbell-bent-over-row',
  ),
  ExerciseInfo(
    name: 'Rematore con Manubrio',
    nameEn: 'Dumbbell Row',
    category: 'dorso',
    muscleImages: ['dorso.png', 'bicipiti.png'],
    primaryMuscle: 'Gran dorsale, Romboidi',
    secondaryMuscles: 'Bicipiti, Trapezio',
    execution:
        'Appoggia una mano e il ginocchio dello stesso lato su una panca piana mantenendo la schiena parallela al suolo e l\'altro piede ben piantato a terra lateralmente, impugnando un manubrio con la mano libera a braccio teso. Tira il manubrio con un arco leggermente arretrato verso l\'anca portando il gomito vicino al fianco e retraendo la scapola. Contrai il gran dorsale in cima, poi scendi lentamente fino al pieno allungamento e cambia lato.',
    tips: 'Evita di ruotare il torace verso l\'alto per alzare un peso troppo pesante: le spalle devono restare allineate e parallele alla panca. Pensa a portare il manubrio verso la tasca e non verso la spalla.',
    aliases: ['Rematore manubrio', 'One arm row', 'Single arm row', 'Dumbbell row'],
    gifFilename: 'dumbbell-row',
  ),
  // ── SPALLE ──
  ExerciseInfo(
    name: 'Lento Avanti',
    nameEn: 'Overhead Press',
    category: 'spalle',
    muscleImages: ['spalle.png', 'tricipiti.png'],
    primaryMuscle: 'Deltoide anteriore e medio',
    secondaryMuscles: 'Tricipiti, Trapezio superiore, Core',
    execution:
        'Mettiti in piedi con piedi alla larghezza delle spalle e sostieni il bilanciere davanti alle clavicole con presa prona appena più larga delle spalle e gomiti leggermente avanti rispetto alla barra. Compatta glutei e addome per bloccare il bacino, spingi il bilanciere verticalmente sopra la testa spostando appena indietro il mento e poi riavanzando il capo sotto la barra a braccia estese. Riabbassa lentamente fino alle spalle lungo la stessa linea verticale.',
    tips: 'Stringere forte i glutei impedisce alla bassa schiena di inarcarsi quando il carico supera la testa. Mantieni i polsi dritti in linea con gli avambracci anziché piegarli indietro.',
    aliases: ['Shoulder Press', 'Overhead press', 'Military press'],
    gifFilename: 'barbell-shoulder-press',
  ),
  ExerciseInfo(
    name: 'Alzate Laterali',
    nameEn: 'Lateral Raises',
    category: 'spalle',
    muscleImages: ['spalle.png'],
    primaryMuscle: 'Deltoide medio',
    secondaryMuscles: 'Trapezio superiore',
    execution:
        'Mettiti in piedi con busto stabile e un manubrio in ogni mano lungo i fianchi con i gomiti appena flessi. Solleva entrambe le braccia lateralmente sul piano leggermente avanzato delle scapole fino a portare i manubri all\'altezza delle spalle con spalle basse. Fermati un istante in cima percependo la contrazione del deltoide laterale, poi riabbassa lentamente i pesi lungo i fianchi frenando la discesa.',
    tips:
        'Evita di dondolare il busto o di ruotare troppo i pollici verso il basso per non irritare la spalla: tieni la mano neutra e guida la salita con i gomiti.',
    aliases: ['Alzate laterali'],
    gifFilename: 'dumbbell-lateral-raise',
  ),
  ExerciseInfo(
    name: 'Alzate Frontali',
    nameEn: 'Front Raises',
    category: 'spalle',
    muscleImages: ['spalle.png'],
    primaryMuscle: 'Deltoide anteriore',
    secondaryMuscles: 'Deltoide medio, Petto superiore',
    execution:
        'Mettiti in piedi con piedi alla larghezza delle spalle impugnando due manubri davanti alle cosce con presa prona e gomiti morbidi. Solleva un braccio alla volta oppure entrambi insieme in avanti fino a portare i pesi all\'altezza delle spalle mantenendo il busto perfettamente fermo. Contrai per un istante il deltoide anteriore nel punto alto e riabbassa lentamente verso le cosce senza lasciar cadere il carico.',
    tips: 'Blocca il core per evitare di piegare indietro la zona lombare mentre i pesi salgono. Non superare la linea delle spalle per mantenere tutta la tensione sul deltoide anteriore.',
    aliases: ['Alzate frontali', 'Front raise'],
    gifFilename: 'dumbbell-front-raise',
  ),
  ExerciseInfo(
    name: 'Alzate Posteriori',
    nameEn: 'Rear Delt Flyes',
    category: 'spalle',
    muscleImages: ['spalle.png', 'dorso.png'],
    primaryMuscle: 'Deltoide posteriore',
    secondaryMuscles: 'Romboidi, Trapezio medio',
    execution:
        'Mettiti in piedi con ginocchia morbide e inclina il busto in avanti dalle anche fino a portarlo quasi parallelo al pavimento con schiena piatta, lasciando pendere due manubri sotto il petto con presa neutra. Solleva le braccia lateralmente tenendo i gomiti appena piegati fino a portarle all\'altezza delle spalle concentrandoti sul deltoide posteriore. Fermati un istante in alto senza stringere di scatto i trapezi, poi riabbassa lentamente i manubri.',
    tips:
        'Scegli manubri leggeri per non raddrizzare la schiena a ogni ripetizione. Pensa ad allontanare i pesi lateralmente verso le pareti anziché tirarli semplicemente verso il soffitto.',
    aliases: ['Alzate posteriori', 'Rear delt fly', 'Butterfly posteriore'],
    gifFilename: 'bent-over-lateral-raise',
  ),
  // ── BICIPITI ──
  ExerciseInfo(
    name: 'Curl con Bilanciere',
    nameEn: 'Barbell Curl',
    category: 'braccia',
    muscleImages: ['bicipiti.png'],
    primaryMuscle: 'Bicipite brachiale',
    secondaryMuscles: 'Brachiale, Brachioradiale',
    execution:
        'Mettiti in piedi con piedi alla larghezza delle spalle e impugna il bilanciere dritto con presa supina alla stessa larghezza, lasciando le braccia distese davanti alle cosce con i gomiti aderenti ai fianchi. Fletti gli avambracci sollevando la barra ad arco verso le spalle senza muovere la schiena né far avanzare i gomiti. Contrai intensamente i bicipiti nel punto alto e riabbassa lentamente il bilanciere fino a quasi estendere le braccia.',
    tips: 'Stringi glutei e addome per bloccare qualsiasi oscillazione del busto. Se devi darti slancio con i lombari per far partire il bilanciere, il peso è eccessivo.',
    aliases: ['Curl', 'Barbell curl'],
    gifFilename: 'barbell-curl',
  ),
  ExerciseInfo(
    name: 'Curl con Manubri Alternati',
    nameEn: 'Alternating Dumbbell Curl',
    category: 'braccia',
    muscleImages: ['bicipiti.png'],
    primaryMuscle: 'Bicipite brachiale',
    secondaryMuscles: 'Brachiale, Brachioradiale',
    execution:
        'Mettiti in piedi con un manubrio in ciascuna mano lungo i fianchi in presa neutra e gomiti vicini al busto. Fletti un solo gomito sollevando il manubrio verso la spalla mentre ruoti fluidamente il polso in supinazione portando il palmo verso l\'alto e il mignolo leggermente più alto in cima. Riabbassa lentamente il peso tornando in presa neutra lungo il fianco e ripeti subito con l\'altro braccio.',
    tips: 'La supinazione attiva lungo la salita recluta al massimo il bicipite brachiale. Mantieni ferme le spalle ed evita di inclinare il busto di lato mentre sollevi un braccio alla volta.',
    aliases: ['Curl manubri', 'Dumbbell curl', 'Curl alternato'],
    gifFilename: 'dumbbell-curl',
  ),
  ExerciseInfo(
    name: 'Curl Martello',
    nameEn: 'Hammer Curl',
    category: 'braccia',
    muscleImages: ['bicipiti.png', 'braccia.png'],
    primaryMuscle: 'Brachiale, Brachioradiale',
    secondaryMuscles: 'Bicipite brachiale',
    execution:
        'Mettiti in piedi con busto eretto impugnando due manubri lungo i fianchi con presa neutra, con i palmi rivolti verso le cosce e i pollici puntati avanti. Mantieni i gomiti fissi accanto alle costole e fletti gli avambracci portando i manubri verso la parte anteriore delle spalle senza mai ruotare i polsi. Contrai a fondo brachiale e brachioradiale in cima, poi scendi lentamente controllando la fase eccentrica.',
    tips: 'Mantieni i polsi rigidi e allineati agli avambracci senza piegarli indietro durante la salita. Puoi eseguirlo in modo simultaneo o alternato purché il busto resti immobile.',
    aliases: ['Curl hammer', 'Hammer curl'],
    gifFilename: 'hammer-curl',
  ),
  ExerciseInfo(
    name: 'Curl al Cavo Basso',
    nameEn: 'Cable Curl',
    category: 'braccia',
    muscleImages: ['bicipiti.png'],
    primaryMuscle: 'Bicipite brachiale',
    secondaryMuscles: 'Brachiale',
    execution:
        'Mettiti in piedi davanti a un cavo basso con barra dritta o sagomata, afferra l\'impugnatura con presa supina alla larghezza delle spalle e fai un piccolo passo indietro per creare tensione a braccia tese. Blocca i gomiti ai lati del busto e fletti gli avambracci portando la barra verso le spalle contro la trazione costante del cavo. Fermati un secondo nella massima contrazione in cima e poi rilascia lentamente fino a quasi estendere i gomiti.',
    tips:
        'A differenza dei pesi liberi, il cavo mantiene forte tensione anche in cima al movimento: sfrutta quel punto per una stretta decisa. Non farti trascinare avanti dal peso durante la discesa.',
    aliases: ['Curl cavo', 'Cable curl', 'Pulley curl'],
    gifFilename: 'cable-curl',
  ),
  // ── TRICIPITI ──
  ExerciseInfo(
    name: 'French Press',
    nameEn: 'Skull Crusher',
    category: 'braccia',
    muscleImages: ['tricipiti.png'],
    primaryMuscle: 'Tricipite brachiale (capo lungo)',
    secondaryMuscles: 'Tricipite (capo laterale e mediale)',
    execution:
        'Sdraiati supino su una panca piana con piedi saldi a terra e sostieni un bilanciere sagomato o due manubri sopra il petto a braccia tese leggermente inclinate indietro oltre la verticale delle spalle. Mantenendo gli omeri immobili, fletti solo i gomiti abbassando il carico lentamente verso la fronte o appena dietro la testa fino al pieno allungamento dei tricipiti. Estendi con controllo i gomiti riportando il carico nella posizione iniziale senza allargare le braccia.',
    tips: 'Portare la barra leggermente dietro la testa invece che sulla fronte aumenta l\'allungamento del capo lungo del tricipite e alleggerisce lo stress sui gomiti. Controlla sempre la discesa.',
    aliases: ['Skull crusher', 'French press bilanciere', 'Estensioni tricipiti sdraiato'],
    gifFilename: 'lying-barbell-triceps-extension',
  ),
  ExerciseInfo(
    name: 'Tricipiti ai Cavi',
    nameEn: 'Cable Tricep Pushdown',
    category: 'braccia',
    muscleImages: ['tricipiti.png'],
    primaryMuscle: 'Tricipite brachiale',
    secondaryMuscles: '',
    execution:
        'Posizionati in piedi davanti al cavo alto con corda o barra dritta, afferra l\'impugnatura, inclina leggermente avanti il busto e incolla i gomiti ai fianchi piegati a poco più di 90 gradi. Spingi verso il basso estendendo completamente i gomiti fino a portare le mani lungo le cosce e separando le estremità se usi la corda. Mantieni la contrazione dei tricipiti per un secondo in basso e poi risali lentamente senza muovere gli omeri.',
    tips:
        'Non staccare i gomiti dal busto e non piegarti sopra la maniglia usando il peso delle spalle. Tieni i polsi dritti per trasferire tutta la forza sui tricipiti.',
    aliases: ['Pushdown corda', 'Pushdown', 'Pushdown barra', 'Push down', 'Tricep pushdown'],
    gifFilename: 'rope-pushdown',
  ),
  ExerciseInfo(
    name: 'Dip ai Tricipiti',
    nameEn: 'Tricep Dips',
    category: 'braccia',
    muscleImages: ['tricipiti.png'],
    primaryMuscle: 'Tricipite brachiale',
    secondaryMuscles: 'Petto, Deltoide anteriore',
    execution:
        'Posizionati in appoggio sulle parallele a presa relativamente stretta mantenendo il busto il più verticale possibile, le spalle depresse e le gambe dritte sotto di te. Abbassa il corpo flettendo i gomiti dritti all\'indietro vicino ai fianchi fino a portare le braccia parallele al suolo senza inclinarti avanti. Spingi con forza verso l\'alto estendendo completamente i gomiti per concentrare tutto lo stimolo sui tricipiti.',
    tips:
        'Tenere il busto verticale e i gomiti stretti riduce il lavoro del pettorale e isola i tricipiti. Non far salire le spalle verso le orecchie nella parte bassa del movimento.',
    aliases: ['Dip tricipiti', 'Tricep dips', 'Bench dip'],
    gifFilename: 'triceps-dips',
  ),
  // ── GAMBE ──
  ExerciseInfo(
    name: 'Squat con Bilanciere',
    nameEn: 'Barbell Squat',
    category: 'gambe',
    muscleImages: ['gambe.png', 'quadricipiti.png', 'glutei.png'],
    primaryMuscle: 'Quadricipiti, Glutei',
    secondaryMuscles: 'Femorali, Core, Erettori spinali',
    execution:
        'Posiziona il bilanciere sui trapezi, staccalo dal rack e fai due passi indietro disponendo i piedi alla larghezza delle spalle con punte leggermente ruotate fuori. Inspira compattando il core, arretra leggermente con le anche e piega le ginocchia scendendo con controllo almeno fino al parallelo tenendo talloni saldi e schiena neutra. Spingi con forza attraverso tutta la pianta dei piedi risalendo in linea verticale fino a estendere completamente anche e ginocchia.',
    tips:
        'Mantieni le ginocchia sempre in linea con le punte dei piedi evitando che cedano verso l\'interno durante la risalita. Scegli la profondità che ti permette di non arrotondare la bassa schiena.',
    aliases: ['Squat', 'Back squat'],
    gifFilename: 'squat',
  ),
  ExerciseInfo(
    name: 'Leg Press',
    nameEn: 'Leg Press',
    category: 'gambe',
    muscleImages: ['gambe.png', 'quadricipiti.png'],
    primaryMuscle: 'Quadricipiti',
    secondaryMuscles: 'Glutei, Femorali',
    execution:
        'Siediti alla pressa regolando lo schienale in modo che schiena e bacino aderiscano interamente, appoggia i piedi al centro della pedana alla larghezza delle spalle e sblocca i fermi laterali. Abbassa lentamente la pedana flettendo le ginocchia verso il petto fino a circa 90 gradi o fin dove la zona lombare resta saldamente poggiata. Spingi con decisione attraverso tutta la pianta dei piedi estendendo le gambe senza bloccare bruscamente le ginocchia in cima.',
    tips:
        'Non staccare mai i glutei o la bassa schiena dallo schienale nel punto più basso per evitare compressioni lombari. Posizionare i piedi più bassi sulla pedana aumenta il lavoro sui quadricipiti.',
    aliases: ['Leg press', 'Pressa', 'Pressa 45'],
    gifFilename: 'leg-press',
  ),
  ExerciseInfo(
    name: 'Affondi',
    nameEn: 'Lunges',
    category: 'gambe',
    muscleImages: ['gambe.png', 'glutei.png'],
    primaryMuscle: 'Quadricipiti, Glutei',
    secondaryMuscles: 'Femorali, Core',
    execution:
        'Mettiti in piedi con busto eretto e mani sui fianchi oppure con due manubri lungo i lati, poi fai un ampio passo in avanti appoggiando bene l\'intera pianta del piede. Piega entrambe le ginocchia scendendo verticalmente fino a portare il ginocchio posteriore a pochi centimetri dal pavimento mantenendo il tronco dritto. Spingi con forza sul piede anteriore per tornare alla posizione di partenza e ripeti alternando le gambe.',
    tips:
        'Mantieni i piedi alla larghezza delle anche anche durante il passo avanti, non su una linea sola come su una fune, per avere grande stabilità. Controlla che il ginocchio anteriore non ceda verso l\'interno.',
    aliases: ['Affondo', 'Lunge', 'Lunges', 'Affondi a corpo libero'],
    gifFilename: 'bodyweight-lunge',
  ),
  ExerciseInfo(
    name: 'Leg Extension',
    nameEn: 'Leg Extension',
    category: 'gambe',
    muscleImages: ['quadricipiti.png'],
    primaryMuscle: 'Quadricipiti',
    secondaryMuscles: '',
    execution:
        'Siediti alla macchina regolando lo schienale per allineare le ginocchia al perno di rotazione e posiziona le caviglie dietro il rullo imbottito afferrando saldamente le maniglie laterali. Estendi le ginocchia con controllo sollevando il rullo fino a distendere del tutto le gambe davanti a te e contrarre a fondo i quadricipiti. Mantieni una breve pausa di un secondo in cima, poi riabbassa lentamente il peso senza far urtare il pacco.',
    tips: 'Tieni i glutei ben schiacciati contro il sedile per tutta la serie evitando di slanciare il carico in partenza. Un movimento fluido e controllato isola i quadricipiti proteggendo l\'articolazione del ginocchio.',
    aliases: ['Leg extension'],
    gifFilename: 'leg-extension',
  ),
  ExerciseInfo(
    name: 'Leg Curl',
    nameEn: 'Leg Curl',
    category: 'gambe',
    muscleImages: ['femorali.png'],
    primaryMuscle: 'Femorali (bicipite femorale)',
    secondaryMuscles: 'Gastrocnemio',
    execution:
        'Sdraiati prono sulla macchina per leg curl allineando le ginocchia al perno di rotazione, posiziona il rullo subito sopra i talloni e afferra saldamente le impugnature anteriori. Contrai gli ischiocrurali flettendo entrambe le ginocchia per portare i talloni verso i glutei tenendo il bacino ben premuto contro l\'imbottitura. Mantieni la contrazione di picco per un secondo in cima, poi riabbassa lentamente il rullo fino a quasi estendere le gambe.',
    tips:
        'Evita di sollevare i fianchi dalla panca quando il peso sale: significa che stai compensando con la bassa schiena. Tenere le punte dei piedi leggermente verso le tibie aumenta il reclutamento femorale.',
    aliases: ['Leg curl'],
    gifFilename: 'seated-leg-curl',
  ),
  ExerciseInfo(
    name: 'Romanian Deadlift',
    nameEn: 'Romanian Deadlift',
    category: 'gambe',
    muscleImages: ['femorali.png', 'glutei.png'],
    primaryMuscle: 'Femorali, Glutei',
    secondaryMuscles: 'Erettori spinali',
    execution:
        'Impugna il bilanciere in piedi davanti alle cosce con presa prona, piedi alla larghezza delle anche, scapole compatte e ginocchia leggermente piegate e bloccate in quell\'angolo. Spingi indietro il bacino inclinando il busto in avanti a schiena perfettamente neutra mentre fai scorrere la barra aderente alle gambe fino a metà stinco o finché senti massimo allungamento femorale. Contrai glutei e ischiocrurali spingendo le anche avanti fino a tornare eretto.',
    tips:
        'Scendi solo finché i fianchi riescono ad arretrare senza far arrotondare la schiena: forzare la barra fino a terra non migliora lo stimolo. Tieni sempre il bilanciere a contatto con cosce e stinchi.',
    aliases: ['Stacco rumeno', 'Stacchi rumeni', 'RDL'],
    gifFilename: 'romanian-deadlift',
  ),
  ExerciseInfo(
    name: 'Hip Thrust',
    nameEn: 'Hip Thrust',
    category: 'glutei',
    muscleImages: ['glutei.png', 'femorali.png'],
    primaryMuscle: 'Glutei (grande gluteo)',
    secondaryMuscles: 'Femorali, Core',
    execution:
        'Appoggia la parte inferiore delle scapole sul bordo di una panca stabile, sistema un bilanciere imbottito nella piega delle anche e pianta i piedi a terra alla larghezza delle spalle con le ginocchia piegate. Spingi con forza attraverso i talloni estendendo completamente le anche fino a formare una linea orizzontale tra spalle, bacino e ginocchia con tibie verticali. Stringi intensamente i glutei per un secondo in cima tenendo il mento verso il petto, poi scendi lentamente.',
    tips:
        'Evita di buttare indietro la testa o inarcare la bassa schiena in cima: mantieni le costole chiuse verso il bacino per massimizzare il lavoro dei glutei. Spingi leggermente le ginocchia verso l\'esterno.',
    aliases: ['Hip thrust'],
    gifFilename: 'barbell-hip-thrusts',
  ),
  ExerciseInfo(
    name: 'Glute Kickback',
    nameEn: 'Cable Glute Kickback',
    category: 'glutei',
    muscleImages: ['glutei.png'],
    primaryMuscle: 'Grande gluteo',
    secondaryMuscles: 'Femorali',
    execution:
        'Aggancia la cavigliera al cavo basso e fissala attorno a una caviglia, posizionati di fronte alla colonna dei pesi appoggiando le mani sul telaio con busto leggermente inclinato avanti e core saldo. Mantenendo la gamba tesa o leggermente morbida, spingi il tallone indietro e verso l\'alto estendendo l\'anca fino alla massima contrazione del grande gluteo. Fermati un istante in chiusura senza inarcare la zona lombare, poi ritorna lentamente avanti e cambia lato.',
    tips:
        'Ferma l\'estensione appena senti la bassa schiena inarcarsi o il bacino ruotare di lato. Un movimento più corto ma puro sull\'anca isola il gluteo molto meglio di uno slancio ampio.',
    aliases: ['Slanci', 'Slanci ai cavi', 'Kickback glutei', 'Calci glutei'],
    gifFilename: 'glute-kickback-machine',
  ),
  ExerciseInfo(
    name: 'Calf Raises',
    nameEn: 'Standing Calf Raises',
    category: 'gambe',
    muscleImages: ['gambe.png'],
    primaryMuscle: 'Gastrocnemio',
    secondaryMuscles: 'Soleo',
    execution:
        'Posizionati alla macchina per polpacci in piedi o su un gradino stabile appoggiando solo gli avampiedi sul bordo con i talloni sospesi e le ginocchia quasi del tutto estese. Spingi con decisione sulle punte salendo il più in alto possibile fino a una contrazione piena del gastrocnemio e trattieni un secondo in cima. Scendi lentamente lasciando calare i talloni sotto il livello del bordo per un allungamento profondo prima di ripartire.',
    tips:
        'Inserisci una breve pausa nel punto più basso di allungamento per annullare il rimbalzo elastico del tendine d\'Achille. Spingi in modo uniforme evitando di far cedere le caviglie verso l\'esterno.',
    aliases: ['Calf', 'Polpacci', 'Calf in piedi', 'Sollevamenti sulle punte'],
    gifFilename: 'calf-raise',
  ),
  // ── CORE ──
  ExerciseInfo(
    name: 'Plank',
    nameEn: 'Plank',
    category: 'core',
    muscleImages: [],
    primaryMuscle: 'Core (trasverso dell\'addome, retto)',
    secondaryMuscles: 'Erettori spinali, Deltoidi, Glutei',
    execution:
        'Appoggia gli avambracci a terra con i gomiti esattamente sotto le spalle, punta le dita dei piedi al suolo e solleva il corpo creando una linea retta continua da capo a talloni. Contrai energicamente addome, glutei e quadricipiti spingendo leggermente i gomiti verso i piedi e le scapole lontano dalle orecchie per generare massima tensione. Mantieni questa tenuta isometrica respirando regolarmente senza mai perdere l\'allineamento.',
    tips:
        'Se la bassa schiena inizia a cedere verso terra o i glutei salgono a tetto, interrompi la tenuta e riposa. Una breve retroversione del bacino protegge i lombari e raddoppia il lavoro dell\'addome.',
    gifFilename: 'plank',
  ),
  ExerciseInfo(
    name: 'Crunch',
    nameEn: 'Crunch',
    category: 'core',
    muscleImages: [],
    primaryMuscle: 'Retto dell\'addome',
    secondaryMuscles: 'Obliqui',
    execution:
        'Sdraiati supino su un tappetino con le ginocchia piegate, i piedi appoggiati a terra e le dita leggermente poggiate dietro le tempie con i gomiti aperti. Espira e contrai il retto addominale sollevando testa e scapole da terra arrotolando le costole verso il bacino senza staccare la zona lombare. Mantieni la contrazione di picco per un istante nel punto più alto e riabbassa lentamente le spalle al tappetino.',
    tips:
        'Non intrecciare le dita tirando in avanti il collo: guarda un punto sul soffitto per mantenere spazio tra mento e sterno. Il movimento è corto e mirato, non serve sedersi completamente.',
    aliases: ['Crunch a terra', 'Crunch addominali'],
    gifFilename: 'crunch',
  ),
  ExerciseInfo(
    name: 'Russian Twist',
    nameEn: 'Russian Twist',
    category: 'core',
    muscleImages: [],
    primaryMuscle: 'Obliqui addominali',
    secondaryMuscles: 'Retto dell\'addome',
    execution:
        'Siediti a terra con le ginocchia piegate, inclina il busto indietro a circa 45 gradi con schiena lunga e addome contratto e scegli se tenere i talloni appoggiati o sollevati da terra. Ruota con controllo il torace prima da un lato e poi dall\'altro portando le mani unite o un peso leggero verso il pavimento accanto al fianco. Mantieni un ritmo fluido e bilanciato seguendo la rotazione con le spalle e lo sguardo.',
    tips:
        'Gira davvero la gabbia toracica e non limitarti a spostare le mani a destra e sinistra tenendo il petto fermo. Se senti fastidio alla bassa schiena, appoggia i talloni a terra e raddrizza il dorso.',
    gifFilename: 'russian-twist',
  ),
  ExerciseInfo(
    name: 'Leg Raise',
    nameEn: 'Hanging Leg Raise',
    category: 'core',
    muscleImages: [],
    primaryMuscle: 'Retto dell\'addome (parte bassa)',
    secondaryMuscles: 'Flessori dell\'anca, Obliqui',
    execution:
        'Appenditi a una sbarra alta con presa prona alla larghezza delle spalle, attiva le scapole per stabilizzare il corpo e tieni le gambe unite e distese sotto di te. Contrai l\'addome sollevando entrambe le gambe tese verso l\'alto fino a superare l\'orizzontale e arrotolando leggermente il bacino verso le costole. Riabbassa lentamente le gambe frenando la discesa con il core per evitare qualsiasi oscillazione del busto.',
    tips: 'Per attivare davvero il retto addominale e non solo i flessori dell\'anca devi ruotare il bacino verso l\'alto a fine salita. Se il movimento è troppo duro a gambe tese, piega leggermente le ginocchia.',
    aliases: ['Alzate gambe', 'Sollevamento gambe', 'Leg raise alla sbarra', 'Hanging leg raise'],
    gifFilename: 'hanging-leg-raises',
  ),
  // ── MOVIMENTI COMPOSTI ──
  ExerciseInfo(
    name: 'Clean and Press',
    nameEn: 'Clean and Press',
    category: 'spalle',
    muscleImages: ['spalle.png', 'gambe.png'],
    primaryMuscle: 'Corpo intero',
    secondaryMuscles: 'Gambe, Schiena, Spalle, Core',
    execution:
        'Posizionati davanti al bilanciere a terra con piedi larghi quanto le anche, presa prona esterna alle ginocchia e schiena neutra. Estendi esplosivamente gambe e anche tirando la barra rasente al corpo, ruota i gomiti sotto per riceverla sulle spalle anteriori in girata e stabilizza la postura. Da lì contrai glutei e core e spingi il bilanciere sopra la testa fino a estendere le braccia, poi riabbassa con controllo.',
    tips:
        'Usa l\'esplosività delle anche per far salire il bilanciere alle spalle anziché tirarlo su di bicipiti. Padroneggia separatamente la girata e la spinta sopra la testa prima di aumentare il carico.',
    gifFilename: 'barbell-clean-and-press',
  ),
  ExerciseInfo(
    name: 'Kettlebell Swing',
    nameEn: 'Kettlebell Swing',
    category: 'glutei',
    muscleImages: ['glutei.png', 'femorali.png', 'dorso.png'],
    primaryMuscle: 'Catena posteriore (glutei, femorali)',
    secondaryMuscles: 'Core, Spalle, Erettori spinali',
    execution:
        'Posizionati con i piedi leggermente più larghi delle spalle dietro un kettlebell a terra, piega le anche indietro a schiena piatta, afferra la maniglia e portalo indietro alto tra le cosce. Estendi con forza esplosiva le anche contraendo glutei e addome per proiettare il kettlebell avanti fino all\'altezza del petto con le braccia completamente distese e rilassate. Lascia ricadere il peso guidandolo di nuovo tra le gambe piegando le anche all\'ultimo istante.',
    tips: 'Il kettlebell swing è una potente cerniera dell\'anca, non uno squat: le ginocchia si piegano appena e le braccia fungono solo da corde. Non inarcare la schiena quando il peso sale davanti a te.',
    gifFilename: 'kettlebell-swings',
  ),
  ExerciseInfo(
    name: 'Face Pull',
    nameEn: 'Face Pull',
    category: 'spalle',
    muscleImages: ['spalle.png', 'dorso.png'],
    primaryMuscle: 'Deltoide posteriore, Rotatori esterni',
    secondaryMuscles: 'Trapezio medio, Romboidi',
    execution:
        'Regola il cavo all\'altezza del viso o poco sopra con la corda, afferra le estremità con presa neutra e pollici rivolti verso di te e fai un passo indietro creando tensione a braccia distese. Tira la corda dritta verso la fronte aprendo i gomiti lateralmente all\'altezza delle spalle e separando le mani mentre ruoti esternamente le spalle portando i polsi dietro i gomiti. Fermati un secondo in piena contrazione del dorso alto e rilascia lentamente.',
    tips:
        'Cerca di far arrivare le mani allo stesso livello o leggermente più indietro dei gomiti per attivare bene gli extrarotatori della spalla. Usa un carico moderato ed evita di piegarti indietro per tirare.',
    gifFilename: 'face-pull',
  ),
  // ── PETTO (extra) ──
  ExerciseInfo(
    name: 'Panca Declinata',
    nameEn: 'Decline Bench Press',
    category: 'petto',
    muscleImages: ['petto.png', 'tricipiti.png'],
    primaryMuscle: 'Petto inferiore (sternale)',
    secondaryMuscles: 'Tricipiti, Deltoidi anteriori',
    execution:
        'Sdraiati sulla panca declinata tra 15 e 30 gradi bloccando saldamente le caviglie sotto i rulli, adduci le scapole e afferra il bilanciere con presa prona più larga delle spalle. Stacca la barra e abbassala con controllo fino alla parte inferiore dello sterno tenendo i gomiti a circa 45 gradi rispetto ai fianchi. Spingi con forza verso l\'alto fino a estendere le braccia concentrando il lavoro sul fascio inferiore del grande pettorale.',
    tips:
        'Chiedi assistenza a un compagno per staccare e riappoggiare la barra in sicurezza data la posizione declinata. Controlla la fase eccentrica evitando rimbalzi sul petto basso.',
    gifFilename: 'decline-barbell-bench-press',
  ),
  ExerciseInfo(
    name: 'Peck Deck',
    nameEn: 'Pec Deck Machine',
    category: 'petto',
    muscleImages: ['petto.png'],
    primaryMuscle: 'Grande pettorale',
    secondaryMuscles: 'Deltoidi anteriori',
    execution:
        'Siediti alla macchina pec deck regolando il sedile affinché le maniglie o i cuscinetti siano all\'altezza del centro del petto, appoggia bene la schiena con scapole retratte e impugna le leve. Spingi le braccia ad arco verso il centro davanti allo sterno fino a far quasi toccare le leve mantenendo i gomiti leggermente flessi e spalle basse. Contrai intensamente i pettorali per un istante, poi riapri lentamente fino a un allungamento confortevole.',
    tips:
        'Non staccare le spalle dallo schienale quando chiudi le braccia davanti al petto. Evita di aprire troppo indietro le leve oltre la linea del busto per non stressare la capsula anteriore della spalla.',
    aliases: ['Butterfly', 'Pec deck', 'Pectoral machine', 'Croci alla macchina'],
    gifFilename: 'pec-deck-fly',
  ),
  ExerciseInfo(
    name: 'Pull Over',
    nameEn: 'Dumbbell Pullover',
    category: 'petto',
    muscleImages: ['petto.png', 'dorso.png'],
    primaryMuscle: 'Grande pettorale, Gran dorsale',
    secondaryMuscles: 'Tricipiti, Dentato anteriore',
    execution:
        'Sdraiati supino su una panca piana o trasversalmente sulle scapole con piedi saldi a terra e sostieni un manubrio sopra il petto con entrambe le mani sotto il disco superiore. Con gomiti leggermente flessi e bloccati, abbassa lentamente il peso ad arco dietro la testa finché senti un profondo allungamento su pettorale e dorsale. Riporta il manubrio sopra lo sterno contraendo petto e dorsali senza inarcare i lombari.',
    tips:
        'Tieni le costole basse e l\'addome attivo quando il manubrio scende dietro la testa per evitare di compensare con la bassa schiena. Scegli un peso controllabile e non trasformarlo in un\'estensione dei tricipiti.',
    aliases: ['Pullover', 'Pullover manubrio'],
    gifFilename: 'dumbbell-pullover',
  ),
  ExerciseInfo(
    name: 'Chest Press Macchina',
    nameEn: 'Machine Chest Press',
    category: 'petto',
    muscleImages: ['petto.png', 'tricipiti.png'],
    primaryMuscle: 'Grande pettorale',
    secondaryMuscles: 'Tricipiti, Deltoidi anteriori',
    execution:
        'Siediti alla chest press regolando il sedile in modo che le maniglie si trovino all\'altezza del centro del petto, appoggia testa, scapole e glutei allo schienale e pianta bene i piedi a terra. Spingi le leve in avanti estendendo le braccia fino a quasi distendere i gomiti mantenendo le spalle ben indietro contro l\'imbottitura. Riporta lentamente le impugnature indietro fino a percepire un buon allungamento pettorale senza far urtare i pesi.',
    tips:
        'Non proiettare le spalle in avanti staccandole dallo schienale alla fine della spinta. Tieni i polsi in linea con gli avambracci e i gomiti leggermente più bassi rispetto alla linea delle spalle.',
    aliases: ['Chest press'],
    gifFilename: 'chest-press-machine',
  ),
  // ── DORSO (extra) ──
  ExerciseInfo(
    name: 'Pulley Basso',
    nameEn: 'Seated Cable Row',
    category: 'dorso',
    muscleImages: ['dorso.png', 'bicipiti.png'],
    primaryMuscle: 'Gran dorsale, Romboidi',
    secondaryMuscles: 'Bicipiti, Trapezio medio, Erettori spinali',
    execution:
        'Siediti alla macchina pulley basso appoggiando i piedi sui supporti con ginocchia leggermente piegate, afferra la maniglia stretta a presa neutra e raddrizza bene la schiena aprendo il torace. Tira la maniglia verso la parte bassa dell\'addome guidando i gomiti rasenti ai fianchi e avvicinando con decisione le scapole. Mantieni la contrazione dorsale per un secondo a fine corsa, poi accompagna lentamente le braccia avanti senza curvare la schiena.',
    tips:
        'Inizia la trazione deprimendo e retraendo le scapole invece di tirare subito con i bicipiti. Mantieni il tronco pressoché verticale evitando ampie oscillazioni avanti e indietro.',
    aliases: ['Pulley', 'Rematore ai cavi', 'Seated row'],
    gifFilename: 'seated-cable-row',
  ),
  ExerciseInfo(
    name: 'Trazioni Presa Neutra',
    nameEn: 'Neutral Grip Pull-Up',
    category: 'dorso',
    muscleImages: ['dorso.png', 'bicipiti.png'],
    primaryMuscle: 'Gran dorsale, Bicipiti',
    secondaryMuscles: 'Romboidi, Brachiale, Trapezio medio',
    execution:
        'Appenditi alle impugnature parallele della sbarra con presa neutra, palmi uno di fronte all\'altro alla larghezza delle spalle e braccia completamente tese. Compatta il core, abbassa le scapole e tira il corpo verso l\'alto portando lo sterno verso le mani e i gomiti dritti lungo i fianchi finché il mento supera le impugnature. Trattieni un istante la chiusura in cima e ridiscendi lentamente fino alla completa estensione controllata delle braccia.',
    tips:
        'La presa neutra allinea in modo naturale spalle e gomiti e consente un forte contributo di brachiale e gran dorsale. Evita slanci con le gambe e mantieni il petto aperto verso l\'alto.',
    aliases: ['Trazioni neutre', 'Neutral grip pullup', 'Chin-up neutro'],
    gifFilename: 'neutral-grip-pull-up',
  ),
  ExerciseInfo(
    name: 'Back Extension',
    nameEn: 'Back Extension',
    category: 'dorso',
    muscleImages: ['dorso.png'],
    primaryMuscle: 'Erettori spinali',
    secondaryMuscles: 'Glutei, Femorali',
    execution:
        'Posizionati prono sulla panca per iperestensioni regolando il cuscinetto subito sotto le pieghe delle anche, blocca saldamente i talloni e incrocia le braccia sul petto. Piega lentamente il busto verso il basso mantenendo la colonna lunga fino a sentire allungarsi femorali e glutei. Risali contraendo glutei ed erettori spinali fino a portare il tronco perfettamente allineato alle gambe senza superare la linea retta.',
    tips:
        'Fermati quando il corpo è perfettamente in linea ed evita di inarcare indietro la zona lombare in cima. Mantieni il mento leggermente retratto per tenere il collo allineato alla colonna.',
    aliases: ['Iperestensioni', 'Roman chair', 'Hyperextension', 'Hyperextensions'],
    gifFilename: 'hyperextension',
  ),
  ExerciseInfo(
    name: 'Good Morning',
    nameEn: 'Good Morning',
    category: 'dorso',
    muscleImages: ['dorso.png', 'femorali.png'],
    primaryMuscle: 'Erettori spinali, Femorali',
    secondaryMuscles: 'Glutei, Core',
    execution:
        'Posiziona un bilanciere sui trapezi come nello squat, mettiti in piedi con i piedi alla larghezza delle anche, ginocchia leggermente piegate e schiena ben compatta. Spingi i fianchi indietro inclinando il busto in avanti con la colonna perfettamente neutra fino a portare il tronco vicino all\'orizzontale e avvertire forte tensione negli ischiocrurali. Contrai glutei e femorali per spingere il bacino avanti e tornare completamente eretto.',
    tips:
        'L\'esercizio nasce da una cerniera dell\'anca pura: non flettere mai la colonna lombare sotto il carico. Inizia sempre con bilanciere scarico o pesi leggeri e imposta i fermi di sicurezza del rack.',
    gifFilename: 'good-morning',
  ),
  // ── SPALLE (extra) ──
  ExerciseInfo(
    name: 'Arnold Press',
    nameEn: 'Arnold Press',
    category: 'spalle',
    muscleImages: ['spalle.png'],
    primaryMuscle: 'Deltoide anteriore e medio',
    secondaryMuscles: 'Tricipiti, Trapezio superiore',
    execution:
        'Siediti su una panca con schienale verticale o stai in piedi tenendo due manubri davanti alle spalle con i gomiti piegati davanti al petto e i palmi rivolti verso il viso. Spingi i pesi verso l\'alto mentre apri fluidamente i gomiti lateralmente e ruoti i polsi finché i palmi guardano in avanti a braccia distese sopra la testa. Riabbassa lentamente i manubri invertendo la rotazione fino a tornare con i palmi rivolti verso di te.',
    tips:
        'Esegui la rotazione in modo continuo lungo tutta la spinta anziché spezzare il gesto in due movimenti distinti. Non inarcare la schiena e non far scontrare i manubri sopra la testa.',
    gifFilename: 'arnold-press',
  ),
  ExerciseInfo(
    name: 'Shoulder Press Macchina',
    nameEn: 'Machine Shoulder Press',
    category: 'spalle',
    muscleImages: ['spalle.png'],
    primaryMuscle: 'Deltoide anteriore e medio',
    secondaryMuscles: 'Tricipiti, Trapezio superiore',
    execution:
        'Siediti alla macchina per spinte sopra la testa regolando il sedile in modo che le maniglie partano all\'altezza delle orecchie, appoggia bene la schiena allo schienale e impugna le leve. Spingi verticalmente verso l\'alto fino a quasi estendere completamente i gomiti mantenendo le spalle depresse e il core saldo. Abbassa lentamente le leve fino all\'altezza del mento o delle spalle controllando la discesa senza far urtare i pesi.',
    tips:
        'Tieni sempre la bassa schiena aderente allo schienale senza scivolare avanti con i glutei. La traiettoria guidata permette di concentrarti su un ritmo lento e controllato nei deltoidi.',
  ),
  ExerciseInfo(
    name: 'Alzate di Spalle',
    nameEn: 'Shoulder Shrug',
    category: 'spalle',
    muscleImages: ['spalle.png'],
    primaryMuscle: 'Trapezio superiore',
    secondaryMuscles: 'Elevatori della scapola',
    execution:
        'Mettiti in piedi con piedi alla larghezza delle anche impugnando due manubri lungo i fianchi oppure un bilanciere davanti alle cosce a braccia completamente distese. Mantieni i gomiti dritti e il collo neutro, poi solleva verticalmente le spalle più in alto possibile verso le orecchie contraendo con forza il trapezio superiore. Trattieni la contrazione di picco per un secondo in cima e riabbassa lentamente le spalle fino al completo allungamento.',
    tips:
        'Non ruotare le spalle avanti o indietro: la direzione delle fibre del trapezio richiede solo una salita verticale pulita. Evita di spingere il mento avanti o piegare i gomiti per alzare un peso eccessivo.',
    aliases: ['Scrollate', 'Scrollate di spalle', 'Shrug'],
    gifFilename: 'barbell-shrug',
  ),
  // ── BRACCIA (extra) ──
  ExerciseInfo(
    name: 'Push Up Diamante',
    nameEn: 'Diamond Push-Up',
    category: 'braccia',
    muscleImages: ['tricipiti.png', 'petto.png'],
    primaryMuscle: 'Tricipite brachiale',
    secondaryMuscles: 'Petto, Deltoidi anteriori',
    execution:
        'Assumi la posizione di piegamento a terra avvicinando le mani sotto il centro dello sterno fino a far toccare pollici e indici formando un diamante, con corpo rigido in linea retta. Abbassa lentamente il petto verso le mani mantenendo i gomiti stretti e vicini ai fianchi mentre senti la forte tensione sui tricipiti. Spingi con decisione estendendo completamente le braccia fino a tornare in alto senza cedere con i fianchi.',
    tips:
        'Se i polsi avvertono fastidio con le mani completamente unite, separale di pochi centimetri ruotando leggermente le dita verso l\'esterno. Non aprire i gomiti lateralmente durante la discesa.',
    gifFilename: 'diamond-push-up',
  ),
  ExerciseInfo(
    name: 'Concentration Curl',
    nameEn: 'Concentration Curl',
    category: 'braccia',
    muscleImages: ['bicipiti.png'],
    primaryMuscle: 'Bicipite brachiale (picco)',
    secondaryMuscles: 'Brachiale',
    execution:
        'Siediti sul bordo di una panca con le gambe divaricate, inclinati leggermente avanti appoggiando il retro del braccio carico contro l\'interno coscia e stabilizza l\'altra mano sul ginocchio opposto. Con il braccio disteso in verticale e presa supina, fletti lentamente il gomito portando il manubrio verso la spalla senza staccare il tricipite dalla coscia. Contrai forte il picco del bicipite ruotando bene il mignolo verso l\'alto, poi scendi lento e cambia braccio.',
    tips:
        'La coscia funge da blocco assoluto contro lo slancio: non spingere con la gamba e non sollevare la spalla durante la salita. Mantieni il movimento lento per massimizzare l\'isolamento.',
    gifFilename: 'concentration-curl',
  ),
  ExerciseInfo(
    name: 'Scott Curl',
    nameEn: 'Preacher Curl',
    category: 'braccia',
    muscleImages: ['bicipiti.png'],
    primaryMuscle: 'Bicipite brachiale (capo corto)',
    secondaryMuscles: 'Brachiale',
    execution:
        'Siediti alla panca Scott sistemando il petto contro il bordo e appoggiando l\'intera parte posteriore delle braccia sul cuscino inclinato, impugnando un bilanciere o manubri con presa supina. Fletti i gomiti portando il carico verso le spalle mantenendo gli omeri sempre incollati all\'imbottitura. Fermati prima che gli avambracci diventino del tutto verticali per non perdere tensione, poi abbassa lentamente fino a quasi distendere i gomiti.',
    tips:
        'Controlla con molta attenzione la fase più bassa del movimento evitando di lasciar cadere il peso di colpo sui gomiti. Non staccare i glutei dal sedile per aiutarti a superare la partenza.',
    aliases: ['Preacher curl', 'Curl scott', 'Curl al banco'],
    gifFilename: 'dumbbell-scott-curl',
  ),
  ExerciseInfo(
    name: 'Overhead Tricep Extension',
    nameEn: 'Overhead Tricep Extension',
    category: 'braccia',
    muscleImages: ['tricipiti.png'],
    primaryMuscle: 'Tricipite (capo lungo)',
    secondaryMuscles: 'Tricipite (capi laterale e mediale)',
    execution:
        'Mettiti in piedi o seduto con schiena dritta e sostieni un manubrio con entrambe le mani oppure una barra sopra la testa a braccia quasi distese, con il core ben contratto. Mantenendo i gomiti puntati avanti e vicini alla testa, fletti lentamente gli avambracci abbassando il carico dietro la nuca fino a percepire un profondo allungamento del capo lungo del tricipite. Estendi i gomiti riportando il peso sopra la testa con pieno controllo.',
    tips:
        'Evita di allargare i gomiti lateralmente mentre il peso scende e non inarcare la zona lombare spingendo avanti l\'addome. Questa posizione allungata è tra le più efficaci per il capo lungo del tricipite.',
    aliases: ['Estensioni tricipiti', 'Tricep overhead', 'Estensione sopra testa'],
    gifFilename: 'seated-ez-bar-overhead-triceps-extension',
  ),
  // ── GAMBE/GLUTEI (extra) ──
  ExerciseInfo(
    name: 'Hip Abductor',
    nameEn: 'Hip Abductor Machine',
    category: 'glutei',
    muscleImages: ['glutei.png'],
    primaryMuscle: 'Gluteo medio, Piccolo gluteo',
    secondaryMuscles: 'Tensore della fascia lata',
    execution:
        'Siediti alla macchina per abduttori appoggiando bene schiena e bacino allo schienale, posiziona l\'esterno di ginocchia e cosce contro i cuscinetti imbottiti e afferra le maniglie laterali. Spingi con controllo le gambe verso l\'esterno aprendole contro la resistenza fino alla massima contrazione di gluteo medio e piccolo gluteo. Trattieni un secondo nel punto di massima apertura e poi richiudi lentamente senza far sbattere i pesi.',
    tips:
        'Evita di darti slancio con il busto o di rimbalzare velocemente in chiusura. Inclinare leggermente il tronco avanti mantenendo la schiena dritta può accentuare la percezione sui glutei laterali.',
    aliases: ['Abductor machine', 'Abduttori', 'Abduttori macchina'],
    gifFilename: 'hip-abduction-machine',
  ),
  ExerciseInfo(
    name: 'Donkey Kick',
    nameEn: 'Donkey Kick',
    category: 'glutei',
    muscleImages: ['glutei.png'],
    primaryMuscle: 'Grande gluteo',
    secondaryMuscles: 'Femorali, Erettori spinali',
    execution:
        'Mettiti in quadrupedia su un tappetino con le mani direttamente sotto le spalle, le ginocchia sotto le anche e la colonna perfettamente neutra con addome attivo. Mantenendo il ginocchio piegato a 90 gradi e il piede a martello, spingi il tallone di una gamba verso il soffitto contraendo energicamente il grande gluteo. Fermati un secondo quando la coscia raggiunge la linea del busto senza inarcare la schiena, poi scendi controllato e cambia lato.',
    tips:
        'Non alzare la coscia oltre l\'orizzontale inarcando la zona lombare: il movimento deve avvenire solo nell\'articolazione dell\'anca. Tieni il peso distribuito in modo equilibrato su entrambe le mani.',
    gifFilename: 'donkey-kicks',
  ),
  ExerciseInfo(
    name: 'Bulgarian Split Squat',
    nameEn: 'Bulgarian Split Squat',
    category: 'gambe',
    muscleImages: ['gambe.png', 'glutei.png'],
    primaryMuscle: 'Quadricipiti, Glutei',
    secondaryMuscles: 'Femorali, Core, Stabilizzatori della caviglia',
    execution:
        'Mettiti in piedi dando le spalle a una panca stabile, appoggia il collo del piede posteriore sul bordo della panca e trova una distanza comoda con il piede anteriore ben piantato a terra. Scendi con controllo piegando il ginocchio anteriore e portando il ginocchio posteriore verso il pavimento finché la coscia anteriore è almeno parallela al suolo. Spingi con forza attraverso tutta la pianta del piede anteriore per tornare su, completa il lato e poi cambia gamba.',
    tips:
        'Una lieve inclinazione controllata del busto avanti enfatizza i glutei, mentre un busto più verticale carica di più il quadricipite. Evita di appoggiare troppo peso sul piede posteriore.',
    aliases: ['BSS', 'Split squat bulgaro', 'Split squat', 'Affondi bulgari'],
    gifFilename: 'barbell-bulgarian-split-squat',
  ),
  ExerciseInfo(
    name: 'Goblet Squat',
    nameEn: 'Goblet Squat',
    category: 'gambe',
    muscleImages: ['gambe.png', 'glutei.png'],
    primaryMuscle: 'Quadricipiti, Glutei',
    secondaryMuscles: 'Core, Femorali',
    execution:
        'Mettiti in piedi con piedi leggermente più larghi delle spalle e punte un po\' aperte, reggendo un kettlebell o un manubrio verticale davanti al petto con i gomiti vicini al busto. Scendi in squat profondo mantenendo il torace ben aperto e la schiena neutra mentre fai passare i gomiti all\'interno delle ginocchia. Spingi attraverso l\'intero piede tenendo i talloni incollati a terra fino a tornare completamente eretto.',
    tips:
        'Il peso tenuto davanti allo sterno funge da contrappeso naturale aiutandoti a tenere il busto verticale e la schiena sicura. Spingi attivamente le ginocchia verso l\'esterno in discesa e in salita.',
    gifFilename: 'kettlebell-goblet-squat',
  ),
  ExerciseInfo(
    name: 'Sumo Deadlift',
    nameEn: 'Sumo Deadlift',
    category: 'gambe',
    muscleImages: ['gambe.png', 'glutei.png', 'dorso.png'],
    primaryMuscle: 'Glutei, Adduttori, Quadricipiti',
    secondaryMuscles: 'Femorali, Erettori spinali',
    execution:
        'Posizionati davanti al bilanciere con piedi ampiamente divaricati oltre le spalle e punte ruotate verso l\'esterno, abbassa le anche aprendo le ginocchia e afferra la barra tra le gambe a braccia tese. Metti in tensione dorsali e core tenendo il busto più verticale rispetto allo stacco classico e spingi con forza il pavimento divaricando le ginocchia mentre la barra sale aderente agli stinchi. Estendi insieme gambe e anche fino al blocco eretto, poi riabbassa controllato.',
    tips:
        'Spingi le ginocchia ben all\'esterno in linea con le punte dei piedi fin dal primo centimetro di spinta. Evita che il bacino salga prima delle spalle lasciando la schiena parallela al pavimento.',
    aliases: ['Stacco sumo', 'Stacchi sumo'],
    gifFilename: 'sumo-deadlift',
  ),
  ExerciseInfo(
    name: 'Step Up',
    nameEn: 'Step Up',
    category: 'gambe',
    muscleImages: ['gambe.png', 'glutei.png'],
    primaryMuscle: 'Quadricipiti, Glutei',
    secondaryMuscles: 'Femorali, Core',
    execution:
        'Mettiti in piedi davanti a un box o a una panca robusta a corpo libero o con manubri lungo i fianchi, e appoggia l\'intera pianta di un piede sopra il rialzo. Spingi con forza attraverso il tallone e il centro del piede sul rialzo estendendo ginocchio e anca fino a salire completamente in piedi appoggiando anche l\'altro piede. Scendi lentamente controllando la discesa con la stessa gamba d\'appoggio, poi alterna o completa prima un lato.',
    tips:
        'Evita di slanciarti spingendo forte dal piede rimasto a terra: concentrati sul far lavorare solo la gamba sul box. Controlla la fase di discesa senza lasciarti cadere di colpo sul pavimento.',
    gifFilename: 'dumbbell-step-up',
  ),
  // ── CORE (extra) ──
  ExerciseInfo(
    name: 'Plank Laterale',
    nameEn: 'Side Plank',
    category: 'core',
    muscleImages: [],
    primaryMuscle: 'Obliqui addominali, Quadrato dei lombi',
    secondaryMuscles: 'Core, Deltoidi, Gluteo medio',
    execution:
        'Sdraiati su un fianco appoggiando l\'avambraccio a terra con il gomito esattamente sotto la spalla, gambe distese e piedi sovrapposti oppure sfalsati per maggiore appoggio. Solleva il bacino da terra fino a disegnare una linea retta continua dalla testa alle caviglie con l\'altra mano appoggiata sul fianco o distesa verso l\'alto. Contrai intensamente obliqui, addome e glutei mantenendo la posizione respirando regolare, poi ripeti sul lato opposto.',
    tips:
        'Spingi attivamente il pavimento con l\'avambraccio per non collassare con la spalla verso l\'orecchio. Controlla che bacino e spalle restino perpendicolari al suolo senza ruotare avanti o indietro.',
    aliases: ['Side plank'],
    gifFilename: 'side-bridge',
  ),
  ExerciseInfo(
    name: 'Mountain Climber',
    nameEn: 'Mountain Climber',
    category: 'core',
    muscleImages: [],
    primaryMuscle: 'Core (retto e obliqui)',
    secondaryMuscles: 'Flessori dell\'anca, Spalle, Glutei',
    execution:
        'Assumi la posizione di plank alto a braccia distese con le mani saldamente sotto le spalle, addome serrato e corpo allineato dalla testa ai talloni. Richiama rapidamente un ginocchio verso il petto mantenendo il piede sollevato da terra e poi scambialo subito con l\'altro in una corsa orizzontale continua e ritmata. Appoggia leggero sugli avampiedi tenendo le spalle ferme sopra i polsi e il bacino basso per tutta l\'esecuzione.',
    tips:
        'Evita di far rimbalzare i glutei verso l\'alto mentre acceleri il passo: il bacino deve restare basso e stabile. Scegli una velocità che ti permetta di mantenere il core sempre contratto.',
    aliases: ['Mountain climbers', 'Scalatore'],
    gifFilename: 'mountain-climber',
  ),
];

// ── RICERCA ESERCIZI ─────────────────────────────────────────────────────────
// Unica ricerca per costruzione scheda, archivio e scelta GIF (gym_app e coach).
// I nomi del catalogo GIF sono solo inglesi: le parole italiane passano da
// kExerciseSynonyms. Ogni parola della query deve trovare riscontro; se una non
// lo trova da nessuna parte restano le voci col massimo di parole trovate, così
// un refuso non svuota la lista.

/// Parola italiana (o grafia alternativa) → frammenti dei nomi inglesi.
/// Si confronta per radice (vedi [_stem]): basta una forma, singolare o plurale.
const Map<String, List<String>> kExerciseSynonyms = {
  // attrezzi
  'panca': ['bench'],
  'manubrio': ['dumbbell'],
  'bilanciere': ['barbell'],
  'cavo': ['cable'],
  'cavi': ['cable'],
  'pulley': ['cable', 'row'],
  'corda': ['rope'],
  'macchina': ['machine', 'lever'],
  'multipower': ['smith'],
  'elastico': ['band'],
  'palla': ['ball'],
  'fitball': ['stability ball'],
  'disco': ['plate'],
  'sbarra': ['bar'],
  'parallele': ['dip'],
  'corpo': ['bodyweight'],
  // varianti
  'inclinata': ['incline'],
  'declinata': ['decline'],
  'seduto': ['seated'],
  'piedi': ['standing'],
  'sdraiato': ['lying'],
  'prono': ['prone', 'lying'],
  'inginocchiato': ['kneeling'],
  'singolo': ['single', 'one'],
  'unilaterale': ['single', 'one'],
  'alternato': ['alternate', 'alternating'],
  'inverso': ['reverse'],
  'stretta': ['close'],
  'larga': ['wide'],
  'neutra': ['neutral', 'hammer'],
  'martello': ['hammer'],
  'frontale': ['front'],
  'laterale': ['lateral', 'side'],
  'posteriore': ['rear', 'reverse'],
  'nuca': ['behind'],
  'testa': ['overhead'],
  'rumeno': ['romanian'],
  'bulgaro': ['bulgarian'],
  'tese': ['stiff'],
  'scott': ['preacher'],
  // movimenti
  'distensione': ['press'],
  'spinta': ['press', 'push'],
  'lento': ['press'],
  'military': ['shoulder press'],
  'pressa': ['leg press'],
  'croci': ['fly', 'crossover'],
  'aperture': ['fly'],
  'butterfly': ['pec deck', 'fly'],
  'pectoral': ['pec', 'chest'],
  'rematore': ['row'],
  'tirata': ['pulldown', 'row', 'pull'],
  'trazione': ['pull up', 'chin up'],
  'stacco': ['deadlift'],
  'affondo': ['lunge'],
  'piegamento': ['push up'],
  'flessione': ['push up'],
  'alzata': ['raise'],
  'sollevamento': ['raise', 'lift'],
  'estensione': ['extension'],
  'iperestensione': ['hyperextension'],
  'french': ['skull', 'skullcrusher', 'lying triceps'],
  'slanci': ['kickback', 'kick'],
  'scrollata': ['shrug'],
  'ponte': ['bridge'],
  'rotazione': ['rotation', 'twist'],
  'torsione': ['twist', 'rotation'],
  'salto': ['jump'],
  'corsa': ['run'],
  'camminata': ['walk'],
  'allungamento': ['stretch'],
  'rullo': ['roller'],
  'addominali': ['crunch', 'sit up', 'ab', 'core'],
  'pullup': ['pull up'],
  'pushup': ['push up'],
  'chinup': ['chin up'],
  'situp': ['sit up'],
  'skullcrusher': ['skull crusher'],
  // muscoli e parti del corpo
  'petto': ['chest', 'pec'],
  'pettorali': ['chest', 'pec'],
  'dorso': ['back', 'lat'],
  'dorsali': ['lat', 'back'],
  'schiena': ['back'],
  'spalla': ['shoulder'],
  'deltoide': ['delt', 'shoulder'],
  'trapezio': ['shrug'],
  'bicipite': ['biceps', 'bicep', 'curl'],
  'tricipite': ['triceps', 'tricep'],
  'avambraccio': ['forearm', 'wrist'],
  'polso': ['wrist'],
  'gomito': ['elbow'],
  'collo': ['neck'],
  'gamba': ['leg'],
  'quadricipite': ['quad', 'leg extension'],
  'femorale': ['hamstring', 'leg curl'],
  'gluteo': ['glute', 'hip'],
  'anca': ['hip'],
  'anche': ['hip'],
  'polpaccio': ['calf'],
  'adduttore': ['adductor', 'adduction'],
  'abduttore': ['abductor', 'abduction'],
  'lombare': ['back extension', 'hyperextension'],
  'obliqui': ['oblique', 'side', 'twist'],
  'ginocchio': ['knee'],
};

const Set<String> _kSearchStopwords = {
  'con', 'col', 'al', 'alla', 'alle', 'ai', 'agli', 'allo', 'a', 'da', 'di',
  'del', 'della', 'dei', 'delle', 'in', 'e', 'ed', 'per', 'su', 'sul', 'sulla',
  'sui', 'il', 'lo', 'la', 'i', 'gli', 'le', 'un', 'una', 'piana', 'piano',
  'presa', 'libero', 'libera', 'the', 'with', 'on', 'to', 'and', 'of',
};

/// Minuscolo, senza accenti né punteggiatura, parole separate da uno spazio.
String _fold(String s) {
  const from = 'àáâäèéêëìíîïòóôöùúûü';
  const to = 'aaaaeeeeiiiioooouuuu';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = from.indexOf(c);
    b.write(i < 0 ? c : to[i]);
  }
  return normalizeExerciseLookup(b.toString());
}

/// Radice grezza: toglie la vocale finale (panca/panche, manubrio/manubri).
/// ponytail: niente stemmer vero, i casi -co/-chi stanno nella tolleranza di
/// una lettera in [_matchesKey].
String _stem(String w) =>
    w.length >= 5 && 'aeiou'.contains(w[w.length - 1])
        ? w.substring(0, w.length - 1)
        : w;

/// Radici uguali a meno di una lettera; [prefix] (parola in digitazione)
/// accetta anche l'inizio di una chiave: «manu» → manubrio.
bool _matchesKey(String s, String k, {bool prefix = false}) =>
    (s.startsWith(k) && s.length - k.length <= 1) ||
    (k.startsWith(s) && (prefix ? s.length >= 3 : k.length - s.length <= 1));

List<String> _synonyms(String stem, {bool prefix = false}) => [
  for (final en in kExerciseSynonyms.entries)
    if (_matchesKey(stem, _stem(en.key), prefix: prefix)) ...en.value,
];

/// Riscontro a inizio parola. [prefix] = parola ancora in digitazione;
/// altrimenti parola intera con al più due lettere in più (plurali, -chi, -s),
/// così «lat» non prende «lateral» e «ab» non prende «abductor».
RegExp _wordRe(String f, {bool prefix = false}) =>
    RegExp(' ${RegExp.escape(f)}${prefix ? '' : '[a-z0-9]{0,2} '}');

class _SearchIdx {
  _SearchIdx(ExerciseInfo e)
    : names = {_fold(e.name), ...e.aliases.map(_fold)},
      main = ' ${_fold([e.name, ...e.aliases].join(' '))} ',
      en = ' ${_fold('${e.nameEn} ${e.gifSlug}')} ',
      body = ' ${_fold('${e.category} ${e.primaryMuscle}')} ',
      words = _fold(e.name).split(' ').length,
      order = kExerciseCatalog.indexOf(e);

  final Set<String> names;
  final String main, en, body; // nome+alias · nome EN+slug · categoria+muscolo
  final int words;
  final int order; // posizione nel catalogo italiano, -1 = voce GIF

  /// 0 = nel nome/alias, 1 = nome inglese o sinonimo, 2 = categoria/muscolo,
  /// -1 = nessun riscontro.
  int tier(RegExp own, List<RegExp> syn) {
    bool any(String hay) => syn.any((r) => r.hasMatch(hay));
    if (own.hasMatch(main)) return 0;
    if (own.hasMatch(en) || any(main) || any(en)) return 1;
    if (own.hasMatch(body) || any(body)) return 2;
    return -1;
  }
}

final Map<ExerciseInfo, _SearchIdx> _searchIdx = {};

/// Catalogo per archivio e ricerca: voci italiane + GIF, senza le GIF che una
/// voce italiana già copre (stessa animazione o stesso nome), così lo stesso
/// esercizio non compare due volte con due nomi.
final List<ExerciseInfo> kAllExercises = () {
  final taken = {
    for (final e in kExerciseCatalog) ...[_fold(e.gifSlug), _fold(e.name)],
  };
  return [
    ...kExerciseCatalog,
    ...kGifCatalog.where(
      (e) => !taken.contains(_fold(e.gifSlug)) && !taken.contains(_fold(e.name)),
    ),
  ];
}();

/// Cerca in [pool] (default [kAllExercises]), risultati per pertinenza:
/// nome esatto, nome che inizia con la query, voci italiane, riscontro più
/// diretto, nome più corto.
List<ExerciseInfo> searchExercises(
  String query, {
  Iterable<ExerciseInfo>? pool,
  int? limit,
}) {
  final q = _fold(query);
  if (q.length < 2) return const [];
  var toks = q.split(' ').where((t) => !_kSearchStopwords.contains(t)).toList();
  if (toks.isEmpty) toks = q.split(' ');
  final stems = [for (final t in toks) _stem(t)];
  final typing = !query.endsWith(' ');
  bool open(int i) => typing && i == stems.length - 1;
  final own = [
    for (var i = 0; i < stems.length; i++) _wordRe(stems[i], prefix: open(i)),
  ];
  final syns = [
    for (var i = 0; i < stems.length; i++)
      [for (final f in _synonyms(stems[i], prefix: open(i))) _wordRe(f)],
  ];

  var best = 1;
  final hits = <({ExerciseInfo e, List<int> key})>[];
  for (final e in pool ?? kAllExercises) {
    final x = _searchIdx[e] ??= _SearchIdx(e);
    var found = 0, cost = 0;
    for (var i = 0; i < stems.length; i++) {
      final t = x.tier(own[i], syns[i]);
      if (t >= 0) {
        found++;
        cost += t;
      }
    }
    if (found < best) continue;
    if (found > best) {
      best = found;
      hits.clear();
    }
    final exact = x.names.contains(q) ? 0 : (x.main.startsWith(' $q') ? 1 : 2);
    final local = x.order >= 0;
    hits.add((e: e, key: [exact, local ? 0 : 1, cost, x.words, x.order]));
  }
  hits.sort((a, b) {
    for (var i = 0; i < a.key.length; i++) {
      final d = a.key[i] - b.key[i];
      if (d != 0) return d;
    }
    return a.e.name.compareTo(b.e.name);
  });
  final out = [for (final h in hits) h.e];
  return limit != null && out.length > limit ? out.sublist(0, limit) : out;
}
