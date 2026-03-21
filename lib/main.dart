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
import 'package:app_links/app_links.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

// Se è WEB usa dart:html, se è APK usa il nostro stub finto
import 'html_stub.dart' if (dart.library.html) 'dart:html' as html;
// ignore: deprecated_member_use
import 'js_stub.dart' if (dart.library.js) 'dart:js' as js;

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
  // 0 = normale, 1+ = gruppo superserie (stessi numeri = stesso gruppo)
  int supersetGroup;
  List<Map<String, dynamic>> results = [];

  ExerciseConfig({
    required this.name,
    required this.targetSets,
    required this.repsList,
    required this.recoveryTime,
    this.interExercisePause = 120,
    this.notePT = "",
    this.noteCliente = "",
    this.supersetGroup = 0,
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
    );
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

class _ClientMainPageState extends State<ClientMainPage>
    with WidgetsBindingObserver {
  List<WorkoutDay> myRoutine = [];
  List<dynamic> history = [];
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _loadMainSettings();

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
      await prefs.setString('client_routine', jsonPulito);
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
      const Color(0xFF00F2FF),
      const Color(0xFF00E676),
      const Color(0xFFFFD740),
      const Color(0xFFFF6D00),
      const Color(0xFFEA80FC),
      const Color(0xFFFF4081),
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
                    Icons.delete_forever_outlined,
                    color: Colors.redAccent,
                  ),
                  label: const Text(
                    'Reset completo dati',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    final ok1 = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFF1C1C1E),
                        title: const Text(
                          'Reset completo',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          'Eliminerà TUTTI i dati: scheda, storico e impostazioni. Continuare?',
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
                        title: const Text(
                          'Sei sicuro?',
                          style: TextStyle(color: Colors.white),
                        ),
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
                    if (mounted) {
                      setState(() {
                        myRoutine = [];
                        history = [];
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tutti i dati eliminati'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
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
        title: const Text(
          "IMPORTA SCHEDA",
          style: TextStyle(color: Color(0xFF00F2FF), fontSize: 18),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share, size: 22),
            onPressed: _exportData,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 22),
            onPressed: _importNewRoutine,
          ),
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
                "${day.exercises.length} esercizi • ${day.exercises.fold(0, (s, ex) => s + ex.targetSets)} serie totali",
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
          onDone: (session) async {
            history.add(session);
            final prefs2 = await SharedPreferences.getInstance();
            await prefs2.setString('client_history', jsonEncode(history));
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
                                    d.dayName.toUpperCase(),
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
                                      Text(
                                        '${d.exercises.length} esercizi',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.repeat,
                                        size: 12,
                                        color: Colors.white38,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${d.exercises.fold(0, (s, ex) => s + ex.targetSets)} serie',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12,
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
  DateTime? _endTime;
  Timer? _bgTimer;
  bool isRestingFullScreen = false;
  bool timerActive = false;
  List<String> eserciziCompletati = [];
  final Map<String, TextEditingController> _noteControllers = {};
  List<Map<String, dynamic>> _allCompletedExercises = [];
  bool _isNewRecord = false;
  final Map<int, List<Map<String, dynamic>>> _supersetAccumulated = {};
  // Risultati sessione precedente: nome esercizio → lista serie {w, r}
  final Map<String, List<Map<String, dynamic>>> _previousResults = {};
  // Chiave persistenza allenamento in corso
  String get _inProgressKey => 'workout_in_progress_${widget.day.dayName}';
  // Suono fine timer
  bool _timerSoundEnabled = true;
  bool _vibrationEnabled = true;
  bool _wakelockEnabled = true;
  bool _autoStartTimer = true;
  bool _confirmSeriesEnabled = true;
  bool _showWeightSuggestion = true;

  @override
  void initState() {
    super.initState();
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
        title: const Text(
          'Riepilogo allenamento',
          style: TextStyle(
            color: Color(0xFF00F2FF),
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
            child: const Text(
              'CHIUDI',
              style: TextStyle(color: Color(0xFF00F2FF)),
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
          perfColor = const Color(0xFF00F2FF);
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
                style: const TextStyle(
                  color: Color(0xFF00F2FF),
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
          content: Column(
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
              const SizedBox(height: 4),
              Text(
                widget.day.dayName,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00F2FF),
                  side: const BorderSide(color: Color(0xFF00F2FF)),
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
                  backgroundColor: const Color(0xFF00F2FF),
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
        Text(label, style: const TextStyle(color: Colors.white60)),
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

    // 2. Programmiamo la notifica
    _programmaNotificaFine(sec);
    if (!kIsWeb) {
      _programmaNotificaFine(sec);
    }

    // 3. Timer visivo
    _bgTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_endTime == null) {
        t.cancel();
        return;
      }

      final remaining = _endTime!.difference(DateTime.now()).inSeconds;

      if (remaining <= 0) {
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
      }
    });
  }

  // Suono di avviso tramite ToneGenerator nativo Android (stream ALARM, si sovrappone alla musica)
  Future<void> _playBeep() async {
    if (kIsWeb) return;
    try {
      // ♪ bip bip BIP: breve, breve, lungo
      await _gymFileChannel.invokeMethod('playBeep', 250);
      await Future.delayed(const Duration(milliseconds: 380));
      await _gymFileChannel.invokeMethod('playBeep', 250);
      await Future.delayed(const Duration(milliseconds: 380));
      await _gymFileChannel.invokeMethod('playBeep', 550);
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
                _chipConferma("$r reps", const Color(0xFF00F2FF)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
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

    // Controlla record personale
    final exHistory = widget.history
        .where((h) => h['exercise'] == currentEx.name)
        .toList();
    double maxPast = 0;
    for (final h in exHistory) {
      for (final s in (h['series'] as List)) {
        final sw = (s['w'] as num).toDouble();
        if (sw > maxPast) maxPast = sw;
      }
    }
    setState(() => _isNewRecord = maxPast > 0 && w > maxPast);

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
          wC.clear();
          rC.clear();
        });
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
          wC.clear();
          rC.clear();
        });
        _triggerTimer(maxRecovery);
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
          await prefs.remove(_inProgressKey); // Cancella snapshot: permette di rifare l'allenamento
          final routineStr = prefs.getString('client_routine');
          if (routineStr != null) {
            List<dynamic> full = jsonDecode(routineStr);
            for (int i = 0; i < full.length; i++) {
              if (full[i]['dayName'] == widget.day.dayName)
                full[i] = widget.day.toJson();
            }
            await prefs.setString('client_routine', jsonEncode(full));
          }
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
            wC.clear();
            rC.clear();
          });
          _triggerTimer(pause);
        } else {
          setState(() {
            wC.clear();
            rC.clear();
          });
        }
      }
      return; // Fine branch superserie/circuito
    }

    // ========== ESERCIZIO NORMALE ==========
    currentExSeries.add(entry);

    if (setN < currentEx.targetSets) {
      setState(() {
        isRestingFullScreen = true;
        setN++;
        wC.clear();
        rC.clear();
      });
      _triggerTimer(currentEx.recoveryTime);
    } else {
      _allCompletedExercises.add({
        'exercise': currentEx.name,
        'series': List.from(currentExSeries),
      });
      widget.onDone({
        'exercise': currentEx.name,
        'series': List.from(currentExSeries),
        'date': DateTime.now().toIso8601String(),
      });
      if (!eserciziCompletati.contains(currentEx.name)) {
        eserciziCompletati.add(currentEx.name);
      }

      final bool tuttoFinito =
          eserciziCompletati.length == widget.day.exercises.length;
      if (tuttoFinito) {
        if (_bgTimer != null) _bgTimer!.cancel();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_inProgressKey); // Cancella snapshot: permette di rifare l'allenamento
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
          wC.clear();
          rC.clear();
        });
        _triggerTimer(pauseTime);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text(
              "Hai completato questo esercizio, ma ne mancano altri! Usa le frecce.",
            ),
          ),
        );
        setState(() {
          wC.clear();
          rC.clear();
        });
      }
    }
    _persistInProgress();
  }

  void _skipRest() {
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

        wC.clear();
        rC.clear();
      });
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

    Widget _buildInputWorkoutSection(
      var ex,
      double lastW,
      int lastR,
      int targetR,
      bool suggerisciAumento,
    ) {
      return Column(
        children: [
          // Sposta qui i tuoi selettori KG, REPS e il tasto CONFERMA SERIE
          // ... (tutto il codice che avevi prima per gli input)
        ],
      );
    }

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

              // Badge nuovo record personale
              if (_isNewRecord)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events, color: Colors.black, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'NUOVO RECORD! 🔥',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

              // Badge superserie
              if (ex.supersetGroup > 0)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.link, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'SUPERSERIE – gruppo ${ex.supersetGroup}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

              // --- SEZIONE INPUT DINAMICA ---
              if (giaFatto)
                _buildBoxEsercizioCompletato() // Widget per mostrare che è finito
              else
                _buildInputWorkoutSection(
                  ex,
                  lastW,
                  lastR,
                  targetR,
                  suggerisciAumento,
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
                controller: _noteControllers.putIfAbsent(
                  ex.name,
                  () => TextEditingController(text: ex.noteCliente),
                ),
                onChanged: (v) {
                  ex.noteCliente = v;
                  _aggiornaJsonSuDisco();
                },
              ),

              // --- FINE CODICE NOTE ---
              // --- BOX INFO SCORSA VOLTA ---
              const SizedBox(height: 10),
              if (lastW > 0)
                Text(
                  "ULTIMA VOLTA: $lastW kg x $lastR REPS ${(suggerisciAumento && _showWeightSuggestion) ? '\nAUMENTA IL PESO🔥' : ''}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: (suggerisciAumento && _showWeightSuggestion)
                        ? Colors.amber
                        : Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),

              const SizedBox(height: 20),
              _buildInputSection(
                "KG",
                wC,
                [lastW - 5.0, lastW - 2.5, lastW, lastW + 2.5, lastW + 5.0],
                ex,
                referenceWeight: lastW, // Passiamo il peso di riferimento
                highlights:
                    suggerisciAumento &&
                    _showWeightSuggestion, // solo se abilitato nelle impostazioni
              ),
              const SizedBox(height: 20),
              _buildInputSection("REPS", rC, [
                (targetR - 2).toDouble(),
                (targetR - 1).toDouble(),
                targetR.toDouble(),
                (targetR + 1).toDouble(),
                (targetR + 2).toDouble(),
              ], ex),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _confermaSerie,
                  child: const Text("CONFERMA SERIE"),
                ),
              ),
            ],
          ),
        ),
      ), // chiude Scaffold
    ); // chiude PopScope
  }

  Widget _buildInputSection(
    String label,
    TextEditingController ctrl,
    List<double> values,
    ExerciseConfig ex, {
    double? referenceWeight,
    bool highlights = false,
  }) {
    bool isLastSet = (setN >= ex.targetSets);
    int timeToUse = isLastSet ? ex.interExercisePause : ex.recoveryTime;
    if (timeToUse <= 0) timeToUse = 60;

    // 1. Calcolo dell'offset per centrare il terzo tab (indice 2)
    // Larghezza tab (70) + Padding (15) = 85 pixel a elemento.
    // Sottraiamo metà larghezza schermo per far finire il terzo tab al centro esatto.
    double screenWidth = MediaQuery.of(context).size.width;
    double tabWidth = 80.0; // Larghezza fissa del tab
    double spacing = 15.0; // Margine destro

    // L'offset per mettere il CENTRO del terzo tab al CENTRO dello schermo:
    // (Spazio occupato dai primi 2 tab) + (Metà del terzo tab) - (Metà schermo) + Padding iniziale(20)
    double centerOffset =
        (2 * (tabWidth + spacing)) + (tabWidth / 2) - (screenWidth / 2) + 20;

    final ScrollController scrollController = ScrollController(
      initialScrollOffset: values.length > 2 ? centerOffset : 0.0,
    );

    return Column(
      children: [
        // HEADER TIMER
        GestureDetector(
          onTap: () {
            if (timerActive) {
              _bgTimer?.cancel();
              setState(() {
                timerActive = false;
                _endTime = null;
                _bgCounter = 0;
              });
            } else {
              _triggerTimer(timeToUse, force: true);
            }
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),

        // LISTA SCORREVOLE
        SingleChildScrollView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: values.asMap().entries.map((entry) {
              int idx = entry.key;
              double v = entry.value;
              String valStr = v % 1 == 0
                  ? v.toInt().toString()
                  : v.toStringAsFixed(1);
              bool isSel = ctrl.text == valStr;
              bool isTarget = (idx == 2);
              bool isSuggested =
                  highlights && referenceWeight != null && v > referenceWeight;

              return Padding(
                padding: const EdgeInsets.only(right: 15.0),
                child: GestureDetector(
                  onTap: () {
                    setState(() => ctrl.text = valStr);
                    HapticFeedback.lightImpact();
                    _triggerTimer(timeToUse, force: false);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width:
                        tabWidth, // Larghezza fissa per precisione centratura
                    height: 70,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSel
                          ? const Color(0xFF00F2FF)
                          : (isSuggested
                                ? Colors.amber.withOpacity(0.15)
                                : const Color(0xFF1C1C1E)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel
                            ? Colors.transparent
                            : (isTarget
                                  ? const Color(0xFF00F2FF).withOpacity(0.5)
                                  : (isSuggested
                                        ? Colors.amber
                                        : Colors.white10)),
                        width: isTarget || isSuggested ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      valStr,
                      style: TextStyle(
                        fontSize: 25,
                        color: isSel
                            ? Colors.black
                            : (isSuggested ? Colors.amber : Colors.white),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // INPUT TESTO
        TextField(
          controller: ctrl,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
            fontSize: 50,
            fontWeight: FontWeight.w200,
            color: Color(0xFF00F2FF),
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: "0",
            hintStyle: TextStyle(color: Colors.white10),
          ),
          onChanged: (v) => setState(() {}),
          onTap: () {
            if (label == "REPS") {
              ctrl.clear();
              setState(() {});
            }
          },
          onSubmitted: (v) => _triggerTimer(timeToUse, force: false),
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

    int targetR = ex.repsList.isNotEmpty
        ? (setN <= ex.repsList.length
              ? ex.repsList[setN - 1]
              : ex.repsList.last)
        : 10;
    bool suggerisciAumento = lastR > targetR && lastR > 0;

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
                      "L'ULTIMA VOLTA (SERIE $setN)",
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

            if (suggerisciAumento)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      color: Colors.amber,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'AUMENTA IL PESO! 🔥',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

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

    // 2. Score = kg × reps per serie → normalizzazione min-max per indice serie
    Map<int, double> minScore = {};
    Map<int, double> maxScore = {};
    for (var l in logs) {
      var series = l['series'] as List;
      for (int i = 0; i < series.length; i++) {
        double w = (series[i]['w'] ?? 0.0).toDouble();
        double r = (series[i]['r'] ?? 0.0).toDouble();
        double sc = w * (1 + r / 30.0); // stima massimale (Epley)
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
        double sc = w * (1 + r / 30.0); // stima massimale (Epley)
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
          if (first) { path.moveTo(x, y); first = false; }
          else path.lineTo(x, y);
          canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(old) => true;
}
