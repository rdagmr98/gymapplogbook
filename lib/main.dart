import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart' as arc;
import 'package:flutter/material.dart';

import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as scala;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:app_links/app_links.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

// Se è WEB usa dart:html, se è APK usa il nostro stub finto
import 'html_stub.dart' if (dart.library.html) 'dart:html' as html;
// ignore: deprecated_member_use
import 'js_stub.dart' if (dart.library.js) 'dart:js' as js;
import 'gif_exercise_catalog.dart';

// Colore accento globale (tema)
final ValueNotifier<Color> appAccentNotifier = ValueNotifier<Color>(
  const Color(0xFF00F2FF),
);

// Istanza globale del plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Channel per leggere file content:// da WhatsApp/Telegram via ContentResolver
const _gymFileChannel = MethodChannel('gym_file_reader');

Future<String> _readFileUri(Uri uri) async {
  if (uri.scheme == 'content') {
    final bytes = await _gymFileChannel.invokeMethod<List<int>>(
      'readBytes',
      uri.toString(),
    );
    return utf8.decode(bytes!);
  }
  return await File(uri.toFilePath()).readAsString();
}

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
  tz_data.initializeTimeZones();

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
    // Crea canali con importanza corretta (evita cache con settings errati)
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel('timer_gym', 'Timer Recupero', importance: Importance.max),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel('timer_gym_cd', 'Timer in corso', importance: Importance.defaultImportance),
    );
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

class ClientGymApp extends StatefulWidget {
  const ClientGymApp({super.key});
  @override
  State<ClientGymApp> createState() => _ClientGymAppState();
}

class _ClientGymAppState extends State<ClientGymApp> {
  @override
  void initState() {
    super.initState();
    _loadAccentColor();
  }

  Future<void> _loadAccentColor() async {
    final prefs = await SharedPreferences.getInstance();
    final hex = prefs.getInt('accent_color') ?? 0xFF00F2FF;
    appAccentNotifier.value = Color(hex);
  }

  ThemeData _buildTheme(Color accent) {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.black,
      primaryColor: accent,
      colorScheme: ColorScheme.dark(
        primary: accent,
        surface: const Color(0xFF1C1C1E),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: appAccentNotifier,
      builder: (_, accent, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(accent),
        home: const AuthGuard(),
      ),
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
                child: Icon(
                  Icons.lock_person_rounded,
                  size: 50,
                  color: Theme.of(context).colorScheme.primary,
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
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 12,
                  color: Theme.of(context).colorScheme.primary,
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
  // 0 = normale, 1+ = gruppo superserie (stessi numeri = stesso gruppo)
  int supersetGroup;
  List<Map<String, dynamic>> results = [];
  /// GIF slug personalizzato (es. 'barbell-curl') per esercizi non in catalogo.
  /// Se null, viene cercato il GIF tramite il catalogo.
  String? gifFilename;

  ExerciseConfig({
    required this.name,
    required this.targetSets,
    required this.repsList,
    required this.recoveryTime,
    this.interExercisePause = 120,
    this.notePT = "",
    this.noteCliente = "",
    this.supersetGroup = 0,
    this.gifFilename,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'targetSets': targetSets,
    'repsList': repsList,
    'recoveryTime': recoveryTime,
    'interExercisePause': interExercisePause,
    'notePT': notePT,
    'noteCliente': noteCliente,
    'supersetGroup': supersetGroup,
    'results': results,
    if (gifFilename != null) 'gifFilename': gifFilename,
  };

  factory ExerciseConfig.fromJson(Map<String, dynamic> json) {
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
      supersetGroup: (json['supersetGroup'] as num?)?.toInt() ?? 0,
      gifFilename: json['gifFilename'] as String?,
    );
    if (json['results'] != null) {
      ex.results = List<Map<String, dynamic>>.from(json['results']);
    }
    return ex;
  }
}

class WorkoutDay {
  String dayName;
  List<String> bodyParts;
  String? muscleImage;
  List<ExerciseConfig> exercises;

  WorkoutDay({
    required this.dayName,
    List<String>? bodyParts,
    this.muscleImage,
    required this.exercises,
  }) : bodyParts = bodyParts ?? [];

  Map<String, dynamic> toJson() => {
    'dayName': dayName,
    'bodyParts': bodyParts,
    'muscleImage': muscleImage,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory WorkoutDay.fromJson(Map<String, dynamic> json) {
    return WorkoutDay(
      dayName: json['dayName'] ?? 'Giorno',
      bodyParts: json['bodyParts'] != null
          ? List<String>.from(json['bodyParts'])
          : (json['bodyPart'] != null &&
                    json['bodyPart'] != 'altro' &&
                    json['bodyPart'] != 'nessuno'
                ? [json['bodyPart'] as String]
                : []),
      muscleImage: json['muscleImage'] as String?,
      exercises: (json['exercises'] as List? ?? json['esercizi'] as List? ?? [])
          .map((e) => ExerciseConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

const Map<String, String> kBodyPartIcons = {
  'nessuno': '',
  'petto': '🦍',
  'schiena': '🔙',
  'gambe': '🦵',
  'spalle': '🏋️',
  'braccia': '💪',
  'core': '🔥',
  'full_body': '🏃',
  'cardio': '❤️',
  'glutei': '🍑',
  'altro': '⚡',
};
const Map<String, String> kBodyPartNames = {
  'nessuno': 'Nessuna',
  'petto': 'Petto',
  'schiena': 'Schiena',
  'gambe': 'Gambe',
  'spalle': 'Spalle',
  'braccia': 'Braccia',
  'core': 'Core',
  'full_body': 'Full Body',
  'cardio': 'Cardio',
  'glutei': 'Glutei',
  'altro': 'Altro',
};

// --- STREAK FUNCTIONS ---
String _isoWeekStr(DateTime d) {
  final thursday = d.add(Duration(days: 4 - (d.weekday == 7 ? 0 : d.weekday)));
  return '${thursday.year}-W${thursday.weekOfYear.toString().padLeft(2, '0')}';
}

extension _WeekOfYear on DateTime {
  int get weekOfYear {
    final firstDayOfYear = DateTime(year, 1, 1);
    final daysFromStart = difference(firstDayOfYear).inDays;
    return ((daysFromStart + firstDayOfYear.weekday - 1) / 7).ceil();
  }
}

Future<int> updateStreakCliente(String dayName, List<String> totalSessionNames) async {
  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now();
  final nowWeek = _isoWeekStr(now);
  final lastWeek = prefs.getString('streak_last_week_c') ?? '';
  int streakCount = prefs.getInt('streak_count_c') ?? 0;

  final rawPrev = prefs.getString('streak_prev_completed_c');
  final prevDone = rawPrev != null ? List<String>.from(jsonDecode(rawPrev)) : <String>[];
  final rawCurrent = prefs.getString('streak_completed_sessions_c');
  var currentDone = rawCurrent != null ? List<String>.from(jsonDecode(rawCurrent)) : <String>[];

  if (lastWeek != nowWeek) {
    if (lastWeek.isNotEmpty && totalSessionNames.isNotEmpty) {
      // Usa conteggio richiesto salvato (robusto a cambi di scheda)
      final prevRequired = prefs.getInt('streak_required_count_c') ?? totalSessionNames.length;
      streakCount = (prevDone.length >= prevRequired && prevRequired > 0) ? streakCount + 1 : 0;
    }
    currentDone = [];
    await prefs.setString('streak_prev_completed_c', jsonEncode(prevDone));
  }

  // Salva conteggio richiesto per questa settimana
  await prefs.setInt('streak_required_count_c', totalSessionNames.length);
  if (!currentDone.contains(dayName)) {
    currentDone.add(dayName);
  }
  await prefs.setInt('streak_count_c', streakCount);
  await prefs.setString('streak_last_week_c', nowWeek);
  await prefs.setString('streak_completed_sessions_c', jsonEncode(currentDone));
  await prefs.setString('last_workout_date_c', now.toIso8601String().split('T')[0]);
  return streakCount;
}

Future<int> getStreakCliente() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('streak_count_c') ?? 0;
}

Future<({int count, Set<String> done})> getStreakDataCliente() async {
  final prefs = await SharedPreferences.getInstance();
  final count = prefs.getInt('streak_count_c') ?? 0;
  final json = prefs.getString('streak_completed_sessions_c') ?? '[]';
  final done = Set<String>.from(jsonDecode(json));
  return (count: count, done: done);
}

Future<void> checkAndScheduleStreakNotificationCliente(String lang) async {
  if (kIsWeb) return;
  final prefs = await SharedPreferences.getInstance();
  final lastDate = prefs.getString('last_workout_date_c');
  if (lastDate == null) return;
  final last = DateTime.tryParse(lastDate);
  if (last == null) return;
  final daysSince = DateTime.now().difference(last).inDays;
  if (daysSince < 2) return;
  const channel = AndroidNotificationChannel('streak_reminder_c', 'Streak Reminders', importance: Importance.defaultImportance);
  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  final title = lang == 'en' ? '💪 Don\'t lose your streak!' : '💪 Non perdere la tua streak!';
  final body = lang == 'en'
      ? 'You haven\'t trained in ${daysSince} days. Train today to keep your progress!'
      : 'Non ti alleni da $daysSince giorni. Allenati oggi per mantenere i tuoi progressi!';
  await flutterLocalNotificationsPlugin.show(9902, title, body,
    NotificationDetails(android: AndroidNotificationDetails('streak_reminder_c', 'Streak Reminders', channelDescription: 'Streak motivation', importance: Importance.defaultImportance, priority: Priority.defaultPriority)));
}

/// Pianifica notifica streak giornaliera 48h dopo l'ultimo allenamento, poi ripete ogni giorno.
/// Chiamare dopo ogni allenamento completato per resettare il timer.
Future<void> scheduleStreakReminderCliente() async {
  if (kIsWeb) return;
  try {
    // Cancella reminder precedente
    await flutterLocalNotificationsPlugin.cancel(9901);
    // Pianifica per 48h da ora, poi ripete ogni giorno alla stessa ora
    final scheduledDate = tz.TZDateTime.now(tz.UTC).add(const Duration(hours: 48));
    await flutterLocalNotificationsPlugin.zonedSchedule(
      9901,
      '💪 Non perdere la tua streak!',
      'Non ti alleni da 2 giorni. Allenati oggi per mantenere i tuoi progressi!',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_reminder_c',
          'Streak Reminders',
          channelDescription: 'Streak motivation',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  } catch (e) {
    debugPrint('scheduleStreakReminder: $e');
  }
}

// --- DASHBOARD ---
class ClientMainPage extends StatefulWidget {
  const ClientMainPage({super.key});
  @override
  State<ClientMainPage> createState() => _ClientMainPageState();
}

class _ClientMainPageState extends State<ClientMainPage>
    with WidgetsBindingObserver {
  List<WorkoutDay> myRoutine = [];
  List<dynamic> history = [];
  Map<String, Map<String, dynamic>> _carryoverWeights = {};
  int _currentIndex = 0;

  // Impostazioni
  bool _stTimerSound = true;
  bool _stVibration = true;
  bool _stWakelock = true;
  bool _stAutoTimer = true;
  bool _stConfirmSeries = true;
  bool _stWeightHint = true;

  // --- NUOVE VARIABILI PER I FILE ---
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  // Streak
  int _streak = 0;
  Set<String> _streakDone = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _loadMainSettings();
    getStreakDataCliente().then((d) { if (mounted) setState(() { _streak = d.count; _streakDone = d.done; }); });
    checkAndScheduleStreakNotificationCliente('it');

    if (kIsWeb) {
      _controllaImportazioneWeb();
    } else {
      _initDeepLinks();
      _checkClipboardForScheda(); // Controlla appunti all'avvio
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !kIsWeb) {
      _checkClipboardForScheda(); // Controlla appunti al ritorno nell'app
    }
  }

  void _controllaImportazioneWeb() {
    if (!kIsWeb) return;
    try {
      // 1. Controlla URL ?data= (vecchio meccanismo QR/link)
      final uri = Uri.parse(html.window.location.href);
      final data = uri.queryParameters['data'];
      if (data != null) {
        String normalized = base64.normalize(data);
        List<int> compressed = base64Url.decode(normalized);
        String jsonScheda = utf8.decode(
          arc.GZipDecoder().decodeBytes(compressed),
        );
        _importaNuovaScheda(jsonScheda);
        html.window.history.replaceState({}, '', html.window.location.pathname);
        return;
      }

      // 2. Controlla file aperto via PWA File Handling API (Chrome desktop)
      _controllaPendingWebFile();
    } catch (e) {
      debugPrint("Errore importazione web: $e");
    }
  }

  void _controllaPendingWebFile() {
    if (!kIsWeb) return;
    try {
      final pendingStr = js.context['_pendingGymFile'] as String?;
      if (pendingStr != null && pendingStr.isNotEmpty) {
        js.context['_pendingGymFile'] = null; // consuma subito
        final data = jsonDecode(pendingStr) as Map<String, dynamic>;
        final name = data['name'] as String? ?? '';
        final content = data['content'] as String? ?? '';
        if (name.endsWith('.workout') && content.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _importaNuovaScheda(content);
          });
        }
      }
    } catch (e) {
      debugPrint("Errore PWA file: $e");
    }
  }

  Future<void> _mostraDialogoCopiaManuale(
    String contenuto,
    String titolo,
  ) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          titolo,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Il browser non ha permesso la copia automatica.\nSeleziona tutto il testo qui sotto e copialo:",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: SelectableText(
                  contenuto,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("CHIUDI", style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initDeepLinks() async {
    _appLinks = AppLinks();
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleIncomingFile(initialLink);
      }
    } catch (e) {
      debugPrint("Errore link iniziale: $e");
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingFile(uri);
    });
  }

  /// Controlla se negli appunti c'è una scheda compatibile e la importa automaticamente.
  Future<void> _checkClipboardForScheda() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data == null || data.text == null) return;
      final text = data.text!.trim();
      if (text.isEmpty) return;

      final bool isScheda =
          text.startsWith("TIPO:SCHEDA_GYM") ||
          text.startsWith("GYM1:") ||
          // Vecchio formato array diretto con chiave dayName
          (text.startsWith('[') && text.contains('dayName')) ||
          // Nuovo formato envelope
          (text.startsWith('{') && text.contains('"routine"'));

      if (isScheda) {
        // Svuota subito gli appunti per evitare loop al prossimo resume
        await Clipboard.setData(const ClipboardData(text: ""));
        _importaNuovaScheda(text);
      }
    } catch (e) {
      debugPrint("Errore controllo clipboard: $e");
    }
  }

