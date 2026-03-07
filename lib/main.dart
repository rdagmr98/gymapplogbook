import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as scala;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data'; //
import 'package:app_links/app_links.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart'; // Per Clipboard e HapticFeedback
import 'package:path_provider/path_provider.dart'; // Per getTemporaryDirectory
import 'package:share_plus/share_plus.dart'; // Per shareXFiles e XFile

// Istanza globale del plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> cercaEsercizioSuYoutube(String nomeEsercizio) async {
  String query = Uri.encodeComponent("esecuzione $nomeEsercizio");
  final Uri url = Uri.parse(
    "https://www.youtube.com/results?search_query=$query",
  );

  if (kIsWeb) {
    // Se sei su WEB, apre una nuova scheda del browser
    await launchUrl(url, webOnlyWindowName: '_blank');
  } else {
    // Se sei su APP, usa la modalità esterna per non bloccare l'app
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Errore apertura YouTube');
    }
  }
}

class YouTubeSearchView extends StatefulWidget {
  final String esercizio;
  const YouTubeSearchView({super.key, required this.esercizio});

  @override
  State<YouTubeSearchView> createState() => _YouTubeSearchViewState();
}

class _YouTubeSearchViewState extends State<YouTubeSearchView> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    // Creiamo il link di ricerca
    final String query = Uri.encodeComponent("esecuzione ${widget.esercizio}");
    final String url = "https://www.youtube.com/results?search_query=$query";

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Video: ${widget.esercizio}"),
        backgroundColor: Colors.black,
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializzazione fusi orari

  // 1. Definisci i settings per Android
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('ic_notification');

  // 2. Uniscili (Qui c'era l'errore 'settings')
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  // 3. Inizializza (Usa il parametro corretto)
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  // --- MODIFICA QUI: Richiesta permessi esplicita ---
  if (!kIsWeb && Platform.isAndroid) {
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    // Questo farà apparire il popup "Consenti a questa app di inviare notifiche"
    await androidPlugin?.requestNotificationsPermission();
    // Questo è necessario per i timer precisi al secondo
    await androidPlugin?.requestExactAlarmsPermission();
  }
  // --------------------------------------------------

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ClientGymApp());
}

class ClientGymApp extends StatelessWidget {
  const ClientGymApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFF00F2FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F2FF),
          surface: Color(0xFF1C1C1E),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00F2FF),
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        // [cite: 225]
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(
            color: Colors.white,
          ), // Aggiunto per sicurezza
          titleTextStyle: TextStyle(
            color: Colors.white, // Forza il bianco qui
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
      ),
      home: const AuthGuard(),
    );
  }
}

// --- PROTEZIONE ID ---
class AuthGuard extends StatefulWidget {
  const AuthGuard({super.key});
  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _isAuthorized = false;
  String _deviceId = "";
  final TextEditingController _keyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  void _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    bool auth = prefs.getBool('is_authorized') ?? false;

    // Recuperiamo l'ID salvato
    String? savedId = prefs.getString('saved_device_id');

    if (savedId == null) {
      // Se è il primo avvio in assoluto, generiamo un ID casuale di 4 cifre
      int randomId = scala.Random().nextInt(9000) + 1000; // Tra 1000 e 9999
      savedId = randomId.toString();
      // Lo salviamo per i futuri avvii
      await prefs.setString('saved_device_id', savedId);
    }