  void _handleIncomingFile(Uri uri) async {
    if (uri.scheme == 'content' || uri.scheme == 'file') {
      try {
        final content = await _readFileUri(uri);
        // _importaNuovaScheda chiama _validaEParseScheda che:
        // - rifiuta con dialog se è un file .gymlog
        // - rifiuta con dialog se il JSON è malformato
        // - accetta .gym e vecchi formati
        _importaNuovaScheda(content);
      } catch (e) {
        debugPrint("Errore apertura file scheda: $e");
        if (mounted) _mostraErroreImportazione("Errore lettura file:\n$e");
      }
      return;
    }

    // --- URL con ?data= (web link condiviso) ---
    final data = uri.queryParameters['data'];
    if (data != null) {
      try {
        final normalized = base64.normalize(data);
        final compressed = base64Url.decode(normalized);
        final jsonStr = utf8.decode(arc.GZipDecoder().decodeBytes(compressed));
        _importaNuovaScheda(jsonStr);
      } catch (e) {
        debugPrint("Errore decodifica link: $e");
        if (mounted)
          _mostraErroreImportazione("Il link non è valido o è corrotto.");
      }
    }
  }

  void _importaNuovaScheda(String contenuto) async {
    try {
      final (routineList, clientName) = _validaEParseScheda(contenuto);
      final jsonPulito = jsonEncode(routineList);

      final prefs = await SharedPreferences.getInstance();

      // Salva i pesi dell'ultima sessione per ogni esercizio come "carryover"
      // così il suggerimento pesi funziona anche dopo aver azzerato i grafici
      final Map<String, Map<String, dynamic>> newCarryover = {};
      for (final entry in history) {
        final name = (entry['exercise'] as String?) ?? '';
        if (name.isEmpty) continue;
        final series = (entry['series'] as List?) ?? [];
        if (series.isEmpty) continue;
        final last = series.last as Map;
        final w = (last['w'] ?? last['weight'] ?? 0.0) as num;
        final r = (last['r'] ?? last['reps'] ?? 0) as num;
        if (w > 0) newCarryover[name] = {'w': w.toDouble(), 'r': r.toInt()};
      }
      // Merge con il carryover esistente (non sovrascrivere se non c'è storico)
      for (final k in _carryoverWeights.keys) {
        if (!newCarryover.containsKey(k)) newCarryover[k] = _carryoverWeights[k]!;
      }

      await prefs.setString('client_routine', jsonPulito);
      await prefs.setString('client_history', '[]'); // Grafici azzerati
      await prefs.setString('carryover_weights', jsonEncode(newCarryover));
      // Reset this week's completed sessions when routine changes (keep week streak count)
      await prefs.setString('streak_completed_sessions_c', '[]');
      final newRequired = (routineList as List).length;
      await prefs.setInt('streak_required_count_c', newRequired);
      if (clientName != null && clientName.trim().isNotEmpty) {
        await prefs.setString('athlete_name', clientName.trim());
      }

      if (mounted) {
        HapticFeedback.vibrate();
        final msg = clientName != null
            ? "✅ Scheda di $clientName caricata!"
            : "✅ Nuova scheda caricata con successo!";
        _mostraMessaggio(msg);
        setState(() {
          _loadData();
        });
      }
    } catch (e) {
      _mostraErroreImportazione(e.toString());
    }
  }

  void _mostraMessaggio(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── VALIDAZIONE JSON SCHEDA ──────────────────────────────────────────────

  /// Valida e parsa un contenuto scheda. Lancia un'eccezione con messaggio
  /// chiaro in caso di formato errato. Restituisce (routineList, clientName).
  (List, String?) _validaEParseScheda(String input) {
    input = input.trim();
    if (input.isEmpty) throw "Il testo è vuoto.";

    // Formato GYM1: (codice compresso base64)
    if (input.startsWith('GYM1:')) {
      try {
        final b64 = input.substring(5).replaceAll(RegExp(r'\s'), '');
        final padded = b64.padRight(b64.length + (4 - b64.length % 4) % 4, '=');
        final bytes = base64Url.decode(padded);
        input = utf8.decode(arc.GZipDecoder().decodeBytes(bytes));
      } catch (_) {
        throw "Codice GYM1 corrotto o incompleto.\nProva a copiarlo di nuovo dall'app del PT.";
      }
    }

    // Tipo sbagliato?
    if (input.startsWith("TIPO:PROGRESSI_GYM")) {
      throw "Questo è un file progressi atleta (.gymlog), non una scheda.\n\nChiedi al tuo PT di inviarti la scheda allenamento.";
    }

    // Rimuovi header
    if (input.startsWith("TIPO:SCHEDA_GYM")) {
      input = input.substring(input.indexOf('\n') + 1).trim();
    }
    if (input.isEmpty) throw "Il file è vuoto dopo l'intestazione.";

    // Parsa JSON
    dynamic decoded;
    try {
      decoded = jsonDecode(input);
    } catch (_) {
      throw "Il testo non è un JSON valido.\n\nAssicurati di copiare l'intero codice senza modifiche.";
    }

    if (decoded is List) {
      if (decoded.isEmpty)
        throw "La scheda è vuota (nessun esercizio trovato).";
      return (decoded, null);
    } else if (decoded is Map) {
      if (decoded.containsKey('routine')) {
        final routine = decoded['routine'];
        if (routine is! List || routine.isEmpty)
          throw "La scheda è vuota o corrotta.";
        return (routine, decoded['clientName'] as String?);
      } else if (decoded.containsKey('logs')) {
        throw "Questo sembra un file progressi (.gymlog), non una scheda.\n\nChiedi al PT di inviarti la scheda.";
      } else {
        throw "Struttura JSON non riconosciuta.\nManca la chiave 'routine' o l'elenco esercizi.";
      }
    } else {
      throw "Formato non riconosciuto. Atteso un array o oggetto JSON.";
    }
  }

  /// Mostra un dialog di errore con messaggio dettagliato (non solo snackbar).
  void _mostraErroreImportazione(String messaggio) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text(
              "Importazione fallita",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          messaggio,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              "OK",
              style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMainSettingsDrawer() {
    final Color accent = appAccentNotifier.value;
    final List<Color> presets = [
      const Color(0xFF00F2FF), // ciano originale
      const Color(0xFF00E676), // verde lime
      const Color(0xFFFFD740), // giallo ambra
      const Color(0xFFFF6D00), // arancione
      const Color(0xFFEA80FC), // viola chiaro
      const Color(0xFFFF4081), // rosa
      const Color(0xFF448AFF), // blu elettrico
      const Color(0xFF69FF47), // verde neon
      const Color(0xFFFF6E40), // corallo
      const Color(0xFFE040FB), // viola neon
    ];
    return Drawer(
      backgroundColor: const Color(0xFF1C1C1E),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<SharedPreferences>(
                future: SharedPreferences.getInstance(),
                builder: (ctx, snap) {
                  final name = snap.data?.getString('athlete_name') ?? '';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? name.toUpperCase() : 'ATLETA',
                        style: TextStyle(
                          color: accent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Impostazioni',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white12),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'FEEDBACK',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              _mainSettingRow(
                Icons.notifications_active_outlined,
                'Suono fine timer',
                _stTimerSound,
                (v) {
                  setState(() => _stTimerSound = v);
                  _saveMainSettings();
                },
              ),
              _mainSettingRow(
                Icons.vibration,
                'Vibrazione fine timer',
                _stVibration,
                (v) {
                  setState(() => _stVibration = v);
                  _saveMainSettings();
                },
              ),
              const Divider(color: Colors.white12),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'TIMER',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              _mainSettingRow(
                Icons.timer_outlined,
                'Avvia timer automaticamente',
                _stAutoTimer,
                (v) {
                  setState(() => _stAutoTimer = v);
                  _saveMainSettings();
                },
              ),
              _mainSettingRow(
                Icons.screen_lock_portrait_outlined,
                'Schermo sempre acceso',
                _stWakelock,
                (v) {
                  setState(() => _stWakelock = v);
                  _saveMainSettings();
                },
              ),
              const Divider(color: Colors.white12),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'SERIE',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              _mainSettingRow(
                Icons.check_circle_outline,
                'Finestra di conferma serie',
                _stConfirmSeries,
                (v) {
                  setState(() => _stConfirmSeries = v);
                  _saveMainSettings();
                },
              ),
              _mainSettingRow(
                Icons.trending_up,
                'Suggerimento aumento peso',
                _stWeightHint,
                (v) {
                  setState(() => _stWeightHint = v);
                  _saveMainSettings();
                },
              ),
              const Divider(color: Colors.white12),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'COLORE TEMA',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: presets.map((c) {
                  final selected = accent.toARGB32() == c.toARGB32();
                  return GestureDetector(
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt('accent_color', c.toARGB32());
                      appAccentNotifier.value = c;
                      setState(() {});
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: c.withAlpha(120),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check,
                              color: Colors.black,
                              size: 18,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const Divider(color: Colors.white12),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'DATI',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(
                    Icons.storage_rounded,
                    color: Colors.redAccent,
                  ),
                  label: const Text(
                    'Gestione Dati',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CancellazioneScreen(
                          history: history,
                          routine: myRoutine,
                          onSave: (newHistory) async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString(
                              'client_history',
                              jsonEncode(newHistory),
                            );
                            if (mounted) {
                              setState(() {
                                history = newHistory;
                              });
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mainSettingRow(
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: appAccentNotifier.value, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: appAccentNotifier.value,
        ),
      ],
    );
  }

  Future<void> _loadMainSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _stTimerSound = prefs.getBool('timer_sound_enabled') ?? true;
      _stVibration = prefs.getBool('vibration_enabled') ?? true;
      _stWakelock = prefs.getBool('wakelock_enabled') ?? true;
      _stAutoTimer = prefs.getBool('auto_start_timer') ?? true;
      _stConfirmSeries = prefs.getBool('confirm_series_enabled') ?? true;
      _stWeightHint = prefs.getBool('show_weight_suggestion') ?? true;
    });
  }

  Future<void> _saveMainSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('timer_sound_enabled', _stTimerSound);
    await prefs.setBool('vibration_enabled', _stVibration);
    await prefs.setBool('wakelock_enabled', _stWakelock);
    await prefs.setBool('auto_start_timer', _stAutoTimer);
    await prefs.setBool('confirm_series_enabled', _stConfirmSeries);
    await prefs.setBool('show_weight_suggestion', _stWeightHint);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Recuperiamo le stringhe, se sono null usiamo una stringa che rappresenta una lista vuota "[]"
    final String routineString = prefs.getString('client_routine') ?? "[]";
    final String historyString = prefs.getString('client_history') ?? "[]";
    final String carryoverString = prefs.getString('carryover_weights') ?? "{}";

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

        try {
          if (carryoverString.trim().isNotEmpty && carryoverString != "null") {
            final raw = jsonDecode(carryoverString) as Map<String, dynamic>;
            _carryoverWeights = raw.map(
              (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
            );
          }
        } catch (_) {
          _carryoverWeights = {};
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
    final String historyJson = prefs.getString('client_history') ?? '[]';
    await _condividiProgressiFile(historyJson);
  }

  Future<void> _condividiProgressiFile(String historyJson) async {
    // Includi il nome atleta nell'envelope per l'auto-assegnazione nel PT
    final prefs = await SharedPreferences.getInstance();
    final athleteName = prefs.getString('athlete_name');
    final String bodyJson;
    if (athleteName != null && athleteName.trim().isNotEmpty) {
      final envelope = {
        'clientName': athleteName.trim(),
        'logs': jsonDecode(historyJson),
      };
      bodyJson = jsonEncode(envelope);
    } else {
      bodyJson = historyJson;
    }
    final String contenutoFile = "TIPO:PROGRESSI_GYM\n$bodyJson";

    if (kIsWeb) {
      bool copiato = false;
      try {
        await Clipboard.setData(ClipboardData(text: contenutoFile));
        copiato = true;
      } catch (_) {}

      if (mounted) {
        if (copiato) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "✅ Dati copiati! Incollali al tuo Coach su WhatsApp.",
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          await _mostraDialogoCopiaManuale(
            contenutoFile,
            "Copia dati per il Coach",
          );
        }
      }
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      const fileName = 'miei_progressi.gymlog';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(contenutoFile, flush: true);
      // Copia anche negli appunti come fallback Apple/web
      await Clipboard.setData(ClipboardData(text: contenutoFile));
      await _gymFileChannel.invokeMethod('shareFile', {
        'path': file.path,
        'name': fileName,
      });
    } catch (e) {
      debugPrint("Errore esportazione: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore durante l'esportazione: $e")),
        );
      }
    }
  }

  Future<void> _importaSchedaDaFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final fileName = result.files.first.name.toLowerCase();
      final fileBytes = result.files.first.bytes;
      final filePath = result.files.first.path;

      // Controllo estensione
      if (!fileName.endsWith('.workout')) {
        _mostraErroreImportazione(
          "Il file selezionato non è una scheda valida.\n\n"
          "Seleziona un file con estensione .workout ricevuto dal tuo PT.\n\n"
          "File selezionato: ${result.files.first.name}",
        );
        return;
      }

      String content;
      if (fileBytes != null) {
        content = utf8.decode(fileBytes);
      } else if (filePath != null) {
        content = await File(filePath).readAsString();
      } else {
        throw "Impossibile leggere il file";
      }

      _importaNuovaScheda(content);
    } catch (e) {
      if (mounted) _mostraErroreImportazione("Errore apertura file:\n$e");
    }
  }

  void _importNewRoutine() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    String initialText = "";
    if (data != null && data.text != null) {
      final t = data.text!;
      if (t.startsWith('GYM1:') || t.contains('dayName')) {
        initialText = t;
      }
    }

    TextEditingController importC = TextEditingController(text: initialText);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "IMPORTA SCHEDA",
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(c);
                await _importaSchedaDaFile();
              },
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text("Apri file .workout"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent.withAlpha(40),
                foregroundColor: Colors.greenAccent,
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
            const Divider(color: Colors.white12, height: 20),
            const Text(
              "Chiedi al tuo PT il codice scheda e incollalo qui sotto, oppure apri direttamente il file .workout ricevuto.",
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: importC,
              maxLines: 4,
              style: const TextStyle(fontSize: 12, color: Colors.white),
              decoration: InputDecoration(
                hintText: "Incolla il codice ricevuto dal PT…",
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
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
              final input = importC.text.trim();
              if (input.isEmpty) return;
              try {
                final (routineList, clientName) = _validaEParseScheda(input);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(
                  'client_routine',
                  jsonEncode(routineList),
                );
                if (clientName != null && clientName.trim().isNotEmpty) {
                  await prefs.setString('athlete_name', clientName.trim());
                }
                if (c.mounted) {
                  Navigator.pop(c);
                  _loadData();
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
                _mostraErroreImportazione(e.toString());
              }
            },
            child: Text(
              "CARICA",
              style: TextStyle(
                color: Theme.of(c).colorScheme.primary,
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
      endDrawer: _buildMainSettingsDrawer(),
      appBar: AppBar(
        title: const Text(
          "GYM LOGBOOK",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: _currentIndex == 0
            ? IconButton(
                icon: const Icon(Icons.forum_rounded, size: 22),
                onPressed: () =>
                    _showSchedaOptions(Theme.of(context).colorScheme.primary),
              )
            : null,
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.settings_outlined, size: 22),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: _currentIndex == 0 ? _buildRoutinePage() : _buildTrainPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: Colors.black,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.white24,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.view_list_rounded),
            label: "Scheda",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_rounded),
            label: "Allenati",
          ),
        ],
      ),
    );
  }

  Widget _buildRoutinePage() {
    final accent = Theme.of(context).colorScheme.primary;
    if (myRoutine.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.view_list_rounded,
              color: accent.withAlpha(60),
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nessuna scheda caricata',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _importNewRoutine,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('CARICA SCHEDA'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent.withAlpha(120)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      children: [
        for (int i = 0; i < myRoutine.length; i++) ...[
          _buildRoutineCard(myRoutine[i], accent, i),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  void _showSchedaOptions(Color accent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              ListTile(
                onTap: () {
                  Navigator.pop(context);
                  _exportData();
                },
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.send_rounded, color: accent, size: 20),
                ),
                title: Text(
                  'Condividi scheda',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: const Text(
                  'Invia la scheda al tuo allenatore o salvala',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
              const SizedBox(height: 4),
              ListTile(
                onTap: () {
                  Navigator.pop(context);
                  _importNewRoutine();
                },
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.sync_rounded, color: accent, size: 22),
                ),
                title: Text(
                  'Aggiorna scheda',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: const Text(
                  'Carica una nuova scheda ricevuta dal coach',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoutineCard(WorkoutDay day, Color accent, int index) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _showWorkoutProgress(day),
        borderRadius: BorderRadius.circular(20),
        splashColor: accent.withAlpha(30),
        highlightColor: accent.withAlpha(15),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [accent.withAlpha(28), const Color(0xFF1C1C1E)],
            ),
            border: Border.all(color: accent.withAlpha(55), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: accent.withAlpha(30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Immagine sfondo sfumata a destra
                if (day.muscleImage != null)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.15,
                      child: Image.asset(
                        'assets/muscle/${day.muscleImage}',
                        fit: BoxFit.cover,
                        alignment: Alignment.centerRight,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      // Immagine / emoji a sinistra
                      if (day.muscleImage != null)
                        GestureDetector(
                          onTap: () => _showImageFullscreen(
                            context,
                            day.muscleImage!,
                            day.dayName,
                          ),
                          child: Hero(
                            tag: 'muscle_${day.muscleImage}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/muscle/${day.muscleImage}',
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        )
                      else if (day.bodyParts.isNotEmpty)
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: Center(
                            child: Text(
                              day.bodyParts
                                  .map((k) => kBodyPartIcons[k] ?? '')
                                  .where((e) => e.isNotEmpty)
                                  .join(' '),
                              style: const TextStyle(fontSize: 28),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      const SizedBox(width: 16),
                      // Nome centrato alla destra dell'immagine
                      Expanded(
                        child: Text(
                          day.dayName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      // Icona lista esercizi: tap → lista diretta
                      GestureDetector(
                        onTap: () => _showDayDetail(day),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.format_list_bulleted_rounded,
                            color: Colors.white38,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showWorkoutProgress(WorkoutDay day) {
    final accent = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E10),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            // Header: nome + link esercizi
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 22,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      day.dayName.toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(c);
                      _showDayDetail(day);
                    },
                    icon: const Icon(Icons.list_alt_rounded, size: 16),
                    label: const Text('Esercizi'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withAlpha(10), height: 1),
            // Immagine muscolo (tap → fullscreen)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: day.muscleImage != null
                  ? GestureDetector(
                      onTap: () {
                        Navigator.pop(c);
                        _showImageFullscreen(
                          context,
                          day.muscleImage!,
                          day.dayName,
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/muscle/${day.muscleImage}',
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : day.bodyParts.isNotEmpty
                  ? Center(
                      child: Text(
                        day.bodyParts
                            .map((k) => kBodyPartIcons[k] ?? '')
                            .where((e) => e.isNotEmpty)
                            .join(' '),
                        style: const TextStyle(fontSize: 60),
                      ),
                    )
                  : const SizedBox(height: 8),
            ),
            const SizedBox(height: 16),
            // Titolo grafico
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    color: Colors.white38,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'ANDAMENTO ALLENAMENTO',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Grafico
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: _WorkoutProgressChart(
                  day: day,
                  history: history,
                  accent: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageFullscreen(BuildContext ctx, String imageFile, String label) {
    Navigator.push(
      ctx,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (_, __, ___) => GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: Hero(
                      tag: 'muscle_$imageFile',
                      child: InteractiveViewer(
                        child: Image.asset(
                          'assets/muscle/$imageFile',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 16,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 12,
                    right: 16,
                    child: Icon(Icons.close, color: Colors.white70, size: 28),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDayDetail(WorkoutDay day) {
    final accent = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E10),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 24,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      day.dayName.toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  Text(
                    '${day.exercises.length} esercizi',
                    style: const TextStyle(color: Colors.white24, fontSize: 12),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withAlpha(10), height: 1),
            // Exercise list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: day.exercises.length,
                separatorBuilder: (_, __) => Divider(
                  color: Colors.white.withAlpha(8),
                  height: 1,
                  indent: 24,
                  endIndent: 24,
                ),
                itemBuilder: (ctx, idx) {
                  final ex = day.exercises[idx];
                  final scheme = _repsSchemeText(ex);
                  final isSuperset = ex.supersetGroup > 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        // YouTube button
                        InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () {
                            if (kIsWeb) {
                              cercaEsercizioSuYoutube(ex.name);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      YouTubeSearchView(esercizio: ex.name),
                                ),
                              );
                            }
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(18),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.red.withAlpha(40),
                              ),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Exercise info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (isSuperset)
                                    Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.withAlpha(80),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.deepPurple.withAlpha(
                                            100,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'S${ex.supersetGroup}',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: Colors.purpleAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () =>
                                          _showExerciseDetail(context, ex),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Text(
                                        ex.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                scheme,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(100),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Chart button
                        InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () {
                            _showGraph(ex.name);
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: accent.withAlpha(18),
                              shape: BoxShape.circle,
                              border: Border.all(color: accent.withAlpha(40)),
                            ),
                            child: Icon(
                              Icons.insights_rounded,
                              color: accent,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExerciseDetail(BuildContext ctx, ExerciseConfig ex) {
    final accent = Theme.of(ctx).colorScheme.primary;
    // Le info seguono la GIF (se presente), altrimenti il nome
    final info = (ex.gifFilename != null ? findByGifSlug(ex.gifFilename!) : null) ??
        findAnyExercise(ex.name);
    final gifPath = ex.gifFilename != null
        ? 'assets/gif/${ex.gifFilename}.gif'
        : info != null ? 'assets/gif/${info.gifSlug}.gif' : null;

    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF0E0E10),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 3,
                  height: 22,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ex.name.toUpperCase(),
                    style: TextStyle(
                      color: accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            if (info != null) ...[
              const SizedBox(height: 4),
              Text(
                info.nameEn,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 16),
            // GIF esercizio
            if (gifPath != null)
              Image.asset(
                gifPath,
                width: 280,
                height: 280,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.fitness_center,
                  size: 80,
                  color: Colors.white30,
                ),
              ),
            const SizedBox(height: 16),
            if (info != null && info.muscleImages.isNotEmpty)
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: info.muscleImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/muscle/${info.muscleImages[i]}',
                      width: 100,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            if (info != null && info.muscleImages.isNotEmpty)
              const SizedBox(height: 16),
            if (info != null) ...[
              _infoTile(
                Icons.fitness_center_rounded,
                'MUSCOLO PRINCIPALE',
                info.primaryMuscle,
                accent,
              ),
              if (info.secondaryMuscles.isNotEmpty)
                _infoTile(
                  Icons.grain_rounded,
                  'MUSCOLI SECONDARI',
                  info.secondaryMuscles,
                  Colors.white54,
                ),
              const SizedBox(height: 12),
              _sectionCard(
                '📋 ESECUZIONE',
                info.execution,
                const Color(0xFF1C1C1E),
              ),
              const SizedBox(height: 8),
              _sectionCard(
                '💡 CONSIGLI',
                info.tips,
                Colors.amber.withAlpha(15),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Esercizio non in catalogo.\nUsa YouTube per vedere la tecnica.',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            Divider(color: Colors.white12),
            const SizedBox(height: 8),
            Row(
              children: [
                _statChip(
                  '${ex.targetSets} serie',
                  Icons.repeat_rounded,
                  accent,
                ),
                const SizedBox(width: 8),
                _statChip(
                  '${ex.repsList.isNotEmpty ? ex.repsList.join('-') : '?'} reps',
                  Icons.numbers_rounded,
                  accent,
                ),
                if (ex.recoveryTime > 0) ...[
                  const SizedBox(width: 8),
                  _statChip(
                    '${ex.recoveryTime}s riposo',
                    Icons.timer_outlined,
                    Colors.white38,
                  ),
                ],
              ],
            ),
            if (ex.notePT.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: const Border(
                    left: BorderSide(color: Colors.amber, width: 3),
                  ),
                ),
                child: Text(
                  'NOTE COACH: ${ex.notePT}',
                  style: const TextStyle(color: Colors.amber, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(c);
                  if (kIsWeb) {
                    cercaEsercizioSuYoutube(info?.nameEn ?? ex.name);
                  } else {
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => YouTubeSearchView(
                          esercizio: info?.nameEn ?? ex.name,
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(
                  Icons.play_circle_outline_rounded,
                  color: Colors.red,
                ),
                label: const Text(
                  'Guarda su YouTube',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.withAlpha(80)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, Color color) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              '$label: ',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: Text(value, style: TextStyle(color: color, fontSize: 12)),
            ),
          ],
        ),
      );

  Widget _sectionCard(String title, String body, Color bg) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    ),
  );

  Widget _statChip(String label, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      border: Border.all(color: color.withAlpha(60)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ],
    ),
  );

  void _showGraph(String name) {
    final accent = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E0E10),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => Container(
        height: MediaQuery.of(context).size.height * 0.72,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.insights_rounded, color: accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Progressi nel tempo — una linea per serie',
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: PTGraphWidget(exerciseName: name, history: history),
            ),
          ],
        ),
      ),
    );
  }

  String _repsSchemeText(ExerciseConfig ex) {
    if (ex.repsList.isEmpty) return '${ex.targetSets}×?';
    final reps = ex.repsList.take(ex.targetSets).toList();
    if (reps.every((r) => r == reps.first))
      return '${reps.length}×${reps.first}';
    return reps.join('–');
  }

  Widget _exPreviewRow(
    String name,
    String scheme,
    Color accent,
    bool isSuperset,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isSuperset ? 8 : 6,
            height: isSuperset ? 8 : 6,
            margin: EdgeInsets.only(right: 10, top: isSuperset ? 3 : 4),
            decoration: BoxDecoration(
              color: isSuperset ? accent : accent.withAlpha(180),
              shape: isSuperset ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isSuperset ? BorderRadius.circular(2) : null,
            ),
          ),
          Expanded(
            child: Text(
              '$name  •  $scheme',
              style: TextStyle(
                color: isSuperset ? Colors.white70 : Colors.white60,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExPreviewList(WorkoutDay d, Color accent) {
    final List<Widget> items = [];
    final Set<int> processedGroups = {};
    int count = 0;
    for (final ex in d.exercises) {
      if (count >= 4) break;
      if (ex.supersetGroup == 0) {
        items.add(_exPreviewRow(ex.name, _repsSchemeText(ex), accent, false));
        count++;
      } else {
        if (!processedGroups.contains(ex.supersetGroup)) {
          processedGroups.add(ex.supersetGroup);
          final group = d.exercises
              .where((e) => e.supersetGroup == ex.supersetGroup)
              .toList();
          final names = group.map((e) => e.name).join(' + ');
          final schemes = group.map((e) => _repsSchemeText(e)).join(' / ');
          items.add(_exPreviewRow(names, schemes, accent, true));
          count++;
        }
      }
    }
    return Column(children: items);
  }

  String _lastTrainedLabel(WorkoutDay day) {
    DateTime? latest;
    for (final ex in day.exercises) {
      for (final h in history) {
        if ((h as Map)['exercise'] == ex.name) {
          try {
            final d = DateTime.parse(h['date'] as String);
            if (latest == null || d.isAfter(latest)) latest = d;
          } catch (_) {}
        }
      }
    }
    if (latest == null) return 'Mai allenato';
    final diff = DateTime.now().difference(latest).inDays;
    if (diff == 0) return 'Oggi';
    if (diff == 1) return 'Ieri';
    return '$diff giorni fa';
  }

  void _startWorkout(WorkoutDay d) async {
    // Cancella SEMPRE lo snapshot precedente: ogni tap su "Allena ora" è una nuova sessione.
    // Il ripristino automatico avviene solo se l'app viene chiusa MID-workout.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('workout_in_progress_${d.dayName}');
    // Resetta i risultati in memoria dell'allenamento precedente
    for (final ex in d.exercises) {
      ex.results = [];
    }
    if (!mounted) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (c, anim, _) => WorkoutEngine(
          day: d,
          history: history,
          carryoverWeights: _carryoverWeights,
          allSessionNames: myRoutine.map((r) => r.dayName).toList(),
          onDone: (session) async {
            history.add(session);
            final prefs2 = await SharedPreferences.getInstance();
            await prefs2.setString('client_history', jsonEncode(history));
            final allNames = myRoutine.map((r) => r.dayName).toList();
            final newStreak = await updateStreakCliente(d.dayName, allNames);
            final streakData = await getStreakDataCliente();
            if (mounted) setState(() { _streak = newStreak; _streakDone = streakData.done; });
            _loadData();
          },
        ),
        transitionsBuilder: (c, anim, _, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  void _showStreakInfo() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 4),
            Text(
              '$_streak',
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 48,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
            Text(
              _streak == 1 ? 'settimana' : 'settimane',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Completa TUTTE le sessioni della tua scheda ogni settimana per incrementare il contatore.\n\nSe salti anche solo una sessione in una settimana, la streak si azzera.\n\nSii costante — ogni settimana conta! 💪',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            if (myRoutine.isNotEmpty) ...[
              Text(
                '${_streakDone.where((n) => myRoutine.any((d) => d.dayName == n)).length}/${myRoutine.length} sessioni questa settimana',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final n = myRoutine.length;
                  final iconSize = n > 0 ? (constraints.maxWidth / n - 8).clamp(20.0, 48.0) : 48.0;
                  return Row(
                    children: List.generate(n, (i) {
                      final name = myRoutine[i].dayName;
                      final done = _streakDone.contains(name);
                      return Expanded(
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: iconSize,
                            height: iconSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: done ? const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFFFFAB00)]) : null,
                              color: done ? null : const Color(0xFF2C2C2E),
                              boxShadow: done ? [BoxShadow(color: Colors.orange.withAlpha(80), blurRadius: 6)] : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Opacity(
                                opacity: done ? 1.0 : 0.2,
                                child: Image.asset('assets/icon_client.png', fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('OK', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainPage() {
    final Color accent = appAccentNotifier.value;
    if (myRoutine.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, color: accent.withAlpha(80), size: 64),
            const SizedBox(height: 16),
            const Text(
              'Nessuna scheda caricata',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Importa una scheda dal tuo Coach',
              style: TextStyle(color: Colors.white24, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 28,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'ALLENATI',
                      style: TextStyle(
                        color: accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Scegli e inizia il tuo allenamento',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
                if (myRoutine.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _showStreakInfo,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _streak > 0 ? const Color(0xFFFF6B00).withAlpha(80) : Colors.white12,
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (ctx, bannerConstraints) {
                          final n = myRoutine.length;
                          final sideIconsWidth = bannerConstraints.maxWidth - 68 - 10 - 6 - 18;
                          final fullIconsWidth = bannerConstraints.maxWidth;
                          final fitsSide = n == 0 || (n * 38.0 + (n - 1) * 6.0) <= sideIconsWidth;
                          final fitsFull = n == 0 || (n * 38.0 + (n - 1) * 6.0) <= fullIconsWidth;

                          final Widget Function(double) buildIconRow = (availWidth) {
                            final iconSize = n > 0 ? (availWidth / n - 8).clamp(20.0, 48.0) : 48.0;
                            return Row(
                              children: List.generate(n, (i) {
                                final name = myRoutine[i].dayName;
                                final done = _streakDone.contains(name);
                                return Expanded(
                                  child: Center(
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      width: iconSize,
                                      height: iconSize,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        gradient: done ? const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFFFFAB00)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                                        color: done ? null : const Color(0xFF2C2C2E),
                                        boxShadow: done ? [BoxShadow(color: Colors.orange.withAlpha(100), blurRadius: 6)] : null,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Opacity(
                                          opacity: done ? 1.0 : 0.2,
                                          child: Image.asset('assets/icon_client.png', fit: BoxFit.cover),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            );
                          };

                          final doneCount = _streakDone.where((nm) => myRoutine.any((d) => d.dayName == nm)).length;

                          if (fitsSide) {
                            return Row(
                              children: [
                                SizedBox(
                                  width: 68,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text('🔥', style: TextStyle(fontSize: 22)),
                                          const SizedBox(width: 2),
                                          Text('$_streak', style: TextStyle(color: _streak > 0 ? Colors.orange : Colors.white24, fontSize: 30, fontWeight: FontWeight.w900, height: 1.0)),
                                        ],
                                      ),
                                      Text(
                                        _streak == 1 ? 'settimana' : 'settimane',
                                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$doneCount/${myRoutine.length}',
                                        style: TextStyle(color: doneCount >= myRoutine.length ? Colors.orange : Colors.white38, fontSize: 10, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: buildIconRow(sideIconsWidth)),
                                const SizedBox(width: 6),
                                const Icon(Icons.info_outline, color: Colors.white24, size: 15),
                              ],
                            );
                          } else {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('🔥', style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$_streak ${_streak == 1 ? 'settimana' : 'settimane'}',
                                      style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '$doneCount/${myRoutine.length}',
                                      style: TextStyle(color: doneCount >= myRoutine.length ? Colors.orange : Colors.white38, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.info_outline, color: Colors.white24, size: 15),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                buildIconRow(fitsFull ? fullIconsWidth : fullIconsWidth),
                              ],
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((_, i) {
              final d = myRoutine[i];
              final label = _lastTrainedLabel(d);
              final isToday = label == 'Oggi';
              return GestureDetector(
                onTap: () => _startWorkout(d),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111113),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isToday
                          ? accent.withAlpha(120)
                          : Colors.white.withAlpha(15),
                      width: isToday ? 1.5 : 1,
                    ),
                    boxShadow: isToday
                        ? [
                            BoxShadow(
                              color: accent.withAlpha(40),
                              blurRadius: 16,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top: nome + badge "ultimo allenamento"
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withAlpha(10),
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${d.bodyParts.map((k) => kBodyPartIcons[k] ?? '').where((e) => e.isNotEmpty).join(' ')} ${d.dayName.toUpperCase()}'
                                        .trim(),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                    style: TextStyle(
                                      color: isToday ? accent : Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.fitness_center,
                                        size: 12,
                                        color: Colors.white38,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '${d.exercises.length} esercizi',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.repeat,
                                        size: 12,
                                        color: Colors.white38,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '${d.exercises.fold(0, (s, ex) => s + ex.targetSets)} serie',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isToday
                                    ? accent.withAlpha(30)
                                    : Colors.white.withAlpha(10),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isToday
                                      ? accent.withAlpha(120)
                                      : Colors.white12,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isToday
                                        ? Icons.check_circle
                                        : Icons.history,
                                    size: 12,
                                    color: isToday ? accent : Colors.white38,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      color: isToday ? accent : Colors.white38,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Exercise preview list
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: Column(
                          children: [
                            _buildExPreviewList(d, accent),
                            if (d.exercises.length > 4)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '+ ${d.exercises.length - 4} altri',
                                    style: TextStyle(
                                      color: accent.withAlpha(150),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // CTA button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _startWorkout(d),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 22,
                            ),
                            label: const Text(
                              'ALLENATI ORA',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 1,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }, childCount: myRoutine.length),
          ),
        ),
      ],
    );
  }
}

// --- MOTORE ALLENAMENTO ---
class WorkoutEngine extends StatefulWidget {
  final WorkoutDay day;
  final List<dynamic> history;
  final Map<String, Map<String, dynamic>> carryoverWeights;
  final List<String> allSessionNames;
  final Function(Map<String, dynamic>) onDone;
  const WorkoutEngine({
    super.key,
    required this.day,
    required this.history,
    required this.onDone,
    required this.allSessionNames,
    this.carryoverWeights = const {},
  });
  @override
  State<WorkoutEngine> createState() => _WorkoutEngineState();
}

class _WorkoutEngineState extends State<WorkoutEngine>
    with WidgetsBindingObserver {
  int exI = 0;
  int setN = 1;
  String _infoProssimo = ""; // Serve per far vedere cosa fare dopo nel timer
  String _prossimoNome =
      ""; // Nome esercizio prossimo (per aprire dettaglio dal timer)
  List<Map<String, dynamic>> currentExSeries = [];
  final TextEditingController wC = TextEditingController();
  final TextEditingController rC = TextEditingController();
  int _bgCounter = 0;
  int _maxTime = 1;
  DateTime? _endTime;
  Timer? _bgTimer;
  bool isRestingFullScreen = false;
  bool timerActive = false;
  List<String> eserciziCompletati = [];
  final Map<String, TextEditingController> _noteControllers = {};
  List<Map<String, dynamic>> _allCompletedExercises = [];
  bool _isNewRecord = false;
  int _currentStreak = 0;
  int _streakDoneCount = 0;
  int _streakTotalCount = 0;
  Set<String> _streakDoneNames = {};
  final Map<int, List<Map<String, dynamic>>> _supersetAccumulated = {};
  // Risultati sessione precedente: nome esercizio → lista serie {w, r}
  final Map<String, List<Map<String, dynamic>>> _previousResults = {};
  // Chiave persistenza allenamento in corso
  String get _inProgressKey => 'workout_in_progress_${widget.day.dayName}';
  // Suono fine timer
  bool _timerSoundEnabled = true;
  bool _vibrationEnabled = true;
  bool _wakelockEnabled = true;
  // Generazione notifica: si incrementa ad ogni nuovo timer,
  // così la notifica precedente non si attiva se è stato riavviato
  int _notifGen = 0;
  // ID univoco di questa sessione di allenamento (usato per separare
  // più sessioni nello stesso giorno nei grafici)
  late final String _sessionId;
  bool _autoStartTimer = true;
  bool _confirmSeriesEnabled = true;
  bool _showWeightSuggestion = true;

  @override
  void initState() {
    super.initState();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    exI = 0;
    currentExSeries = [];
    setN = 1;
    // Popola _previousResults dall'ultima sessione dello storico
    for (var ex in widget.day.exercises) {
      Map<String, dynamic>? lastEntry;
      for (final h in widget.history) {
        if ((h as Map<String, dynamic>)['exercise'] == ex.name) {
          if (lastEntry == null) {
            lastEntry = h;
          } else {
            try {
              final dLast = DateTime.parse(lastEntry['date'] as String);
              final dH = DateTime.parse(h['date'] as String);
              if (dH.isAfter(dLast)) lastEntry = h;
            } catch (_) {}
          }
        }
      }
      if (lastEntry != null) {
        _previousResults[ex.name] = (lastEntry['series'] as List)
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();
      }
      ex.results = [];
    }
    _loadSettings();
    _restoreInProgressWorkout();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted)
      setState(() {
        _timerSoundEnabled = prefs.getBool('timer_sound_enabled') ?? true;
        _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
        _wakelockEnabled = prefs.getBool('wakelock_enabled') ?? true;
        _autoStartTimer = prefs.getBool('auto_start_timer') ?? true;
        _confirmSeriesEnabled = prefs.getBool('confirm_series_enabled') ?? true;
        _showWeightSuggestion = prefs.getBool('show_weight_suggestion') ?? true;
      });
  }

  /// Salva lo stato corrente dell'allenamento in SharedPreferences
  Future<void> _persistInProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = {
      'exI': exI,
      'setN': setN,
      'eserciziCompletati': eserciziCompletati,
      'currentExSeries': currentExSeries,
      'supersetAccumulated': _supersetAccumulated.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'allCompletedExercises': _allCompletedExercises,
    };
    await prefs.setString(_inProgressKey, jsonEncode(snapshot));
  }

  /// Ripristina un allenamento in corso (se esiste) all'avvio
  Future<void> _restoreInProgressWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_inProgressKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final snap = jsonDecode(raw) as Map<String, dynamic>;
      final savedExI = (snap['exI'] as num).toInt();
      final savedSetN = (snap['setN'] as num).toInt();
      final savedCompleted = (snap['eserciziCompletati'] as List)
          .cast<String>();
      final savedCurrent = (snap['currentExSeries'] as List)
          .cast<Map<String, dynamic>>();
      final savedSuperset =
          (snap['supersetAccumulated'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(
              int.parse(k),
              (v as List).cast<Map<String, dynamic>>(),
            ),
          );
      final savedAllDone = (snap['allCompletedExercises'] as List)
          .cast<Map<String, dynamic>>();

      // Difesa: se lo snapshot contiene un allenamento già completato, cancella e riparte
      if (savedCompleted.length >= widget.day.exercises.length) {
        await prefs.remove(_inProgressKey);
        return;
      }

      if (!mounted) return;
      setState(() {
        exI = savedExI.clamp(0, widget.day.exercises.length - 1);
        setN = savedSetN;
        eserciziCompletati = savedCompleted;
        currentExSeries = savedCurrent;
        _supersetAccumulated.addAll(savedSuperset);
        _allCompletedExercises = savedAllDone;
        // Ripristina i risultati degli esercizi completati nel modello
        for (final done in savedAllDone) {
          final name = done['exercise'] as String;
          final series = (done['series'] as List).cast<Map<String, dynamic>>();
          final ex = widget.day.exercises.firstWhere(
            (e) => e.name == name,
            orElse: () => widget.day.exercises.first,
          );
          ex.results = series;
        }
        if (currentExSeries.isNotEmpty) {
          widget.day.exercises[exI].results = currentExSeries;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('♻️ Allenamento precedente ripristinato'),
            duration: Duration(seconds: 3),
            backgroundColor: Color(0xFF1C1C2E),
          ),
        );
      }
    } catch (_) {
      // Snapshot corrotto: ignora
      final prefs2 = await SharedPreferences.getInstance();
      await prefs2.remove(_inProgressKey);
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
                child: Text(
                  "ESCI E SALVA",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  // --- FUNZIONE NOTIFICA ---
  Future<void> _programmaNotificaFine(int secondi) async {
    ++_notifGen;
    final gen = _notifGen;
    if (kIsWeb) return;

    // Cancella notifica finale precedente
    try { await flutterLocalNotificationsPlugin.cancel(0); } catch (_) {}

    // Notifica fine recupero — Future.delayed affidabile (come cliente.txt)
    try {
      await Future.delayed(Duration(seconds: secondi));
      if (gen != _notifGen) return; // annullato via _skipRest
      await flutterLocalNotificationsPlugin.show(
        0,
        'TORNA AD ALLENARTI!',
        null,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'timer_gym',
            'Timer Recupero',
            importance: Importance.max,
            priority: Priority.high,
            icon: 'ic_notification',
            playSound: true,
            enableVibration: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Errore notifica: $e");
    }
  }

  // Aggiorna la notifica countdown nel pannello con il tempo rimanente grande (nativo)
  void _aggiornaCountdown(int remaining) {
    if (kIsWeb) return;
    final mins = remaining ~/ 60;
    final secs = remaining % 60;
    final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    try {
      _gymFileChannel.invokeMethod('showTimerNotification', {
        'time': timeStr,
        'subtitle': '⏱ Recupero in corso',
        'channel': 'timer_gym_cd',
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_bgTimer != null) _bgTimer!.cancel();
    wC.dispose();
    rC.dispose();
    for (final ctrl in _noteControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // Questo metodo rileva quando l'utente esce dall'app (va su YouTube)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      flutterLocalNotificationsPlugin.cancelAll();
    }
  }

  // Calcola il punteggio performance: > 0 miglioramento, < 0 peggioramento, 0 stallo
  int _calcPerformanceScore() {
    int improved = 0, regressed = 0;
    for (final ex in _allCompletedExercises) {
      final name = ex['exercise'] as String;
      final currSeries = (ex['series'] as List).cast<Map<String, dynamic>>();
      final prevSeries = _previousResults[name];
      if (prevSeries == null || prevSeries.isEmpty || currSeries.isEmpty)
        continue;
      final prevAvgW =
          prevSeries
              .map((s) => (s['w'] as num).toDouble())
              .reduce((a, b) => a + b) /
          prevSeries.length;
      final prevAvgR =
          prevSeries
              .map((s) => (s['r'] as num).toDouble())
              .reduce((a, b) => a + b) /
          prevSeries.length;
      final currAvgW =
          currSeries
              .map((s) => (s['w'] as num).toDouble())
              .reduce((a, b) => a + b) /
          currSeries.length;
      final currAvgR =
          currSeries
              .map((s) => (s['r'] as num).toDouble())
              .reduce((a, b) => a + b) /
          currSeries.length;
      if (currAvgW > prevAvgW + 0.05 || currAvgR > prevAvgR + 0.05)
        improved++;
      else if (currAvgW < prevAvgW - 0.05 && currAvgR < prevAvgR - 0.05)
        regressed++;
    }
    return improved - regressed;
  }

  // Ritorna lista dettagli miglioramenti per esercizio
  void _showDettagliMiglioramenti(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Riepilogo allenamento',
          style: TextStyle(
            color: Theme.of(c).colorScheme.primary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _allCompletedExercises.length,
            itemBuilder: (_, i) {
              final ex = _allCompletedExercises[i];
              final name = ex['exercise'] as String;
              final currSeries = (ex['series'] as List)
                  .map((s) => Map<String, dynamic>.from(s as Map))
                  .toList();
              final prevSeries = _previousResults[name];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...List.generate(currSeries.length, (si) {
                      final s = currSeries[si];
                      final double w = (s['w'] as num).toDouble();
                      final int r = (s['r'] as num).toInt();
                      // Confronto con la stessa serie del giro precedente
                      Color serieColor = Colors.white70;
                      String compareStr = '';
                      if (prevSeries != null && si < prevSeries.length) {
                        final ps = prevSeries[si];
                        final double pw = (ps['w'] as num).toDouble();
                        final int pr = (ps['r'] as num).toInt();
                        final dW = w - pw;
                        final dR = r - pr;
                        if (dW > 0.05 || dR > 0) {
                          serieColor = Colors.greenAccent;
                          if (dW > 0.05 && dR > 0)
                            compareStr =
                                ' (+${dW.toStringAsFixed(1)}kg, +$dR reps)';
                          else if (dW > 0.05)
                            compareStr = ' (+${dW.toStringAsFixed(1)}kg)';
                          else
                            compareStr = ' (+$dR reps)';
                        } else if (dW < -0.05 && dR < 0) {
                          serieColor = Colors.redAccent;
                          compareStr =
                              ' (${dW.toStringAsFixed(1)}kg, ${dR}reps)';
                        } else {
                          serieColor = Colors.white60;
                          compareStr = ' (=)';
                        }
                      } else if (prevSeries == null) {
                        serieColor = Colors.white54;
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                'S${si + 1}',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              '${w % 1 == 0 ? w.toInt() : w} kg × $r reps$compareStr',
                              style: TextStyle(
                                color: serieColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(color: Colors.white12, height: 20),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(
              'CHIUDI',
              style: TextStyle(color: Theme.of(c).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _showRecapDialog() {
    int totalSeries = 0;
    for (final ex in _allCompletedExercises) {
      totalSeries += (ex['series'] as List).length;
    }
    final score = _calcPerformanceScore();
    // hasPrev = almeno un esercizio ha dati dalla sessione precedente
    final hasPrev = _allCompletedExercises.any(
      (ex) => _previousResults.containsKey(ex['exercise']),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        IconData perfIcon;
        Color perfColor;
        String perfLabel;
        if (!hasPrev) {
          perfIcon = Icons.fitness_center;
          perfColor = Theme.of(c).colorScheme.primary;
          perfLabel = 'Prima sessione!';
        } else if (score > 0) {
          perfIcon = Icons.trending_up;
          perfColor = Colors.greenAccent;
          perfLabel = 'In miglioramento!';
        } else if (score < 0) {
          perfIcon = Icons.trending_down;
          perfColor = Colors.redAccent;
          perfLabel = 'In calo';
        } else {
          perfIcon = Icons.trending_flat;
          perfColor = Colors.orangeAccent;
          perfLabel = 'Stallo';
        }
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Icon(perfIcon, color: perfColor, size: 52),
              const SizedBox(height: 8),
              Text(
                'ALLENAMENTO COMPLETATO!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(c).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                perfLabel,
                style: TextStyle(
                  color: perfColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              _recapRow(
                Icons.fitness_center,
                'Esercizi',
                '${_allCompletedExercises.length}',
              ),
              _recapRow(Icons.repeat, 'Serie totali', '$totalSeries'),
              const SizedBox(height: 8),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              // Streak progress section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF252527),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _currentStreak > 0 ? Colors.orange.withAlpha(80) : Colors.white12,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🔓', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Sessione sbloccata! $_streakDoneCount/$_streakTotalCount questa settimana',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    if (widget.allSessionNames.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final n = widget.allSessionNames.length;
                          final iconSize = n > 0 ? (constraints.maxWidth / n - 8).clamp(18.0, 48.0) : 48.0;
                          return Row(
                            children: List.generate(n, (i) {
                              final name = widget.allSessionNames[i];
                              final done = _streakDoneNames.contains(name);
                              return Expanded(
                                child: Center(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: iconSize,
                                    height: iconSize,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(7),
                                      gradient: done
                                          ? const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFFFFAB00)])
                                          : null,
                                      color: done ? null : const Color(0xFF1C1C1E),
                                      boxShadow: done ? [BoxShadow(color: Colors.orange.withAlpha(80), blurRadius: 6)] : null,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(7),
                                      child: Opacity(
                                        opacity: done ? 1.0 : 0.2,
                                        child: Image.asset('assets/icon_client.png', fit: BoxFit.cover),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (_streakDoneCount >= _streakTotalCount && _streakTotalCount > 0)
                      const Text(
                        '🔥 Settimana completata! La streak continua!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                      )
                    else
                      Text(
                        'Completa ancora ${_streakTotalCount - _streakDoneCount} session${_streakTotalCount - _streakDoneCount == 1 ? 'e' : 'i'} per non perdere la streak!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    if (_currentStreak > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        '🔥 $_currentStreak ${_currentStreak == 1 ? 'settimana' : 'settimane'} di fila!',
                        style: const TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.day.dayName,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(c).colorScheme.primary,
                  side: BorderSide(color: Theme.of(c).colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _showDettagliMiglioramenti(c),
                child: const Text(
                  'DETTAGLI',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(c).colorScheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(c);
                  Navigator.pop(context);
                },
                child: const Text(
                  'OTTIMO LAVORO!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _recapRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, color: Colors.amber, size: 20),
        const SizedBox(width: 12),
        Flexible(
          child: Text(label, style: const TextStyle(color: Colors.white60)),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );

  // Avvia il timer al primo tocco — se è già attivo non fa nulla
  void _avviaTimerSeNonAttivo(int sec) {
    if (timerActive) return; // già in corso, non azzerare
    _triggerTimer(sec, force: true);
  }

  void _triggerTimer(int sec, {bool force = false}) {
    // Se il timer è già attivo e NON stiamo forzando, usciamo subito
    // SENZA cancellare il timer che sta correndo.
    if (timerActive && !force) return;
    if (!_autoStartTimer && !force) return;

    if (_wakelockEnabled)
      try {
        WakelockPlus.enable();
      } catch (_) {}
    _bgTimer?.cancel();

    // 1. Calcoliamo l'orario esatto di fine
    _endTime = DateTime.now().add(Duration(seconds: sec));

    setState(() {
      _bgCounter = sec;
      _maxTime = sec;
      timerActive = true;
    });

    // 2. Programmiamo la notifica finale (Future.delayed) e mostriamo countdown
    _programmaNotificaFine(sec);
    _aggiornaCountdown(sec); // countdown iniziale nel pannello notifiche

    // 3. Timer visivo
    _bgTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_endTime == null) {
        t.cancel();
        return;
      }

      final remaining = _endTime!.difference(DateTime.now()).inSeconds;

      if (remaining <= 0) {
        if (!kIsWeb) _gymFileChannel.invokeMethod('cancelTimerNotification').catchError((_) {}); // cancella countdown nativo
        _eseguiFeedbackFineTimer();
        t.cancel();
        if (mounted) {
          setState(() {
            timerActive = false;
            isRestingFullScreen = false;
            _bgCounter = 0;
            _endTime = null;
          });
        }
        try {
          WakelockPlus.disable();
        } catch (_) {}
      } else {
        if (mounted) {
          setState(() {
            _bgCounter = remaining;
          });
        }
        _aggiornaCountdown(remaining); // aggiorna timer nel pannello ogni secondo
      }
    });
  }

  // Suono di avviso tramite ToneGenerator nativo Android — campanella bassa x3
  Future<void> _playBeep() async {
    if (kIsWeb) return;
    try {
      // ♪ dong dong DONG — tre rintocchi lenti da campanella
      await _gymFileChannel.invokeMethod('playBeep', 500);
      await Future.delayed(const Duration(milliseconds: 350));
      await _gymFileChannel.invokeMethod('playBeep', 500);
      await Future.delayed(const Duration(milliseconds: 350));
      await _gymFileChannel.invokeMethod('playBeep', 700);
    } catch (e) {
      debugPrint("Errore beep: $e");
    }
  }

  void _eseguiFeedbackFineTimer() async {
    if (kIsWeb) {
      debugPrint("TIMER FINITO!");
    } else {
      if (_timerSoundEnabled) _playBeep();
      if (_vibrationEnabled && (await Vibration.hasVibrator()) == true) {
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

  void _confermaSerie() {
    final double w = double.tryParse(wC.text) ?? -1;
    final int r = int.tryParse(rC.text) ?? 0;
    if (w < 0 || r <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Inserisci kg e reps prima di confermare"),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final currentEx = widget.day.exercises[exI];
    if (!_confirmSeriesEnabled) {
      _saveSet();
      return;
    }

    // ── Avvia subito il timer al tap su "Conferma Serie" ──────────────────
    // Usiamo il recoveryTime dell'esercizio corrente (o maxRecovery del gruppo)
    int previewRecovery = currentEx.recoveryTime;
    if (currentEx.supersetGroup > 0) {
      int groupStart = exI, groupEnd = exI;
      while (groupStart > 0 &&
          widget.day.exercises[groupStart - 1].supersetGroup ==
              currentEx.supersetGroup) groupStart--;
      while (groupEnd < widget.day.exercises.length - 1 &&
          widget.day.exercises[groupEnd + 1].supersetGroup ==
              currentEx.supersetGroup) groupEnd++;
      previewRecovery = widget.day.exercises
          .sublist(groupStart, groupEnd + 1)
          .map((e) => e.recoveryTime)
          .reduce((a, b) => a > b ? a : b);
    }
    // Avvia il timer al tap su Conferma (solo se non è già partito)
    _avviaTimerSeNonAttivo(previewRecovery);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              currentEx.name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Serie $setN",
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _chipConferma(
                  "${w % 1 == 0 ? w.toInt() : w} kg",
                  const Color(0xFFFFD700),
                ),
                const SizedBox(width: 20),
                _chipConferma("$r reps", Theme.of(ctx).colorScheme.primary),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Annulla: il timer continua a scorrere
                      Navigator.pop(ctx);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("ANNULLA"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      // Il timer è già avviato, _saveSet non deve riavviarlo
                      _saveSet();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "SALVA SERIE",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipConferma(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    decoration: BoxDecoration(
      color: color.withAlpha(30),
      border: Border.all(color: color.withAlpha(180), width: 1.5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
    ),
  );

  void _saveSet() async {
    double w = double.tryParse(wC.text) ?? 0.0;
    int r = int.tryParse(rC.text) ?? 0;
    if (w < 0 || r <= 0) return;

    final currentEx = widget.day.exercises[exI];

    // Controlla record personale rispetto all'ultima sessione
    final suggest = _getSuggest(currentEx.name, setN);
    final lastW = (suggest['w'] as num?)?.toDouble() ?? 0.0;
    final lastR = (suggest['r'] as num?)?.toInt() ?? 0;
    setState(() => _isNewRecord = (lastW > 0 || lastR > 0) && (w > lastW || r > lastR));
    if (_isNewRecord && mounted) {
      _showNewRecordOverlay();
    }

    final entry = {'s': setN, 'w': w, 'r': r};

    // ========== SUPERSERIE / CIRCUITO (round-robin) ==========
    final currentGroup = currentEx.supersetGroup;
    if (currentGroup > 0) {
      _supersetAccumulated.putIfAbsent(exI, () => []);
      _supersetAccumulated[exI]!.add(entry);

      // Trova confini del gruppo
      int groupStart = exI;
      while (groupStart > 0 &&
          widget.day.exercises[groupStart - 1].supersetGroup == currentGroup) {
        groupStart--;
      }
      int groupEnd = exI;
      while (groupEnd < widget.day.exercises.length - 1 &&
          widget.day.exercises[groupEnd + 1].supersetGroup == currentGroup) {
        groupEnd++;
      }

      int maxRounds = widget.day.exercises
          .sublist(groupStart, groupEnd + 1)
          .map((e) => e.targetSets)
          .reduce((a, b) => a > b ? a : b);
      int maxRecovery = widget.day.exercises
          .sublist(groupStart, groupEnd + 1)
          .map((e) => e.recoveryTime)
          .reduce((a, b) => a > b ? a : b);

      // Prossimo esercizio nel round corrente con ancora serie da fare (gestisce set diversi)
      int? nextExInRound;
      for (int i = exI + 1; i <= groupEnd; i++) {
        if (setN <= widget.day.exercises[i].targetSets) {
          nextExInRound = i;
          break;
        }
      }

      if (nextExInRound != null) {
        // Vai al prossimo esercizio nel round, senza riposo
        setState(() {
          exI = nextExInRound!;
          currentExSeries = List.from(_supersetAccumulated[exI] ?? []);
          _isNewRecord = false;
        });
        _setDrumValues(nextExInRound, setN);
      } else if (setN < maxRounds) {
        // Fine del round corrente, riposa e ricomincia al prossimo round
        final nextRound = setN + 1;
        // Trova il primo esercizio del prossimo round (skippa quelli con meno serie)
        int firstExNextRound = groupStart;
        for (int i = groupStart; i <= groupEnd; i++) {
          if (nextRound <= widget.day.exercises[i].targetSets) {
            firstExNextRound = i;
            break;
          }
        }
        setState(() {
          setN = nextRound;
          exI = firstExNextRound;
          currentExSeries = List.from(
            _supersetAccumulated[firstExNextRound] ?? [],
          );
          isRestingFullScreen = true;
          _isNewRecord = false;
        });
        _setDrumValues(firstExNextRound, nextRound);
        _avviaTimerSeNonAttivo(maxRecovery);
      } else {
        // Superserie/Circuito completato! Salva tutti gli esercizi del gruppo
        for (int i = groupStart; i <= groupEnd; i++) {
          final s = List<Map<String, dynamic>>.from(
            _supersetAccumulated[i] ?? [],
          );
          if (s.isNotEmpty) {
            _allCompletedExercises.add({
              'exercise': widget.day.exercises[i].name,
              'series': s,
            });
            widget.onDone({
              'exercise': widget.day.exercises[i].name,
              'series': s,
              'date': DateTime.now().toIso8601String(),
              'dayName': widget.day.dayName,
              'session_id': _sessionId,
            });
            if (!eserciziCompletati.contains(widget.day.exercises[i].name))
              eserciziCompletati.add(widget.day.exercises[i].name);
          }
        }
        _supersetAccumulated.clear();
        final bool tuttoFinito =
            eserciziCompletati.length == widget.day.exercises.length;
        if (tuttoFinito) {
          _bgTimer?.cancel();
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(
            _inProgressKey,
          ); // Cancella snapshot: permette di rifare l'allenamento
          final routineStr = prefs.getString('client_routine');
          if (routineStr != null) {
            List<dynamic> full = jsonDecode(routineStr);
            for (int i = 0; i < full.length; i++) {
              if (full[i]['dayName'] == widget.day.dayName)
                full[i] = widget.day.toJson();
            }
            await prefs.setString('client_routine', jsonEncode(full));
          }
          final newStreak = await updateStreakCliente(widget.day.dayName, widget.allSessionNames);
          final sData = await getStreakDataCliente();
          scheduleStreakReminderCliente(); // reset reminder: prossimo in 48h
          if (mounted) setState(() {
            _currentStreak = newStreak;
            _streakDoneCount = sData.done.length;
            _streakTotalCount = widget.allSessionNames.length;
            _streakDoneNames = sData.done;
          });
          if (mounted) _showRecapDialog();
          return; // Non salvare stato dopo workout completato
        } else if (groupEnd + 1 < widget.day.exercises.length) {
          final pause = widget.day.exercises[groupEnd].interExercisePause > 0
              ? widget.day.exercises[groupEnd].interExercisePause
              : 120;
          setState(() {
            exI = groupEnd + 1;
            setN = 1;
            currentExSeries = [];
            isRestingFullScreen = true;
            _isNewRecord = false;
          });
          _setDrumValues(groupEnd + 1, 1);
          _triggerTimer(pause, force: true); // fine gruppo superset: pausa inter-esercizio
        } else {}
      }
      _persistInProgress();
      return; // Fine branch superserie/circuito
    }

    // ========== ESERCIZIO NORMALE ==========
    currentExSeries.add(entry);

    if (setN < currentEx.targetSets) {
      setState(() {
        isRestingFullScreen = true;
        setN++;
      });
      _setDrumValues(exI, setN);
      _avviaTimerSeNonAttivo(currentEx.recoveryTime);
    } else {
      _allCompletedExercises.add({
        'exercise': currentEx.name,
        'series': List.from(currentExSeries),
      });
      widget.onDone({
        'exercise': currentEx.name,
        'series': List.from(currentExSeries),
        'date': DateTime.now().toIso8601String(),
        'dayName': widget.day.dayName,
        'session_id': _sessionId,
      });
      if (!eserciziCompletati.contains(currentEx.name)) {
        eserciziCompletati.add(currentEx.name);
      }

      final bool tuttoFinito =
          eserciziCompletati.length == widget.day.exercises.length;
      if (tuttoFinito) {
        if (_bgTimer != null) _bgTimer!.cancel();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(
          _inProgressKey,
        ); // Cancella snapshot: permette di rifare l'allenamento
        final routineStr = prefs.getString('client_routine');
        if (routineStr != null) {
          List<dynamic> full = jsonDecode(routineStr);
          for (int i = 0; i < full.length; i++) {
            if (full[i]['dayName'] == widget.day.dayName) {
              full[i] = widget.day.toJson();
            }
          }
          await prefs.setString('client_routine', jsonEncode(full));
        }
        final newStreak = await updateStreakCliente(widget.day.dayName, widget.allSessionNames);
        final sData = await getStreakDataCliente();
        scheduleStreakReminderCliente(); // reset reminder: prossimo in 48h
        if (mounted) setState(() {
          _currentStreak = newStreak;
          _streakDoneCount = sData.done.length;
          _streakTotalCount = widget.allSessionNames.length;
          _streakDoneNames = sData.done;
        });
        if (mounted) _showRecapDialog();
        return; // Non salvare stato dopo workout completato
      } else if (exI < widget.day.exercises.length - 1) {
        final pauseTime = currentEx.interExercisePause > 0
            ? currentEx.interExercisePause
            : 120;
        setState(() {
          isRestingFullScreen = true;
          exI++;
          setN = 1;
          currentExSeries = [];
          _isNewRecord = false;
        });
        _setDrumValues(exI, 1);
        _triggerTimer(pauseTime, force: true); // fine esercizio: sempre pausa inter-esercizio
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text(
              "Hai completato questo esercizio, ma ne mancano altri! Usa le frecce.",
            ),
          ),
        );
      }
    }
    _persistInProgress();
  }

  void _skipRest() {
    ++_notifGen; // previene notifica Future.delayed pendente
    _bgTimer?.cancel();
    try {
      if (!kIsWeb) flutterLocalNotificationsPlugin.cancelAll();
    } catch (_) {}
    setState(() {
      isRestingFullScreen = false;
      timerActive = false;
      _bgCounter = 0;
      _endTime = null;
    });
    try {
      WakelockPlus.disable();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // 1. DEFINIAMO L'ESERCIZIO ATTUALE
    var ex = widget.day.exercises[exI];

    void _cambiaEsercizio(int nuovoIndice) {
      setState(() {
        // Salviamo i progressi dell'esercizio che stiamo lasciando
        widget.day.exercises[exI].results = List.from(currentExSeries);

        exI = nuovoIndice;
        var nuovoEx = widget.day.exercises[exI];
        currentExSeries = List.from(nuovoEx.results);

        // Se l'esercizio è già stato completato, puntiamo all'ultima serie
        // altrimenti puntiamo alla serie successiva da fare
        if (eserciziCompletati.contains(nuovoEx.name)) {
          setN = nuovoEx.targetSets;
        } else {
          setN = currentExSeries.length + 1;
        }
      });
      _setDrumValues(nuovoIndice, setN);
    }

    Widget _buildBoxEsercizioCompletato() {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        margin: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF00FF88).withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.5)),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF00FF88), size: 50),
            const SizedBox(height: 15),
            const Text(
              "ESERCIZIO COMPLETATO",
              style: TextStyle(
                color: Color(0xFF00FF88),
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              "I dati sono stati salvati e non sono più modificabili.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // 2. CALCOLIAMO COSA FARE DOPO(Logica originale)
    if (setN <= ex.targetSets) {
      _infoProssimo =
          "${ex.name.toUpperCase()}\nSerie $setN di ${ex.targetSets}";
      _prossimoNome = ex.name;
    } else if (exI < widget.day.exercises.length - 1) {
      var prossimoEs = widget.day.exercises[exI + 1];
      _infoProssimo = "CAMBIO ESERCIZIO:\n${prossimoEs.name.toUpperCase()}";
      _prossimoNome = prossimoEs.name;
    } else {
      _infoProssimo = "ALLENAMENTO COMPLETATO!";
      _prossimoNome = '';
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

    bool isLastSet = (setN >= ex.targetSets);
    int timeToUse = isLastSet
        ? (ex.interExercisePause > 0 ? ex.interExercisePause : 120)
        : (ex.recoveryTime > 0 ? ex.recoveryTime : 60);
    final Color accent = Theme.of(context).colorScheme.primary;

    // CONTROLLO CRUCIALE: L'esercizio attuale è nella lista dei completati?
    bool giaFatto = eserciziCompletati.contains(ex.name);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        bool conferma = await _mostraDialogConfermaUscita();
        if (conferma && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // FRECCIA SINISTRA
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: exI > 0 ? () => _cambiaEsercizio(exI - 1) : null,
              ),

              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ex.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                            : Theme.of(context).colorScheme.primary.withAlpha(
                                180,
                              ), // Azzurrino mentre procedi
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
                    ? () => _cambiaEsercizio(exI + 1)
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
          actions: const [],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _triggerTimer(timeToUse, force: false),
          child: Column(
            children: [
              // Compact badges row (only if needed)
              if (ex.supersetGroup > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (ex.supersetGroup > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.link,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'SUPERSERIE ${ex.supersetGroup}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

              // Info panel: ultima volta + notes
              _buildInfoPanel(ex, lastW, lastR, suggerisciAumento, accent, timeToUse),

              // Drums or completed box
              if (giaFatto)
                Expanded(child: Center(child: _buildBoxEsercizioCompletato()))
              else
                Expanded(
                  child: _DrumPickers(
                    key: ValueKey('drum_${exI}_$setN'),
                    initialKg: lastW <= 0 ? 20.0 : lastW,
                    initialReps: targetR,
                    suggerisciAumento:
                        suggerisciAumento && _showWeightSuggestion,
                    accent: accent,
                    onKgChanged: (v) {
                      wC.text = v % 1 == 0
                          ? v.toInt().toString()
                          : v.toStringAsFixed(1);
                    },
                    onRepsChanged: (v) {
                      rC.text = v.toString();
                    },
                    onInteraction: () => _avviaTimerSeNonAttivo(timeToUse),
                  ),
                ),

              // Fixed CONFERMA SERIE
              if (!giaFatto)
                Container(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    12,
                    24,
                    MediaQuery.of(context).padding.bottom + 16,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1C1C1E),
                    border: Border(
                      top: BorderSide(color: Colors.white12, width: 1),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _confermaSerie,
                      child: const Text("CONFERMA SERIE"),
                    ),
                  ),
                ),
            ],
          ),
        ), // closes GestureDetector (body)
      ), // closes Scaffold
    ); // chiude PopScope
  }

  void _setDrumValues(int targetExI, int targetSetN) {
    if (targetExI >= widget.day.exercises.length) return;
    final ex = widget.day.exercises[targetExI];
    final suggest = _getSuggest(ex.name, targetSetN);
    final double kg = (suggest['w'] as num?)?.toDouble() ?? 0.0;
    int tR = ex.repsList.isNotEmpty
        ? (targetSetN <= ex.repsList.length
              ? ex.repsList[targetSetN - 1]
              : ex.repsList.last)
        : 10;
    wC.text = kg % 1 == 0 ? kg.toInt().toString() : kg.toStringAsFixed(1);
    rC.text = tR.toString();
  }

  void _showNewRecordOverlay() {
    HapticFeedback.heavyImpact();
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _RecordOverlay(
        lang: 'it',
        onDone: () { if (entry.mounted) entry.remove(); },
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (entry.mounted) entry.remove();
    });
  }

  Widget _buildInfoPanel(
    ExerciseConfig ex,
    double lastW,
    int lastR,
    bool suggerisciAumento,
    Color accent,
    int timeToUse,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lastW > 0)
            Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  color: Colors.white38,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'ULTIMA VOLTA: ${lastW % 1 == 0 ? lastW.toInt() : lastW} kg × $lastR reps',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),
                if (suggerisciAumento && _showWeightSuggestion) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(30),
                      border: Border.all(color: Colors.amber),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.trending_up_rounded,
                          color: Colors.amber,
                          size: 13,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'AUMENTA',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          if (ex.notePT.isNotEmpty) ...[
            if (lastW > 0) const Divider(color: Colors.white10, height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 14,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'COACH: ${ex.notePT}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const Divider(color: Colors.white10, height: 10),
          TextField(
            style: const TextStyle(fontSize: 12, color: Colors.white54),
            decoration: const InputDecoration(
              hintText: 'Le mie note...',
              hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
              prefixIcon: Icon(
                Icons.edit_note,
                size: 16,
                color: Colors.white24,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            controller: _noteControllers.putIfAbsent(
              ex.name,
              () => TextEditingController(text: ex.noteCliente),
            ),
            onChanged: (v) {
              ex.noteCliente = v;
              _aggiornaJsonSuDisco();
              _avviaTimerSeNonAttivo(timeToUse > 0 ? timeToUse : 60);
            },
          ),
        ],
      ),
    );
  }

  void _showCatalogDetail(String exName, {String? gifFilename}) {
    if (exName.isEmpty) return;
    final accent = Theme.of(context).colorScheme.primary;
    // Se c'è una GIF assegnata, le info seguono la GIF (muscoli/esecuzione dalla GIF)
    // Solo se la GIF non ha info si fa fallback sul nome
    final info = (gifFilename != null ? findByGifSlug(gifFilename) : null) ??
        findAnyExercise(exName);
    final gifPath = gifFilename != null
        ? 'assets/gif/$gifFilename.gif'
        : info != null ? 'assets/gif/${info.gifSlug}.gif' : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E10),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 3,
                  height: 22,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    exName.toUpperCase(),
                    style: TextStyle(
                      color: accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            if (info != null) ...[
              const SizedBox(height: 4),
              Text(
                info.nameEn,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              // GIF esercizio
              if (gifPath != null)
                Image.asset(
                  gifPath,
                  width: 280,
                  height: 280,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.fitness_center,
                    size: 80,
                    color: Colors.white30,
                  ),
                ),
              const SizedBox(height: 16),
              if (info.muscleImages.isNotEmpty) ...[
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: info.muscleImages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/muscle/${info.muscleImages[i]}',
                        width: 100,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.fitness_center_rounded, size: 16, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MUSCOLO PRINCIPALE',
                            style: TextStyle(
                              color: accent.withAlpha(180),
                              fontSize: 10,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            info.primaryMuscle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 ESECUZIONE',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      info.execution,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 CONSIGLI',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      info.tips,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Esercizio non in catalogo.',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestUI() {
    var ex = widget.day.exercises[exI];
    var suggest = _getSuggest(ex.name, setN);
    double lastW = (suggest['w'] as num?)?.toDouble() ?? 0.0;
    int lastR = (suggest['r'] as num?)?.toInt() ?? 0;

    int targetR = ex.repsList.isNotEmpty
        ? (setN <= ex.repsList.length
              ? ex.repsList[setN - 1]
              : ex.repsList.last)
        : 10;
    bool suggerisciAumento = lastR > targetR && lastR > 0;

    // GIF del prossimo esercizio
    ExerciseConfig? prossimoConfig;
    if (_prossimoNome.isNotEmpty) {
      try {
        prossimoConfig = widget.day.exercises.firstWhere(
          (e) => e.name == _prossimoNome,
        );
      } catch (_) {}
    }
    final prossimoInfo = _prossimoNome.isNotEmpty
        ? ((prossimoConfig?.gifFilename != null
                ? findByGifSlug(prossimoConfig!.gifFilename!)
                : null) ??
            findAnyExercise(_prossimoNome))
        : null;
    final prossimoGifPath = prossimoConfig?.gifFilename != null
        ? 'assets/gif/${prossimoConfig!.gifFilename}.gif'
        : prossimoInfo != null
            ? 'assets/gif/${prossimoInfo.gifSlug}.gif'
            : null;

    final accent = Theme.of(context).colorScheme.primary;
    final progress = timerActive
        ? (_bgCounter / _maxTime).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'REST',
              style: TextStyle(
                color: Colors.white.withAlpha(80),
                fontSize: 12,
                letterSpacing: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),

            // ── METÀ SUPERIORE: ring adattivo ──────────────────────────
            Expanded(
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  // Il ring occupa l'85% dell'altezza disponibile (max 320)
                  final ringSize =
                      (constraints.maxHeight * 0.85).clamp(80.0, 320.0);
                  return Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: ringSize,
                          height: ringSize,
                          child: CustomPaint(
                            painter: _RestRingPainter(
                              progress: progress,
                              color: accent,
                            ),
                          ),
                        ),
                        Text(
                          '$_bgCounter',
                          style: TextStyle(
                            fontSize: ringSize * 0.38,
                            fontWeight: FontWeight.w100,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── METÀ INFERIORE: suggerimenti + skip ────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Card prossimo esercizio
                    GestureDetector(
                      onTap: _prossimoNome.isNotEmpty
                          ? () => _showCatalogDetail(
                                _prossimoNome,
                                gifFilename: prossimoConfig?.gifFilename,
                              )
                          : null,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _prossimoNome.isNotEmpty
                                ? accent.withAlpha(60)
                                : Colors.white10,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'PROSSIMA',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(70),
                                    fontSize: 15,
                                    letterSpacing: 4,
                                  ),
                                ),
                                if (_prossimoNome.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.play_circle_outline_rounded,
                                    color: accent.withAlpha(150),
                                    size: 16,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            // GIF sinistra + info destra
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (prossimoGifPath != null) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.asset(
                                      prossimoGifPath,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _infoProssimo,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 3,
                                        style: TextStyle(
                                          color: accent.withAlpha(210),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (lastW > 0) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.history_rounded,
                                              color: Colors.white.withAlpha(70),
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${lastW}kg × ${lastR} reps',
                                              style: TextStyle(
                                                color: Colors.white.withAlpha(160),
                                                fontSize: 14,
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (suggerisciAumento) const _AumentaPesoWidget(),
                    // SKIP
                    GestureDetector(
                      onTap: _skipRest,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 60,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withAlpha(40),
                          ),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Text(
                          'SKIP',
                          style: TextStyle(
                            letterSpacing: 3,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Suggerisce peso/reps dalla SESSIONE PRECEDENTE (snapshot _previousResults
  // catturato a initState) — non dalla sessione corrente in corso.
  Map<String, dynamic> _getSuggest(String ex, int s) {
    try {
      final prevSeries = _previousResults[ex];
      if (prevSeries == null || prevSeries.isEmpty) {
        final carry = widget.carryoverWeights[ex];
        if (carry != null) return carry;
        return {'w': 0.0, 'r': 0};
      }
      final setData = s <= prevSeries.length ? prevSeries[s - 1] : prevSeries.last;
      final double weight =
          (setData['w'] ?? setData['weight'] ?? 0.0).toDouble();
      final int reps = (setData['r'] ?? setData['reps'] ?? 0).toInt();
      return {'w': weight, 'r': reps};
    } catch (e) {
      debugPrint("Errore suggerimenti: $e");
      return {'w': 0.0, 'r': 0};
    }
  }
}

class _RecordOverlay extends StatefulWidget {
  final String lang;
  final VoidCallback onDone;
  const _RecordOverlay({required this.lang, required this.onDone});
  @override
  State<_RecordOverlay> createState() => _RecordOverlayState();
}

class _RecordOverlayState extends State<_RecordOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _cardCtrl;
  late final AnimationController _sparkCtrl;
  late final Animation<double> _cardScale;
  late final Animation<double> _sparkAnim;

  static const List<String> _sparks = ['🎆', '✨', '🔥', '⭐', '💥', '🎇', '🏆', '💫'];
  static const List<Offset> _dirs = [
    Offset(-1.0, -1.2), Offset(0.0, -1.5), Offset(1.0, -1.2),
    Offset(-1.3, 0.0), Offset(1.3, 0.0),
    Offset(-0.8, 1.2), Offset(0.0, 1.5), Offset(0.8, 1.2),
  ];

  @override
  void initState() {
    super.initState();
    _cardCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _sparkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _cardScale = CurvedAnimation(parent: _cardCtrl, curve: Curves.elasticOut);
    _sparkAnim = CurvedAnimation(parent: _sparkCtrl, curve: Curves.easeOut);
    _cardCtrl.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _sparkCtrl.forward();
    });
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _sparkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = size.height * 0.4;
    return Stack(
      children: [
        ...List.generate(_sparks.length, (i) {
          final dir = _dirs[i % _dirs.length];
          return AnimatedBuilder(
            animation: _sparkAnim,
            builder: (_, __) {
              final t = _sparkAnim.value;
              final dx = dir.dx * 120 * t;
              final dy = dir.dy * 120 * t;
              final opacity = (1.0 - t).clamp(0.0, 1.0);
              return Positioned(
                left: cx + dx - 16,
                top: cy + dy - 16,
                child: Opacity(
                  opacity: opacity,
                  child: Text(_sparks[i], style: const TextStyle(fontSize: 24)),
                ),
              );
            },
          );
        }),
        Positioned(
          top: cy - 90,
          left: 24,
          right: 24,
          child: Material(
            color: Colors.transparent,
            child: ScaleTransition(
              scale: _cardScale,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.amber.withAlpha(120), blurRadius: 20, spreadRadius: 2)],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🏆', style: TextStyle(fontSize: 52)),
                    SizedBox(height: 8),
                    Text(
                      'NUOVO RECORD PERSONALE!',
                      style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '🚀 Continua così! 💪',
                      style: TextStyle(color: Colors.black87, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- BADGE ANIMATO AUMENTA IL PESO ---
class _AumentaPesoWidget extends StatefulWidget {
  const _AumentaPesoWidget();

  @override
  State<_AumentaPesoWidget> createState() => _AumentaPesoWidgetState();
}

class _AumentaPesoWidgetState extends State<_AumentaPesoWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;
  int _flashes = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _scale = Tween(
      begin: 1.0,
      end: 1.07,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _glow = Tween(
      begin: 0.0,
      end: 22.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    _ctrl.addStatusListener((status) {
      if (!mounted) return;
      if (status == AnimationStatus.completed) {
        _ctrl.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _flashes++;
        if (_flashes < 3) _ctrl.forward();
        // dopo 3 lampeggi rimane a valore 0 = aspetto normale
      }
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.amber.shade700,
                Colors.deepOrange.shade600,
                Colors.red.shade700,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _glow.value > 0
                ? [
                    BoxShadow(
                      color: Colors.amber.withAlpha(180),
                      blurRadius: _glow.value,
                      spreadRadius: _glow.value / 5,
                    ),
                    BoxShadow(
                      color: Colors.red.withAlpha(100),
                      blurRadius: _glow.value * 1.6,
                      spreadRadius: _glow.value / 4,
                    ),
                  ]
                : [],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🔥', style: TextStyle(fontSize: 20)),
              SizedBox(width: 10),
              Text(
                'AUMENTA IL PESO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(width: 10),
              Text('🔥', style: TextStyle(fontSize: 20)),
            ],
          ),
        ),
      ),
    );
  }
}

// --- RING PAINTER TIMER ---
class _RestRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RestRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    const strokeW = 12.0;
    const startAngle = -scala.pi / 2;

    // Traccia di sfondo
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withAlpha(20)
        ..strokeWidth = strokeW
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;

    // Glow (arco allargato e sfocato)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * scala.pi * progress,
      false,
      Paint()
        ..color = color.withAlpha(60)
        ..strokeWidth = strokeW + 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Arco principale
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * scala.pi * progress,
      false,
      Paint()
        ..color = color
        ..strokeWidth = strokeW
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RestRingPainter old) =>
      old.progress != progress || old.color != color;
}

// --- GRAFICO ANDAMENTO ALLENAMENTO (una linea, per sessione) ---
class _DrumPickers extends StatefulWidget {
  final double initialKg;
  final int initialReps;
  final bool suggerisciAumento;
  final Color accent;
  final ValueChanged<double> onKgChanged;
  final ValueChanged<int> onRepsChanged;
  final VoidCallback onInteraction; // chiamato ad ogni scroll

  const _DrumPickers({
    super.key,
    required this.initialKg,
    required this.initialReps,
    required this.suggerisciAumento,
    required this.accent,
    required this.onKgChanged,
    required this.onRepsChanged,
    required this.onInteraction,
  });

  @override
  State<_DrumPickers> createState() => _DrumPickersState();
}

class _DrumPickersState extends State<_DrumPickers>
    with SingleTickerProviderStateMixin {
  // 0–100 kg a step di 2.5, poi 105–300 a step di 5 (valori >100 occupano meno spazio)
  static final List<double> _kgValues = [
    ...List.generate(41, (i) => i * 2.5),        // 0, 2.5, 5, … 100  (indici 0-40)
    ...List.generate(40, (i) => 105.0 + i * 5.0), // 105, 110, … 300  (indici 41-80)
  ];
  static final List<int> _repsValues = List.generate(50, (i) => i + 1);

  // Mappa un peso (kg) all'indice in _kgValues
  static int _kgToIndex(double kg) {
    if (kg <= 100) return (kg / 2.5).round().clamp(0, 40);
    return (40 + ((kg - 100) / 5).round()).clamp(0, 80);
  }

  late FixedExtentScrollController _kgCtrl;
  late FixedExtentScrollController _repsCtrl;
  late int _selKg;
  late int _selReps;
  bool _interacted = false;

  // Animazione freccia suggerimento aumento peso
  late AnimationController _arrowCtrl;
  late Animation<double> _arrowAnim;

  @override
  void initState() {
    super.initState();
    _selKg = _kgToIndex(widget.initialKg);
    _selReps = (widget.initialReps - 1).clamp(0, 49);
    _kgCtrl = FixedExtentScrollController(initialItem: _selKg);
    _repsCtrl = FixedExtentScrollController(initialItem: _selReps);

    _arrowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _arrowAnim = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _arrowCtrl, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onKgChanged(_kgValues[_selKg]);
      widget.onRepsChanged(_repsValues[_selReps]);
    });
  }

  @override
  void dispose() {
    _arrowCtrl.dispose();
    _kgCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  void _triggerInteraction() {
    _interacted = true;
    widget.onInteraction();
  }

  void _editValue({required bool isKg}) {
    final textCtrl = TextEditingController(
      text: isKg
          ? (_kgValues[_selKg] % 1 == 0
                ? _kgValues[_selKg].toInt().toString()
                : _kgValues[_selKg].toStringAsFixed(1))
          : _repsValues[_selReps].toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        title: Text(
          isKg ? 'Inserisci KG' : 'Inserisci REPS',
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white, fontSize: 28),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: widget.accent),
            ),
          ),
          onSubmitted: (_) {
            Navigator.pop(ctx);
            _applyTextInput(textCtrl.text, isKg: isKg);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Annulla',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _applyTextInput(textCtrl.text, isKg: isKg);
            },
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyTextInput(String raw, {required bool isKg}) {
    if (isKg) {
      final v = double.tryParse(raw.replaceAll(',', '.'));
      if (v == null) return;
      int best = 0;
      double bestDiff = double.infinity;
      for (int i = 0; i < _kgValues.length; i++) {
        final diff = (_kgValues[i] - v).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          best = i;
        }
      }
      setState(() => _selKg = best);
      _kgCtrl.animateToItem(
        best,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      widget.onKgChanged(_kgValues[best]);
    } else {
      final v = int.tryParse(raw);
      if (v == null) return;
      final idx = (v - 1).clamp(0, 49);
      setState(() => _selReps = idx);
      _repsCtrl.animateToItem(
        idx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      widget.onRepsChanged(_repsValues[idx]);
    }
  }

  Widget _buildDrum({
    required FixedExtentScrollController ctrl,
    required List items,
    required int selectedIdx,
    required String label,
    required Function(int) onChanged,
    required String Function(dynamic) formatter,
    required bool highlightAbove,
    required double referenceKg,
    required bool isKg,
  }) {
    final accent = widget.accent;
    // Rimbalzo quando il peso NON è ancora stato aumentato (invita a salire)
    final bool showNudge = isKg && highlightAbove &&
        selectedIdx < items.length &&
        (items[selectedIdx] as double) <= referenceKg;

    // Dimensioni e opacità basate sulla distanza dal centro
    double _itemSize(int dist) {
      switch (dist) {
        case 0: return 82;
        case 1: return 54;
        case 2: return 38;
        default: return 26;
      }
    }
    int _itemAlpha(int dist) {
      switch (dist) {
        case 0: return 255;
        case 1: return 160;
        case 2: return 100;
        default: return 55;
      }
    }
    FontWeight _itemWeight(int dist) {
      switch (dist) {
        case 0: return FontWeight.w700;
        case 1: return FontWeight.w500;
        default: return FontWeight.w300;
      }
    }

    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 22,
            letterSpacing: 4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: AnimatedBuilder(
            animation: _arrowAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, showNudge ? _arrowAnim.value : 0),
              child: child,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Linee di selezione
                IgnorePointer(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 1.5,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        color: accent.withAlpha(130),
                      ),
                      const SizedBox(height: 96),
                      Container(
                        height: 1.5,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: accent.withAlpha(130),
                    ),
                  ],
                ),
              ),
              // Scroller
              ListWheelScrollView.useDelegate(
                controller: ctrl,
                itemExtent: 96,
                diameterRatio: 1.2,
                perspective: 0.003,
                squeeze: 0.85,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (i) {
                  setState(() {
                    if (isKg) _selKg = i;
                    else _selReps = i;
                  });
                  onChanged(i);
                  _triggerInteraction();
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: items.length,
                  builder: (ctx, i) {
                    final dist = (i - selectedIdx).abs();
                    final isSel = dist == 0;
                    final isAmber = isKg && highlightAbove && isSel &&
                        (items[i] as double) > referenceKg;
                    final color = isSel
                        ? (isAmber ? Colors.amber : accent)
                        : Colors.white.withAlpha(_itemAlpha(dist));
                    final textWidget = Text(
                      formatter(items[i]),
                      style: TextStyle(
                        fontSize: _itemSize(dist),
                        height: 1.0,
                        color: color,
                        fontWeight: _itemWeight(dist),
                        letterSpacing: isSel ? 1 : 0,
                      ),
                    );
                    return Center(
                      child: isSel
                          ? GestureDetector(
                              onTap: () => _editValue(isKg: isKg),
                              child: textWidget,
                            )
                          : textWidget,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildDrum(
              ctrl: _kgCtrl,
              items: _kgValues,
              selectedIdx: _selKg,
              label: 'KG',
              onChanged: (i) => widget.onKgChanged(_kgValues[i]),
              formatter: (v) {
                final d = v as double;
                return d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(1);
              },
              highlightAbove: widget.suggerisciAumento,
              referenceKg: widget.initialKg,
              isKg: true,
            ),
          ),
          Container(
            width: 1,
            color: Colors.white10,
            margin: const EdgeInsets.symmetric(vertical: 40),
          ),
          Expanded(
            child: _buildDrum(
              ctrl: _repsCtrl,
              items: _repsValues,
              selectedIdx: _selReps,
              label: 'REPS',
              onChanged: (i) => widget.onRepsChanged(_repsValues[i]),
              formatter: (v) => v.toString(),
              highlightAbove: false,
              referenceKg: 0,
              isKg: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutProgressChart extends StatelessWidget {
  final WorkoutDay day;
  final List<dynamic> history;
  final Color accent;
  const _WorkoutProgressChart({
    required this.day,
    required this.history,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final exerciseNames = day.exercises.map((e) => e.name).toSet();

    // Raggruppa la history per session_id (o data se manca) per separare
    // più sessioni nello stesso giorno
    final Map<String, Map<String, double>> bySession = {};
    final Map<String, String> sessionDate = {}; // sessionKey → yyyy-MM-dd
    for (final h in history) {
      final exName = h['exercise'] as String? ?? '';
      if (!exerciseNames.contains(exName)) continue;
      final dateRaw = h['date'] as String? ?? '';
      if (dateRaw.isEmpty) continue;
      final dateOnly = dateRaw.substring(0, 10);
      // Usa session_id se disponibile, altrimenti fallback su data
      final sessionKey =
          (h['session_id'] as String?)?.isNotEmpty == true
              ? h['session_id'] as String
              : dateOnly;
      sessionDate.putIfAbsent(sessionKey, () => dateOnly);
      final series = h['series'] as List? ?? [];
      double maxEst1RM = 0;
      for (final s in series) {
        final w = (s['w'] ?? 0.0).toDouble();
        final r = (s['r'] ?? 0).toDouble();
        final est1RM = r > 0 ? w * (1 + r / 30.0) : w;
        if (est1RM > maxEst1RM) maxEst1RM = est1RM;
      }
      bySession.putIfAbsent(sessionKey, () => {})[exName] = maxEst1RM;
    }

    if (bySession.isEmpty) {
      return const Center(
        child: Text(
          'Nessun dato registrato',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    // Ordina per data
    final sessions = bySession.keys.toList()
      ..sort((a, b) => (sessionDate[a] ?? a).compareTo(sessionDate[b] ?? b));
    final scores = sessions
        .map((s) => bySession[s]!.values.fold(0.0, (a, b) => a + b))
        .toList();

    // Costruisce etichette: se più sessioni stessa data aggiunge (1),(2)...
    final Map<String, int> dateTotal = {};
    for (final s in sessions) {
      final d = sessionDate[s] ?? '';
      dateTotal[d] = (dateTotal[d] ?? 0) + 1;
    }
    final Map<String, int> dateCounter = {};
    final labels = sessions.map((s) {
      final d = sessionDate[s] ?? s;
      final dd = d.length >= 10 ? '${d.substring(8, 10)}/${d.substring(5, 7)}' : d;
      if ((dateTotal[d] ?? 1) > 1) {
        dateCounter[d] = (dateCounter[d] ?? 0) + 1;
        return '$dd(${dateCounter[d]})';
      }
      return dd;
    }).toList();

    final minS = scores.reduce((a, b) => a < b ? a : b);
    final maxS = scores.reduce((a, b) => a > b ? a : b);

    return CustomPaint(
      painter: _WorkoutProgressPainter(
        labels: labels,
        scores: scores,
        minS: minS,
        maxS: maxS,
        accent: accent,
      ),
    );
  }
}

class _WorkoutProgressPainter extends CustomPainter {
  final List<String> labels;
  final List<double> scores;
  final double minS, maxS;
  final Color accent;
  _WorkoutProgressPainter({
    required this.labels,
    required this.scores,
    required this.minS,
    required this.maxS,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty) return;

    final double range = (maxS - minS).abs();
    final bool flat = range < 1.0;

    // Assi
    final axisPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      axisPaint,
    );

    // Linea gradiente
    final linePaint = Paint()
      ..color = accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;
    final dotBg = Paint()
      ..color = const Color(0xFF0E0E10)
      ..style = PaintingStyle.fill;

    final path = Path();
    final n = labels.length;

    for (int i = 0; i < n; i++) {
      final x = n == 1 ? size.width / 2 : size.width / (n - 1) * i;
      final norm = flat ? 0.5 : (scores[i] - minS) / range;
      final y = size.height * 0.9 - (size.height * 0.8 * norm.clamp(0.0, 1.0));
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    canvas.drawPath(path, linePaint);

    // Punti + etichette
    for (int i = 0; i < n; i++) {
      final x = n == 1 ? size.width / 2 : size.width / (n - 1) * i;
      final norm = flat ? 0.5 : (scores[i] - minS) / range;
      final y = size.height * 0.9 - (size.height * 0.8 * norm.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 5, dotBg);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);

      if (n <= 8 || i % ((n / 6).ceil()) == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            (x - tp.width / 2).clamp(0, size.width - tp.width),
            size.height - 14,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WorkoutProgressPainter old) => true;
}

// --- GRAFICI ---

class PTGraphWidget extends StatelessWidget {
  final String exerciseName;
  final List<dynamic> history;

  const PTGraphWidget({
    super.key,
    required this.exerciseName,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> seriesColors = [
      Theme.of(context).colorScheme.primary,
      Colors.purpleAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.redAccent,
    ];
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

    // 2. Score = 1RM stimato (Epley) per serie → normalizzazione min-max per indice serie
    Map<int, double> minScore = {};
    Map<int, double> maxScore = {};
    for (var l in logs) {
      var series = l['series'] as List;
      for (int i = 0; i < series.length; i++) {
        double w = (series[i]['w'] ?? 0.0).toDouble();
        double r = (series[i]['r'] ?? 0.0).toDouble();
        double sc = w * (1 + r / 30.0); // Epley 1RM estimate
        minScore[i] = sc < (minScore[i] ?? sc) ? sc : (minScore[i] ?? sc);
        maxScore[i] = sc > (maxScore[i] ?? sc) ? sc : (maxScore[i] ?? sc);
      }
    }

    // 3. Applica normalizzazione score
    for (var l in logs) {
      var series = l['series'] as List;
      for (int i = 0; i < series.length; i++) {
        double w = (series[i]['w'] ?? 0.0).toDouble();
        double r = (series[i]['r'] ?? 0.0).toDouble();
        double sc = w * (1 + r / 30.0); // Epley 1RM estimate
        double lo = minScore[i] ?? 0;
        double hi = maxScore[i] ?? 1;
        double range = hi - lo;
        series[i]['s_norm'] = range > 0.5 ? (sc - lo) / range : 0.5;
        series[i]['s_min'] = lo;
        series[i]['s_max'] = hi;
      }
    }

    return Column(
      children: [
        const SizedBox(height: 10),
        Text(
          exerciseName.toUpperCase(),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
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
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
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

    int maxSets = 0;
    for (var log in logs) {
      if ((log['series'] as List).length > maxSets)
        maxSets = (log['series'] as List).length;
    }

    for (int sIdx = 0; sIdx < maxSets; sIdx++) {
      final color = colors[sIdx % colors.length];
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();
      bool first = true;

      for (int i = 0; i < logs.length; i++) {
        final sData = logs[i]['series'] as List;
        if (sIdx < sData.length) {
          double x = logs.length == 1
              ? size.width / 2
              : size.width / (logs.length - 1) * i;
          double sNorm = ((sData[sIdx]['s_norm'] ?? 0.5) as double).clamp(
            0.0,
            1.0,
          );
          double y = size.height * (1.0 - sNorm);
          if (first) {
            path.moveTo(x, y);
            first = false;
          } else
            path.lineTo(x, y);
          canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(old) => true;
}

// --- SCHERMATA GESTIONE DATI ---
class CancellazioneScreen extends StatefulWidget {
  final List<dynamic> history;
  final List<WorkoutDay> routine;
  final Future<void> Function(List<dynamic> newHistory) onSave;

  const CancellazioneScreen({
    super.key,
    required this.history,
    required this.onSave,
    this.routine = const [],
  });

  @override
  State<CancellazioneScreen> createState() => _CancellazioneScreenState();
}

class _CancellazioneScreenState extends State<CancellazioneScreen> {
  late List<dynamic> _history;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _history = List<dynamic>.from(widget.history);
  }

  Map<String, List<dynamic>> get _grouped {
    final Map<String, List<dynamic>> map = {};
    for (final h in _history) {
      final name = (h['exercise'] as String?) ?? '';
      if (name.isEmpty) continue;
      map.putIfAbsent(name, () => []).add(h);
    }
    return map;
  }

  /// Raggruppa lo storico per allenamento (dayName), rispettando l'ordine della scheda.
  List<MapEntry<String, Map<String, List<dynamic>>>> get _groupedByDay {
    // dayName → { exerciseName → [sessions] }
    final Map<String, Map<String, List<dynamic>>> byDay = {};

    // Inizializza i giorni nell'ordine della scheda
    for (final day in widget.routine) {
      byDay[day.dayName] = {};
    }

    for (final h in _history) {
      final exName = (h['exercise'] as String?) ?? '';
      if (exName.isEmpty) continue;
      final dayName = (h['dayName'] as String?) ?? '';

      // Trova il dayName dalla scheda se non presente nell'entry
      String resolvedDay = dayName;
      if (resolvedDay.isEmpty) {
        for (final day in widget.routine) {
          if (day.exercises.any((e) => e.name == exName)) {
            resolvedDay = day.dayName;
            break;
          }
        }
        if (resolvedDay.isEmpty) resolvedDay = 'Altro';
      }

      byDay.putIfAbsent(resolvedDay, () => {});
      byDay[resolvedDay]!.putIfAbsent(exName, () => []).add(h);
    }

    // Rimuovi giorni vuoti e restituisci come lista ordinata
    return byDay.entries
        .where((e) => e.value.isNotEmpty)
        .toList();
  }

  Future<void> _eliminaSelezionati() async {
    if (_selected.isEmpty) return;
    final toDelete = Set<String>.from(_selected);
    final filtered = _history
        .where((h) => !toDelete.contains(h['exercise']))
        .toList();
    await widget.onSave(filtered);
    if (!mounted) return;
    setState(() {
      _history = filtered;
      _selected.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dati eliminati'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> _resetTotale() async {
    final ok1 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Reset completo',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Eliminerà TUTTI i dati: scheda, storico e impostazioni.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'CONTINUA',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok1 != true || !mounted) return;
    final ok2 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Sei sicuro?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Operazione irreversibile.',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'CANCELLA TUTTO',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok2 != true || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _apriDettaglio(String exName, List<dynamic> sessions) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DettaglioEsercizioScreen(
          exerciseName: exName,
          sessions: sessions,
          onSave: (updatedSessions) async {
            final newHistory =
                _history.where((h) => h['exercise'] != exName).toList()
                  ..addAll(updatedSessions);
            await widget.onSave(newHistory);
            if (mounted) setState(() => _history = newHistory);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _groupedByDay;
    // Raccogliamo tutti gli esercizi per la selezione multipla
    final grouped = _grouped;

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.storage_rounded, color: Colors.redAccent, size: 20),
            SizedBox(width: 8),
            Text(
              'Gestione Dati',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: days.isEmpty
                ? Center(
                    child: Text(
                      'Nessuno storico presente',
                      style: TextStyle(
                        color: Colors.white.withAlpha(80),
                        fontSize: 15,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: days.length,
                    itemBuilder: (_, dayIdx) {
                      final dayName = days[dayIdx].key;
                      final exercises = days[dayIdx].value;
                      final exNames = exercises.keys.toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header giorno
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 16,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                Text(
                                  dayName.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(180),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Esercizi del giorno
                          ...exNames.map((exName) {
                            final sessions = exercises[exName]!;
                            final isSelected = _selected.contains(exName);
                            return GestureDetector(
                              onLongPress: () => setState(() {
                                _selected.clear();
                                _selected.add(exName);
                              }),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.redAccent.withAlpha(30)
                                      : Colors.white.withAlpha(8),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.redAccent.withAlpha(120)
                                        : Colors.white10,
                                  ),
                                ),
                                child: ListTile(
                                  onTap: () => _apriDettaglio(
                                    exName,
                                    grouped[exName] ?? sessions,
                                  ),
                                  leading: Checkbox(
                                    value: isSelected,
                                    activeColor: Colors.redAccent,
                                    checkColor: Colors.white,
                                    onChanged: (v) => setState(() {
                                      if (v == true)
                                        _selected.add(exName);
                                      else
                                        _selected.remove(exName);
                                    }),
                                  ),
                                  title: Text(
                                    exName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${sessions.length} session${sessions.length == 1 ? 'e' : 'i'}',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(100),
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.white24,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
          ),
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.delete_sweep_outlined,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Elimina selezionati (${_selected.length})',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _eliminaSelezionati,
                ),
              ),
            ),
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'RESET TOTALE',
              style: TextStyle(
                color: Colors.white.withAlpha(100),
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(
                  Icons.delete_forever_outlined,
                  color: Colors.redAccent,
                ),
                label: const Text(
                  'Reset completo dati',
                  style: TextStyle(color: Colors.redAccent),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _resetTotale,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- DETTAGLIO ESERCIZIO — modifica e cancella serie ---
class _DettaglioEsercizioScreen extends StatefulWidget {
  final String exerciseName;
  final List<dynamic> sessions;
  final Future<void> Function(List<dynamic> updated) onSave;

  const _DettaglioEsercizioScreen({
    required this.exerciseName,
    required this.sessions,
    required this.onSave,
  });

  @override
  State<_DettaglioEsercizioScreen> createState() =>
      _DettaglioEsercizioScreenState();
}

class _DettaglioEsercizioScreenState extends State<_DettaglioEsercizioScreen> {
  late List<dynamic> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = List<dynamic>.from(
      widget.sessions.map((s) => Map<String, dynamic>.from(s)),
    );
  }

  Future<void> _save() => widget.onSave(_sessions);

  void _eliminaSessione(int sIdx) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Elimina sessione?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tutti i dati di questa sessione verranno eliminati.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'ELIMINA',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _sessions.removeAt(sIdx));
    await _save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sessione eliminata'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _eliminaSerie(int sIdx, int serieIdx) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Elimina serie?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'ELIMINA',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      final series = List<dynamic>.from(_sessions[sIdx]['series'] ?? []);
      series.removeAt(serieIdx);
      _sessions[sIdx] = Map<String, dynamic>.from(_sessions[sIdx])
        ..['series'] = series;
    });
    await _save();
  }

  void _modificaSerie(int sIdx, int serieIdx) {
    final serie = (_sessions[sIdx]['series'] as List)[serieIdx] as Map;
    final wCtrl = TextEditingController(
      text: '${serie['w'] ?? serie['weight'] ?? ''}',
    );
    final rCtrl = TextEditingController(
      text: '${serie['r'] ?? serie['reps'] ?? ''}',
    );
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          'Serie ${serieIdx + 1}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Peso (kg)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Reps',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () async {
              final newW = double.tryParse(wCtrl.text) ?? 0.0;
              final newR = int.tryParse(rCtrl.text) ?? 0;
              setState(() {
                final series = List<dynamic>.from(
                  _sessions[sIdx]['series'] ?? [],
                );
                series[serieIdx] = {'w': newW, 'r': newR};
                _sessions[sIdx] = Map<String, dynamic>.from(_sessions[sIdx])
                  ..['series'] = series;
              });
              await _save();
              if (mounted) Navigator.pop(context);
            },
            child: const Text(
              'SALVA',
              style: TextStyle(color: Color(0xFF00F2FF)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.exerciseName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _sessions.isEmpty
          ? Center(
              child: Text(
                'Nessuna sessione',
                style: TextStyle(
                  color: Colors.white.withAlpha(80),
                  fontSize: 15,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _sessions.length,
              itemBuilder: (_, sIdx) {
                final session = _sessions[sIdx];
                final date = session['date'] as String? ?? '';
                final series = (session['series'] as List?) ?? [];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header sessione
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                date,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              tooltip: 'Elimina sessione',
                              onPressed: () => _eliminaSessione(sIdx),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      // Serie
                      ...series.asMap().entries.map((e) {
                        final idx = e.key;
                        final s = e.value as Map;
                        final w = s['w'] ?? s['weight'] ?? 0;
                        final r = s['r'] ?? s['reps'] ?? 0;
                        return ListTile(
                          dense: true,
                          title: Text(
                            'Serie ${idx + 1}:  ${w}kg × ${r} reps',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_rounded,
                                  color: Colors.white38,
                                  size: 18,
                                ),
                                onPressed: () => _modificaSerie(sIdx, idx),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                                onPressed: () => _eliminaSerie(sIdx, idx),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