    setState(() {
      _isAuthorized = auth;
      _deviceId = savedId!;
    });
  }

  void _verifyKey() async {
    int idNum = int.parse(_deviceId);
    int expectedKey = (idNum * 2) + 567;
    if (_keyController.text == expectedKey.toString()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_authorized', true);
      setState(() => _isAuthorized = true);
    } else {
      HapticFeedback.vibrate();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthorized) return const ClientMainPage();
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.lock_person_rounded,
                  size: 50,
                  color: Color(0xFF00F2FF),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                "DEVICE ID: $_deviceId",
                style: const TextStyle(
                  color: Colors.white24,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              TextField(
                controller: _keyController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 12,
                  color: Color(0xFF00F2FF),
                ),
                decoration: const InputDecoration(
                  hintText: "••••",
                  hintStyle: TextStyle(color: Colors.white10),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton(
                  onPressed: _verifyKey,
                  child: const Text("UNFOLD"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- MODELLI DATI (SINCRONIZZATI AL 100% CON APP PT) ---
class ExerciseConfig {
  String name;
  int targetSets;
  List<int> repsList;
  int recoveryTime;
  int interExercisePause;
  String notePT;
  String noteCliente;
  // AGGIUNGI QUESTA RIGA:
  List<Map<String, dynamic>> results = [];

  ExerciseConfig({
    required this.name,
    required this.targetSets,
    required this.repsList,
    required this.recoveryTime,
    this.interExercisePause = 120,
    this.notePT = "",
    this.noteCliente = "",
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'targetSets': targetSets,
    'repsList': repsList,
    'recoveryTime': recoveryTime,
    'interExercisePause': interExercisePause,
    'notePT': notePT,
    'noteCliente': noteCliente,
    'results': results,
  };

  factory ExerciseConfig.fromJson(Map<String, dynamic> json) {
    // 1. Creiamo l'istanza dell'esercizio
    var ex = ExerciseConfig(
      name: json['name'] ?? "Esercizio",
      targetSets:
          (json['targetSets'] as num? ?? json['sets'] as num?)?.toInt() ?? 0,
      repsList:
          (json['repsList'] as List? ?? json['reps'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      recoveryTime:
          (json['recoveryTime'] as num? ?? json['rest'] as num?)?.toInt() ?? 60,
      interExercisePause:
          (json['interExercisePause'] as num? ?? json['pause'] as num?)
              ?.toInt() ??
          120,
      notePT: json['notePT'] ?? "",
      noteCliente: json['noteCliente'] ?? "",
    );

    // 2. CARICHIAMO I RISULTATI SALVATI (le serie già fatte)
    if (json['results'] != null) {
      ex.results = List<Map<String, dynamic>>.from(json['results']);
    }

    return ex;
  }
}

class WorkoutDay {
  String dayName;
  List<ExerciseConfig> exercises;

  WorkoutDay({required this.dayName, required this.exercises});

  Map<String, dynamic> toJson() => {
    'dayName': dayName,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory WorkoutDay.fromJson(Map<String, dynamic> json) {
    return WorkoutDay(
      dayName: json['dayName'] ?? "Giorno",
      exercises:
          (json['exercises'] as List?)
              ?.map((e) => ExerciseConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// --- DASHBOARD ---
class ClientMainPage extends StatefulWidget {
  const ClientMainPage({super.key});
  @override
  State<ClientMainPage> createState() => _ClientMainPageState();
}

class _ClientMainPageState extends State<ClientMainPage> {
  List<WorkoutDay> myRoutine = [];
  List<dynamic> history = [];
  int _currentIndex = 0;

  // --- NUOVE VARIABILI PER I FILE ---
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initDeepLinks(); // Inizializza l'ascolto dei file .gym
  }

  @override
  void dispose() {
    _linkSubscription?.cancel(); // Pulisce il listener quando chiudi l'app
    super.dispose();
  }

  // --- LOGICA RICEZIONE FILE .GYM ---
  void _initDeepLinks() async {
    _appLinks = AppLinks();

    // 1. Usa getInitialLink() invece di getInitialAppLink()
    try {
      final appLink = await _appLinks.getInitialLink();
      if (appLink != null) _handleIncomingFile(appLink);
    } catch (e) {
      debugPrint("Errore link iniziale: $e");
    }

    // 2. Il listener dello stream rimane lo stesso
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingFile(uri);
    });
  }

  void _handleIncomingFile(Uri uri) async {
    try {
      String contenutoGrezzo;

      // 1. Lettura fisica del file
      if (uri.scheme == 'content') {
        final File file = File.fromUri(uri);
        contenutoGrezzo = await file.readAsString();
      } else {
        contenutoGrezzo = await File(uri.toFilePath()).readAsString();
      }

      // 2. PULIZIA: Rimuoviamo la riga "TIPO:SCHEDA_GYM"
      // Dividiamo il testo in righe e prendiamo solo quelle che iniziano con '['
      String jsonPulito = contenutoGrezzo.substring(
        contenutoGrezzo.indexOf('['),
      );

      // 3. VALIDAZIONE E SALVATAGGIO
      final List<dynamic> datiRicevuti = jsonDecode(jsonPulito);

      if (datiRicevuti.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();

        // Salviamo il JSON pulito (senza la scritta iniziale)
        await prefs.setString('client_routine', jsonPulito);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Scheda di Simone importata!")),
          );
          _loadData(); // Ricarica la lista esercizi
        }
      }
    } catch (e) {
      debugPrint("Errore importazione: $e");
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Recuperiamo le stringhe, se sono null usiamo una stringa che rappresenta una lista vuota "[]"
    final String routineString = prefs.getString('client_routine') ?? "[]";
    final String historyString = prefs.getString('client_history') ?? "[]";

    setState(() {
      try {
        // Se la stringa è proprio vuota "", jsonDecode si rompe.
        // Quindi controlliamo che non sia vuota prima di procedere.
        if (routineString.trim().isNotEmpty && routineString != "null") {
          myRoutine = (jsonDecode(routineString) as List)
              .map((i) => WorkoutDay.fromJson(i))
              .toList();
        } else {
          myRoutine = [];
        }

        if (historyString.trim().isNotEmpty && historyString != "null") {
          history = jsonDecode(historyString);
        } else {
          history = [];
        }
      } catch (e) {
        // Se c'è un errore nel formato, resettiamo a liste vuote invece di crashare
        debugPrint("Errore nel caricamento dati: $e");
        myRoutine = [];
        history = [];
      }
    });
  }

  void _exportData() async {
    final prefs = await SharedPreferences.getInstance();
    String historyJson = prefs.getString('client_history') ?? '[]';

    // 1. BACKUP APPUNTI (Per Web/Manuale)
    await Clipboard.setData(ClipboardData(text: historyJson));

    try {
      // 2. CREAZIONE FILE .TXT PER IL COACH
      String contenutoFile = "TIPO:PROGRESSI_GYM\n$historyJson";

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/miei_progressi.txt');
      await file.writeAsString(contenutoFile);

      // 3. CONDIVISIONE VIA SHARE_PLUS
      await Share.shareXFiles([
        XFile(file.path, name: 'progressi.txt', mimeType: 'text/plain'),
      ], text: 'Coach, ecco i dati per i miei grafici!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("File generato e JSON copiato negli appunti!"),
          ),
        );
      }
    } catch (e) {
      debugPrint("Errore esportazione: $e");
    }
  }

  void _importNewRoutine() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    String initialText = "";
    if (data != null && data.text != null && data.text!.contains('dayName')) {
      initialText = data.text!;
    }

    TextEditingController importC = TextEditingController(text: initialText);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "IMPORTA SCHEDA",
          style: TextStyle(color: Color(0xFF00F2FF), fontSize: 18),
        ),
        content: TextField(
          controller: importC,
          maxLines: 5,
          style: const TextStyle(fontSize: 12, color: Colors.white),
          decoration: InputDecoration(
            hintText: "Incolla qui il codice...",
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              "Annulla",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              String input = importC.text.trim();
              if (input.isEmpty) return;

              try {
                // Rimuoviamo l'intestazione se presente anche qui
                if (input.startsWith("TIPO:SCHEDA_GYM")) {
                  input = input.substring(input.indexOf('\n') + 1);
                }

                final decoded = jsonDecode(input);
                if (decoded is! List) throw Exception("Formato non valido");

                final prefs = await SharedPreferences.getInstance();

                // 2. SALVIAMO LA NUOVA ROUTINE
                await prefs.setString('client_routine', importC.text.trim());

                // 3. LOGICA CONSERVAZIONE DATI:
                // NON chiamiamo prefs.remove('client_history').
                // La storia rimane intatta. Quando l'atleta aprirà il nuovo esercizio,
                // se il nome coincide con uno vecchio, vedrà i suoi precedenti record.

                if (c.mounted) {
                  Navigator.pop(c);
                  _loadData(); // Ricarica la UI con la nuova routine e la vecchia storia
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Scheda aggiornata! I tuoi progressi sono stati mantenuti.",
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Errore: Il codice non è valido"),
                  ),
                );
              }
            },
            child: const Text(
              "CARICA",
              style: TextStyle(
                color: Color(0xFF00F2FF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Forziamo il colore bianco e lo stile per il Web
        title: const Text(
          "GYM LOGBOOK",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        // Forza il colore bianco per le icone (ios_share e add_circle)
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share, size: 22),
            onPressed: _exportData,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 22),
            onPressed: _importNewRoutine,
          ),
        ],
      ),
      body: _currentIndex == 0 ? _buildRoutinePage() : _buildTrainPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: Colors.black,
        selectedItemColor: const Color(0xFF00F2FF),
        unselectedItemColor: Colors.white24,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_rounded),
            label: "Programma",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_rounded),
            label: "Allenati",
          ),
        ],
      ),
    );
  }

  Widget _buildRoutinePage() => ListView(
    padding: const EdgeInsets.all(16),
    children: myRoutine
        .map(
          (day) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              title: Text(
                day.dayName,
                style: const TextStyle(
                  color: Color(0xFF00F2FF),
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              subtitle: Text(
                "${day.exercises.length} esercizi",
                style: const TextStyle(color: Colors.white38),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.white12,
              ),
              onTap: () => _showDayDetail(day),
            ),
          ),
        )
        .toList(),
  );

  void _showDayDetail(WorkoutDay day) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: day.exercises.map((ex) {
                  return ListTile(
                    // 1. A sinistra l'icona di YouTube per il video
                    leading: IconButton(
                      icon: const Icon(
                        Icons.play_circle_fill,
                        color: Colors.red,
                        size: 28,
                      ),
                      onPressed: () {
                        if (kIsWeb) {
                          // Su Web apriamo YouTube in una nuova scheda (più sicuro e veloce)
                          cercaEsercizioSuYoutube(ex.name);
                        } else {
                          // Su Android/iOS usiamo la pagina interna che abbiamo creato
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  YouTubeSearchView(esercizio: ex.name),
                            ),
                          );
                        }
                      },
                    ),
                    // 2. Al centro il nome dell'esercizio
                    title: Text(
                      ex.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    // 3. A destra l'icona dei grafici per le statistiche
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.insights_rounded,
                        color: Color(0xFF00F2FF),
                        size: 24,
                      ),
                      onPressed: () {
                        Navigator.pop(c); // Chiude il popup del giorno
                        _showGraph(ex.name); // Apre il grafico
                      },
                    ),
                    // Opzionale: se clicca sul testo, possiamo decidere cosa fargli fare
                    onTap: () {
                      // Magari qui apriamo il grafico di default
                      Navigator.pop(c);
                      _showGraph(ex.name);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGraph(String name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (c) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        child: PTGraphWidget(exerciseName: name, history: history),
      ),
    );
  }

  Widget _buildTrainPage() => ListView(
    padding: const EdgeInsets.all(16),
    children: myRoutine
        .map(
          (d) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1C1C1E), Colors.black.withAlpha(128)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withAlpha(13)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(20),
              title: Text(
                d.dayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              trailing: const CircleAvatar(
                backgroundColor: Color(0xFF00F2FF),
                child: Icon(Icons.play_arrow_rounded, color: Colors.black),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => WorkoutEngine(
                    day: d,
                    history: history,
                    onDone: (session) async {
                      history.add(session);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(
                        'client_history',
                        jsonEncode(history),
                      );
                      _loadData();
                    },
                  ),
                ),
              ),
            ),
          ),
        )
        .toList(),
  );
}

// --- MOTORE ALLENAMENTO ---
class WorkoutEngine extends StatefulWidget {
  final WorkoutDay day;
  final List<dynamic> history;
  final Function(Map<String, dynamic>) onDone;
  const WorkoutEngine({
    super.key,
    required this.day,
    required this.history,
    required this.onDone,
  });
  @override
  State<WorkoutEngine> createState() => _WorkoutEngineState();
}

class _WorkoutEngineState extends State<WorkoutEngine>
    with WidgetsBindingObserver {
  int exI = 0;
  int setN = 1;
  String _infoProssimo = ""; // Serve per far vedere cosa fare dopo nel timer
  List<Map<String, dynamic>> currentExSeries = [];
  final TextEditingController wC = TextEditingController();
  final TextEditingController rC = TextEditingController();
  int _bgCounter = 0;
  int _maxTime = 1;
  DateTime? _endTime; // <--- AGGIUNGI QUESTA
  Timer? _bgTimer;
  bool isRestingFullScreen = false;
  bool timerActive = false;

  @override
  void initState() {
    super.initState();
    // AZZERA TUTTO APPENA ENTRI
    exI = 0; // Riparte dal primo esercizio della lista
    currentExSeries = []; // Svuota le serie fatte precedentemente
    setN = 1; // Forza il set a 1
    Timer? _recoveryTimer; // Questo ci permette di controllare il tempo
    // Opzionale: se vuoi azzerare anche le serie salvate nell'oggetto per sicurezza
    for (var ex in widget.day.exercises) {
      ex.results = [];
    }
  }

  Future<void> _saveAndExit() async {
    final prefs = await SharedPreferences.getInstance();

    // Sincronizza l'esercizio corrente prima di chiudere
    widget.day.exercises[exI].results = List.from(currentExSeries);

    // Recupera la routine dal disco (quella che leggono i grafici)
    String? routineString = prefs.getString('client_routine');
    if (routineString != null) {
      List<dynamic> fullRoutine = jsonDecode(routineString);

      // Trova il giorno attuale e aggiornalo con i nuovi risultati (serie e note)
      for (int i = 0; i < fullRoutine.length; i++) {
        if (fullRoutine[i]['dayName'] == widget.day.dayName) {
          fullRoutine[i] = widget.day.toJson();
          break;
        }
      }

      // Sovrascrivi il file sul disco: ora i grafici vedranno le modifiche!
      await prefs.setString('client_routine', jsonEncode(fullRoutine));
    }

    if (mounted) Navigator.pop(context);
  }

  // QUESTA FUNZIONE DEVE STARE QUI (FUORI DA INITSTATE)
  Future<void> _checkResumeWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedDay = prefs.getString('last_workout_id');

    // widget.day.dayName è il nome dell'allenamento che stai aprendo
    if (savedDay == widget.day.dayName) {
      setState(() {
        // Recuperiamo l'indice dell'esercizio e della serie
        exI = prefs.getInt('last_ex_idx') ?? 0;
        setN = prefs.getInt('last_set_n') ?? 1;
      });
    }
  }

  Future<bool> _mostraDialogConfermaUscita() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            title: const Text(
              "Interrompere?",
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              "Vuoi davvero uscire dall'allenamento? I progressi fin qui fatti sono comunque salvati.",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  "ANNULLA",
                  style: TextStyle(color: Colors.white38),
                ),
              ),
              // Nel metodo _mostraDialogConfermaUscita
              TextButton(
                onPressed: () async {
                  // 1. Chiudi il Dialog immediatamente
                  Navigator.of(context).pop();

                  // 2. Esegui il salvataggio e la chiusura della pagina
                  await _saveAndExit();
                },
                child: const Text(
                  "ESCI E SALVA",
                  style: TextStyle(color: Color(0xFF00F2FF)),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  // --- NUOVA FUNZIONE NOTIFICA ---
  Future<void> _programmaNotificaFine(int secondi) async {
    try {
      // Aspetta i secondi del timer
      await Future.delayed(Duration(seconds: secondi));

      const androidDetails = AndroidNotificationDetails(
        'timer_gym',
        'Timer Recupero',
        importance: Importance.max,
        priority: Priority.high,
        icon: 'ic_notification', //
      );

      await flutterLocalNotificationsPlugin.show(
        0,
        'Recupero Terminato!',
        'Torna ad allenarti!',
        const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint("Errore notifica: $e");
    }
  }

  @override
  void dispose() {
    // Rimuoviamo l'osservatore quando chiudiamo l'allenamento
    WidgetsBinding.instance.removeObserver(this);
    if (_bgTimer != null) _bgTimer!.cancel();
    wC.dispose();
    rC.dispose();
    super.dispose();
  }

  // Questo metodo rileva quando l'utente esce dall'app (va su YouTube)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Quando rientriamo nell'app, cancelliamo le notifiche e
    // il timer si aggiornerà da solo al prossimo scatto del Timer.periodic
    if (state == AppLifecycleState.resumed) {
      flutterLocalNotificationsPlugin.cancelAll();
    }
  }

  void _triggerTimer(int sec, {bool force = false}) {
    WakelockPlus.enable();
    _bgTimer?.cancel(); // Annulla eventuali timer precedenti
    if (timerActive && !force) return;
    if (force) _bgTimer?.cancel();

    // 1. Calcoliamo l'orario esatto di fine
    _endTime = DateTime.now().add(Duration(seconds: sec));

    setState(() {
      _bgCounter = sec;
      _maxTime = sec;
      timerActive = true;
    });

    // 2. Programmiamo subito la notifica di sistema
    _programmaNotificaFine(sec);
    if (!kIsWeb) {
      _programmaNotificaFine(sec);
    }
    // 3. Timer visivo basato sulla differenza di orario
    _bgTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_endTime == null) {
        t.cancel();
        return;
      }

      final remaining = _endTime!.difference(DateTime.now()).inSeconds;

      if (remaining <= 0) {
        _eseguiFeedbackFineTimer(); // Funzione per vibrazione (sotto)
        t.cancel();
        if (mounted) {
          setState(() {
            timerActive = false;
            isRestingFullScreen = false;
            _bgCounter = 0;
            _endTime = null;
          });
        }
        WakelockPlus.disable();
      } else {
        if (mounted) {
          setState(() {
            _bgCounter = remaining;
          });
        }
      }
    });
  }

  void _eseguiFeedbackFineTimer() async {
    if (kIsWeb) {
      // Feedback per il Web (Visto che non può vibrare bene)
      debugPrint("TIMER FINITO!");
      // Opzionale: puoi aggiungere un suono qui se hai una libreria audio
    } else {
      // Feedback per Android
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500]);
      }
      HapticFeedback.heavyImpact();
      Future.delayed(
        const Duration(milliseconds: 300),
        () => HapticFeedback.heavyImpact(),
      );
    }
  }

  Future<void> _aggiornaJsonSuDisco() async {
    final prefs = await SharedPreferences.getInstance();
    String? routineString = prefs.getString('client_routine');

    if (routineString != null) {
      List<dynamic> fullRoutine = jsonDecode(routineString);

      // Cerchiamo il giorno corrente (es. "Push") nella lista globale
      for (int i = 0; i < fullRoutine.length; i++) {
        if (fullRoutine[i]['dayName'] == widget.day.dayName) {
          // Sovrascriviamo il giorno vecchio con quello aggiornato (che ha i nuovi results)
          fullRoutine[i] = widget.day.toJson();
          break;
        }
      }

      // Scriviamo il JSON aggiornato sul telefono
      await prefs.setString('client_routine', jsonEncode(fullRoutine));
      debugPrint("Grafici aggiornati sul disco!");
    }
  }

  void _saveSet() async {
    double w = double.tryParse(wC.text) ?? 0.0;
    int r = int.tryParse(rC.text) ?? 0;
    if (r <= 0) return;

    currentExSeries.add({'s': setN, 'w': w, 'r': r});

    // Prendiamo l'esercizio corrente prima di cambiare indice
    var currentEx = widget.day.exercises[exI];

    if (setN < currentEx.targetSets) {
      // Caso: mancano serie nello stesso esercizio
      setState(() {
        isRestingFullScreen = true;
        _triggerTimer(currentEx.recoveryTime); // Pausa breve
        setN++;
        wC.clear();
        rC.clear();
      });
    } else {
      // Caso: esercizio finito
      widget.onDone({
        'exercise': currentEx.name,
        'series': List.from(currentExSeries),
        'date': DateTime.now().toIso8601String(),
      });

      if (exI < widget.day.exercises.length - 1) {
        // C'è un altro esercizio dopo? Pausa Lunga
        setState(() {
          isRestingFullScreen = true;
          exI++;
          setN = 1;
          currentExSeries = [];
          wC.clear();
          rC.clear();
        });
      } else {
        // Allenamento finito
        if (_bgTimer != null) _bgTimer!.cancel();
        final prefs = await SharedPreferences.getInstance();
        // Recuperiamo la routine attuale per aggiornare il giorno specifico
        final String? routineString = prefs.getString('client_routine');
        if (routineString != null) {
          List<dynamic> fullRoutine = jsonDecode(routineString);
          // Troviamo l'indice del giorno che stiamo allenando e lo aggiorniamo
          // Nota: questa logica assume che i nomi dei giorni siano univoci
          for (int i = 0; i < fullRoutine.length; i++) {
            if (fullRoutine[i]['dayName'] == widget.day.dayName) {
              fullRoutine[i] = widget.day.toJson();
            }
          }
          await prefs.setString('client_routine', jsonEncode(fullRoutine));
        }
        Navigator.pop(context);
      }
    }
  }

  void _skipRest() {
    _bgTimer?.cancel(); // Annulla eventuali timer precedenti
    if (_bgTimer != null) _bgTimer!.cancel();
    setState(() {
      timerActive = false;
      isRestingFullScreen = false;
      _bgCounter = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. DEFINIAMO L'ESERCIZIO ATTUALE
    var ex = widget.day.exercises[exI];

    // 2. CALCOLIAMO COSA FARE DOPO (Logica originale)
    if (setN <= ex.targetSets) {
      _infoProssimo =
          "PROSSIMA: Serie $setN di ${ex.targetSets}\n${ex.name.toUpperCase()}";
    } else if (exI < widget.day.exercises.length - 1) {
      var prossimoEs = widget.day.exercises[exI + 1];
      _infoProssimo = "CAMBIO ESERCIZIO:\n${prossimoEs.name.toUpperCase()}";
    } else {
      _infoProssimo = "ALLENAMENTO COMPLETATO!";
    }

    // 3. SE IL TIMER È ATTIVO, MOSTRA LA SCHERMATA NERA (Tua logica originale)
    if (isRestingFullScreen) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Usa il tasto 'SKIP' per tornare all'esercizio"),
            ),
          );
        },
        child: _buildRestUI(),
      );
    }

    // --- DA QUI IN POI CONTINUA IL TUO CODICE ORIGINALE ---
    // var suggest = _getSuggest(ex.name, setN);
    // ... rest of your code ...

    // Suggerimento basato sullo storico (se esiste)
    var suggest = _getSuggest(ex.name, setN);
    double lastW = (suggest['w'] as num?)?.toDouble() ?? 0.0;
    int lastR = (suggest['r'] as num?)?.toInt() ?? 0;

    // CALCOLO SICURO REPS (Correzione Errore Bad State)
    int targetR = ex.repsList.isNotEmpty
        ? (setN <= ex.repsList.length
              ? ex.repsList[setN - 1]
              : ex.repsList.last)
        : 10;
    // Il suggerimento si attiva SOLO se le reps dell'ultima volta sono MAGGIORI del target
    bool suggerisciAumento = lastR > targetR && lastR > 0;
    if (ex.repsList.isNotEmpty) {
      if (setN <= ex.repsList.length) {
        targetR = ex.repsList[setN - 1];
      } else {
        targetR = ex.repsList.last;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // FRECCIA SINISTRA
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: exI > 0
                  ? () => setState(() {
                      widget.day.exercises[exI].results = List.from(
                        currentExSeries,
                      );
                      exI--;
                      currentExSeries = List.from(
                        widget.day.exercises[exI].results,
                      );
                      setN = currentExSeries.length + 1; // <--- RISOLVE 5/3
                      wC.clear();
                      rC.clear();
                    })
                  : null,
            ),

            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ex.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  // --- AGGIUNGIAMO IL PROGRESSO QUI SOTTO ---
                  const SizedBox(
                    height: 4,
                  ), // Un po' di spazio tra nome e progresso
                  Text(
                    "SERIE FATTE: ${currentExSeries.length} DI ${ex.targetSets}",
                    style: TextStyle(
                      color: currentExSeries.length >= ex.targetSets
                          ? const Color(0xFF00FF88) // Verde se hai finito
                          : const Color(
                              0xFF00F2FF,
                            ).withAlpha(180), // Azzurrino mentre procedi
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed: exI < widget.day.exercises.length - 1
                  ? () => setState(() {
                      widget.day.exercises[exI].results = List.from(
                        currentExSeries,
                      );
                      exI++;
                      currentExSeries = List.from(
                        widget.day.exercises[exI].results,
                      );
                      setN = currentExSeries.length + 1; // <--- RISOLVE 5/3
                      wC.clear();
                      rC.clear();
                    })
                  : null,
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () async {
            bool conferma = await _mostraDialogConfermaUscita();
            if (conferma) {
              if (mounted) Navigator.pop(context);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              "SET $setN / ${ex.targetSets}",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white38,
                letterSpacing: 2,
              ),
            ),
            // --- INIZIO CODICE NOTE ---
            const SizedBox(height: 20),
            if (ex.notePT.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(
                    25,
                  ), // Nota: usa .withAlpha o .withValues
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                    left: BorderSide(color: Colors.amber, width: 4),
                  ),
                ),
                child: Text(
                  "NOTE COACH: ${ex.notePT}",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ),

            TextField(
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: "Le mie note / Feedback",
                prefixIcon: Icon(Icons.edit_note, size: 20),
                border: InputBorder.none,
              ),
              // Usiamo un controller per gestire il testo
              controller: TextEditingController(text: ex.noteCliente)
                ..selection = TextSelection.collapsed(
                  offset: ex.noteCliente.length,
                ),
              onChanged: (v) async {
                // Aggiorna l'oggetto in memoria immediatamente
                ex.noteCliente = v;
                final prefs = await SharedPreferences.getInstance();
              },
            ),

            // --- FINE CODICE NOTE ---
            // --- BOX INFO SCORSA VOLTA ---
            const SizedBox(height: 10),
            if (lastW > 0)
              Text(
                "ULTIMA VOLTA: $lastW kg x $lastR REPS ${suggerisciAumento ? '\nAUMENTA IL PESO🔥' : ''}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: suggerisciAumento ? Colors.amber : Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),

            const SizedBox(height: 60),
            _buildInputSection(
              "KG",
              wC,
              [lastW - 5.0, lastW - 2.5, lastW, lastW + 2.5, lastW + 5.0],
              ex,
              referenceWeight: lastW, // Passiamo il peso di riferimento
              highlights:
                  suggerisciAumento, // Accendiamo il suggerimento se ha vinto la sfida scorsa volta
            ),
            const SizedBox(height: 60),
            _buildInputSection("REPS", rC, [
              (targetR - 2).toDouble(),
              (targetR - 1).toDouble(),
              targetR.toDouble(),
              (targetR + 1).toDouble(),
              (targetR + 2).toDouble(),
            ], ex),
            const SizedBox(height: 60),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveSet,
                child: const Text("CONFERMA SERIE"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection(
    String label,
    TextEditingController ctrl,
    List<double> values,
    ExerciseConfig ex, {
    double? referenceWeight,
    bool highlights = false,
  }) {
    bool isLastSet = setN == ex.targetSets;
    int timeToUse = isLastSet ? ex.interExercisePause : ex.recoveryTime;

    // --- LOGICA POSIZIONAMENTO INIZIALE ---
    // Calcoliamo lo spazio occupato da ogni elemento (padding + larghezza testo + margine)
    // Con le misure fisse che abbiamo messo, ogni elemento occupa circa 90-100 pixel.
    // L'offset 80-100 di solito centra il terzo elemento su schermi standard.
    final double initialOffset = values.length > 2 ? 85.0 : 0.0;

    final ScrollController scrollController = ScrollController(
      initialScrollOffset: initialOffset,
    );

    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 20),

        // RIGA DEI SUGGERIMENTI CENTRATA
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: (() {
            List<double> items = [];
            if (label == "KG") {
              double center = (referenceWeight != null && referenceWeight > 0)
                  ? referenceWeight
                  : 20.0;
              // Generiamo i 5 tab classici
              items = [
                center - 5.0,
                center - 2.5,
                center,
                center + 2.5,
                center + 5.0,
              ];
            } else {
              double center = (values.isNotEmpty) ? values[0] : 10.0;
              items = [center - 2, center - 1, center, center + 1, center + 2];
            }

            return items.asMap().entries.map((entry) {
              int idx = entry.key;
              double v = entry.value;
              if (v < 0) v = 0;

              String valStr = v % 1 == 0
                  ? v.toInt().toString()
                  : v.toStringAsFixed(1);
              bool isSelected = ctrl.text == valStr;

              // LOGICA RICHIESTA:
              // Se highlights è attivo e questo specifico peso è maggiore del vecchio -> AMBRA
              bool isSuggestedIncrease =
                  highlights && referenceWeight != null && v > referenceWeight;

              // Colore di base: Ciano se è il tab centrale (pareggio), Ambra se è un aumento suggerito
              bool isCentralTab = (idx == 2);
              Color tabColor = isSuggestedIncrease
                  ? Colors.amber
                  : (isCentralTab ? const Color(0xFF00F2FF) : Colors.white24);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: GestureDetector(
                  onTap: () {
                    setState(() => ctrl.text = valStr);
                    HapticFeedback.lightImpact();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 62,
                    height: 55,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      // Sfondo pieno se selezionato, altrimenti opaco con il colore del tab
                      color: isSelected
                          ? tabColor
                          : (isSuggestedIncrease || isCentralTab
                                ? tabColor.withOpacity(0.12)
                                : const Color(0xFF1C1C1E)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : (isSuggestedIncrease || isCentralTab
                                  ? tabColor
                                  : Colors.white10),
                        width: (isSuggestedIncrease || isCentralTab)
                            ? 2.0
                            : 1.0,
                      ),
                      boxShadow:
                          (isSelected || isSuggestedIncrease || isCentralTab)
                          ? [
                              BoxShadow(
                                color: tabColor.withOpacity(0.2),
                                blurRadius: 8,
                              ),
                            ]
                          : [],
                    ),
                    child: Text(
                      valStr,
                      style: TextStyle(
                        fontSize: (isSuggestedIncrease || isCentralTab)
                            ? 18
                            : 16,
                        color: isSelected
                            ? Colors.black
                            : (isSuggestedIncrease || isCentralTab
                                  ? tabColor
                                  : Colors.white60),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList();
          })(),
        ),
        const SizedBox(height: 20),

        // INPUT GRANDE IN BASSO
        TextField(
          controller: ctrl,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
            fontSize: 60,
            fontWeight: FontWeight.w200,
            color: Color(0xFF00F2FF),
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: "0",
            hintStyle: TextStyle(color: Colors.white10),
          ),
          onChanged: (v) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildRestUI() {
    // 1. RECUPERO DATI ESERCIZIO ATTUALE (usando le variabili del tuo build)
    // exI è l'indice dell'esercizio, setN è la serie che hai appena finito
    var ex = widget.day.exercises[exI];

    // 2. RECUPERO IL SUGGERIMENTO (Cosa hai fatto l'ultima volta in questa serie)
    // Nota: usiamo setN perché nel tuo codice setN viene incrementato DOPO il salvataggio
    // o rappresenta la serie corrente. Se il timer parte dopo il salvataggio,
    // setN potrebbe essere già quello della serie successiva.
    var suggest = _getSuggest(ex.name, setN);
    double lastW = (suggest['w'] as num?)?.toDouble() ?? 0.0;
    int lastR = (suggest['r'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "REST",
              style: TextStyle(
                letterSpacing: 10,
                color: Colors.white38,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 25),

            // --- INFO SESSIONE PRECEDENTE ---
            if (lastW > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Text(
                      "PRECEDENTE (SERIE $setN)",
                      style: TextStyle(
                        color: Colors.white.withAlpha(100),
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${lastW}kg  ×  ${lastR} reps",
                      style: const TextStyle(
                        color: Color(0xFF00F2FF),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 54),

            const SizedBox(height: 30),

            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 260,
                  height: 260,
                  child: CircularProgressIndicator(
                    value: timerActive
                        ? (_bgCounter / _maxTime).clamp(0, 1)
                        : 0,
                    strokeWidth: 4,
                    color: const Color(0xFF00F2FF),
                    backgroundColor: Colors.white.withAlpha(25),
                  ),
                ),
                Text(
                  "$_bgCounter",
                  style: const TextStyle(
                    fontSize: 90,
                    fontWeight: FontWeight.w100,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // --- INFO PROSSIMO ESERCIZIO ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _infoProssimo, // Questa variabile è già calcolata nel build()
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF00F2FF).withAlpha(180),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

            const SizedBox(height: 40),
            GestureDetector(
              onTap: _skipRest,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white10),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  "SKIP",
                  style: TextStyle(
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getSuggest(String ex, int s) {
    try {
      var logs = widget.history.where((h) => h['exercise'] == ex).toList();
      if (logs.isEmpty) return {'w': 0.0, 'r': 0};

      var lastEntry = logs.last;
      if (lastEntry['series'] == null) return {'w': 0.0, 'r': 0};

      var lastS = lastEntry['series'] as List;
      if (s <= lastS.length) {
        var setDetails = lastS[s - 1];
        // Mappatura flessibile: legge sia 'w' che 'weight'
        double weight = (setDetails['w'] ?? setDetails['weight'] ?? 0.0)
            .toDouble();
        int reps = (setDetails['r'] ?? setDetails['reps'] ?? 0).toInt();
        return {'w': weight, 'r': reps};
      } else {
        var lastSetDetails = lastS.last;
        double weight = (lastSetDetails['w'] ?? lastSetDetails['weight'] ?? 0.0)
            .toDouble();
        int reps = (lastSetDetails['r'] ?? lastSetDetails['reps'] ?? 0).toInt();
        return {'w': weight, 'r': reps};
      }
    } catch (e) {
      debugPrint("Errore suggerimenti: $e");
      return {'w': 0.0, 'r': 0};
    }
  }
}

// --- GRAFICI ---
class PTGraphWidget extends StatelessWidget {
  final String exerciseName;
  final List<dynamic> history;

  static const List<Color> seriesColors = [
    Color(0xFF00F2FF),
    Colors.purpleAccent,
    Colors.greenAccent,
    Colors.orangeAccent,
    Colors.redAccent,
  ];

  const PTGraphWidget({
    super.key,
    required this.exerciseName,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    var logs = history
        .where((h) => h['exercise'] == exerciseName)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (logs.isEmpty) return const Center(child: Text("Nessun dato"));

    // 1. Troviamo il numero massimo di serie per questo esercizio
    int maxSetsFound = 0;
    for (var l in logs) {
      var series = l['series'] as List;
      if (series.length > maxSetsFound) maxSetsFound = series.length;
    }

    // 2. Calcoliamo la media storica specifica per OGNI serie (S1, S2, S3...)
    Map<int, double> avgWeightPerSet = {};
    Map<int, double> avgRepsPerSet = {};
    Map<int, int> countPerSet = {};

    for (var l in logs) {
      var series = l['series'] as List;
      for (int i = 0; i < series.length; i++) {
        double w = (series[i]['w'] ?? 0.0).toDouble();
        double r = (series[i]['r'] ?? 0.0).toDouble();

        avgWeightPerSet[i] = (avgWeightPerSet[i] ?? 0) + w;
        avgRepsPerSet[i] = (avgRepsPerSet[i] ?? 0) + r;
        countPerSet[i] = (countPerSet[i] ?? 0) + 1;
      }
    }

    // Trasformiamo le somme in medie reali
    avgWeightPerSet.forEach((index, totalW) {
      if (countPerSet[index]! > 0 && totalW > 0) {
        avgWeightPerSet[index] = totalW / countPerSet[index]!;
      } else {
        avgWeightPerSet[index] = 1.0;
      }
    });

    avgRepsPerSet.forEach((index, totalR) {
      if (countPerSet[index]! > 0 && totalR > 0) {
        avgRepsPerSet[index] = totalR / countPerSet[index]!;
      } else {
        avgRepsPerSet[index] = 1.0;
      }
    });

    // 3. Normalizziamo ogni punto in base alla media della SUA serie
    // Ora il valore 1.0 nel grafico rappresenta: "sto facendo la mia media solita in QUESTA serie"
    for (var l in logs) {
      var series = l['series'] as List;
      for (int i = 0; i < series.length; i++) {
        series[i]['w_norm'] = (series[i]['w'] ?? 0.0) / avgWeightPerSet[i]!;
        series[i]['r_norm'] = (series[i]['r'] ?? 0.0) / avgRepsPerSet[i]!;
      }
    }

    return Column(
      children: [
        const SizedBox(height: 10),
        Text(
          exerciseName.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF00F2FF),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 15,
          runSpacing: 15,
          children: List.generate(
            maxSetsFound,
            (i) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 3,
                  color: seriesColors[i % seriesColors.length],
                ),
                const SizedBox(width: 5),
                Text(
                  "S${i + 1}",
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            "Linea spessa = Peso - Linea sottile = Reps",
            style: TextStyle(fontSize: 9, color: Colors.white24),
          ),
        ),
        const SizedBox(height: 30),
        Expanded(
          child: logs.isEmpty
              ? const Center(child: Text("Nessun dato"))
              : CustomPaint(
                  size: Size.infinite,
                  painter: PTChartPainter(logs: logs, colors: seriesColors),
                ),
        ),
      ],
    );
  }
}

class PTChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> logs;
  final List<Color> colors;
  PTChartPainter({required this.logs, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (logs.isEmpty) return;

    // Con i dati normalizzati, 1.0 è la media.
    // Impostiamo il tetto del grafico a 2.0 (il doppio della media)
    const double maxVal = 2.0;

    int maxSets = 0;
    for (var log in logs) {
      if (log['series'].length > maxSets) maxSets = log['series'].length;
    }

    for (int sIdx = 0; sIdx < maxSets; sIdx++) {
      final color = colors[sIdx % colors.length];

      final weightPaint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final repsPaint = Paint()
        ..color = color
            .withAlpha(80) // Più trasparente per non confondere
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      final weightPath = Path();
      final repsPath = Path();
      bool firstPoint = true;

      for (int i = 0; i < logs.length; i++) {
        var sData = logs[i]['series'] as List;
        if (sIdx < sData.length) {
          double x = (size.width / (logs.length > 1 ? logs.length - 1 : 1)) * i;
          if (logs.length == 1) x = size.width / 2;

          // Usiamo i valori normalizzati calcolati nel widget
          double yW =
              size.height -
              ((sData[sIdx]['w_norm'] as double).clamp(0, maxVal) /
                  maxVal *
                  size.height);
          double yR =
              size.height -
              ((sData[sIdx]['r_norm'] as double).clamp(0, maxVal) /
                  maxVal *
                  size.height);

          if (firstPoint) {
            weightPath.moveTo(x, yW);
            repsPath.moveTo(x, yR);
            firstPoint = false;
          } else {
            weightPath.lineTo(x, yW);
            repsPath.lineTo(x, yR);
          }

          // Pallino solo sul Peso per pulizia visiva
          canvas.drawCircle(Offset(x, yW), 2.5, Paint()..color = color);
        }
      }
      canvas.drawPath(repsPath, repsPaint); // Disegna prima le reps (sotto)
      canvas.drawPath(weightPath, weightPaint); // Poi il peso (sopra)
    }
  }

  @override
  bool shouldRepaint(old) => true;
}
