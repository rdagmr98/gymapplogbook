import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart' as arc;
import 'package:flutter/cupertino.dart';
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
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
// Se è WEB usa dart:html, se è APK usa il nostro stub finto
import 'html_stub.dart' if (dart.library.html) 'dart:html' as html;
// ignore: deprecated_member_use
import 'js_stub.dart' if (dart.library.js) 'dart:js' as js;
import 'gif_exercise_catalog.dart';
import 'workout_tutorial.dart';

// Colore accento globale (tema)
/// Returns true if dark mode is active
bool _isDarkCtx(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;


final ValueNotifier<Color> appAccentNotifier = ValueNotifier<Color>(
  const Color(0xFF00F2FF),
);
final ValueNotifier<ThemeMode> appThemeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

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

class AppL {
  static String _lang = 'it';
  static void setLang(String lang) {} // Italian only
  static String get lang => _lang;

  static String _t(String key) {
    final m = _s[key];
    if (m == null) return key;
    return m['it'] ?? key;
  }

  static String tryReps(int n) => 'PROVA $n REPS';

  static const Map<String, Map<String, String>> _s = {
    'mySchedule': {'it': 'La mia scheda'},
    'noSchedule': {'it': 'Nessuna scheda'},
    'createSchedule': {'it': 'Crea la tua scheda'},
    'train': {'it': 'Allenati'},
    'progress': {'it': 'Progressi'},
    'settings': {'it': 'Impostazioni'},
    'deleteData': {'it': 'Cancella dati'},
    'day': {'it': 'Giorno'},
    'exercises': {'it': 'Esercizi'},
    'sets': {'it': 'Serie'},
    'reps': {'it': 'Ripetizioni'},
    'recovery': {'it': 'Recupero (s)'},
    'notes': {'it': 'Note'},
    'save': {'it': 'Salva'},
    'cancel': {'it': 'Annulla'},
    'add': {'it': 'Aggiungi'},
    'weight': {'it': 'Peso (kg)'},
    'weightUnit': {'it': 'Unita peso'},
    'usePounds': {'it': 'Usa libbre (lb)'},
    'startWorkout': {'it': 'Inizia Allenamento'},
    'proTrainer': {'it': 'Sei un Personal Trainer?'},
    'pause': {'it': 'Pausa tra esercizi (s)'},
    'browseArchive': {'it': 'Sfoglia archivio'},
    'repsPerSet': {'it': 'Reps per serie'},
    'muscleGroup': {'it': 'Gruppo muscolare'},
    'chooseExercise': {'it': 'Scegli esercizio'},
    'noScheduleYet': {'it': 'Nessun giorno ancora'},
    'addFirstDay': {'it': 'Premi + per aggiungere il primo giorno'},
    'deleteDay': {'it': 'Elimina giorno?'},
    'delete': {'it': 'ELIMINA'},
    'circuit': {'it': 'Superserie e circuito'},
    'circuitHint': {'it': 'Assegna lo stesso numero agli esercizi da fare in sequenza senza recupero. 0 = normale, 1/2/3 = gruppo superserie/circuito.'},
    'exerciseName': {'it': 'Nome esercizio'},
    'pauseSec': {'it': 'Pausa (s)'},
    'tapToChooseMuscle': {'it': 'Tocca per scegliere immagine muscolo'},
    'noScheduleMsg': {'it': 'Nessuna scheda.\nCrea il tuo primo allenamento!'},
    'history': {'it': 'Storico'},
    'workoutOf': {'it': 'Allenamento del'},
    'restTimer': {'it': 'Timer recupero'},
    'nextSet': {'it': 'Prossima serie'},
    'done': {'it': 'Fatto'},
    'skip': {'it': 'Salta'},
    'confirm': {'it': 'Conferma'},
    'workout': {'it': 'Allenamento'},
    'totalVolume': {'it': 'Volume totale'},
    'personalBest': {'it': 'Record personale'},
    'language': {'it': 'Lingua'},
    'italian': {'it': 'Italiano'},
    'english': {'it': 'Inglese'},
    'spanish': {'it': 'Spagnolo'},
    'portuguese': {'it': 'Portoghese'},
    'french': {'it': 'Francese'},
    'german': {'it': 'Tedesco'},
    'greek': {'it': 'Greco'},
    'arabic': {'it': 'Arabo'},
    'polish': {'it': 'Polacco'},
    'romanian': {'it': 'Rumeno'},
    'hungarian': {'it': 'Ungherese'},
    'accentColor': {'it': 'Colore accento'},
    'chooseLanguage': {'it': 'Scegli la tua lingua'},
    'continueBtn': {'it': 'Continua'},
    'welcomeTitle': {'it': 'Benvenuto in GymApp'},
    'setGroup': {'it': 'Gruppo'},
    'onboardingWelcomeText': {'it': 'La tua app per allenarsi in modo intelligente, ovunque tu sia.'},
    'onboardingScheduleTitle': {'it': 'Crea la tua scheda'},
    'onboardingScheduleText': {'it': 'Costruisci la tua routine personalizzata con esercizi dal nostro database di 1200+ movimenti con GIF animate.'},
    'onboardingTrainTitle': {'it': 'Allena e registra'},
    'onboardingTrainText': {'it': 'Segui ogni serie con timer automatico, registra pesi e ripetizioni, visualizza i tuoi progressi nel tempo.'},
    'onboardingProgressTitle': {'it': 'Monitora i progressi'},
    'onboardingProgressText': {'it': 'Grafici per ogni esercizio, storico delle sessioni e suggerimenti automatici per aumentare i carichi.'},
    'onboardingProText': {'it': 'Porta i tuoi clienti al livello successivo con l\'ecosistema completo: app PT per creare schede e monitorare tutti i tuoi atleti da un\'unica dashboard.'},
    'contactGianmarco': {'it': 'Contatta Gianmarco'},
    'proInfoText': {'it': 'Scrivi per info sull\'ecosistema GymApp Pro'},
    'startBtn': {'it': 'INIZIA'},
    'nextBtn': {'it': 'AVANTI'},
    'chooseMuscleImage': {'it': 'Immagine allenamento'},
    'noImage': {'it': 'Nessuna'},
    'promoText': {'it': 'Porta i tuoi clienti al livello successivo con l\'ecosistema GymApp Pro.'},
    'noScheduleLoaded': {'it': 'Nessuna scheda caricata'},
    'editOrCreate': {'it': 'Modifica o crea una nuova scheda'},
    'trainNow': {'it': 'ALLENATI ORA'},
    'train2': {'it': 'ALLENATI'},
    'chooseAndStart': {'it': 'Scegli e inizia il tuo allenamento'},
    'createFirstSchedule': {'it': 'Crea la tua scheda prima di allenarti'},
    'workoutProgress': {'it': 'ANDAMENTO ALLENAMENTO'},
    'neverTrained': {'it': 'Mai allenato'},
    'today': {'it': 'Oggi'},
    'yesterday': {'it': 'Ieri'},
    'daysAgo': {'it': 'giorni fa'},
    'others': {'it': 'altri'},
    'timerSound': {'it': 'Suono fine timer'},
    'timerVibration': {'it': 'Vibrazione fine timer'},
    'autoStartTimer': {'it': 'Avvia timer automaticamente'},
    'screenAlwaysOn': {'it': 'Schermo sempre acceso'},
    'confirmSeriesWindow': {'it': 'Finestra di conferma serie'},
    'weightSuggestion': {'it': 'Suggerimento aumento peso'},
    'dataManagement': {'it': 'Gestione Dati'},
    'insertKg': {'it': 'Inserisci KG'},
    'insertReps': {'it': 'Inserisci REPS'},
    'enterKgReps': {'it': 'Inserisci kg e reps prima di confermare'},
    'saveSeries': {'it': 'SALVA SERIE'},
    'confirmSeries': {'it': 'CONFERMA SERIE'},
    'quitWorkout': {'it': 'Interrompere?'},
    'quitWorkoutMsg': {'it': 'Vuoi davvero uscire dall\'allenamento? I progressi fin qui fatti sono comunque salvati.'},
    'exitAndSave': {'it': 'ESCI E SALVA'},
    'exerciseComplete': {'it': 'ESERCIZIO COMPLETATO'},
    'exerciseCompleteMsg': {'it': 'I dati sono stati salvati e non sono più modificabili.'},
    'nextInfo': {'it': 'PROSSIMA'},
    'lastTime': {'it': 'ULTIMA VOLTA'},
    'increaseWeight': {'it': 'AUMENTA PESO'},
    'increase': {'it': 'AUMENTA'},
    'workoutComplete': {'it': 'ALLENAMENTO COMPLETATO!'},
    'firstSession': {'it': 'Prima sessione!'},
    'improving': {'it': 'In miglioramento!'},
    'declining': {'it': 'In calo'},
    'plateau': {'it': 'Stallo'},
    'details': {'it': 'DETTAGLI'},
    'greatWork': {'it': 'OTTIMO LAVORO!'},
    'workoutSummary': {'it': 'Riepilogo allenamento'},
    'close': {'it': 'CHIUDI'},
    'totalSeries': {'it': 'Serie totali'},
    'exercisesLabel': {'it': 'Esercizi'},
    'primaryMuscle': {'it': 'MUSCOLO PRINCIPALE'},
    'secondaryMuscles': {'it': 'MUSCOLI SECONDARI'},
    'execution': {'it': '📋 ESECUZIONE'},
    'tips': {'it': '💡 CONSIGLI'},
    'notInCatalog': {'it': 'Esercizio non in catalogo.\nUsa YouTube per vedere la tecnica.'},
    'notInCatalogShort': {'it': 'Esercizio non in catalogo.'},
    'watchOnYoutube': {'it': 'Guarda su YouTube'},
    'progressOverTime': {'it': 'Progressi nel tempo — una linea per serie'},
    'noData': {'it': 'Nessun dato'},
    'noDataRegistered': {'it': 'Nessun dato registrato'},
    'myNotes': {'it': 'Le mie note...'},
    'coachNotes': {'it': 'COACH'},
    'setsDone': {'it': 'SERIE FATTE'},
    'of': {'it': 'DI'},
    'changeExercise': {'it': 'CAMBIO ESERCIZIO'},
    'noHistory': {'it': 'Nessuno storico presente'},
    'deleteSelected': {'it': 'Elimina selezionati'},
    'totalReset': {'it': 'RESET TOTALE'},
    'fullReset': {'it': 'Reset completo dati'},
    'fullResetTitle': {'it': 'Reset completo'},
    'fullResetMsg': {'it': 'Eliminerà TUTTI i dati: scheda, storico e impostazioni.'},
    'continueLabel': {'it': 'CONTINUA'},
    'areYouSure': {'it': 'Sei sicuro?'},
    'irreversible': {'it': 'Operazione irreversibile.'},
    'deleteAll': {'it': 'CANCELLA TUTTO'},
    'noSession': {'it': 'Nessuna sessione'},
    'deleteSession': {'it': 'Elimina sessione?'},
    'deleteSessionMsg': {'it': 'Tutti i dati di questa sessione verranno eliminati.'},
    'sessionDeleted': {'it': 'Sessione eliminata'},
    'deleteSeries': {'it': 'Elimina serie?'},
    'dataDeleted': {'it': 'Dati eliminati'},
    'skipUseButton': {'it': 'Usa il tasto \'SKIP\' per tornare all\'esercizio'},
    'restoreWorkout': {'it': '♻️ Allenamento precedente ripristinato'},
    'workoutNotDone': {'it': 'Hai completato questo esercizio, ma ne mancano altri! Usa le frecce.'},
    'proFeature1': {'it': '✅ Schede personalizzate per ogni atleta'},
    'proFeature2': {'it': '✅ Monitoraggio progressi in tempo reale'},
    'proFeature3': {'it': '✅ Database esercizi condiviso'},
    'proFeature4': {'it': '✅ Senza abbonamenti mensili'},
    'gymAppPro': {'it': 'GymApp Pro - Per PT'},
    'recoverySuffix': {'it': 's riposo'},
    'sessionCount': {'it': 'session'},
    'sessionCountPlural': {'it': 'sessioni'},
    'loadExample': {'it': 'Carica esempio'},
    'renameSession': {'it': 'Rinomina sessione'},
    'sessionName': {'it': 'Nome sessione'},
    'editExercise': {'it': 'Modifica esercizio'},
    'streakWeeks': {'it': 'Microcicli di fila'},
    'streakMsg': {'it': '🔥 Mantieni la tua streak!'},
    'newRecord': {'it': 'NUOVO RECORD!'},
  };

  static String get mySchedule => _t('mySchedule');
  static String get noSchedule => _t('noSchedule');
  static String get createSchedule => _t('createSchedule');
  static String get train => _t('train');
  static String get progress => _t('progress');
  static String get settings => _t('settings');
  static String get deleteData => _t('deleteData');
  static String get day => _t('day');
  static String get exercises => _t('exercises');
  static String get sets => _t('sets');
  static String get reps => _t('reps');
  static String get recovery => _t('recovery');
  static String get notes => _t('notes');
  static String get save => _t('save');
  static String get cancel => _t('cancel');
  static String get add => _t('add');
  static String get weight => _t('weight');
  static String get weightUnit => _t('weightUnit');
  static String get usePounds => _t('usePounds');
  static String get startWorkout => _t('startWorkout');
  static String get proTrainer => _t('proTrainer');
  static String get pause => _t('pause');
  static String get browseArchive => _t('browseArchive');
  static String get repsPerSet => _t('repsPerSet');
  static String get muscleGroup => _t('muscleGroup');
  static String get chooseExercise => _t('chooseExercise');
  static String get noScheduleYet => _t('noScheduleYet');
  static String get addFirstDay => _t('addFirstDay');
  static String get deleteDay => _t('deleteDay');
  static String get delete => _t('delete');
  static String get circuit => _t('circuit');
  static String get circuitHint => _t('circuitHint');
  static String get exerciseName => _t('exerciseName');
  static String get pauseSec => _t('pauseSec');
  static String get tapToChooseMuscle => _t('tapToChooseMuscle');
  static String get noScheduleMsg => _t('noScheduleMsg');
  static String get history => _t('history');
  static String get workoutOf => _t('workoutOf');
  static String get restTimer => _t('restTimer');
  static String get nextSet => _t('nextSet');
  static String get done => _t('done');
  static String get skip => _t('skip');
  static String get confirm => _t('confirm');
  static String get workout => _t('workout');
  static String get totalVolume => _t('totalVolume');
  static String get personalBest => _t('personalBest');
  static String get language => _t('language');
  static String get italian => _t('italian');
  static String get english => _t('english');
  static String get spanish => _t('spanish');
  static String get portuguese => _t('portuguese');
  static String get french => _t('french');
  static String get german => _t('german');
  static String get greek => _t('greek');
  static String get arabic => _t('arabic');
  static String get polish => _t('polish');
  static String get romanian => _t('romanian');
  static String get hungarian => _t('hungarian');
  static String get accentColor => _t('accentColor');
  static String get chooseLanguage => _t('chooseLanguage');
  static String get continueBtn => _t('continueBtn');
  static String get welcomeTitle => _t('welcomeTitle');
  static String get setGroup => _t('setGroup');
  static String get onboardingWelcomeText => _t('onboardingWelcomeText');
  static String get onboardingScheduleTitle => _t('onboardingScheduleTitle');
  static String get onboardingScheduleText => _t('onboardingScheduleText');
  static String get onboardingTrainTitle => _t('onboardingTrainTitle');
  static String get onboardingTrainText => _t('onboardingTrainText');
  static String get onboardingProgressTitle => _t('onboardingProgressTitle');
  static String get onboardingProgressText => _t('onboardingProgressText');
  static String get onboardingProText => _t('onboardingProText');
  static String get contactGianmarco => _t('contactGianmarco');
  static String get proInfoText => _t('proInfoText');
  static String get startBtn => _t('startBtn');
  static String get nextBtn => _t('nextBtn');
  static String get chooseMuscleImage => _t('chooseMuscleImage');
  static String get noImage => _t('noImage');
  static String get promoText => _t('promoText');
  static String get noScheduleLoaded => _t('noScheduleLoaded');
  static String get editOrCreate => _t('editOrCreate');
  static String get trainNow => _t('trainNow');
  static String get train2 => _t('train2');
  static String get chooseAndStart => _t('chooseAndStart');
  static String get createFirstSchedule => _t('createFirstSchedule');
  static String get workoutProgress => _t('workoutProgress');
  static String get neverTrained => _t('neverTrained');
  static String get today => _t('today');
  static String get yesterday => _t('yesterday');
  static String get daysAgo => _t('daysAgo');
  static String get others => _t('others');
  static String get timerSound => _t('timerSound');
  static String get timerVibration => _t('timerVibration');
  static String get autoStartTimer => _t('autoStartTimer');
  static String get screenAlwaysOn => _t('screenAlwaysOn');
  static String get confirmSeriesWindow => _t('confirmSeriesWindow');
  static String get weightSuggestion => _t('weightSuggestion');
  static String get dataManagement => _t('dataManagement');
  static String get insertKg => _t('insertKg');
  static String get insertReps => _t('insertReps');
  static String get enterKgReps => _t('enterKgReps');
  static String get saveSeries => _t('saveSeries');
  static String get confirmSeries => _t('confirmSeries');
  static String get quitWorkout => _t('quitWorkout');
  static String get quitWorkoutMsg => _t('quitWorkoutMsg');
  static String get exitAndSave => _t('exitAndSave');
  static String get exerciseComplete => _t('exerciseComplete');
  static String get exerciseCompleteMsg => _t('exerciseCompleteMsg');
  static String get nextInfo => _t('nextInfo');
  static String get lastTime => _t('lastTime');
  static String get increaseWeight => _t('increaseWeight');
  static String get increase => _t('increase');
  static String get workoutComplete => _t('workoutComplete');
  static String get firstSession => _t('firstSession');
  static String get improving => _t('improving');
  static String get declining => _t('declining');
  static String get plateau => _t('plateau');
  static String get details => _t('details');
  static String get greatWork => _t('greatWork');
  static String get workoutSummary => _t('workoutSummary');
  static String get close => _t('close');
  static String get totalSeries => _t('totalSeries');
  static String get exercisesLabel => _t('exercisesLabel');
  static String get primaryMuscle => _t('primaryMuscle');
  static String get secondaryMuscles => _t('secondaryMuscles');
  static String get execution => _t('execution');
  static String get tips => _t('tips');
  static String get notInCatalog => _t('notInCatalog');
  static String get notInCatalogShort => _t('notInCatalogShort');
  static String get watchOnYoutube => _t('watchOnYoutube');
  static String get progressOverTime => _t('progressOverTime');
  static String get noData => _t('noData');
  static String get noDataRegistered => _t('noDataRegistered');
  static String get myNotes => _t('myNotes');
  static String get coachNotes => _t('coachNotes');
  static String get setsDone => _t('setsDone');
  static String get of => _t('of');
  static String get changeExercise => _t('changeExercise');
  static String get noHistory => _t('noHistory');
  static String get deleteSelected => _t('deleteSelected');
  static String get totalReset => _t('totalReset');
  static String get fullReset => _t('fullReset');
  static String get fullResetTitle => _t('fullResetTitle');
  static String get fullResetMsg => _t('fullResetMsg');
  static String get continueLabel => _t('continueLabel');
  static String get areYouSure => _t('areYouSure');
  static String get irreversible => _t('irreversible');
  static String get deleteAll => _t('deleteAll');
  static String get noSession => _t('noSession');
  static String get deleteSession => _t('deleteSession');
  static String get deleteSessionMsg => _t('deleteSessionMsg');
  static String get sessionDeleted => _t('sessionDeleted');
  static String get deleteSeries => _t('deleteSeries');
  static String get dataDeleted => _t('dataDeleted');
  static String get skipUseButton => _t('skipUseButton');
  static String get restoreWorkout => _t('restoreWorkout');
  static String get workoutNotDone => _t('workoutNotDone');
  static String get proFeature1 => _t('proFeature1');
  static String get proFeature2 => _t('proFeature2');
  static String get proFeature3 => _t('proFeature3');
  static String get proFeature4 => _t('proFeature4');
  static String get gymAppPro => _t('gymAppPro');
  static String get recoverySuffix => _t('recoverySuffix');
  static String get sessionCount => _t('sessionCount');
  static String get sessionCountPlural => _t('sessionCountPlural');
  static String get loadExample => _t('loadExample');
  static String get renameSession => _t('renameSession');
  static String get sessionName => _t('sessionName');
  static String get editExercise => _t('editExercise');
  static String get streakWeeks => _t('streakWeeks');
  static String get streakMsg => _t('streakMsg');
  static String get newRecord => _t('newRecord');
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
  {
    final _p = await SharedPreferences.getInstance();
    AppL.setLang(_p.getString('app_lang') ?? 'it');
  }

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
      const AndroidNotificationChannel(
        'timer_gym',
        'Timer Recupero',
        importance: Importance.max,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'timer_gym_alert',
        'Timer Fine Recupero',
        importance: Importance.max,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'timer_gym_cd',
        'Timer in corso',
        importance: Importance.defaultImportance,
      ),
    );
  }
  // --------------------------------------------------

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    final dark = prefs.getBool('dark_mode') ?? true;
    appThemeModeNotifier.value = dark ? ThemeMode.dark : ThemeMode.light;
  }

  ThemeData _buildLightTheme(Color accent) {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      primaryColor: accent,
      colorScheme: ColorScheme.light(
        primary: accent,
        surface: Colors.white,
        onSurface: Colors.black87,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: accent,
        unselectedItemColor: Colors.black38,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE0E0E0)),
      cardTheme: const CardThemeData(color: Colors.white),
      listTileTheme: const ListTileThemeData(
        textColor: Colors.black87,
        iconColor: Colors.black54,
      ),
    );
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
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeModeNotifier,
      builder: (_, themeMode, __) => ValueListenableBuilder<Color>(
        valueListenable: appAccentNotifier,
        builder: (_, accent, __) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _buildLightTheme(accent),
          darkTheme: _buildTheme(accent),
          themeMode: themeMode,
          home: const AuthGuard(),
        ),
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
    if (_isAuthorized) {
      return const ClientMainPage();
    }
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
                  color: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.grey.shade100,
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
                style: TextStyle(
                  color: _isDarkCtx(context) ? Colors.white24 : Colors.black26,
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
                decoration: InputDecoration(
                  hintText: "••••",
                  hintStyle: TextStyle(color: _isDarkCtx(context) ? Colors.white10 : Colors.black26),
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
const String kExerciseAnimationExtension = 'webp';

String exerciseAnimationAssetPath(String slug) =>
    'assets/gif/$slug.$kExerciseAnimationExtension';

String muscleAssetPath(String? fileName) =>
    'assets/muscle/${fileName!.replaceAll(RegExp(r"\.png$", caseSensitive: false), ".webp")}';

bool usesQuarterStepIncrement(double valueKg) {
  final centiKg = (valueKg.abs() * 100).round();
  if (centiKg % 125 != 0) return false;
  // Values like 1.25, 3.75, 6.25… (odd multiples of 1.25)
  if (centiKg % 250 == 125) return true;
  // Above 100 kg the standard wheel steps are 5 kg, so 2.5-step values need quarter wheel
  if (valueKg.abs() > 100.0 && centiKg % 500 == 250) return true;
  return false;
}

bool usesEvenStepIncrement(double valueKg) {
  final milliKg = (valueKg.abs() * 1000).round();
  return milliKg % 1000 == 0 &&
      valueKg.abs() >= 2 &&
      valueKg.toInt().isEven &&
      valueKg.toInt() % 10 != 0;
}

bool usesSingleStepIncrement(double valueKg) {
  final centiKg = (valueKg.abs() * 100).round();
  // Standard 2.5-step values (multiples of 250 centi-kg) that are NOT quarter-step
  final isStandardStep = centiKg % 250 == 0 && !usesQuarterStepIncrement(valueKg);
  return !usesQuarterStepIncrement(valueKg) &&
      !usesEvenStepIncrement(valueKg) &&
      !isStandardStep;
}

double kgToLb(double kg) => kg * 2.2046226218;

double lbToKg(double lb) => lb / 2.2046226218;

String formatWeightValue(
  double kg, {
  bool usePounds = false,
  int maxDecimals = 2,
}) {
  final value = usePounds ? kgToLb(kg) : kg;
  final fixed = value.toStringAsFixed(maxDecimals);
  return fixed.contains('.')
      ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
      : fixed;
}

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
  bool useQuarterStep;
  bool useEvenStep;
  bool useSingleStep;

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
    this.useQuarterStep = false,
    this.useEvenStep = false,
    this.useSingleStep = false,
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
    if (useQuarterStep) 'useQuarterStep': useQuarterStep,
    if (useEvenStep) 'useEvenStep': useEvenStep,
    if (useSingleStep) 'useSingleStep': useSingleStep,
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
      useQuarterStep: json['useQuarterStep'] == true,
      useEvenStep: json['useEvenStep'] == true,
      useSingleStep: json['useSingleStep'] == true,
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

/// Manage badge reset if 1 week passed since first badge OR new microcycle started
Future<void> _manageBadgeResetCliente() async {
  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now();
  final thisWeek = _isoWeekStr(now);
  
  final badgesStartStr = prefs.getString('badges_start_date_c');
  if (badgesStartStr == null) {
    await prefs.setString('badges_start_date_c', now.toIso8601String());
    return;
  }
  
  final badgesStart = DateTime.tryParse(badgesStartStr);
  if (badgesStart == null) return;
  
  final daysPassed = now.difference(badgesStart).inDays;
  final shouldResetByTime = daysPassed >= 7;
  
  final lastBadgeMicrocycleWeek = prefs.getString('last_badge_microcycle_week_c') ?? '';
  final currentMicrocycleWeek = prefs.getString('current_microcycle_week_c') ?? thisWeek;
  final shouldResetByMicrocycle = lastBadgeMicrocycleWeek.isNotEmpty && lastBadgeMicrocycleWeek != currentMicrocycleWeek;
  
  if (shouldResetByTime || shouldResetByMicrocycle) {
    await prefs.remove('badges_start_date_c');
    if (shouldResetByTime) {
      await prefs.setString('last_badge_reset_week_c', thisWeek);
    }
  } else {
    await prefs.setString('current_microcycle_week_c', thisWeek);
  }
}

Future<int> updateStreakCliente(
  String dayName,
  List<String> totalSessionNames,
) async {
  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now();
  int streakCount = prefs.getInt('streak_count_c') ?? 0;

  // ─── MIGRATION: Se esiste la vecchia chiave 'streak_c' e non è ancora stata migrata ───
  if (prefs.getString('streak_migration_done_c') == null && prefs.containsKey('streak_c')) {
    final oldStreakWeeks = prefs.getInt('streak_c') ?? 0;
    // Converti settimane a microcicli (approssimato: 3 sessioni/settimana ~= 1 settimana per microciclo)
    // Se l'utente aveva già completato 2+ settimane, assume 2 microcicli
    final migratedMicrocycles = oldStreakWeeks > 0 ? 2 : 0;
    streakCount = migratedMicrocycles;
    await prefs.setInt('streak_count_c', streakCount);
    await prefs.setString('streak_migration_done_c', 'true');
  }

  // Sessioni già completate nel microciclo corrente
  final microJson = prefs.getString('microcycle_done_c') ?? '[]';
  Set<String> microDone = Set<String>.from(jsonDecode(microJson));
  // Rimuovi sessioni non più presenti nella scheda
  if (totalSessionNames.isNotEmpty) {
    microDone = microDone.intersection(Set<String>.from(totalSessionNames));
  }

  // REGOLA 7 GIORNI: se una sessione del piano non è stata fatta da >7 giorni → reset streak
  for (final name in totalSessionNames) {
    if (name == dayName) continue;
    final lastStr = prefs.getString('last_session_date_c_$name');
    if (lastStr != null) {
      final last = DateTime.tryParse(lastStr);
      if (last != null && now.difference(last).inDays > 13) {
        streakCount = 0;
        break;
      }
    }
  }

  // LOGICA MICROCICLO
  final bool newCycleStarting = microDone.isEmpty;
  if (microDone.contains(dayName)) {
    // Sessione ripetuta nel microciclo corrente → il vecchio ciclo non è stato completato,
    // si ricomincia da capo con questa sessione.
    streakCount = 0;
    microDone = {dayName};
    await prefs.remove('microcycle_completed_at_c');
  } else {
    if (newCycleStarting) {
      // Prima sessione del nuovo microciclo — cancella lo stato "appena completato"
      await prefs.remove('microcycle_completed_at_c');
    }
    microDone.add(dayName);
    // Microciclo completo quando tutte le sessioni sono state fatte
    if (totalSessionNames.isNotEmpty &&
        totalSessionNames.every((n) => microDone.contains(n))) {
      streakCount++;
      await prefs.setString('microcycle_completed_at_c', now.toIso8601String());
      await prefs.setString('microcycle_last_sessions_c', jsonEncode(microDone.toList()));
      microDone = {}; // Azzera per il prossimo microciclo
    }
  }

  await prefs.setInt('streak_count_c', streakCount);
  await prefs.setString('microcycle_done_c', jsonEncode(microDone.toList()));
  await prefs.setString('last_session_date_c_$dayName', now.toIso8601String());
  await prefs.setString(
    'last_workout_date_c',
    now.toIso8601String().split('T')[0],
  );

  // Manage badge reset
  await _manageBadgeResetCliente();

  return streakCount;
}

Future<int> getStreakCliente() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('streak_count_c') ?? 0;
}

Future<({int count, Set<String> done})> getStreakDataCliente() async {
  final prefs = await SharedPreferences.getInstance();
  final count = prefs.getInt('streak_count_c') ?? 0;
  final json = prefs.getString('microcycle_done_c') ?? '[]';
  Set<String> done = Set<String>.from(jsonDecode(json));
  // Se il microciclo è stato appena completato (< 2 giorni fa) e non è ancora
  // iniziato il successivo, mostra tutti i badge come conquistati
  if (done.isEmpty) {
    final completedAtStr = prefs.getString('microcycle_completed_at_c');
    if (completedAtStr != null) {
      final completedAt = DateTime.tryParse(completedAtStr);
      if (completedAt != null && DateTime.now().difference(completedAt).inDays < 2) {
        final lastJson = prefs.getString('microcycle_last_sessions_c') ?? '[]';
        done = Set<String>.from(jsonDecode(lastJson));
      }
    }
  }
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
  // Don't show immediate notification — AlarmManager handles background delivery.
  // Only reschedule if no alarm is pending (alarm was somehow missed).
  if (daysSince >= 2) {
    final nextFireStr = prefs.getString('streak_reminder_next_fire_c');
    final nextFireMs = int.tryParse(nextFireStr ?? '0') ?? 0;
    if (nextFireMs <= DateTime.now().millisecondsSinceEpoch) {
      // Alarm is overdue and was not fired (e.g., killed by OS) — reschedule it now.
      await scheduleStreakReminderCliente(force: true);
    }
  }
}

/// Pianifica notifica streak giornaliera 48h dopo l'ultimo allenamento, poi ripete ogni giorno.
/// Chiamare dopo ogni allenamento completato per resettare il timer.
Future<void> scheduleStreakReminderCliente({bool force = false}) async {
  if (kIsWeb) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    // Se non è forzato (es. apertura app), non riprogrammare se c'è già un allarme in futuro.
    if (!force) {
      final nextFireStr = prefs.getString('streak_reminder_next_fire_c');
      final nextFireMs = int.tryParse(nextFireStr ?? '0') ?? 0;
      if (nextFireMs > DateTime.now().millisecondsSinceEpoch) return;
    }
    await flutterLocalNotificationsPlugin.cancel(9901);
    try {
      await _gymFileChannel.invokeMethod('cancelStreakReminderNotification');
    } catch (_) {}
    final lastStr = prefs.getString('last_workout_date_c');
    final lastWorkout =
        DateTime.tryParse(lastStr ?? '')?.toLocal() ?? DateTime.now();
    final scheduledDate = lastWorkout.add(const Duration(hours: 48));
    // Salva l'orario pianificato
    await prefs.setString('streak_reminder_next_fire_c', scheduledDate.millisecondsSinceEpoch.toString());
    const title = 'Non perdere la tua streak!';
    const body =
        'Non ti alleni da 2 giorni. Allenati oggi per mantenere i tuoi progressi!';
    // Salva title/body per BootCompletedReceiver
    await prefs.setString('streak_reminder_title_c', title);
    await prefs.setString('streak_reminder_body_c', body);
    if (Platform.isAndroid) {
      final delayMs = scheduledDate
          .difference(DateTime.now())
          .inMilliseconds
          .clamp(0, 2147483647);
      await _gymFileChannel.invokeMethod('scheduleStreakReminderNotification', {
        'delayMs': delayMs,
        'title': title,
        'body': body,
      });
      return;
    }
    await flutterLocalNotificationsPlugin.zonedSchedule(
      9901,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
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
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
  bool _stUsePounds = false;
  bool _stDisableWeightKeyboard = false;
  bool _stDarkMode = true;

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
    getStreakDataCliente().then((d) {
      if (mounted)
        setState(() {
          _streak = d.count;
          _streakDone = d.done;
        });
    });
    checkAndScheduleStreakNotificationCliente('it');
    scheduleStreakReminderCliente();

    if (kIsWeb) {
      _controllaImportazioneWeb();
    } else {
      _initDeepLinks();
      _checkClipboardForScheda(); // Controlla appunti all'avvio
      // Handle widget play button warm-start (app already running)
      _gymFileChannel.setMethodCallHandler((call) async {
        if (call.method == 'startWorkout') await _maybeStartWorkoutFromWidget();
        return null;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkMiuiWidget());
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
        backgroundColor: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          titolo,
          style: TextStyle(color: _isDarkCtx(context) ? Colors.white : Colors.black87, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Il browser non ha permesso la copia automatica.\nSeleziona tutto il testo qui sotto e copialo:",
              style: TextStyle(color: _isDarkCtx(context) ? Colors.white70 : Colors.black87, fontSize: 13),
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

  Future<void> _checkMiuiWidget() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('widget_hint_shown') ?? false) return;

    bool isMiui = false;
    bool isSamsung = false;
    try {
      isMiui = await _gymFileChannel.invokeMethod<bool>('isMiui') ?? false;
      isSamsung = await _gymFileChannel.invokeMethod<bool>('isSamsung') ?? false;
    } catch (_) {}

    if ((!isMiui && !isSamsung) || !mounted) return;

    final dark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = dark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = dark ? Colors.white70 : Colors.black87;

    final String title;
    final String message;
    final String buttonLabel;
    final String channelMethod;

    if (isMiui) {
      title = '📱 Widget GymLogbook';
      message = 'Su Xiaomi/MIUI il widget richiede il permesso di avvio automatico.\n\nVai in:\nImpostazioni → App → GymLogbook → Avvio automatico → Attiva';
      buttonLabel = 'Apri impostazioni';
      channelMethod = 'openAutoStartSettings';
    } else {
      title = '📱 Widget GymLogbook';
      message = 'Su Samsung il widget potrebbe non funzionare se l\'app è in risparmio energetico.\n\nVai in:\nImpostazioni App → Batteria → Nessuna restrizione';
      buttonLabel = 'Apri impostazioni batteria';
      channelMethod = 'openBatterySettings';
    }

    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message,
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor, height: 1.45),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Dopo')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(c);
              try { await _gymFileChannel.invokeMethod(channelMethod); } catch (_) {}
            },
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
    await prefs.setBool('widget_hint_shown', true);
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
        await _confirmClipboardSchedaImport(text);
      }
    } catch (e) {
      debugPrint("Errore controllo clipboard: $e");
    }
  }

  Future<void> _confirmClipboardSchedaImport(String text) async {
    if (!mounted) return;
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Nuova scheda trovata',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
        content: Text(
          'Negli appunti c\'e una nuova scheda. Vuoi caricarla ora?',
          style: TextStyle(color: _isDarkCtx(context) ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'NON ORA',
              style: TextStyle(color: _isDarkCtx(context) ? Colors.white54 : Colors.black54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'CARICA',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
    if (shouldImport != true || !mounted) return;
    await Clipboard.setData(const ClipboardData(text: ""));
    _importaNuovaScheda(text);
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

  Map<String, String> _decodeRoutineArchive(String? raw) {
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  String _buildRoutineProfileId(
    List<dynamic> routineList, {
    String? clientName,
  }) {
    final normalized = jsonEncode({
      'clientName': (clientName ?? '').trim().toLowerCase(),
      'routine': routineList.map((day) {
        final map = Map<String, dynamic>.from(day as Map);
        return {
          'dayName': (map['dayName'] ?? '').toString().trim().toLowerCase(),
          'exercises': (map['exercises'] as List? ?? const []).map((exercise) {
            final ex = Map<String, dynamic>.from(exercise as Map);
            return {
              'name': (ex['name'] ?? '').toString().trim().toLowerCase(),
              'targetSets': ex['targetSets'] ?? 0,
              'repsList': ex['repsList'] ?? const [],
              'recoveryTime': ex['recoveryTime'] ?? 0,
              'interExercisePause': ex['interExercisePause'] ?? 0,
              'supersetGroup': ex['supersetGroup'] ?? 0,
            };
          }).toList(),
        };
      }).toList(),
    });
    var hash = 2166136261; // FNV offset basis (32-bit safe)
    for (final byte in utf8.encode(normalized)) {
      hash ^= byte;
      hash = (hash * 16777619) % 0x100000000; // Keep in 32-bit range
    }
    return hash.toRadixString(16);
  }

  Future<void> _archiveCurrentRoutineState(SharedPreferences prefs) async {
    final routineRaw = prefs.getString('client_routine');
    if (routineRaw == null || routineRaw.trim().isEmpty || routineRaw == '[]') {
      return;
    }
    final decoded = jsonDecode(routineRaw);
    if (decoded is! List || decoded.isEmpty) return;

    final profileId =
        prefs.getString('client_routine_profile_id') ??
        _buildRoutineProfileId(
          decoded,
          clientName: prefs.getString('athlete_name'),
        );

    final historyArchive = _decodeRoutineArchive(
      prefs.getString('client_history_archive_v2'),
    );
    final carryoverArchive = _decodeRoutineArchive(
      prefs.getString('carryover_archive_v2'),
    );

    historyArchive[profileId] = prefs.getString('client_history') ?? '[]';
    carryoverArchive[profileId] = prefs.getString('carryover_weights') ?? '{}';

    await prefs.setString(
      'client_history_archive_v2',
      jsonEncode(historyArchive),
    );
    await prefs.setString('carryover_archive_v2', jsonEncode(carryoverArchive));
    await prefs.setString('client_routine_profile_id', profileId);
  }

  void _importaNuovaScheda(String contenuto) async {
    try {
      final (routineList, clientName) = _validaEParseScheda(contenuto);
      final jsonPulito = jsonEncode(routineList);

      final prefs = await SharedPreferences.getInstance();
      await _archiveCurrentRoutineState(prefs);

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
        if (!newCarryover.containsKey(k))
          newCarryover[k] = _carryoverWeights[k]!;
      }

      final profileId = _buildRoutineProfileId(
        List<dynamic>.from(routineList as List),
        clientName: clientName,
      );
      final historyArchive = _decodeRoutineArchive(
        prefs.getString('client_history_archive_v2'),
      );
      final carryoverArchive = _decodeRoutineArchive(
        prefs.getString('carryover_archive_v2'),
      );
      final restoredHistory = historyArchive[profileId] ?? '[]';
      final restoredCarryover =
          carryoverArchive[profileId] ?? jsonEncode(newCarryover);

      await prefs.setString('client_routine', jsonPulito);
      await prefs.setString('client_history', restoredHistory);
      await prefs.setString('carryover_weights', restoredCarryover);
      await prefs.setString('client_routine_profile_id', profileId);
      // Reset microcycle in progress when routine changes (keep streak count)
      await prefs.setString('microcycle_done_c', '[]');
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
        backgroundColor: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text(
              "Importazione fallita",
              style: TextStyle(color: _isDarkCtx(context) ? Colors.white : Colors.black87, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          messaggio,
          style: TextStyle(
            color: _isDarkCtx(context) ? Colors.white70 : Colors.black87,
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subColor  = isDark ? Colors.white38 : Colors.black45;
    final Color divColor  = isDark ? Colors.white12 : Colors.black12;
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                      Text(
                        'Impostazioni',
                        style: TextStyle(color: subColor, fontSize: 12),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Divider(color: divColor),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'FEEDBACK',
                  style: TextStyle(
                    color: subColor,
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
              Divider(color: divColor),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'TIMER',
                  style: TextStyle(
                    color: subColor,
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
              Divider(color: divColor),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'SERIE',
                  style: TextStyle(
                    color: subColor,
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
              _mainSegmentSettingRow(
                Icons.straighten,
                'Unità peso',
                selectedKey: _stUsePounds ? 'lb' : 'kg',
                options: const {'kg': 'KG', 'lb': 'LIBBRE'},
                onChanged: (value) {
                  setState(() => _stUsePounds = value == 'lb');
                  _saveMainSettings();
                },
              ),
              _mainSettingRow(
                Icons.keyboard_hide_outlined,
                'No tastiera',
                _stDisableWeightKeyboard,
                (v) {
                  setState(() => _stDisableWeightKeyboard = v);
                  _saveMainSettings();
                },
              ),
              Divider(color: divColor),

              Divider(color: divColor),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'ASPETTO',
                  style: TextStyle(color: subColor, fontSize: 11, letterSpacing: 1.5),
                ),
              ),
              _mainSettingRow(
                Icons.brightness_medium,
                'Tema scuro',
                _stDarkMode,
                (v) async {
                  setState(() => _stDarkMode = v);
                  appThemeModeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('dark_mode', v);
                },
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'TUTORIAL',
                  style: TextStyle(
                    color: subColor,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('workout_tutorial_shown', false);
                  if (mounted) {
                    final demoDay = WorkoutDay(
                      dayName: '🏠 Allenamento Prova',
                      bodyParts: const ['full_body'],
                      muscleImage: null,
                      exercises: [
                        ExerciseConfig(
                          name: 'Flessioni',
                          targetSets: 2,
                          repsList: const [10, 10],
                          recoveryTime: 60,
                          gifFilename: 'push-up.webp',
                          notePT: 'Tieni il core contratto e le spalle lontane dalle orecchie.',
                        ),
                        ExerciseConfig(
                          name: 'Squat a corpo libero',
                          targetSets: 2,
                          repsList: const [12, 12],
                          recoveryTime: 60,
                          gifFilename: 'bodyweight-squat.webp',
                          notePT: 'Scendi finché le cosce sono parallele al suolo.',
                        ),
                      ],
                    );
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (c, anim, _) => WorkoutTutorial(
                          accentColor: accent,
                          onComplete: () {
                            Navigator.pop(context);
                            prefs.setBool('workout_tutorial_shown', true);
                          },
                          demoWorkoutBuilder: (ctx) => WorkoutEngine(
                            day: demoDay,
                            history: const [],
                            carryoverWeights: const {},
                            allSessionNames: const ['🏠 Allenamento Prova'],
                            demoMode: true,
                            onDone: (_) {},
                          ),
                        ),
                        transitionsBuilder: (c, anim, _, child) => FadeTransition(
                          opacity: anim,
                          child: child,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _isDarkCtx(context) ? const Color(0xFF2C2C2E) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accent.withAlpha(100),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        color: accent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Rivedere Tutorial',
                          style: TextStyle(
                            color: accent,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(color: divColor),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'COLORE TEMA',
                  style: TextStyle(
                    color: subColor,
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
                            ? Border.all(color: _isDarkCtx(context) ? Colors.white : Colors.black87, width: 3)
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
              Divider(color: divColor),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'DATI',
                  style: TextStyle(
                    color: subColor,
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
                    ).then((didChange) {
                      if (didChange == true) {
                        _loadData();
                      }
                    });
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
    return Builder(builder: (ctx) {
      final textClr = Theme.of(ctx).colorScheme.onSurface;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, color: appAccentNotifier.value, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    softWrap: true,
                    style: TextStyle(color: textClr, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: appAccentNotifier.value,
          ),
        ],
      );
    });
  }

  Widget _mainSegmentSettingRow(
    IconData icon,
    String label, {
    required String selectedKey,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, color: appAccentNotifier.value, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  softWrap: true,
                  style: TextStyle(color: _isDarkCtx(context) ? Colors.white : Colors.black87, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Wrap(
          spacing: 8,
          children: options.entries.map((entry) {
            final selected = selectedKey == entry.key;
            return ChoiceChip(
              label: Text(
                entry.value,
                style: TextStyle(
                  color: selected ? Colors.black : (_isDarkCtx(context) ? Colors.white70 : Colors.black87),
                  fontWeight: FontWeight.w700,
                ),
              ),
              selected: selected,
              onSelected: (_) => onChanged(entry.key),
              selectedColor: appAccentNotifier.value,
              backgroundColor: _isDarkCtx(context) ? Colors.white10 : Colors.grey.shade200,
              side: BorderSide(
                color: selected ? appAccentNotifier.value : (_isDarkCtx(context) ? Colors.white12 : Colors.grey.shade400),
              ),
            );
          }).toList(),
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
      _stUsePounds = prefs.getBool('use_pounds') ?? false;
      _stDisableWeightKeyboard =
          prefs.getBool('disable_weight_keyboard') ?? false;
      _stDarkMode = prefs.getBool('dark_mode') ?? true;
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
    await prefs.setBool('use_pounds', _stUsePounds);
    await prefs.setBool('disable_weight_keyboard', _stDisableWeightKeyboard);
    await prefs.setBool('dark_mode', _stDarkMode);
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
    if (!kIsWeb) _updateWidgetData();
    if (!kIsWeb) _maybeStartWorkoutFromWidget();
  }

  Future<void> _updateWidgetData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final streakData = await getStreakDataCliente();
      // First uncompleted session (not in done set)
      final doneNames = streakData.done;
      String nextWorkout = '—';
      WorkoutDay? nextDay;
      for (final day in myRoutine) {
        if (!doneNames.contains(day.dayName)) {
          nextWorkout = day.dayName;
          nextDay = day;
          break;
        }
      }
      if (nextWorkout == '—' && myRoutine.isNotEmpty) {
        nextWorkout = myRoutine.first.dayName; // All done: show first as next cycle
        nextDay = myRoutine.first;
      }
      await prefs.setInt('widget_streak', streakData.count);
      await prefs.setString('widget_next_workout', nextWorkout);
      // Write session list for badge display (up to 7)
      final sessionNames = myRoutine.take(7).map((d) => d.dayName).toList();
      await prefs.setString('widget_session_names', jsonEncode(sessionNames));
      // Write emoji icons for each session (based on first bodyPart)
      final sessionIcons = myRoutine.take(7).map((d) {
        if (d.bodyParts.isNotEmpty) {
          return kBodyPartIcons[d.bodyParts.first] ?? '💪';
        }
        return '💪';
      }).toList();
      await prefs.setString('widget_session_icons', jsonEncode(sessionIcons));
      // Write muscle image name for the next workout and per-session muscles
      const kBodyPartToMuscle = {
        'petto': 'petto',
        'schiena': 'dorso',
        'gambe': 'gambe',
        'spalle': 'spalle',
        'braccia': 'braccia',
        'core': '',
        'full_body': 'push',
        'cardio': '',
        'glutei': 'glutei',
        'altro': '',
      };
      final nextMuscle = kBodyPartToMuscle[nextDay?.bodyParts.firstOrNull ?? ''] ?? '';
      await prefs.setString('widget_next_muscle', nextMuscle);
      // Per-session muscle names for badges
      final sessionMuscles = myRoutine.take(7).map((d) {
        return kBodyPartToMuscle[d.bodyParts.firstOrNull ?? ''] ?? '';
      }).toList();
      await prefs.setString('widget_session_muscles', jsonEncode(sessionMuscles));
      // Force-refresh widget on Android
      try {
        await _gymFileChannel.invokeMethod('updateWidget');
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> _maybeStartWorkoutFromWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tsStr = prefs.getString('widget_start_workout_ts');
      if (tsStr == null) return;
      final ts = int.tryParse(tsStr) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - ts > 10000) return;
      await prefs.remove('widget_start_workout_ts');
      if (myRoutine.isEmpty || !mounted) return;
      final streakData = await getStreakDataCliente();
      WorkoutDay? nextDay;
      for (final day in myRoutine) {
        if (!streakData.done.contains(day.dayName)) { nextDay = day; break; }
      }
      nextDay ??= myRoutine.first;
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startWorkout(nextDay!);
      });
    } catch (_) {}
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
        backgroundColor: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
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
            Divider(color: _isDarkCtx(context) ? Colors.white12 : Colors.black12, height: 20),
            Text(
              "Chiedi al tuo PT il codice scheda e incollalo qui sotto, oppure apri direttamente il file .workout ricevuto.",
              style: TextStyle(fontSize: 12, color: _isDarkCtx(context) ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: importC,
              maxLines: 4,
              style: TextStyle(fontSize: 12, color: _isDarkCtx(context) ? Colors.white : Colors.black87),
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
            child: Text(
              "Annulla",
              style: TextStyle(color: _isDarkCtx(context) ? Colors.white54 : Colors.black54),
            ),
          ),
          TextButton(
            onPressed: () async {
              final input = importC.text.trim();
              if (input.isEmpty) return;
              Navigator.pop(c);
              if (!mounted) return;
              try {
                _importaNuovaScheda(input);
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
        title: Text(
          "GYM LOGBOOK",
          style: TextStyle(
            color: _isDarkCtx(context) ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: _isDarkCtx(context) ? Colors.white : Colors.black87),
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withAlpha(80),
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
            Text(
              'Nessuna scheda caricata',
              style: TextStyle(color: _isDarkCtx(context) ? Colors.white38 : Colors.black38, fontSize: 16),
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
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final n = myRoutine.length;
        const double topPad = 28, bottomPad = 32;
        final double gaps = 14.0 * (n > 1 ? n - 1 : 0);
        final double cardH = n > 0
            ? ((constraints.maxHeight - topPad - bottomPad - gaps) / n)
                .clamp(80.0, double.infinity)
            : 100.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < n; i++) ...[
                SizedBox(
                  height: cardH,
                  child: _buildRoutineCard(myRoutine[i], accent, i),
                ),
                if (i < n - 1) const SizedBox(height: 14),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showSchedaOptions(Color accent) {
    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      backgroundColor: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
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
                  color: _isDarkCtx(context) ? Colors.white12 : Colors.black12,
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
                subtitle: Text(
                  'Invia la scheda al tuo allenatore o salvala',
                  style: TextStyle(color: _isDarkCtx(context) ? Colors.white38 : Colors.black38, fontSize: 12),
                ),
              ),
              const SizedBox(height: 4),
              ListTile(
                onTap: () {
                  Navigator.pop(context);
                  final history = this.history;
                  final routine = myRoutine;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _OverallProgressPage(
                        history: history,
                        routine: routine,
                        streak: _streak,
                        accent: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                },
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0x4400BCD4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF00BCD4), size: 22),
                ),
                title: const Text(
                  'Condividi risultati 📊',
                  style: TextStyle(
                    color: Color(0xFF00BCD4),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  'Condividi i tuoi progressi sui social',
                  style: TextStyle(color: _isDarkCtx(context) ? Colors.white38 : Colors.black38, fontSize: 12),
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
                subtitle: Text(
                  'Carica una nuova scheda ricevuta dal coach',
                  style: TextStyle(color: _isDarkCtx(context) ? Colors.white38 : Colors.black38, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoutineCard(WorkoutDay day, Color accent, int index) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
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
              colors: [accent.withAlpha(28), cardBg],
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
              alignment: Alignment.centerLeft,
              children: [
                // Immagine sfondo sfumata a destra
                if (day.muscleImage != null)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.15,
                      child: Image.asset(
                        muscleAssetPath(day.muscleImage),
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
                                muscleAssetPath(day.muscleImage),
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
                          style: TextStyle(
                            color: _isDarkCtx(context) ? Colors.white : Colors.black87,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      // Icona lista esercizi: tap → lista diretta
                      GestureDetector(
                        onTap: () => _showDayDetail(day),
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.format_list_bulleted_rounded,
                            color: _isDarkCtx(context) ? Colors.white38 : Colors.black38,
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

  String _todayLabel() {
    final now = DateTime.now();
    const months = ['gen','feb','mar','apr','mag','giu','lug','ago','set','ott','nov','dic'];
    return '${now.day} ${months[now.month - 1]}';
  }

  List<Map<String, dynamic>> _buildLastSessionExercises(String dayName) {
    final Map<String, List<Map<String, dynamic>>> bySid = {};
    final Map<String, DateTime> sidDate = {};
    for (final h in history) {
      if ((h['dayName'] as String?) != dayName) continue;
      final sid = (h['session_id'] as String?)?.isNotEmpty == true
          ? h['session_id'] as String
          : ((h['date'] as String?) ?? '').substring(0, 10);
      bySid.putIfAbsent(sid, () => []).add(Map<String, dynamic>.from(h));
      sidDate.putIfAbsent(sid, () => DateTime.tryParse((h['date'] as String?) ?? '') ?? DateTime(2000));
    }
    if (bySid.isEmpty) return [];
    final lastSid = sidDate.entries.reduce((a, b) => a.value.isAfter(b.value) ? a : b).key;
    return bySid[lastSid]!.map((h) => {
      'exercise': h['exercise'] as String? ?? '',
      'series': (h['series'] as List?) ?? [],
    }).toList();
  }

  List<_SessionPoint> _computeProgressPoints() {
    final Map<String, Map<String, double>> bySessionEx = {};
    final Map<String, String> sessionDate = {};
    final Map<String, String> sessionDayName = {};
    for (final h in history) {
      final sid = (h['session_id'] as String?)?.isNotEmpty == true
          ? h['session_id'] as String
          : ((h['date'] as String?) ?? '').substring(0, 10);
      final exName = (h['exercise'] as String?) ?? '';
      if (exName.isEmpty) continue;
      sessionDate.putIfAbsent(sid, () => (h['date'] as String?) ?? '');
      sessionDayName.putIfAbsent(sid, () => (h['dayName'] as String?) ?? '');
      final series = (h['series'] as List?) ?? [];
      double maxEst1RM = 0;
      for (final s in series) {
        final w = (s['w'] ?? 0.0).toDouble();
        final r = (s['r'] ?? 0).toDouble();
        final est1RM = r > 0 ? w * (1 + r / (30.0 + w / 10.0)) : w;
        if (est1RM > maxEst1RM) maxEst1RM = est1RM;
      }
      final exMap = bySessionEx.putIfAbsent(sid, () => {});
      if ((exMap[exName] ?? 0) < maxEst1RM) exMap[exName] = maxEst1RM;
    }
    final List<_SessionPoint> points = [];
    for (final sid in bySessionEx.keys) {
      final date = sessionDate[sid] ?? '';
      if (date.isEmpty) continue;
      final score = bySessionEx[sid]!.values.fold(0.0, (a, b) => a + b);
      points.add(_SessionPoint(
        sessionId: sid,
        date: DateTime.tryParse(date) ?? DateTime(2000),
        score: score,
        dayName: sessionDayName[sid] ?? '',
      ));
    }
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  void _showWorkoutProgress(WorkoutDay day) {
    final accent = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      backgroundColor: _isDarkCtx(context) ? const Color(0xFF0E0E10) : Colors.white,
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
                    color: _isDarkCtx(context) ? Colors.white12 : Colors.black12,
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
            Divider(color: _isDarkCtx(context) ? Colors.white12 : Colors.black87.withAlpha(10), height: 1),
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
                          muscleAssetPath(day.muscleImage),
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
                  Icon(
                    Icons.trending_up_rounded,
                    color: _isDarkCtx(context) ? Colors.white38 : Colors.black38,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ANDAMENTO ALLENAMENTO',
                    style: TextStyle(
                      color: _isDarkCtx(context) ? Colors.white38 : Colors.black38,
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
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: _WorkoutProgressChart(
                  day: day,
                  history: history,
                  accent: accent,
                ),
              ),
            ),
            // Share buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final exercises = _buildLastSessionExercises(day.dayName);
                        final allNames = myRoutine.map((r) => r.dayName).toList();
                        showModalBottomSheet(
      useSafeArea: true,
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _WorkoutShareSheet(
                            dayName: day.dayName,
                            todayLabel: _todayLabel(),
                            exercises: exercises,
                            streak: _streak,
                            accent: accent,
                            streakDoneNames: _streakDone,
                            allSessionNames: allNames,
                          ),
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Condividi 🏋️'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: accent.withAlpha(80)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final hist = history;
                        final rout = myRoutine;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _OverallProgressPage(
                              history: hist,
                              routine: rout,
                              streak: _streak,
                              accent: accent,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.bar_chart_rounded, size: 16),
                      label: const Text('Progressi 📊'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00BCD4),
                        side: const BorderSide(color: Color(0x4400BCD4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
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
                          muscleAssetPath(imageFile),
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
                      style: TextStyle(
                        color: _isDarkCtx(context) ? Colors.white : Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 16,
                    child: Icon(Icons.close, color: _isDarkCtx(context) ? Colors.white70 : Colors.black87, size: 28),
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
      useSafeArea: true,
      context: context,
      backgroundColor: _isDarkCtx(context) ? const Color(0xFF0E0E10) : Colors.white,
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
                  color: _isDarkCtx(context) ? Colors.white12 : Colors.black12,
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
                    style: TextStyle(color: _isDarkCtx(context) ? Colors.white24 : Colors.black26, fontSize: 12),
                  ),
                ],
              ),
            ),
            Divider(color: _isDarkCtx(context) ? Colors.white12 : Colors.black87.withAlpha(10), height: 1),
            // Exercise list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: day.exercises.length,
                separatorBuilder: (_, __) => Divider(
                  color: _isDarkCtx(context) ? Colors.white12 : Colors.black87.withAlpha(8),
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
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: _isDarkCtx(context) ? Colors.white : Colors.black87,
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
                                  color: _isDarkCtx(context) ? Colors.white : Colors.black87.withAlpha(100),
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
    final info =
        (ex.gifFilename != null ? findByGifSlug(ex.gifFilename!) : null) ??
        findAnyExercise(ex.name);
    final gifPath = ex.gifFilename != null
        ? exerciseAnimationAssetPath(ex.gifFilename!)
        : info != null
        ? exerciseAnimationAssetPath(info.gifSlug)
        : null;

    showModalBottomSheet(
      useSafeArea: true,
      context: ctx,
      backgroundColor: _isDarkCtx(context) ? const Color(0xFF0E0E10) : Colors.white,
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
                    color: _isDarkCtx(context) ? Colors.white12 : Colors.black12,
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
                style: TextStyle(
                  color: _isDarkCtx(context) ? Colors.white38 : Colors.black38,
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
                      muscleAssetPath(info.muscleImages[i]),
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
                  _isDarkCtx(context) ? Colors.white54 : Colors.black54,
                ),
              const SizedBox(height: 12),
              _sectionCard(
                '📋 ESECUZIONE',
                info.execution,
                _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.grey.shade100,
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
                  color: _isDarkCtx(context) ? Colors.white.withAlpha(5) : Colors.black87.withAlpha(5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Esercizio non in catalogo.\nUsa YouTube per vedere la tecnica.',
                  style: TextStyle(color: _isDarkCtx(context) ? Colors.white38 : Colors.black38, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            Divider(color: _isDarkCtx(context) ? Colors.white12 : Colors.black12),
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
          style: TextStyle(
            color: _isDarkCtx(context) ? Colors.white54 : Colors.black54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: TextStyle(
            color: _isDarkCtx(context) ? Colors.white : Colors.black87,
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
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDarkCtx(context) ? const Color(0xFF0E0E10) : Colors.white,
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
                color: _isDarkCtx(context) ? Colors.white12 : Colors.black12,
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
                    style: TextStyle(
                      color: _isDarkCtx(context) ? Colors.white : Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Progressi nel tempo — una linea per serie',
              style: TextStyle(color: _isDarkCtx(context) ? Colors.white24 : Colors.black26, fontSize: 11),
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
                color: isSuperset ? (_isDarkCtx(context) ? Colors.white70 : Colors.black87) : (_isDarkCtx(context) ? Colors.white60 : Colors.black54),
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
    for (final ex in d.exercises) {
      if (ex.supersetGroup == 0) {
        items.add(_exPreviewRow(ex.name, _repsSchemeText(ex), accent, false));
      } else {
        if (!processedGroups.contains(ex.supersetGroup)) {
          processedGroups.add(ex.supersetGroup);
          final group = d.exercises
              .where((e) => e.supersetGroup == ex.supersetGroup)
              .toList();
          final names = group.map((e) => e.name).join(' + ');
          final schemes = group.map((e) => _repsSchemeText(e)).join(' / ');
          items.add(_exPreviewRow(names, schemes, accent, true));
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
    // Check if tutorial should be shown
    final prefs = await SharedPreferences.getInstance();
    final tutorialShown = prefs.getBool('workout_tutorial_shown') ?? false;
    
    if (!tutorialShown && !kIsWeb) {
      // Show tutorial first
      if (!mounted) return;
      final demoDay = WorkoutDay(
        dayName: '🏠 Allenamento Prova',
        bodyParts: const ['full_body'],
        muscleImage: null,
        exercises: [
          ExerciseConfig(
            name: 'Flessioni',
            targetSets: 2,
            repsList: const [10, 10],
            recoveryTime: 60,
            gifFilename: 'push-up.webp',
            notePT: 'Tieni il core contratto e le spalle lontane dalle orecchie.',
          ),
          ExerciseConfig(
            name: 'Squat a corpo libero',
            targetSets: 2,
            repsList: const [12, 12],
            recoveryTime: 60,
            gifFilename: 'bodyweight-squat.webp',
            notePT: 'Scendi finché le cosce sono parallele al suolo.',
          ),
        ],
      );
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (c, anim, _) => WorkoutTutorial(
            accentColor: appAccentNotifier.value,
            onComplete: () {
              Navigator.pop(context);
            },
            demoWorkoutBuilder: (ctx) => WorkoutEngine(
              day: demoDay,
              history: const [],
              carryoverWeights: const {},
              allSessionNames: const ['🏠 Allenamento Prova'],
              demoMode: true,
              onDone: (_) {},
            ),
          ),
          transitionsBuilder: (c, anim, _, child) => FadeTransition(
            opacity: anim,
            child: child,
          ),
        ),
      );
      await prefs.setBool('workout_tutorial_shown', true);
      if (!mounted) return;
    }
    
    // Cancella SEMPRE lo snapshot precedente: ogni tap su "Allena ora" è una nuova sessione.
    // Il ripristino automatico avviene solo se l'app viene chiusa MID-workout.
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
            _loadData();
            // Aggiorna badge home dopo che WorkoutEngine ha completato updateStreak
            Future.delayed(const Duration(milliseconds: 600), () async {
              if (!mounted) return;
              final streakData = await getStreakDataCliente();
              if (mounted)
                setState(() {
                  _streak = streakData.count;
                  _streakDone = streakData.done;
                });
              if (!kIsWeb) _updateWidgetData();
            });
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
        backgroundColor: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
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
              _streak == 1 ? 'micro' : 'micro',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Completa TUTTE le sessioni della tua scheda ogni microciclo per incrementare il contatore.\n\nSe salti anche solo una sessione in un microciclo, la streak si azzera.\n\nSii costante — ogni microciclo conta! 💪',
              style: TextStyle(color: _isDarkCtx(context) ? Colors.white70 : Colors.black87, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            if (myRoutine.isNotEmpty) ...[
              Text(
                '${_streakDone.where((n) => myRoutine.any((d) => d.dayName == n)).length}/${myRoutine.length} sessioni questo microciclo',
                style: TextStyle(color: _isDarkCtx(context) ? Colors.white54 : Colors.black54, fontSize: 11),
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final n = myRoutine.length;
                  final iconSize = n > 0
                      ? (constraints.maxWidth / n - 8).clamp(20.0, 48.0)
                      : 48.0;
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
                              gradient: done
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFFF6B00),
                                        Color(0xFFFFAB00),
                                      ],
                                    )
                                  : null,
                              color: done ? null : const Color(0xFF2C2C2E),
                              boxShadow: done
                                  ? [
                                      BoxShadow(
                                        color: Colors.orange.withAlpha(80),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Opacity(
                                opacity: done ? 1.0 : 0.2,
                                child: Image.asset(
                                  'assets/icon_client.png',
                                  fit: BoxFit.cover,
                                ),
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
            onPressed: () {
              Navigator.pop(c);
              Future.microtask(() => showModalBottomSheet(
      useSafeArea: true,
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _StreakShareSheet(
                  streak: _streak,
                  streakDoneNames: _streakDone,
                  allSessionNames: myRoutine.map((r) => r.dayName).toList(),
                  accent: Theme.of(context).colorScheme.primary,
                ),
              ));
            },
            child: const Text('Condividi 🔥', style: TextStyle(color: Colors.orange)),
          ),
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
            Text(
              'Nessuna scheda caricata',
              style: TextStyle(color: _isDarkCtx(context) ? Colors.white38 : Colors.black38, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Importa una scheda dal tuo Coach',
              style: TextStyle(color: _isDarkCtx(context) ? Colors.white24 : Colors.black26, fontSize: 13),
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
                Text(
                  'Scegli e inizia il tuo allenamento',
                  style: TextStyle(color: _isDarkCtx(context) ? Colors.white38 : Colors.black38, fontSize: 13),
                ),
                if (myRoutine.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _showStreakInfo,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _streak > 0
                              ? const Color(0xFFFF6B00).withAlpha(80)
                              : (_isDarkCtx(context) ? Colors.white12 : Colors.black12),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (ctx, bannerConstraints) {
                          final n = myRoutine.length;
                          final sideIconsWidth =
                              bannerConstraints.maxWidth - 68 - 10 - 6 - 18;
                          final fullIconsWidth = bannerConstraints.maxWidth;
                          final fitsSide =
                              n == 0 ||
                              (n * 38.0 + (n - 1) * 6.0) <= sideIconsWidth;
                          final fitsFull =
                              n == 0 ||
                              (n * 38.0 + (n - 1) * 6.0) <= fullIconsWidth;

                          final Widget Function(double)
                          buildIconRow = (availWidth) {
                            final iconSize = n > 0
                                ? (availWidth / n - 8).clamp(20.0, 48.0)
                                : 48.0;
                            return Row(
                              children: List.generate(n, (i) {
                                final name = myRoutine[i].dayName;
                                final done = _streakDone.contains(name);
                                return Expanded(
                                  child: Center(
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      width: iconSize,
                                      height: iconSize,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        gradient: done
                                            ? const LinearGradient(
                                                colors: [
                                                  Color(0xFFFF6B00),
                                                  Color(0xFFFFAB00),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : null,
                                        color: done
                                            ? null
                                            : const Color(0xFF2C2C2E),
                                        boxShadow: done
                                            ? [
                                                BoxShadow(
                                                  color: Colors.orange
                                                      .withAlpha(100),
                                                  blurRadius: 6,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Opacity(
                                          opacity: done ? 1.0 : 0.2,
                                          child: Image.asset(
                                            'assets/icon_client.png',
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            );
                          };

                          final doneCount = _streakDone
                              .where(
                                (nm) => myRoutine.any((d) => d.dayName == nm),
                              )
                              .length;

                          if (fitsSide) {
                            return Row(
                              children: [
                                SizedBox(
                                  width: 68,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            '🔥',
                                            style: TextStyle(fontSize: 22),
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '$_streak',
                                            style: TextStyle(
                                              color: _streak > 0
                                                  ? Colors.orange
                                                  : Colors.white24,
                                              fontSize: 30,
                                              fontWeight: FontWeight.w900,
                                              height: 1.0,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        _streak == 1
                                            ? 'micro'
                                            : 'micro',
                                        style: TextStyle(
                                          color: _isDarkCtx(context) ? Colors.white38 : Colors.black38,
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$doneCount/${myRoutine.length}',
                                        style: TextStyle(
                                          color: doneCount >= myRoutine.length
                                              ? Colors.orange
                                              : Colors.white38,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: buildIconRow(sideIconsWidth)),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.info_outline,
                                  color: _isDarkCtx(context) ? Colors.white24 : Colors.black26,
                                  size: 15,
                                ),
                              ],
                            );
                          } else {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      '🔥',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$_streak ${_streak == 1 ? 'micro' : 'micro'}',
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '$doneCount/${myRoutine.length}',
                                      style: TextStyle(
                                        color: doneCount >= myRoutine.length
                                            ? Colors.orange
                                            : Colors.white38,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.info_outline,
                                      color: _isDarkCtx(context) ? Colors.white24 : Colors.black26,
                                      size: 15,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                buildIconRow(
                                  fitsFull ? fullIconsWidth : fullIconsWidth,
                                ),
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
                    color: _isDarkCtx(context) ? const Color(0xFF111113) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isToday
                          ? accent.withAlpha(120)
                          : (_isDarkCtx(context) ? Colors.white.withAlpha(15) : Colors.black12),
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
                              color: _isDarkCtx(context) ? Colors.white12 : Colors.black87.withAlpha(10),
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
                                      color: isToday ? accent : (_isDarkCtx(context) ? Colors.white : Colors.black87),
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
                                        color: _isDarkCtx(context) ? Colors.white38 : Colors.black38,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '${d.exercises.length} esercizi',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: _isDarkCtx(context) ? Colors.white38 : Colors.black38,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.repeat,
                                        size: 12,
                                        color: _isDarkCtx(context) ? Colors.white38 : Colors.black38,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '${d.exercises.fold(0, (s, ex) => s + ex.targetSets)} serie',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: _isDarkCtx(context) ? Colors.white38 : Colors.black38,
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
                                    : (_isDarkCtx(context) ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8)),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isToday
                                      ? accent.withAlpha(120)
                                      : (_isDarkCtx(context) ? Colors.white12 : Colors.black12),
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
                                    color: isToday ? accent : (_isDarkCtx(context) ? Colors.white38 : Colors.black38),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      color: isToday ? accent : (_isDarkCtx(context) ? Colors.white38 : Colors.black38),
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
                        child: _buildExPreviewList(d, accent),
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



/// Returns true if the exercise has had no weight improvement for [minSessions] consecutive recorded sessions.
bool _detectExercisePlateau(
  String exerciseName,
  List<dynamic> history, {
  int minSessions = 4,
}) {
  final sessions = <Map<String, dynamic>>[];
  for (final entry in history.reversed) {
    final name = (entry['exercise'] as String?) ?? '';
    if (name.toLowerCase().trim() != exerciseName.toLowerCase().trim()) continue;
    final series = (entry['series'] as List?) ?? [];
    if (series.isEmpty) continue;
    double maxW = 0;
    for (final s in series) {
      final w = (s['w'] as num?)?.toDouble() ?? 0.0;
      if (w > maxW) maxW = w;
    }
    if (maxW > 0) {
      sessions.add({
        'maxW': maxW,
        'date': (entry['date'] as String?) ?? '',
      });
    }
    if (sessions.length >= minSessions) break;
  }
  if (sessions.length < minSessions) return false;
  final ref = sessions.first['maxW'] as double;
  if (!sessions.every((s) => (s['maxW'] as double) <= ref)) return false;
  // Plateau only if sessions span at least 14 days
  final dates = sessions
      .map((s) {
        final d = s['date'] as String;
        return d.length >= 10 ? DateTime.tryParse(d.substring(0, 10)) : null;
      })
      .whereType<DateTime>()
      .toList();
  if (dates.length < 2) return false;
  dates.sort();
  return dates.last.difference(dates.first).inDays >= 14;
}

class WorkoutEngine extends StatefulWidget {
  final WorkoutDay day;
  final List<dynamic> history;
  final Map<String, Map<String, dynamic>> carryoverWeights;
  final List<String> allSessionNames;
  final Function(Map<String, dynamic>) onDone;
  final bool demoMode;
  const WorkoutEngine({
    super.key,
    required this.day,
    required this.history,
    required this.onDone,
    required this.allSessionNames,
    this.carryoverWeights = const {},
    this.demoMode = false,
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
  // AdMob native ads
  // Ads disabled for app_cliente per richiesta utente
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
  bool _plateauDetected = false;
  final Set<String> _shownSuggestions = {};
  // Chiave persistenza allenamento in corso
  String get _inProgressKey => 'workout_in_progress_${widget.day.dayName}';
  // Suono fine timer
  bool _timerSoundEnabled = true;
  bool _vibrationEnabled = true;
  bool _wakelockEnabled = true;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  // Generazione notifica: si incrementa ad ogni nuovo timer,
  // così la notifica precedente non si attiva se è stato riavviato
  int _notifGen = 0;
  int _timerRunId = 0;
  int _newTimerRunId() => DateTime.now().microsecondsSinceEpoch;
  // ID univoco di questa sessione di allenamento (usato per separare
  // più sessioni nello stesso giorno nei grafici)
  late final String _sessionId;
  bool _autoStartTimer = true;
  bool _confirmSeriesEnabled = true;
  bool _showWeightSuggestion = true;
  bool _displayInPounds = false;
  bool _disableWeightKeyboard = false;
  bool _awaitingFirstExerciseStart = true;

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
    _checkPlateauForWorkout();
    _loadSettings();
    _restoreInProgressWorkout();
    // Ads disabled for app_cliente
    // if (!kIsWeb) _loadWorkoutNativeAds();
    if (widget.demoMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showDemoHint());
    }
  }

  void _loadWorkoutNativeAds() {
    // Ads disabled for app_cliente per richiesta utente
  }

  Widget _buildWorkoutNativeAd() => const SizedBox.shrink();

  Widget _buildTimerNativeAd() => const SizedBox.shrink();

  Widget _buildRecapNativeAd() => const SizedBox.shrink();

  void _showDemoHint() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _isDarkCtx(context) ? const Color(0xFF121620) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('💪 Come funziona',
            style: TextStyle(color: _isDarkCtx(context) ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: Text(
          'Prima esegui la serie fisicamente.\n\nPoi inserisci il peso e le ripetizioni e premi CONFERMA SERIE per registrare il risultato.',
          style: TextStyle(color: _isDarkCtx(context) ? Colors.white70 : Colors.black87, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ho capito!',
                style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
        _displayInPounds = prefs.getBool('use_pounds') ?? false;
        _disableWeightKeyboard =
            prefs.getBool('disable_weight_keyboard') ?? false;
      });
  }

  /// Salva lo stato corrente dell'allenamento in SharedPreferences
  Future<void> _persistInProgress() async {
    if (widget.demoMode) return; // demo: non salvare stato
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
        _awaitingFirstExerciseStart = false;
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

    _timerRunId = _newTimerRunId();
    _bgTimer?.cancel();
    timerActive = false;
    _bgCounter = 0;
    _endTime = null;
    await _clearTimerNotifications();
    if (mounted) Navigator.pop(context);
  }

  Future<bool> _mostraDialogConfermaUscita() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
            title: Text(
              "Interrompere?",
              style: TextStyle(color: _isDarkCtx(context) ? Colors.white : Colors.black87),
            ),
            content: Text(
              "Vuoi davvero uscire dall'allenamento? I progressi fin qui fatti sono comunque salvati.",
              style: TextStyle(color: _isDarkCtx(context) ? Colors.white70 : Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  "ANNULLA",
                  style: TextStyle(color: _isDarkCtx(context) ? Colors.white38 : Colors.black38),
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
  Future<void> _programmaNotificaFine(int secondi, int timerRunId) async {
    ++_notifGen;
    final gen = _notifGen;
    if (kIsWeb) {
      await Future.delayed(Duration(seconds: secondi));
      if (gen != _notifGen || timerRunId != _timerRunId || _endTime == null) {
        return;
      }
      _showWebTimerNotification();
      return;
    }

    // Cancella notifica finale precedente
    try {
      await flutterLocalNotificationsPlugin.cancel(0);
      await flutterLocalNotificationsPlugin.cancel(2);
    } catch (_) {}
    try {
      await _gymFileChannel.invokeMethod('cancelTimerFinishedNotification');
    } catch (_) {}

    try {
      await _gymFileChannel.invokeMethod('scheduleTimerFinishedNotification', {
        'delayMs': secondi * 1000,
        'title': 'TORNA AD ALLENARTI!',
        'body': '',
      });
    } catch (e) {
      debugPrint("Errore notifica: $e");
    }
  }

  Future<void> _showTimerFinishedNotificationNow() async {
    if (kIsWeb) return;
    try {
      await flutterLocalNotificationsPlugin.cancel(2);
      await _gymFileChannel.invokeMethod('cancelTimerFinishedNotification');
      await flutterLocalNotificationsPlugin.show(
        0,
        'TORNA AD ALLENARTI!',
        null,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'timer_gym_alert',
            'Timer Fine Recupero',
            importance: Importance.max,
            priority: Priority.max,
            icon: 'ic_notification',
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.message,
            visibility: NotificationVisibility.public,
            ticker: 'Torna ad allenarti',
          ),
        ),
      );
    } catch (_) {}
  }

  // Aggiorna la notifica countdown nel pannello con il tempo rimanente grande (nativo)
  void _aggiornaCountdown(int remaining, int timerRunId) {
    if (kIsWeb) return;
    if (timerRunId != _timerRunId || !timerActive || _endTime == null) return;
    final mins = remaining ~/ 60;
    final secs = remaining % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    try {
      _gymFileChannel.invokeMethod('showTimerNotification', {
        'time': timeStr,
        'subtitle': '⏱ Recupero in corso',
        'channel': 'timer_gym_cd',
        'remainingSeconds': remaining,
        'token': timerRunId,
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_bgTimer != null) _bgTimer!.cancel();
    _clearTimerNotifications();
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
    _appLifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      // Only clear if timer is not active — avoids cancelling the countdown
      // notification when the user merely closes the notification shade.
      if (!timerActive) {
        _clearTimerNotifications();
      }
    }
  }

  Future<void> _clearCountdownNotification() async {
    if (kIsWeb) return;
    try {
      await flutterLocalNotificationsPlugin.cancel(0);
      await flutterLocalNotificationsPlugin.cancel(1);
      await flutterLocalNotificationsPlugin.cancel(2);
    } catch (_) {}
    try {
      await _gymFileChannel.invokeMethod('cancelCountdownNotification');
    } catch (_) {}
  }

  Future<void> _clearTimerNotifications() async {
    if (kIsWeb) {
      ++_notifGen;
      return;
    }
    ++_notifGen;
    try {
      await flutterLocalNotificationsPlugin.cancel(0);
    } catch (_) {}
    try {
      await flutterLocalNotificationsPlugin.cancel(1);
    } catch (_) {}
    try {
      await flutterLocalNotificationsPlugin.cancel(2);
    } catch (_) {}
    try {
      await _gymFileChannel.invokeMethod('cancelTimerFinishedNotification');
    } catch (_) {}
    try {
      await _gymFileChannel.invokeMethod('cancelTimerNotification');
    } catch (_) {}
  }

  void _prepareWebTimerFeedback() {
    if (!kIsWeb) return;
    try {
      js.context.callMethod('eval', [
        """
(() => {
  try {
    if ('Notification' in window && Notification.permission === 'default') {
      Notification.requestPermission();
    }
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (Ctx) {
      const ctx = window.__clientTimerAudioCtx || (window.__clientTimerAudioCtx = new Ctx());
      if (ctx.state === 'suspended') ctx.resume();
    }
  } catch (_) {}
})();
""",
      ]);
    } catch (_) {}
  }

  void _showWebTimerNotification() {
    if (!kIsWeb) return;
    final title = jsonEncode('Workout timer finished');
    final body = jsonEncode('Get back to training.');
    try {
      js.context.callMethod('eval', [
        """
(() => {
  try {
    if (!('Notification' in window)) return;
    const show = () => new Notification($title, {
      body: $body,
      tag: 'app-cliente-rest-timer',
      renotify: true,
    });
    if (Notification.permission === 'granted') {
      show();
    } else if (Notification.permission !== 'denied') {
      Notification.requestPermission().then((permission) => {
        if (permission === 'granted') show();
      });
    }
  } catch (_) {}
})();
""",
      ]);
    } catch (_) {}
  }

  void _playWebTimerBeep() {
    if (!kIsWeb) return;
    try {
      js.context.callMethod('eval', [
        """
(() => {
  try {
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return;
    const ctx = window.__clientTimerAudioCtx || (window.__clientTimerAudioCtx = new Ctx());
    const base = ctx.currentTime + 0.01;
    [740, 740, 880].forEach((freq, index) => {
      const offset = index * 0.35;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0.0001, base + offset);
      gain.gain.exponentialRampToValueAtTime(0.12, base + offset + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, base + offset + 0.28);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(base + offset);
      osc.stop(base + offset + 0.30);
    });
    if (ctx.state === 'suspended') ctx.resume();
  } catch (_) {}
})();
""",
      ]);
    } catch (_) {}
  }

  void _vibrateWebTimer() {
    if (!kIsWeb) return;
    try {
      js.context.callMethod('eval', [
        "try { if (navigator.vibrate) navigator.vibrate([0, 500, 200, 500, 200, 500]); } catch (_) {}",
      ]);
    } catch (_) {}
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
        backgroundColor: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
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
                      style: TextStyle(
                        color: _isDarkCtx(context) ? Colors.white54 : Colors.black54,
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
                                style: TextStyle(
                                  color: _isDarkCtx(context) ? Colors.white38 : Colors.black38,
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
                    Divider(color: _isDarkCtx(context) ? Colors.white12 : Colors.black12, height: 20),
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
          backgroundColor: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
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
                Divider(color: _isDarkCtx(context) ? Colors.white24 : Colors.black26),
                const SizedBox(height: 8),
                _recapRow(
                  Icons.fitness_center,
                  'Esercizi',
                  '${_allCompletedExercises.length}',
                ),
                _recapRow(Icons.repeat, 'Serie totali', '$totalSeries'),
                const SizedBox(height: 8),
                Divider(color: _isDarkCtx(context) ? Colors.white24 : Colors.black26),
                const SizedBox(height: 8),
                // Streak progress section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isDarkCtx(context) ? const Color(0xFF252527) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _currentStreak > 0
                          ? Colors.orange.withAlpha(80)
                          : (_isDarkCtx(context) ? Colors.white12 : Colors.black12),
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
                              'Sessione sbloccata! $_streakDoneCount/$_streakTotalCount questo microciclo',
                              style: TextStyle(
                                color: _isDarkCtx(context) ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.allSessionNames.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (ctx, constraints) {
                            final n = widget.allSessionNames.length;
                            final iconSize = n > 0
                                ? (constraints.maxWidth / n - 8).clamp(
                                    18.0,
                                    48.0,
                                  )
                                : 48.0;
                            return Row(
                              children: List.generate(n, (i) {
                                final name = widget.allSessionNames[i];
                                final done = _streakDoneNames.contains(name);
                                return Expanded(
                                  child: Center(
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      width: iconSize,
                                      height: iconSize,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(7),
                                        gradient: done
                                            ? const LinearGradient(
                                                colors: [
                                                  Color(0xFFFF6B00),
                                                  Color(0xFFFFAB00),
                                                ],
                                              )
                                            : null,
                    color: done
                                            ? null
                                            : (_isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.black.withAlpha(20)),
                                        boxShadow: done
                                            ? [
                                                BoxShadow(
                                                  color: Colors.orange
                                                      .withAlpha(80),
                                                  blurRadius: 6,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(7),
                                        child: Opacity(
                                          opacity: done ? 1.0 : 0.2,
                                          child: Image.asset(
                                            'assets/icon_client.png',
                                            fit: BoxFit.cover,
                                          ),
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
                      if (_streakDoneCount >= _streakTotalCount &&
                          _streakTotalCount > 0)
                        const Text(
                          '🔥 Microciclo completato! La streak continua!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        )
                      else
                        Text(
                          'Completa ancora ${_streakTotalCount - _streakDoneCount} session${_streakTotalCount - _streakDoneCount == 1 ? 'e' : 'i'} per non perdere la streak!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isDarkCtx(context) ? Colors.white60 : Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      if (_currentStreak > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          '🔥 $_currentStreak ${_currentStreak == 1 ? 'micro' : 'micro'} di fila!',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.day.dayName,
                  style: TextStyle(color: _isDarkCtx(context) ? Colors.white38 : Colors.black38, fontSize: 12),
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
            if (!kIsWeb)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.share_rounded),
                  label: const Text(
                    'Condividi allenamento',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(c).colorScheme.primary,
                    side: BorderSide(color: Theme.of(c).colorScheme.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _shareWorkoutResult(c),
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
          child: Text(label, style: TextStyle(color: _isDarkCtx(context) ? Colors.white60 : Colors.black54)),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: _isDarkCtx(context) ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );

  String _todayLabel() {
    final now = DateTime.now();
    const months = ['gen','feb','mar','apr','mag','giu','lug','ago','set','ott','nov','dic'];
    return '${now.day} ${months[now.month - 1]}';
  }

  Future<void> _shareWorkoutResult(BuildContext ctx) async {
    double? progressPct;
    if (_previousResults.isNotEmpty && _allCompletedExercises.isNotEmpty) {
      double totalDelta = 0;
      int matchCount = 0;
      for (final ex in _allCompletedExercises) {
        final currSeries = (ex['series'] as List);
        final prevSeries = _previousResults[ex['exercise']] ?? [];
        if (currSeries.isEmpty || prevSeries.isEmpty) continue;
        double bestCW = 0, bestCR = 0;
        for (final s in currSeries) {
          final w = (s['w'] ?? 0.0).toDouble();
          final r = (s['r'] ?? 0.0).toDouble();
          if (w > bestCW) { bestCW = w; bestCR = r; }
        }
        double bestPW = 0, bestPR = 0;
        for (final s in prevSeries) {
          final w = (s['w'] ?? 0.0).toDouble();
          final r = (s['r'] ?? 0.0).toDouble();
          if (w > bestPW) { bestPW = w; bestPR = r; }
        }
        final weightUp = bestCW > bestPW;
        final effCR = weightUp ? (bestCR < bestPR ? bestCR : bestPR) : bestCR;
        final effPR = weightUp ? (bestPR < bestCR ? bestPR : bestCR) : bestPR;
        final ec = effCR > 0 ? bestCW * (1 + effCR / (30.0 + bestCW / 10.0)) : bestCW;
        final ep = effPR > 0 ? bestPW * (1 + effPR / (30.0 + bestPW / 10.0)) : bestPW;
        if (ep > 0) {
          totalDelta += (ec - ep) / ep;
          matchCount++;
        }
      }
      if (matchCount > 0) progressPct = totalDelta / matchCount * 100;
    }
    await showModalBottomSheet(
      useSafeArea: true,
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => _WorkoutShareSheet(
        dayName: widget.day.dayName,
        todayLabel: _todayLabel(),
        exercises: List.from(_allCompletedExercises),
        streak: _currentStreak,
        accent: Theme.of(ctx).colorScheme.primary,
        streakDoneNames: Set<String>.from(_streakDoneNames),
        progressPercent: progressPct,
        allSessionNames: List<String>.from(widget.allSessionNames),
      ),
    );
  }

  // Avvia il timer al primo tocco — se è già attivo non fa nulla
  void _avviaTimerSeNonAttivo(int sec) {
    if (timerActive) return; // già in corso, non azzerare
    _triggerTimer(sec, force: true);
  }

  // Avvia timer con il tempo specificato; se il timer è attivo con tempo diverso, lo sostituisce
  void _avviaTimerConTempo(int sec) {
    if (timerActive && _maxTime == sec) return;
    _bgTimer?.cancel();
    timerActive = false;
    setState(() { _maxTime = sec; });
    _avviaTimerSeNonAttivo(sec);
  }

  // Pre-avvia il timer di pausa inter-esercizio se siamo sull'ultima serie
  void _avviaPausaSeUltimaSerie() {
    if (!mounted || isRestingFullScreen) return;
    final ex = widget.day.exercises[exI];
    if (setN < ex.targetSets) return;
    if (eserciziCompletati.contains(ex.name)) return;
    if (ex.supersetGroup > 0) return;
    final pause = ex.interExercisePause > 0 ? ex.interExercisePause : 120;
    _avviaTimerConTempo(pause);
  }

  // Cambia esercizio corrente (accessibile anche da _buildRestUI)
  void _cambiaEsercizioMethod(int nuovoIndice) {
    _shownSuggestions.clear();
    setState(() {
      widget.day.exercises[exI].results = List.from(currentExSeries);
      exI = nuovoIndice;
      var nuovoEx = widget.day.exercises[exI];
      currentExSeries = List.from(nuovoEx.results);
      if (eserciziCompletati.contains(nuovoEx.name)) {
        setN = nuovoEx.targetSets;
      } else {
        setN = currentExSeries.length + 1;
      }
    });
    _setDrumValues(nuovoIndice, setN);
  }

  void _triggerTimer(int sec, {bool force = false}) {
    // Se il timer è già attivo e NON stiamo forzando, usciamo subito
    // SENZA cancellare il timer che sta correndo.
    if (timerActive && !force) return;
    if (!_autoStartTimer && !force) return;
    _prepareWebTimerFeedback();

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

    final timerRunId = _newTimerRunId();
    _timerRunId = timerRunId;

    // 2. Programmiamo la notifica finale (Future.delayed) e mostriamo countdown
    _programmaNotificaFine(sec, timerRunId);
    _aggiornaCountdown(
      sec,
      timerRunId,
    ); // countdown iniziale nel pannello notifiche

    // 3. Timer visivo
    _bgTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timerRunId != _timerRunId || _endTime == null) {
        t.cancel();
        return;
      }

      final remaining = _endTime!.difference(DateTime.now()).inSeconds;

      if (remaining <= 0) {
        _clearCountdownNotification();
        if (_appLifecycleState == AppLifecycleState.resumed) {
          _showTimerFinishedNotificationNow();
        }
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
        // Aggiorna la notifica countdown ogni secondo per il timer in background
        _aggiornaCountdown(remaining, timerRunId);
      }
    });
  }

  // Suono di avviso tramite ToneGenerator nativo Android — campanella bassa x3
  Future<void> _playBeep() async {
    if (kIsWeb) {
      _playWebTimerBeep();
      return;
    }
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
      _showWebTimerNotification();
      if (_timerSoundEnabled) _playWebTimerBeep();
      if (_vibrationEnabled) _vibrateWebTimer();
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
    _setExerciseWeightMode(
      currentEx,
      useQuarterStep: _usesQuarterStepForExercise(currentEx, w),
      useEvenStep: _usesEvenStepForExercise(currentEx, w),
      useSingleStep: _usesSingleStepForExercise(currentEx, w),
    );
    if (!_confirmSeriesEnabled) {
      _saveSet();
      return;
    }

    // Start rest timer immediately so the chip appears on screen during the popup
    final bool _isLastSet = setN >= currentEx.targetSets;
    final int _timerSec = _isLastSet
        ? (currentEx.interExercisePause > 0 ? currentEx.interExercisePause : 120)
        : (currentEx.recoveryTime > 0 ? currentEx.recoveryTime : 90);
    _avviaTimerSeNonAttivo(_timerSec);

    showModalBottomSheet(
      useSafeArea: true,
      isScrollControlled: true,
      context: context,
      backgroundColor: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24 +
              [
                MediaQuery.of(ctx).padding.bottom,
                MediaQuery.of(ctx).viewPadding.bottom,
                64.0, // floor: alcuni device (es. Samsung One UI) riportano inset 0/errato per la nav bar
              ].reduce(scala.max),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _isDarkCtx(context) ? Colors.white24 : Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      currentEx.name.toUpperCase(),
                      style: TextStyle(
                        color: _isDarkCtx(context) ? Colors.white54 : Colors.black54,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Serie $setN",
                      style: TextStyle(color: _isDarkCtx(context) ? Colors.white38 : Colors.black38, fontSize: 13),
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
                  ],
                ),
              ),
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
                      side: BorderSide(color: _isDarkCtx(context) ? Colors.white24 : Colors.black26),
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

  bool _usesQuarterStepForExercise(ExerciseConfig ex, double fallbackWeight) {
    if (ex.useQuarterStep || ex.useEvenStep || ex.useSingleStep) {
      return ex.useQuarterStep;
    }
    return usesQuarterStepIncrement(fallbackWeight);
  }

  bool _usesEvenStepForExercise(ExerciseConfig ex, double fallbackWeight) {
    if (ex.useQuarterStep || ex.useEvenStep || ex.useSingleStep) {
      return ex.useEvenStep;
    }
    if (_usesQuarterStepForExercise(ex, fallbackWeight)) return false;
    return usesEvenStepIncrement(fallbackWeight);
  }

  bool _usesSingleStepForExercise(ExerciseConfig ex, double fallbackWeight) {
    if (ex.useQuarterStep || ex.useEvenStep || ex.useSingleStep) {
      return ex.useSingleStep;
    }
    if (_usesQuarterStepForExercise(ex, fallbackWeight) ||
        _usesEvenStepForExercise(ex, fallbackWeight)) {
      return false;
    }
    return !_displayInPounds && usesSingleStepIncrement(fallbackWeight);
  }

  void _setExerciseWeightMode(
    ExerciseConfig ex, {
    required bool useQuarterStep,
    required bool useEvenStep,
    required bool useSingleStep,
  }) {
    setState(() {
      ex.useQuarterStep = useQuarterStep;
      ex.useEvenStep = !useQuarterStep && useEvenStep;
      ex.useSingleStep = !useQuarterStep && !useEvenStep && useSingleStep;
    });
    _aggiornaJsonSuDisco();
  }

  String _formatWeightLabel(double kg) =>
      '${formatWeightValue(kg, usePounds: _displayInPounds)} ${_displayInPounds ? 'lb' : 'kg'}';

  bool get _showWorkoutReadyScreen =>
      _awaitingFirstExerciseStart &&
      currentExSeries.isEmpty &&
      widget.day.exercises.isNotEmpty &&
      !eserciziCompletati.contains(widget.day.exercises[exI].name);

  Widget _buildWorkoutReadyScreen(
    ExerciseConfig ex,
    double lastW,
    int lastR,
    bool suggerisciAumento,
    bool suggerisciReps,
    int targetR,
    Color accent,
  ) {
    final info =
        (ex.gifFilename != null ? findByGifSlug(ex.gifFilename!) : null) ??
        findAnyExercise(ex.name);
    final gifPath = ex.gifFilename != null
        ? exerciseAnimationAssetPath(ex.gifFilename!)
        : info != null
        ? exerciseAnimationAssetPath(info.gifSlug)
        : null;
    final canGoPrev = exI > 0;
    final canGoNext = exI < widget.day.exercises.length - 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _isDarkCtx(context) ? Colors.white10 : Colors.black12),
            ),
            child: Column(
              children: [
                Text(
                  exI == 0
                      ? 'Preparati al primo esercizio'
                      : 'Preparati a questo esercizio',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  ex.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isDarkCtx(context) ? Colors.white : Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    IconButton(
                      onPressed: canGoPrev ? () => setState(() => exI--) : null,
                      icon: Icon(Icons.chevron_left, color: _isDarkCtx(context) ? Colors.white : Colors.black87),
                    ),
                    Expanded(
                      child: gifPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.asset(
                                gifPath,
                                height: 220,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.fitness_center,
                                  size: 72,
                                  color: _isDarkCtx(context) ? Colors.white24 : Colors.black26,
                                ),
                              ),
                            )
                          : SizedBox(
                              height: 220,
                              child: Center(
                                child: Icon(
                                  Icons.fitness_center,
                                  size: 72,
                                  color: _isDarkCtx(context) ? Colors.white24 : Colors.black26,
                                ),
                              ),
                            ),
                    ),
                    IconButton(
                      onPressed: canGoNext ? () => setState(() => exI++) : null,
                      icon: Icon(
                        Icons.chevron_right,
                        color: _isDarkCtx(context) ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (lastW > 0) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_rounded, size: 11,
                        color: _isDarkCtx(context) ? Colors.white38 : Colors.black38),
                      const SizedBox(width: 4),
                      Text(AppL.lastTime,
                        style: TextStyle(
                          color: _isDarkCtx(context) ? Colors.white38 : Colors.black38,
                          fontSize: 11,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withAlpha(30),
                          border: Border.all(color: const Color(0xFFFFD700).withAlpha(180), width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${lastW % 1 == 0 ? lastW.toInt() : lastW} kg',
                          style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: accent.withAlpha(30),
                          border: Border.all(color: accent.withAlpha(180), width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('$lastR reps',
                          style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      if (suggerisciReps && _showWeightSuggestion)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(30),
                            border: Border.all(color: Colors.green.withAlpha(180), width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(AppL.tryReps(targetR + 2),
                            style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      if (suggerisciAumento && _showWeightSuggestion)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.amber.withAlpha(30),
                            border: Border.all(color: Colors.amber.withAlpha(180), width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('↑ AUMENTA PESO',
                            style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),

                ],
                if (ex.notePT.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'COACH: ${ex.notePT}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (suggerisciAumento) _showSuggestionOverlay(isWeight: true, targetReps: targetR);
                      else if (suggerisciReps) _showSuggestionOverlay(isWeight: false, targetReps: targetR);
                      setState(() {
                        _awaitingFirstExerciseStart = false;
                      });
                      _setDrumValues(exI, setN);
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      exI == 0
                          ? 'Inizia il primo esercizio'
                          : 'Inizia da questo esercizio',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
    _awaitingFirstExerciseStart = false;

    final currentEx = widget.day.exercises[exI];

    // Controlla record personale rispetto all'ultima sessione
    final suggest = _getSuggest(currentEx.name, setN);
    final lastW = (suggest['w'] as num?)?.toDouble() ?? 0.0;
    final lastR = (suggest['r'] as num?)?.toInt() ?? 0;
    setState(
      () => _isNewRecord = (lastW > 0 || lastR > 0) && (w > lastW || r > lastR),
    );
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
          await _clearTimerNotifications();
          if (widget.demoMode) {
            if (mounted) Navigator.of(context).pop();
            return;
          }
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
          final newStreak = await updateStreakCliente(
            widget.day.dayName,
            widget.allSessionNames,
          );
          final sData = await getStreakDataCliente();
          scheduleStreakReminderCliente(force: true); // reset reminder: prossimo in 48h
          if (mounted)
            setState(() {
              _currentStreak = newStreak;
              _streakDoneCount = sData.done.length;
              _streakTotalCount = widget.allSessionNames.length;
              _streakDoneNames = sData.done;
            });
          if (mounted) _showRecapDialog();
          return; // Non salvare stato dopo workout completato
        } else if (_nextPendingExerciseIndex(fromExclusive: groupEnd)
            case final nextIndex?) {
          final pause = widget.day.exercises[groupEnd].interExercisePause > 0
              ? widget.day.exercises[groupEnd].interExercisePause
              : 120;
          setState(() {
            exI = nextIndex;
            setN = 1;
            currentExSeries = [];
            isRestingFullScreen = true;
            _isNewRecord = false;
          });
          _setDrumValues(nextIndex, 1);
          _avviaTimerConTempo(pause);
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
        await _clearTimerNotifications();
        if (widget.demoMode) {
          // Demo: non salvare dati, non aggiornare streak, tornare indietro
          if (mounted) Navigator.of(context).pop();
          return;
        }
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
        final newStreak = await updateStreakCliente(
          widget.day.dayName,
          widget.allSessionNames,
        );
        final sData = await getStreakDataCliente();
        scheduleStreakReminderCliente(force: true); // reset reminder: prossimo in 48h
        if (mounted)
          setState(() {
            _currentStreak = newStreak;
            _streakDoneCount = sData.done.length;
            _streakTotalCount = widget.allSessionNames.length;
            _streakDoneNames = sData.done;
          });
        if (mounted) _showRecapDialog();
        return; // Non salvare stato dopo workout completato
      } else if (_nextPendingExerciseIndex(fromExclusive: exI)
          case final nextIndex?) {
        final pauseTime = currentEx.interExercisePause > 0
            ? currentEx.interExercisePause
            : 120;
        setState(() {
          isRestingFullScreen = true;
          exI = nextIndex;
          setN = 1;
          currentExSeries = [];
          _isNewRecord = false;
        });
        _setDrumValues(nextIndex, 1);
        _avviaTimerConTempo(pauseTime);
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

  Future<void> _skipRest() async {
    ++_notifGen; // previene notifica Future.delayed pendente
    _timerRunId = _newTimerRunId();
    _bgTimer?.cancel();
    setState(() {
      isRestingFullScreen = false;
      timerActive = false;
      _bgCounter = 0;
      _endTime = null;
    });
    await _clearTimerNotifications();
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
            Text(
              "I dati sono stati salvati e non sono più modificabili.",
              textAlign: TextAlign.center,
              style: TextStyle(color: _isDarkCtx(context) ? Colors.white38 : Colors.black38, fontSize: 12),
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
    } else if (_nextPendingExerciseIndex(fromExclusive: exI)
        case final nextIndex?) {
      var prossimoEs = widget.day.exercises[nextIndex];
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
    final _sugg = _computeSuggestions(ex, setN, lastR, targetR);
    bool suggerisciAumento = _sugg['aumento']!;
    bool suggerisciReps = _sugg['reps']!;
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
        if (conferma) {
          _bgTimer?.cancel();
          timerActive = false;
          _bgCounter = 0;
          _endTime = null;
          await _clearTimerNotifications();
          if (mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // FRECCIA SINISTRA
              IconButton(
                icon: Icon(Icons.chevron_left, color: _isDarkCtx(context) ? Colors.white : Colors.black87),
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
                      style: TextStyle(
                        color: _isDarkCtx(context) ? Colors.white : Colors.black87,
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
                icon: Icon(Icons.chevron_right, color: _isDarkCtx(context) ? Colors.white : Colors.black87),
                onPressed: exI < widget.day.exercises.length - 1
                    ? () => _cambiaEsercizio(exI + 1)
                    : null,
              ),
            ],
          ),
          leading: IconButton(
            icon: Icon(Icons.close, color: _isDarkCtx(context) ? Colors.white : Colors.black87),
            onPressed: () async {
              bool conferma = await _mostraDialogConfermaUscita();
              if (conferma) {
                _bgTimer?.cancel();
                timerActive = false;
                _bgCounter = 0;
                _endTime = null;
                await _clearTimerNotifications();
                if (mounted) Navigator.pop(context);
              }
            },
          ),
          actions: const [],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showWorkoutReadyScreen
              ? null
              : () => _triggerTimer(timeToUse, force: false),
          child: Column(
            children: [
              // Demo mode banner handled via popup in initState
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
                              Icon(
                                Icons.link,
                                color: _isDarkCtx(context) ? Colors.white : Colors.black87,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'SUPERSERIE ${ex.supersetGroup}',
                                style: TextStyle(
                                  color: _isDarkCtx(context) ? Colors.white : Colors.black87,
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

              if (_showWorkoutReadyScreen)
                Expanded(
                  child: _buildWorkoutReadyScreen(
                    ex,
                    lastW,
                    lastR,
                    suggerisciAumento,
                    suggerisciReps,
                    targetR,
                    accent,
                  ),
                )
              else ...[
                _buildInfoPanel(
                  ex,
                  lastW,
                  lastR,
                  suggerisciAumento,
                  accent,
                  timeToUse,
                  targetR,
                  suggerisciReps,
                ),
                _buildWorkoutNativeAd(),
              
                if (giaFatto)
                  Expanded(child: Center(child: _buildBoxEsercizioCompletato()))
                else
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _DrumPickers(
                            key: ValueKey('drum_$exI'),
                            initialKg: lastW <= 0 ? 20.0 : lastW,
                            initialReps: targetR,
                            suggerisciAumento:
                                suggerisciAumento && _showWeightSuggestion,
                            useQuarterStep: _usesQuarterStepForExercise(ex, lastW),
                            useEvenStep: _usesEvenStepForExercise(ex, lastW),
                            useSingleStep: _usesSingleStepForExercise(ex, lastW),
                            displayInPounds: _displayInPounds,
                            allowKeyboardInput: !_disableWeightKeyboard,
                            accent: accent,
                            onKgChanged: (v) =>
                                wC.text = formatWeightValue(v, maxDecimals: 2),
                            onRepsChanged: (v) {
                              rC.text = v.toString();
                            },
                            onWeightModeChanged:
                                (useQuarterStep, useEvenStep, useSingleStep) {
                                  _setExerciseWeightMode(
                                    ex,
                                    useQuarterStep: useQuarterStep,
                                    useEvenStep: useEvenStep,
                                    useSingleStep: useSingleStep,
                                  );
                                },
                            onInteraction: () => _avviaTimerConTempo(timeToUse),
                          ),
                        ),
                        if (!giaFatto && timerActive)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: _buildFloatingTimerChip(accent),
                          ),
                      ],
                    ),
                  ),
                if (!giaFatto)
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      12,
                      24,
                      scala.max(
                            MediaQuery.of(context).padding.bottom,
                            MediaQuery.of(context).viewPadding.bottom,
                          ) +
                          16,
                    ),
                    decoration: BoxDecoration(
                      color: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: _isDarkCtx(context) ? Colors.white12 : Colors.black12,
                          width: 1,
                        ),
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
            ],
          ),
        ), // closes GestureDetector (body)
      ), // closes Scaffold
    ); // chiude PopScope
  }

  Widget _buildFloatingTimerChip(Color accent) {
    final int s = _bgCounter;
    final String label = s >= 60
        ? '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}'
        : '$s s';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: accent.withAlpha(230),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  _bgTimer?.cancel();
                  setState(() { timerActive = false; _bgCounter = 0; _endTime = null; });
                  _clearTimerNotifications();
                },
                child: const Icon(Icons.close, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
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
    wC.text = formatWeightValue(kg);
    rC.text = tR.toString();
  }

  int? _nextPendingExerciseIndex({int fromExclusive = -1}) {
    for (int i = fromExclusive + 1; i < widget.day.exercises.length; i++) {
      if (!eserciziCompletati.contains(widget.day.exercises[i].name)) return i;
    }
    for (
      int i = 0;
      i <= fromExclusive && i < widget.day.exercises.length;
      i++
    ) {
      if (!eserciziCompletati.contains(widget.day.exercises[i].name)) return i;
    }
    return null;
  }

  void _showSuggestionOverlay({required bool isWeight, required int targetReps, bool force = false}) {
    final key = isWeight ? 'peso_\${exI}_\${currentExSeries.length}' : 'reps_\${exI}_\${currentExSeries.length}';
    if (!force && _shownSuggestions.contains(key)) return;
    _shownSuggestions.add(key);
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (ctx) => _SuggestionOverlay(
        isWeight: isWeight,
        targetReps: targetReps,
        onDismiss: () { entry?.remove(); },
      ),
    );
    Overlay.of(context).insert(entry);
  }

  void _showNewRecordOverlay() {
    HapticFeedback.heavyImpact();
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _RecordOverlay(
        lang: 'it',
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1200), () {
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
    int targetR,
    bool suggerisciReps,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _isDarkCtx(context) ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lastW > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded, size: 11,
                  color: _isDarkCtx(context) ? Colors.white38 : Colors.black38),
                const SizedBox(width: 4),
                Text(AppL.lastTime,
                  style: TextStyle(
                    color: _isDarkCtx(context) ? Colors.white38 : Colors.black38,
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withAlpha(30),
                    border: Border.all(color: const Color(0xFFFFD700).withAlpha(180), width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${lastW % 1 == 0 ? lastW.toInt() : lastW} kg',
                    style: const TextStyle(color: Color(0xFFFFD700), fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: accent.withAlpha(30),
                    border: Border.all(color: accent.withAlpha(180), width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$lastR reps',
                    style: TextStyle(color: accent, fontSize: 17, fontWeight: FontWeight.bold)),
                ),

              ],
            ),
          ],

          if (suggerisciAumento || suggerisciReps) ...[
            GestureDetector(
              onTap: () => _showSuggestionOverlay(
                isWeight: suggerisciAumento,
                targetReps: targetR,
                force: true,
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: (suggerisciAumento ? const Color(0xFFFF7043) : const Color(0xFF00B0FF)).withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: suggerisciAumento ? const Color(0xFFFF7043) : const Color(0xFF00B0FF), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(suggerisciAumento ? Icons.trending_up : Icons.add, size: 16,
                      color: suggerisciAumento ? const Color(0xFFFF7043) : const Color(0xFF00B0FF)),
                    const SizedBox(width: 5),
                    Text(suggerisciAumento ? 'Aumenta peso' : 'Aumenta reps',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: suggerisciAumento ? const Color(0xFFFF7043) : const Color(0xFF00B0FF))),
                  ],
                ),
              ),
            ),
          ],
          if (ex.notePT.isNotEmpty) ...[
            if (lastW > 0) Divider(color: _isDarkCtx(context) ? Colors.white10 : Colors.black12, height: 10),
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
          Divider(color: _isDarkCtx(context) ? Colors.white10 : Colors.black12, height: 10),
          TextField(
            style: TextStyle(fontSize: 12, color: _isDarkCtx(context) ? Colors.white54 : Colors.black54),
            decoration: InputDecoration(
              hintText: 'Le mie note...',
              hintStyle: TextStyle(color: _isDarkCtx(context) ? Colors.white24 : Colors.black26, fontSize: 12),
              prefixIcon: Icon(
                Icons.edit_note,
                size: 16,
                color: _isDarkCtx(context) ? Colors.white24 : Colors.black26,
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
              _avviaTimerConTempo(timeToUse > 0 ? timeToUse : 60);
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
    final info =
        (gifFilename != null ? findByGifSlug(gifFilename) : null) ??
        findAnyExercise(exName);
    final gifPath = gifFilename != null
        ? exerciseAnimationAssetPath(gifFilename)
        : info != null
        ? exerciseAnimationAssetPath(info.gifSlug)
        : null;

    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      backgroundColor: _isDarkCtx(context) ? const Color(0xFF0E0E10) : Colors.white,
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
                    color: _isDarkCtx(context) ? Colors.white12 : Colors.black12,
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
                    (info?.nameEn ?? exName).toUpperCase(),
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
                style: TextStyle(
                  color: _isDarkCtx(context) ? Colors.white38 : Colors.black38,
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
                        muscleAssetPath(info.muscleImages[i]),
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
                  color: _isDarkCtx(context) ? Colors.white.withAlpha(7) : Colors.black87.withAlpha(7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _isDarkCtx(context) ? Colors.white10 : Colors.black12),
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
                            style: TextStyle(
                              color: _isDarkCtx(context) ? Colors.white : Colors.black87,
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
                  color: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.black12.withAlpha(10),
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
                      style: TextStyle(
                        color: _isDarkCtx(context) ? Colors.white : Colors.black87,
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
                      style: TextStyle(
                        color: _isDarkCtx(context) ? Colors.white : Colors.black87,
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
                  color: _isDarkCtx(context) ? Colors.white.withAlpha(5) : Colors.black87.withAlpha(5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Esercizio non in catalogo.',
                  style: TextStyle(color: _isDarkCtx(context) ? Colors.white38 : Colors.black38, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Calcola i suggerimenti per la serie corrente.
  /// - suggerisciAumento: le reps dell'ultima volta per questa serie superano il target
  /// - suggerisciReps: in una sessione precedente una serie successiva ha superato il target,
  ///   quindi suggerisci +2 reps su questa serie (a meno che il corrente non abbia già fatto più reps)
  void _checkPlateauForWorkout() {
    // Group by session_id (falls back to date) so all exercises in one workout = one session.
    final Map<String, Map<String, List<Map<String, dynamic>>>> byDate = {};
    for (final h in widget.history) {
      final entry = h as Map<String, dynamic>;
      final sid = (entry['session_id'] as String?)?.isNotEmpty == true
          ? entry['session_id'] as String
          : (entry['date'] as String?) ?? '';
      final exName = (entry['exercise'] as String?) ?? '';
      if (sid.isEmpty || exName.isEmpty) continue;
      byDate.putIfAbsent(sid, () => {});
      final rawSeries = entry['series'];
      if (rawSeries is List) {
        byDate[sid]![exName] =
            rawSeries.map((s) => Map<String, dynamic>.from(s as Map)).toList();
      }
    }
    final sortedDates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    if (sortedDates.length < 2) { _plateauDetected = false; return; }
    bool anyImprovement = false;
    final sess1 = byDate[sortedDates[0]]!;
    final sess2 = byDate[sortedDates[1]]!;
    for (final exName in sess1.keys) {
      final s1 = sess1[exName] ?? [];
      final s2 = sess2[exName] ?? [];
      if (s2.isEmpty) continue;
      double maxW1 = 0, maxW2 = 0;
      int maxR1 = 0, maxR2 = 0;
      for (final s in s1) {
        final w = ((s['w'] ?? s['weight'] ?? 0) as num).toDouble();
        final r = ((s['r'] ?? s['reps'] ?? 0) as num).toInt();
        if (w > maxW1) maxW1 = w;
        if (r > maxR1) maxR1 = r;
      }
      for (final s in s2) {
        final w = ((s['w'] ?? s['weight'] ?? 0) as num).toDouble();
        final r = ((s['r'] ?? s['reps'] ?? 0) as num).toInt();
        if (w > maxW2) maxW2 = w;
        if (r > maxR2) maxR2 = r;
      }
      if (maxW1 > maxW2 || maxR1 > maxR2) { anyImprovement = true; break; }
    }
    _plateauDetected = !anyImprovement;
  }


  Map<String, bool> _computeSuggestions(ExerciseConfig ex, int setN, int lastR, int targetR) {
    bool suggerisciAumento = _plateauDetected && lastR > targetR && lastR > 0;

    // Trova la serie con numero più alto (della sessione precedente) dove le reps hanno superato il target
    int? repsTriggerSet;
    for (int sn = ex.targetSets; sn >= 1; sn--) {
      final tgt = ex.repsList.isNotEmpty
          ? (sn <= ex.repsList.length ? ex.repsList[sn - 1] : ex.repsList.last)
          : 10;
      final prevSug = _getSuggest(ex.name, sn);
      final pr = (prevSug['r'] as num?)?.toInt() ?? 0;
      if (pr > tgt && pr > 0) {
        repsTriggerSet = sn;
        break;
      }
    }

    bool suggerisciReps = false;
    if (!suggerisciAumento && repsTriggerSet != null && setN < repsTriggerSet) {
      // Controlla se nell'allenamento corrente è già stata fatta una serie con più reps del target
      final currentHasHigherReps = currentExSeries.any((s) {
        final sn2 = (s['s'] as num?)?.toInt() ?? 0;
        final r2 = (s['r'] as num?)?.toInt() ?? 0;
        if (sn2 <= 0) return false;
        final tgt2 = ex.repsList.isNotEmpty
            ? (sn2 <= ex.repsList.length ? ex.repsList[sn2 - 1] : ex.repsList.last)
            : 10;
        return r2 > tgt2;
      });
      if (currentHasHigherReps) {
        suggerisciAumento = true; // già fatte più reps → suggerisci aumento peso
      } else {
        suggerisciReps = true;
      }
    }

    return {'aumento': suggerisciAumento, 'reps': suggerisciReps};
  }

  Widget _buildRestUI() {
    var ex = widget.day.exercises[exI];
    var suggest = _getSuggest(ex.name, setN);
    // Auto-show suggestion overlay when rest timer starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final suggDelay = _isNewRecord ? const Duration(milliseconds: 1400) : Duration.zero;
      Future.delayed(suggDelay, () {
        if (!mounted) return;
        final _s2 = _computeSuggestions(ex, setN,
            (suggest['r'] as num?)?.toInt() ?? 0,
            ex.repsList.isNotEmpty ? (setN <= ex.repsList.length ? ex.repsList[setN-1] : ex.repsList.last) : 10);
        if (_s2['aumento']!) _showSuggestionOverlay(isWeight: true, targetReps: ex.repsList.isNotEmpty ? (setN <= ex.repsList.length ? ex.repsList[setN-1] : ex.repsList.last) : 10);
        else if (_s2['reps']!) _showSuggestionOverlay(isWeight: false, targetReps: ex.repsList.isNotEmpty ? (setN <= ex.repsList.length ? ex.repsList[setN-1] : ex.repsList.last) : 10);
      });
    });
    double lastW = (suggest['w'] as num?)?.toDouble() ?? 0.0;
    int lastR = (suggest['r'] as num?)?.toInt() ?? 0;

    int targetR = ex.repsList.isNotEmpty
        ? (setN <= ex.repsList.length
              ? ex.repsList[setN - 1]
              : ex.repsList.last)
        : 10;
    bool suggerisciAumento = lastR > targetR && lastR > 0;
    final _sugg2 = _computeSuggestions(ex, setN, lastR, targetR);
    suggerisciAumento = _sugg2['aumento']!;
    bool suggerisciReps = _sugg2['reps']!;

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
        ? exerciseAnimationAssetPath(prossimoConfig!.gifFilename!)
        : prossimoInfo != null
        ? exerciseAnimationAssetPath(prossimoInfo.gifSlug)
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
                color: _isDarkCtx(context) ? Colors.white : Colors.black87.withAlpha(80),
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
                  final ringSize = (constraints.maxHeight * 0.85).clamp(
                    80.0,
                    320.0,
                  );
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
                            color: _isDarkCtx(context) ? Colors.white : Colors.black87,
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
                    // Navigazione esercizio durante riposo inter-esercizio - solo prima della prima serie
                    if (widget.day.exercises.length > 1 && setN == 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.chevron_left_rounded,
                              color: _isDarkCtx(context) ? Colors.white : Colors.black87.withAlpha(80),
                              size: 34,
                            ),
                            onPressed: () {
                              final total = widget.day.exercises.length;
                              int c = (exI - 1 + total) % total;
                              for (int i = 0; i < total - 1; i++) {
                                if (!eserciziCompletati.contains(widget.day.exercises[c].name)) break;
                                c = (c - 1 + total) % total;
                              }
                              if (c != exI) _cambiaEsercizioMethod(c);
                            },
                          ),
                          Text(
                            'CAMBIA ESERCIZIO',
                            style: TextStyle(
                              color: _isDarkCtx(context) ? Colors.white : Colors.black87.withAlpha(60),
                              fontSize: 10,
                              letterSpacing: 2,
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.chevron_right_rounded,
                              color: _isDarkCtx(context) ? Colors.white : Colors.black87.withAlpha(80),
                              size: 34,
                            ),
                            onPressed: () {
                              final total = widget.day.exercises.length;
                              int c = (exI + 1) % total;
                              for (int i = 0; i < total - 1; i++) {
                                if (!eserciziCompletati.contains(widget.day.exercises[c].name)) break;
                                c = (c + 1) % total;
                              }
                              if (c != exI) _cambiaEsercizioMethod(c);
                            },
                          ),
                        ],
                      ),
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
                          color: _isDarkCtx(context) ? Colors.white.withAlpha(8) : Colors.black87.withAlpha(8),
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
                                  AppL.nextInfo,
                                  style: TextStyle(
                                    color: _isDarkCtx(context) ? Colors.white : Colors.black87.withAlpha(70),
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
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        _infoProssimo,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 3,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: accent.withAlpha(210),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (lastW > 0) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.history_rounded, size: 11,
                                              color: _isDarkCtx(context) ? Colors.white : Colors.black87.withAlpha(70)),
                                            const SizedBox(width: 4),
                                            Text(AppL.lastTime,
                                              style: TextStyle(
                                                color: _isDarkCtx(context) ? Colors.white : Colors.black87.withAlpha(70),
                                                fontSize: 11,
                                                letterSpacing: 2,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          alignment: WrapAlignment.center,
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFD700).withAlpha(30),
                                                border: Border.all(color: const Color(0xFFFFD700).withAlpha(180), width: 1.5),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text('${lastW % 1 == 0 ? lastW.toInt() : lastW} kg',
                                                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.bold)),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: accent.withAlpha(30),
                                                border: Border.all(color: accent.withAlpha(180), width: 1.5),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text('$lastR reps',
                                                style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.bold)),
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
                    // SKIP
                    GestureDetector(
                      onTap: _skipRest,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 60,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: _isDarkCtx(context) ? Colors.white38 : Colors.black87.withAlpha(40)),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          'SKIP',
                          style: TextStyle(
                            letterSpacing: 3,
                            fontWeight: FontWeight.w600,
                            color: _isDarkCtx(context) ? Colors.white : Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    _buildTimerNativeAd(),
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
      final setData = s <= prevSeries.length
          ? prevSeries[s - 1]
          : prevSeries.last;
      final double weight = (setData['w'] ?? setData['weight'] ?? 0.0)
          .toDouble();
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

    static const List<Color> _sparkColors = [
    Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFFE082),
    Color(0xFFFF8C00), Color(0xFFFFD700), Color(0xFFFFC107),
    Color(0xFFFFAB40), Color(0xFFFFD740),
  ];
  static const List<double> _sparkSizes = [18, 12, 16, 10, 14, 11, 13, 15];
  static const List<Offset> _dirs = [
    Offset(-1.0, -1.2),
    Offset(0.0, -1.5),
    Offset(1.0, -1.2),
    Offset(-1.3, 0.0),
    Offset(1.3, 0.0),
    Offset(-0.8, 1.2),
    Offset(0.0, 1.5),
    Offset(0.8, 1.2),
  ];

  @override
  void initState() {
    super.initState();
    _cardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _sparkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
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
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Fullscreen gold card
          Positioned.fill(
            child: ScaleTransition(
              scale: _cardScale,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('🏆', style: TextStyle(fontSize: 88)),
                        SizedBox(height: 20),
                        Text(
                          'NUOVO RECORD PERSONALE!',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12),
                        Text(
                          '🚀 Continua così! 💪',
                          style: TextStyle(color: Colors.black87, fontSize: 20),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Sparks on top
          ...List.generate(_sparkColors.length, (i) {
            final dir = _dirs[i % _dirs.length];
            return AnimatedBuilder(
              animation: _sparkAnim,
              builder: (_, __) {
                final t = _sparkAnim.value;
                final dx = dir.dx * 180 * t;
                final dy = dir.dy * 180 * t;
                final opacity = (1.0 - t).clamp(0.0, 1.0);
                final sz = _sparkSizes[i % _sparkSizes.length];
                return Positioned(
                  left: cx + dx - sz / 2,
                  top: cy + dy - sz / 2,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: sz,
                      height: sz,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _sparkColors[i % _sparkColors.length],
                        boxShadow: [BoxShadow(color: _sparkColors[i % _sparkColors.length].withAlpha(180), blurRadius: 8)],
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}


// --- SUGGESTION OVERLAY MODAL ---
class _SuggestionOverlay extends StatefulWidget {
  final bool isWeight;
  final int targetReps;
  final VoidCallback onDismiss;
  const _SuggestionOverlay({required this.isWeight, required this.targetReps, required this.onDismiss});
  @override
  State<_SuggestionOverlay> createState() => _SuggestionOverlayState();
}

class _SuggestionOverlayState extends State<_SuggestionOverlay> with TickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late AnimationController _auraCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _scale = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _scaleCtrl.forward();
    _auraCtrl = AnimationController(vsync: this, duration: Duration(milliseconds: widget.isWeight ? 2200 : 3400));
    _auraCtrl.repeat();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _auraCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWeight = widget.isWeight;
    final c1 = isWeight ? const Color(0xFFFF7043) : const Color(0xFF00B0FF);
    final c2 = isWeight ? const Color(0xFFFFD600) : const Color(0xFF9C27B0);
    final cardBorder = isWeight ? const Color(0xFFFF8A65) : const Color(0xFF40C4FF);
    final title = isWeight ? 'AUMENTA PESO' : 'PROVA ${widget.targetReps + 2} REPS';
    return Material(
      color: Colors.transparent,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          color: (isWeight ? const Color(0xFFFF5722) : const Color(0xFF1565C0)).withAlpha(35),
          child: Center(
            child: ScaleTransition(
              scale: _scale,
              child: AnimatedBuilder(
                animation: _auraCtrl,
                builder: (context, child) {
                  final t = _auraCtrl.value * 2 * scala.pi;
                  final pulse1 = 0.88 + 0.12 * scala.sin(t);
                  final pulse2 = 0.90 + 0.10 * scala.sin(t + 1.2);
                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: (isWeight ? 320.0 : 260.0) * pulse1,
                        height: (isWeight ? 320.0 : 260.0) * pulse1,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              c1.withAlpha(isWeight ? 70 : 50),
                              c2.withAlpha(isWeight ? 35 : 25),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      Container(
                        width: (isWeight ? 200.0 : 160.0) * pulse2,
                        height: (isWeight ? 200.0 : 160.0) * pulse2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              c1.withAlpha(isWeight ? 110 : 80),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      child!,
                    ],
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 36),
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isWeight
                          ? [const Color(0xFF1A0800), const Color(0xFF2D1200)]
                          : [const Color(0xFF00081A), const Color(0xFF0A0028)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: cardBorder.withAlpha(180), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: c1.withAlpha(100), blurRadius: 40, spreadRadius: 8),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cardBorder,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          shadows: [Shadow(color: c1.withAlpha(200), blurRadius: 12)],
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: widget.onDismiss,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c1,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                            elevation: 6,
                            shadowColor: c1,
                          ),
                          child: const Text('Ci provo'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🔥', style: TextStyle(fontSize: 20)),
              SizedBox(width: 10),
              Text(
                'AUMENTA IL PESO',
                style: TextStyle(
                  color: _isDarkCtx(context) ? Colors.white : Colors.black87,
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

// --- BADGE ANIMATO AUMENTA LE REPS ---
class _AumentaRepsWidget extends StatefulWidget {
  final int targetReps;
  const _AumentaRepsWidget({required this.targetReps});

  @override
  State<_AumentaRepsWidget> createState() => _AumentaRepsWidgetState();
}

class _AumentaRepsWidgetState extends State<_AumentaRepsWidget>
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
    _scale = Tween(begin: 1.0, end: 1.07)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _glow = Tween(begin: 0.0, end: 18.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.addStatusListener((status) {
      if (!mounted) return;
      if (status == AnimationStatus.completed) {
        _ctrl.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _flashes++;
        if (_flashes < 3) _ctrl.forward();
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
                Colors.green.shade600,
                Colors.teal.shade500,
                Colors.green.shade700,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _glow.value > 0
                ? [
                    BoxShadow(
                      color: Colors.green.withAlpha(160),
                      blurRadius: _glow.value,
                      spreadRadius: _glow.value / 5,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('💪', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Text(
                AppL.tryReps(widget.targetReps),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 10),
              const Text('💪', style: TextStyle(fontSize: 20)),
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
  final bool useQuarterStep;
  final bool useEvenStep;
  final bool useSingleStep;
  final bool displayInPounds;
  final bool allowKeyboardInput;
  final Color accent;
  final ValueChanged<double> onKgChanged;
  final ValueChanged<int> onRepsChanged;
  final void Function(
    bool useQuarterStep,
    bool useEvenStep,
    bool useSingleStep,
  )?
  onWeightModeChanged;
  final VoidCallback onInteraction; // chiamato ad ogni scroll

  const _DrumPickers({
    super.key,
    required this.initialKg,
    required this.initialReps,
    required this.suggerisciAumento,
    this.useQuarterStep = false,
    this.useEvenStep = false,
    this.useSingleStep = false,
    this.displayInPounds = false,
    this.allowKeyboardInput = true,
    required this.accent,
    required this.onKgChanged,
    required this.onRepsChanged,
    this.onWeightModeChanged,
    required this.onInteraction,
  });

  @override
  State<_DrumPickers> createState() => _DrumPickersState();
}

class _DrumPickersState extends State<_DrumPickers>
    with SingleTickerProviderStateMixin {
  // 0–100 kg a step di 2.5, poi 105–300 a step di 5 (valori >100 occupano meno spazio)
  static final List<double> _kgValues = [
    ...List.generate(41, (i) => i * 2.5), // 0, 2.5, 5, … 100  (indici 0-40)
    ...List.generate(
      40,
      (i) => 105.0 + i * 5.0,
    ), // 105, 110, … 300  (indici 41-80)
  ];
  static final List<double> _kgQuarterValues = [
    ...List.generate(81, (i) => i * 1.25),
    ...List.generate(80, (i) => 102.5 + i * 2.5),
  ];
  static final List<double> _kgEvenValues = List.generate(151, (i) => i * 2.0);
  static final List<double> _kgSingleValues = List.generate(
    301,
    (i) => i * 1.0,
  );
  static final List<double> _lbValues = [
    ...List.generate(61, (i) => i * 5.0),
    ...List.generate(70, (i) => 310.0 + i * 10.0),
  ];
  static final List<double> _lbQuarterValues = [
    ...List.generate(121, (i) => i * 2.5),
    ...List.generate(140, (i) => 302.5 + i * 5.0),
  ];
  static final List<double> _lbSingleValues = List.generate(
    661,
    (i) => i * 1.0,
  );
  static final List<double> _kgMergedValues = (() {
    final values = <double>{
      ..._kgValues,
      ..._kgQuarterValues,
      ..._kgEvenValues,
      ..._kgSingleValues,
    }.toList()..sort();
    return values;
  })();
  static final List<double> _lbMergedValues = (() {
    final values = <double>{
      ..._lbValues,
      ..._lbQuarterValues,
      ..._lbSingleValues,
    }.toList()..sort();
    return values;
  })();
  static final List<int> _repsValues = List.generate(50, (i) => i + 1);

  // Mappa un peso (kg) all'indice del picker corrente
  int _kgToIndex(double kg) {
    final values = _weightValues;
    final target = widget.displayInPounds ? kgToLb(kg) : kg;
    int best = 0;
    double bestDiff = double.infinity;
    for (int i = 0; i < values.length; i++) {
      final diff = (values[i] - target).abs();
      if (diff < bestDiff) {
        best = i;
        bestDiff = diff;
      }
    }
    return best;
  }

  List<double> get _weightValues {
    if (!widget.allowKeyboardInput) {
      return widget.displayInPounds ? _lbMergedValues : _kgMergedValues;
    }
    if (widget.displayInPounds) {
      if (_manualUseSingleStep || widget.useSingleStep) return _lbSingleValues;
      if (_manualUseQuarterStep || widget.useQuarterStep)
        return _lbQuarterValues;
      return _lbValues;
    }
    if (_manualUseQuarterStep || widget.useQuarterStep) return _kgQuarterValues;
    if (_manualUseEvenStep || widget.useEvenStep) return _kgEvenValues;
    if (_manualUseSingleStep || widget.useSingleStep) return _kgSingleValues;
    return _kgValues;
  }

  late FixedExtentScrollController _kgCtrl;
  late FixedExtentScrollController _repsCtrl;
  late int _selKg;
  late int _selReps;
  double? _customKgValue;
  bool _manualUseQuarterStep = false;
  bool _manualUseEvenStep = false;
  bool _manualUseSingleStep = false;
  bool _interacted = false;

  // Animazione freccia suggerimento aumento peso
  late AnimationController _arrowCtrl;
  late Animation<double> _arrowAnim;

  @override
  void initState() {
    super.initState();
    _manualUseQuarterStep = widget.useQuarterStep;
    _manualUseEvenStep = widget.useEvenStep;
    _manualUseSingleStep = widget.useSingleStep;
    _selKg = _kgToIndex(widget.initialKg);
    _selReps = (widget.initialReps - 1).clamp(0, 49);
    _kgCtrl = FixedExtentScrollController(initialItem: _selKg);
    _repsCtrl = FixedExtentScrollController(initialItem: _selReps);

    _arrowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _arrowAnim = Tween<double>(
      begin: 0,
      end: -10,
    ).animate(CurvedAnimation(parent: _arrowCtrl, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _interacted) return;
      widget.onKgChanged(_selectedKgValue());
      widget.onRepsChanged(_repsValues[_selReps]);
    });
  }

  @override
  void didUpdateWidget(_DrumPickers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.useQuarterStep != widget.useQuarterStep ||
        oldWidget.useEvenStep != widget.useEvenStep ||
        oldWidget.useSingleStep != widget.useSingleStep) {
      _manualUseQuarterStep = widget.useQuarterStep;
      _manualUseEvenStep = widget.useEvenStep;
      _manualUseSingleStep = widget.useSingleStep;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final kg = _customKgValue ?? _displayValueToKg(_weightValues[_selKg.clamp(0, _weightValues.length - 1)]);
        final newIdx = _kgToIndex(kg);
        setState(() => _selKg = newIdx);
        _kgCtrl.jumpToItem(newIdx);
      });
    }
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

  double _displayValueToKg(double value) =>
      widget.displayInPounds ? lbToKg(value) : value;

  double _selectedDisplayedWeight() =>
      widget.displayInPounds ? kgToLb(_selectedKgValue()) : _selectedKgValue();

  double _selectedKgValue() =>
      _customKgValue ?? _displayValueToKg(_weightValues[_selKg]);

  String _formatKg(double value) => formatWeightValue(value);

  void _editValue({required bool isKg}) {
    if (!widget.allowKeyboardInput) return;
    final textCtrl = TextEditingController(
      text: isKg
          ? _formatKg(_selectedDisplayedWeight())
          : _repsValues[_selReps].toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        title: Text(
          isKg
              ? (widget.displayInPounds ? 'Inserisci LIBBRE' : 'Inserisci KG')
              : 'Inserisci REPS',
          style: TextStyle(color: _isDarkCtx(context) ? Colors.white : Colors.black87),
        ),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: _isDarkCtx(context) ? Colors.white : Colors.black87, fontSize: 28),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _isDarkCtx(context) ? Colors.white24 : Colors.black26),
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
            child: Text(
              'Annulla',
              style: TextStyle(color: _isDarkCtx(context) ? Colors.white38 : Colors.black38),
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
      final normalized = (widget.displayInPounds ? lbToKg(v) : v).clamp(
        0.0,
        widget.displayInPounds ? lbToKg(_lbValues.last) : 999.0,
      );
      final useQuarterStep = widget.displayInPounds
          ? (((v.abs() * 100).round()) % 500 == 250)
          : usesQuarterStepIncrement(normalized);
      final useEvenStep =
          !widget.displayInPounds &&
          !useQuarterStep &&
          usesEvenStepIncrement(normalized);
      final useSingleStep = widget.displayInPounds
          ? (!useQuarterStep && ((v.abs() * 100).round()) % 250 != 0)
          : (!useQuarterStep &&
                !useEvenStep &&
                usesSingleStepIncrement(normalized));
      final values = widget.displayInPounds
          ? (useSingleStep
                ? _lbSingleValues
                : useQuarterStep
                ? _lbQuarterValues
                : _lbValues)
          : (useQuarterStep
                ? _kgQuarterValues
                : useEvenStep
                ? _kgEvenValues
                : useSingleStep
                ? _kgSingleValues
                : _kgValues);
      int best = 0;
      double bestDiff = double.infinity;
      for (int i = 0; i < values.length; i++) {
        final target = widget.displayInPounds ? v : normalized;
        final diff = (values[i] - target).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          best = i;
        }
      }
      setState(() {
        _manualUseQuarterStep = useQuarterStep;
        _manualUseEvenStep = useEvenStep;
        _manualUseSingleStep = useSingleStep;
        _selKg = best;
        _customKgValue = normalized;
      });
      _kgCtrl.animateToItem(
        best,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      _triggerInteraction();
      widget.onKgChanged(_customKgValue!);
      widget.onWeightModeChanged?.call(
        useQuarterStep,
        useEvenStep,
        useSingleStep,
      );
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
      _triggerInteraction();
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
    final referenceDisplayed = widget.displayInPounds
        ? kgToLb(referenceKg)
        : referenceKg;
    final currentSelectedKg = isKg ? _selectedDisplayedWeight() : 0.0;
    final bool showNudge =
        isKg && highlightAbove && currentSelectedKg <= referenceDisplayed;

    // Dimensioni e opacità basate sulla distanza dal centro
    double _itemSize(int dist) {
      switch (dist) {
        case 0:
          return 82;
        case 1:
          return 54;
        case 2:
          return 38;
        default:
          return 26;
      }
    }

    int _itemAlpha(int dist) {
      switch (dist) {
        case 0:
          return 255;
        case 1:
          return 160;
        case 2:
          return 100;
        default:
          return 55;
      }
    }

    FontWeight _itemWeight(int dist) {
      switch (dist) {
        case 0:
          return FontWeight.w700;
        case 1:
          return FontWeight.w500;
        default:
          return FontWeight.w300;
      }
    }

    return ClipRect(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: _isDarkCtx(context) ? Colors.white54 : Colors.black54,
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
                  _buildWheelScroller(
                    ctrl: ctrl,
                    items: items,
                    selectedIdx: selectedIdx,
                    formatter: formatter,
                    highlightAbove: highlightAbove,
                    referenceKg: referenceDisplayed,
                    isKg: isKg,
                    accent: accent,
                    onChanged: onChanged,
                    itemAlpha: _itemAlpha,
                    itemSize: _itemSize,
                    itemWeight: _itemWeight,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDrumSelection({
    required bool isKg,
    required int index,
    required List items,
    required Function(int) onChanged,
  }) {
    setState(() {
      if (isKg) {
        _selKg = index;
        _customKgValue = null;
      } else {
        _selReps = index;
      }
    });
    if (isKg) {
      widget.onKgChanged(_displayValueToKg(items[index] as double));
    } else {
      onChanged(index);
    }
    _triggerInteraction();
  }

  Widget _buildWheelScroller({
    required FixedExtentScrollController ctrl,
    required List items,
    required int selectedIdx,
    required String Function(dynamic) formatter,
    required bool highlightAbove,
    required double referenceKg,
    required bool isKg,
    required Color accent,
    required Function(int) onChanged,
    required int Function(int) itemAlpha,
    required double Function(int) itemSize,
    required FontWeight Function(int) itemWeight,
  }) {
    Widget buildItem(int i) {
      final dist = (i - selectedIdx).abs();
      final isSel = dist == 0;
      final double displayedKg = isKg
          ? (isSel ? _selectedDisplayedWeight() : (items[i] as double))
          : 0;
      final displayText = isKg ? _formatKg(displayedKg) : formatter(items[i]);
      final isAmber =
          isKg && highlightAbove && isSel && displayedKg > referenceKg;
      final color = isSel
          ? (isKg ? (isAmber ? Colors.amber : accent) : accent)
          : Colors.white.withAlpha(itemAlpha(dist));
      final fontSize = isKg && displayText.length >= 4
          ? (itemSize(dist) - (dist == 0 ? 16 : 8)).clamp(18.0, 82.0)
          : itemSize(dist);
      final textWidget = Text(
        displayText,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.0,
          color: color,
          fontWeight: itemWeight(dist),
          letterSpacing: isSel ? 1 : 0,
          shadows: isSel
              ? const [Shadow(color: Colors.black87, blurRadius: 10)]
              : null,
        ),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
      );
      final centeredText = SizedBox(
        width: double.infinity,
        child: Center(child: textWidget),
      );
      return isSel && widget.allowKeyboardInput
          ? GestureDetector(
              onTap: () => _editValue(isKg: isKg),
              child: centeredText,
            )
          : centeredText;
    }

    if (Theme.of(context).platform == TargetPlatform.android) {
      return ListWheelScrollView.useDelegate(
        controller: ctrl,
        itemExtent: 96,
        diameterRatio: 1.2,
        perspective: 0.003,
        physics: const FixedExtentScrollPhysics(),
        overAndUnderCenterOpacity: 0.25,
        onSelectedItemChanged: (i) => _handleDrumSelection(
          isKg: isKg,
          index: i,
          items: items,
          onChanged: onChanged,
        ),
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: items.length,
          builder: (ctx, i) {
            if (i == null || i < 0 || i >= items.length) return null;
            return buildItem(i);
          },
        ),
      );
    }

    return CupertinoPicker.builder(
      scrollController: ctrl,
      itemExtent: 96,
      diameterRatio: 1.2,
      squeeze: 0.85,
      selectionOverlay: const SizedBox.shrink(),
      backgroundColor: Colors.transparent,
      onSelectedItemChanged: (i) => _handleDrumSelection(
        isKg: isKg,
        index: i,
        items: items,
        onChanged: onChanged,
      ),
      childCount: items.length,
      itemBuilder: (ctx, i) => buildItem(i),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ClipRect(
              child: _buildDrum(
                ctrl: _kgCtrl,
                items: _weightValues,
                selectedIdx: _selKg,
                label: widget.displayInPounds ? 'LB' : 'KG',
                onChanged: (_) {},
                formatter: (v) => formatWeightValue(v as double),
                highlightAbove: widget.suggerisciAumento,
                referenceKg: widget.initialKg,
                isKg: true,
              ),
            ),
          ),
          Container(
            width: 1,
            color: _isDarkCtx(context) ? Colors.white10 : Colors.black12,
            margin: const EdgeInsets.symmetric(vertical: 40),
          ),
          Expanded(
            child: ClipRect(
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
          ),
        ],
      ),
    );
  }
}

class _WorkoutProgressChart extends StatefulWidget {
  final WorkoutDay day;
  final List<dynamic> history;
  final Color accent;
  const _WorkoutProgressChart({
    required this.day,
    required this.history,
    required this.accent,
  });

  @override
  State<_WorkoutProgressChart> createState() => _WorkoutProgressChartState();
}

class _WorkoutProgressChartState extends State<_WorkoutProgressChart> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exerciseNames = widget.day.exercises.map((e) => e.name).toSet();

    // Raggruppa la history per session_id (o data se manca) per separare
    // più sessioni nello stesso giorno
    final Map<String, Map<String, double>> bySession = {};
    final Map<String, String> sessionDate = {}; // sessionKey → yyyy-MM-dd
    for (final h in widget.history) {
      final exName = h['exercise'] as String? ?? '';
      if (!exerciseNames.contains(exName)) continue;
      final dateRaw = h['date'] as String? ?? '';
      if (dateRaw.isEmpty) continue;
      final dateOnly = dateRaw.substring(0, 10);
      // Usa session_id se disponibile, altrimenti fallback su data
      final sessionKey = (h['session_id'] as String?)?.isNotEmpty == true
          ? h['session_id'] as String
          : dateOnly;
      sessionDate.putIfAbsent(sessionKey, () => dateOnly);
      final series = h['series'] as List? ?? [];
      double maxEst1RM = 0;
      for (final s in series) {
        final w = (s['w'] ?? 0.0).toDouble();
        final r = (s['r'] ?? 0).toDouble();
        final est1RM = r > 0 ? w * (1 + r / (30.0 + w / 10.0)) : w;
        if (est1RM > maxEst1RM) maxEst1RM = est1RM;
      }
      bySession.putIfAbsent(sessionKey, () => {})[exName] = maxEst1RM;
    }

    if (bySession.isEmpty) {
      return Center(
        child: Text(
          'Nessun dato registrato',
          style: TextStyle(color: _isDarkCtx(context) ? Colors.white38 : Colors.black38),
        ),
      );
    }

    // Ordina per data
    final allSessions = bySession.keys.toList()
      ..sort((a, b) => (sessionDate[a] ?? a).compareTo(sessionDate[b] ?? b));

    // Carry-forward: se un esercizio manca in una sessione, usa l'ultimo valore noto
    final Map<String, double> carryForward = {};
    for (final sessionKey in allSessions) {
      for (final exName in exerciseNames) {
        final existing = bySession[sessionKey]![exName];
        if (existing != null && existing > 0) {
          carryForward[exName] = existing;
        } else if (carryForward.containsKey(exName)) {
          bySession[sessionKey]![exName] = carryForward[exName]!;
        }
      }
    }
    final scores = allSessions
        .map((s) => bySession[s]!.values.fold(0.0, (a, b) => a + b))
        .toList();

    // Costruisce etichette
    final labels = allSessions
        .asMap()
        .entries
        .map((e) => (e.key + 1).toString())
        .toList();

    final minS = scores.reduce((a, b) => a < b ? a : b);
    final maxS = scores.reduce((a, b) => a > b ? a : b);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    });
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = (allSessions.length * 50.0).clamp(constraints.maxWidth, double.infinity);
        return SingleChildScrollView(
          controller: _scrollCtrl,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartWidth,
            height: constraints.maxHeight,
            child: CustomPaint(
              size: Size.infinite,
              painter: _WorkoutProgressPainter(
                labels: labels,
                scores: scores,
                minS: minS,
                maxS: maxS,
                accent: widget.accent,
              ),
            ),
          ),
        );
      },
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
    final fillPath = Path();
    final n = labels.length;

    for (int i = 0; i < n; i++) {
      final x = n == 1 ? size.width / 2 : size.width / (n - 1) * i;
      final norm = flat ? 0.5 : (scores[i] - minS) / range;
      final y = size.height * 0.9 - (size.height * 0.8 * norm.clamp(0.0, 1.0));
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    final lastX = n == 1 ? size.width / 2 : size.width;
    fillPath.lineTo(lastX, size.height);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withAlpha(55), accent.withAlpha(0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(path, linePaint);

    // Punti + etichette
    for (int i = 0; i < n; i++) {
      final x = n == 1 ? size.width / 2 : size.width / (n - 1) * i;
      final norm = flat ? 0.5 : (scores[i] - minS) / range;
      final y = size.height * 0.9 - (size.height * 0.8 * norm.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 5, dotBg);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_WorkoutProgressPainter old) => true;
}

// --- GRAFICI ---

class PTGraphWidget extends StatefulWidget {
  final String exerciseName;
  final List<dynamic> history;

  const PTGraphWidget({
    super.key,
    required this.exerciseName,
    required this.history,
  });

  @override
  State<PTGraphWidget> createState() => _PTGraphWidgetState();
}

class _PTGraphWidgetState extends State<PTGraphWidget> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> seriesColors = [
      Theme.of(context).colorScheme.primary,
      Colors.purpleAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.redAccent,
    ];
    var logs = widget.history
        .where((h) => h['exercise'] == widget.exerciseName)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (logs.isEmpty) return const Center(child: Text("Nessun dato"));

    // 1. Troviamo il numero massimo di serie per questo esercizio
    int maxSetsFound = 0;
    for (var l in logs) {
      var series = l['series'] as List;
      if (series.length > maxSetsFound) maxSetsFound = series.length;
    }

    // 2. Score = 1RM stimato (adattivo) per serie → normalizzazione min-max per indice serie
    Map<int, double> minScore = {};
    Map<int, double> maxScore = {};
    for (var l in logs) {
      var series = l['series'] as List;
      for (int i = 0; i < series.length; i++) {
        double w = (series[i]['w'] ?? 0.0).toDouble();
        double r = (series[i]['r'] ?? 0.0).toDouble();
        double sc = w * (1 + r / (30.0 + w / 10.0));
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
        double sc = w * (1 + r / (30.0 + w / 10.0));
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
          widget.exerciseName.toUpperCase(),
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
                  style: TextStyle(fontSize: 11, color: _isDarkCtx(context) ? Colors.white70 : Colors.black87),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = (logs.length * 50.0).clamp(constraints.maxWidth, double.infinity);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
              });
              return SingleChildScrollView(
                controller: _scrollCtrl,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: chartWidth,
                  height: 160,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: PTChartPainter(logs: logs, colors: seriesColors),
                  ),
                ),
              );
            },
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
      final fillPath = Path();
      bool first = true;
      double lastX = 0;

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
            fillPath.moveTo(x, size.height);
            fillPath.lineTo(x, y);
            first = false;
          } else {
            path.lineTo(x, y);
            fillPath.lineTo(x, y);
          }
          lastX = x;
          canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
        }
      }
      if (!first) {
        fillPath.lineTo(lastX, size.height);
        fillPath.close();
        canvas.drawPath(
          fillPath,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withAlpha(40), color.withAlpha(0)],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
        );
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
    return byDay.entries.where((e) => e.value.isNotEmpty).toList();
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
        backgroundColor: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
        title: Text(
          'Reset completo',
          style: TextStyle(color: _isDarkCtx(context) ? Colors.white : Colors.black87),
        ),
        content: Text(
          'Eliminerà TUTTI i dati: scheda, storico e impostazioni.',
          style: TextStyle(color: _isDarkCtx(context) ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppL.cancel),
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
        backgroundColor: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
        title: Text('Sei sicuro?', style: TextStyle(color: _isDarkCtx(context) ? Colors.white : Colors.black87)),
        content: const Text(
          'Operazione irreversibile.',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppL.cancel),
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
    try {
      await _gymFileChannel.invokeMethod('cancelStreakReminderNotification');
      await _gymFileChannel.invokeMethod('cancelCountdownNotification');
      await _gymFileChannel.invokeMethod('cancelTimerFinishedNotification');
    } catch (_) {}
    await prefs.clear();
    if (!mounted) return;
    setState(() {
      _history = [];
      _selected.clear();
    });
    Navigator.pop(context, true);
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
      backgroundColor: _isDarkCtx(context) ? const Color(0xFF111111) : Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: _isDarkCtx(context) ? const Color(0xFF111111) : Colors.grey.shade100,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: _isDarkCtx(context) ? Colors.white70 : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(Icons.storage_rounded, color: Colors.redAccent, size: 20),
            SizedBox(width: 8),
            Text(
              'Gestione Dati',
              style: TextStyle(
                color: _isDarkCtx(context) ? Colors.white : Colors.black87,
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
                        color: _isDarkCtx(context) ? Colors.white : Colors.black87.withAlpha(80),
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
                                    color: _isDarkCtx(context) ? Colors.white : Colors.black87.withAlpha(180),
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
                                    style: TextStyle(
                                      color: _isDarkCtx(context) ? Colors.white : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${sessions.length} session${sessions.length == 1 ? 'e' : 'i'}',
                                    style: TextStyle(
                                      color: _isDarkCtx(context) ? Colors.white : Colors.black87.withAlpha(100),
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.chevron_right_rounded,
                                    color: _isDarkCtx(context) ? Colors.white24 : Colors.black26,
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
                  icon: Icon(
                    Icons.delete_sweep_outlined,
                    color: _isDarkCtx(context) ? Colors.white : Colors.black87,
                  ),
                  label: Text(
                    'Elimina selezionati (${_selected.length})',
                    style: TextStyle(color: _isDarkCtx(context) ? Colors.white : Colors.black87),
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
          Divider(color: _isDarkCtx(context) ? Colors.white12 : Colors.black12, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'RESET TOTALE',
              style: TextStyle(
                color: _isDarkCtx(context) ? Colors.white : Colors.black87.withAlpha(100),
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
        backgroundColor: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
        title: Text(
          'Elimina sessione?',
          style: TextStyle(color: _isDarkCtx(context) ? Colors.white : Colors.black87),
        ),
        content: Text(
          'Tutti i dati di questa sessione verranno eliminati.',
          style: TextStyle(color: _isDarkCtx(context) ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppL.cancel),
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
        backgroundColor: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
        title: Text(
          'Elimina serie?',
          style: TextStyle(color: _isDarkCtx(context) ? Colors.white : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppL.cancel),
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
        backgroundColor: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
        title: Text(
          'Serie ${serieIdx + 1}',
          style: TextStyle(color: _isDarkCtx(context) ? Colors.white : Colors.black87),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: _isDarkCtx(context) ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Peso (kg)',
                labelStyle: TextStyle(color: _isDarkCtx(context) ? Colors.white54 : Colors.black54),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: _isDarkCtx(context) ? Colors.white24 : Colors.black26),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: _isDarkCtx(context) ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Reps',
                labelStyle: TextStyle(color: _isDarkCtx(context) ? Colors.white54 : Colors.black54),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: _isDarkCtx(context) ? Colors.white24 : Colors.black26),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppL.cancel),
          ),
          TextButton(
            onPressed: () async {
              final newW =
                  double.tryParse(wCtrl.text.replaceAll(',', '.')) ?? 0.0;
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
            child: Text(
              AppL.save,
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
      backgroundColor: _isDarkCtx(context) ? const Color(0xFF111111) : Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: _isDarkCtx(context) ? const Color(0xFF111111) : Colors.grey.shade100,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: _isDarkCtx(context) ? Colors.white70 : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.exerciseName,
          style: TextStyle(
            color: _isDarkCtx(context) ? Colors.white : Colors.black87,
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
                  color: _isDarkCtx(context) ? Colors.white : Colors.black87.withAlpha(80),
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
                    color: _isDarkCtx(context) ? Colors.white.withAlpha(8) : Colors.black87.withAlpha(8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isDarkCtx(context) ? Colors.white10 : Colors.black12),
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
                                style: TextStyle(
                                  color: _isDarkCtx(context) ? Colors.white54 : Colors.black54,
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
                      Divider(color: _isDarkCtx(context) ? Colors.white10 : Colors.black12, height: 1),
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
                            style: TextStyle(
                              color: _isDarkCtx(context) ? Colors.white70 : Colors.black87,
                              fontSize: 13,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.edit_rounded,
                                  color: _isDarkCtx(context) ? Colors.white38 : Colors.black38,
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

// ─── OVERALL PROGRESS PAGE ────────────────────────────────────────────────────
class _OverallProgressPage extends StatefulWidget {
  final List<dynamic> history;
  final List<WorkoutDay> routine;
  final int streak;
  final Color accent;

  const _OverallProgressPage({
    required this.history,
    required this.routine,
    required this.streak,
    required this.accent,
  });

  @override
  State<_OverallProgressPage> createState() => _OverallProgressPageState();
}

class _OverallProgressPageState extends State<_OverallProgressPage> {
  String? _filterDay;
  final GlobalKey _chartKey = GlobalKey();
  final ScrollController _chartScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollChartToEnd());
  }

  @override
  void dispose() {
    _chartScrollCtrl.dispose();
    super.dispose();
  }

  void _scrollChartToEnd() {
    if (_chartScrollCtrl.hasClients) {
      _chartScrollCtrl.jumpTo(_chartScrollCtrl.position.maxScrollExtent);
    }
  }

  List<_SessionPoint> _computePoints() {
    final Map<String, Map<String, double>> bySessionEx = {};
    final Map<String, String> sessionDate = {};
    final Map<String, String> sessionDayName = {};

    for (final h in widget.history) {
      final sid = (h['session_id'] as String?)?.isNotEmpty == true
          ? h['session_id'] as String
          : ((h['date'] as String?) ?? '').substring(0, 10);
      if (_filterDay != null && h['dayName'] != _filterDay) continue;
      final exName = (h['exercise'] as String?) ?? '';
      if (exName.isEmpty) continue;
      sessionDate.putIfAbsent(sid, () => (h['date'] as String?) ?? '');
      sessionDayName.putIfAbsent(sid, () => (h['dayName'] as String?) ?? '');

      final series = (h['series'] as List?) ?? [];
      double maxEst1RM = 0;
      for (final s in series) {
        final w = (s['w'] ?? 0.0).toDouble();
        final r = (s['r'] ?? 0).toDouble();
        final est1RM = r > 0 ? w * (1 + r / (30.0 + w / 10.0)) : w;
        if (est1RM > maxEst1RM) maxEst1RM = est1RM;
      }
      final exMap = bySessionEx.putIfAbsent(sid, () => {});
      if ((exMap[exName] ?? 0) < maxEst1RM) exMap[exName] = maxEst1RM;
    }

    final List<_SessionPoint> points = [];
    for (final sid in bySessionEx.keys) {
      final date = sessionDate[sid] ?? '';
      if (date.isEmpty) continue;
      final score = bySessionEx[sid]!.values.fold(0.0, (a, b) => a + b);
      points.add(_SessionPoint(
        sessionId: sid,
        date: DateTime.tryParse(date) ?? DateTime(2000),
        score: score,
        dayName: sessionDayName[sid] ?? '',
      ));
    }
    points.sort((a, b) => a.date.compareTo(b.date));

    if (_filterDay == null && widget.routine.length > 1) {
      return _groupByMicrocycle(points);
    }
    return points;
  }

  List<_SessionPoint> _groupByMicrocycle(List<_SessionPoint> sessions) {
    final dayNames = widget.routine.map((d) => d.dayName).toSet();
    if (dayNames.length <= 1) return sessions;

    final List<_SessionPoint> result = [];
    List<_SessionPoint> currentCycle = [];
    Set<String> seenDays = {};
    int cycleIndex = 1;
    Map<String, _SessionPoint> lastCompleteCycleSessions = {};

    for (final s in sessions) {
      final day = s.dayName;
      if (!dayNames.contains(day)) continue;

      if (seenDays.contains(day)) {
        if (currentCycle.isNotEmpty) {
          lastCompleteCycleSessions = {for (final p in currentCycle) p.dayName: p};
          result.add(_aggregateCycle(currentCycle, cycleIndex++));
        }
        currentCycle = [s];
        seenDays = {day};
      } else {
        currentCycle.add(s);
        seenDays.add(day);
        if (seenDays.length == dayNames.length) {
          lastCompleteCycleSessions = {for (final p in currentCycle) p.dayName: p};
          result.add(_aggregateCycle(currentCycle, cycleIndex++));
          currentCycle = [];
          seenDays = {};
        }
      }
    }

    // Partial last cycle: supplement missing sessions with prev cycle values
    if (currentCycle.isNotEmpty) {
      if (lastCompleteCycleSessions.isNotEmpty) {
        final supplemented = List<_SessionPoint>.from(currentCycle);
        for (final day in dayNames) {
          if (!seenDays.contains(day) && lastCompleteCycleSessions.containsKey(day)) {
            supplemented.add(lastCompleteCycleSessions[day]!);
          }
        }
        result.add(_aggregateCycle(supplemented, cycleIndex));
      } else {
        result.add(_aggregateCycle(currentCycle, cycleIndex));
      }
    }

    return result;
  }

  _SessionPoint _aggregateCycle(List<_SessionPoint> sessions, int index) {
    final avgScore = sessions.fold(0.0, (sum, s) => sum + s.score) / sessions.length;
    return _SessionPoint(
      sessionId: 'cycle_$index',
      date: sessions.last.date,
      score: avgScore,
      dayName: 'Microciclo $index',
    );
  }

  Future<void> _shareProgress(BuildContext context) async {
    await showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProgressShareSheet(
        chartKey: _chartKey,
        streak: widget.streak,
        points: _computePoints(),
        accent: widget.accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final allPoints = _computePoints();
    final dayNames = widget.routine.map((d) => d.dayName).toList();

    return Scaffold(
      backgroundColor: _isDarkCtx(context) ? const Color(0xFF0E0E10) : Colors.white,
      appBar: AppBar(
        backgroundColor: _isDarkCtx(context) ? const Color(0xFF0E0E10) : Colors.white,
        title: Text(
          'Progressi Generali',
          style: TextStyle(
            color: _isDarkCtx(context) ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        iconTheme: IconThemeData(color: _isDarkCtx(context) ? Colors.white : Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () => _shareProgress(context),
            tooltip: 'Condividi',
          ),
        ],
      ),
      body: Column(
        children: [
          if (dayNames.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _filterChip(
                    label: 'Tutti',
                    selected: _filterDay == null,
                    accent: accent,
                    onTap: () { setState(() => _filterDay = null); WidgetsBinding.instance.addPostFrameCallback((_) => _scrollChartToEnd()); },
                  ),
                  const SizedBox(width: 8),
                  ...dayNames.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _filterChip(
                        label: d,
                        selected: _filterDay == d,
                        accent: accent,
                  onTap: () { setState(() => _filterDay = _filterDay == d ? null : d); WidgetsBinding.instance.addPostFrameCallback((_) => _scrollChartToEnd()); },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: allPoints.isEmpty
                ? Center(
                    child: Text(
                      'Nessun dato disponibile',
                      style: TextStyle(color: _isDarkCtx(context) ? Colors.white38 : Colors.black38, fontSize: 16),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsRow(allPoints, accent),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _filterDay == null && widget.routine.length > 1
                                        ? 'Progressi per microciclo'
                                        : 'Progressi per sessione',
                                    style: TextStyle(
                                      color: _isDarkCtx(context) ? Colors.white70 : Colors.black87,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final chartWidth = (allPoints.length * 50.0).clamp(constraints.maxWidth, double.infinity);
                                  return SingleChildScrollView(
                                    controller: _chartScrollCtrl,
                                    scrollDirection: Axis.horizontal,
                                    child: RepaintBoundary(
                                      key: _chartKey,
                                      child: SizedBox(
                                        width: chartWidth,
                                        height: 220,
                                        child: CustomPaint(
                                          size: Size.infinite,
                                          painter: _OverallProgressPainter(
                                            points: allPoints,
                                            accent: accent,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.share_rounded),
                            label: const Text('Condividi progressi'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: accent,
                              side: BorderSide(color: accent),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _shareProgress(context),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withAlpha(40) : (_isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : (_isDarkCtx(context) ? Colors.white12 : Colors.grey.shade400),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : (_isDarkCtx(context) ? Colors.white60 : Colors.black54),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(List<_SessionPoint> points, Color accent) {
    final totalSessions = points.length;
    final streak = widget.streak;
    final trendPct = points.length >= 2 && points.first.score > 0
        ? ((points.last.score - points.first.score) / points.first.score * 100)
        : 0.0;
    final trendUp = trendPct >= 0;

    return Row(
      children: [
        _statCard(
          _filterDay == null && widget.routine.length > 1
              ? 'Microcicli'
              : 'Sessioni',
          '$totalSessions',
          Icons.calendar_today_rounded,
          accent,
        ),
        const SizedBox(width: 8),
        _statCard(
          'Streak',
          '🔥 $streak',
          Icons.local_fire_department_rounded,
          Colors.orange,
        ),
        const SizedBox(width: 8),
        _statCard(
          'Trend',
          points.length >= 2
              ? '${trendUp ? '+' : ''}${trendPct.toStringAsFixed(0)}%'
              : '—',
          trendUp ? Icons.trending_up : Icons.trending_down,
          trendUp ? Colors.greenAccent : Colors.redAccent,
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(100), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: _isDarkCtx(context) ? Colors.white38 : Colors.black38, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SESSION POINT ────────────────────────────────────────────────────────────
class _SessionPoint {
  final String sessionId;
  final DateTime date;
  final double score;
  final String dayName;
  const _SessionPoint({
    required this.sessionId,
    required this.date,
    required this.score,
    required this.dayName,
  });
}

class _OverallProgressPainter extends CustomPainter {
  final List<_SessionPoint> points;
  final Color accent;

  const _OverallProgressPainter({required this.points, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final n = points.length;
    final volumes = points.map((p) => p.score).toList();
    final minV = volumes.reduce((a, b) => a < b ? a : b);
    final maxV = volumes.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs();

    final axisPaint = Paint()..color = Colors.white12..strokeWidth = 1;
    const leftPad = 10.0;
    const botPad = 20.0;
    final chartH = size.height - botPad;
    canvas.drawLine(Offset(leftPad, 0), Offset(leftPad, chartH), axisPaint);
    canvas.drawLine(Offset(leftPad, chartH), Offset(size.width, chartH), axisPaint);

    final fillPath = Path();
    final linePath = Path();
    for (int i = 0; i < n; i++) {
      final x = leftPad + (size.width - leftPad) / (n > 1 ? (n - 1) : 1) * i;
      final norm = range > 0.5 ? (volumes[i] - minV) / range : 0.5;
      final y = chartH * 0.9 - (chartH * 0.8 * norm.clamp(0.0, 1.0));
      if (i == 0) {
        fillPath.moveTo(x, chartH);
        fillPath.lineTo(x, y);
        linePath.moveTo(x, y);
      } else {
        fillPath.lineTo(x, y);
        linePath.lineTo(x, y);
      }
    }
    fillPath.lineTo(leftPad + (size.width - leftPad), chartH);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withAlpha(60), accent.withAlpha(0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, chartH)),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = accent
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final dotPaint = Paint()..color = accent..style = PaintingStyle.fill;
    final dotBg = Paint()..color = const Color(0xFF1C1C1E)..style = PaintingStyle.fill;
    for (int i = 0; i < n; i++) {
      final x = leftPad + (size.width - leftPad) / (n > 1 ? (n - 1) : 1) * i;
      final norm = range > 0.5 ? (volumes[i] - minV) / range : 0.5;
      final y = chartH * 0.9 - (chartH * 0.8 * norm.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 5, dotBg);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_OverallProgressPainter old) => true;
}

// ─── SHARE WORKOUT IMAGE SHEET ────────────────────────────────────────────────
class _WorkoutShareSheet extends StatefulWidget {
  final String dayName;
  final String todayLabel;
  final List<Map<String, dynamic>> exercises;
  final int streak;
  final Color accent;
  final Set<String> streakDoneNames;
  final double? progressPercent;
  final List<String> allSessionNames;
  const _WorkoutShareSheet({
    required this.dayName,
    required this.todayLabel,
    required this.exercises,
    required this.streak,
    required this.accent,
    this.streakDoneNames = const {},
    this.progressPercent,
    this.allSessionNames = const [],
  });
  @override
  State<_WorkoutShareSheet> createState() => _WorkoutShareSheetState();
}

class _WorkoutShareSheetState extends State<_WorkoutShareSheet> {
  bool _showStreak = true;
  bool _showWeeklyBadges = false;
  bool _showSessionProgress = false;
  bool _showExercises = true;
  bool _sharing = false;
  final GlobalKey _cardKey = GlobalKey();

  Widget _buildCard(Color accent) {
    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withAlpha(80)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/icon_client.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Text('💪', style: TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GymApp',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '${widget.dayName} · ${widget.todayLabel}',
                    style: TextStyle(color: _isDarkCtx(context) ? Colors.white54 : Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_showExercises) ...[
            Divider(color: _isDarkCtx(context) ? Colors.white12 : Colors.black12),
            const SizedBox(height: 8),
            ...widget.exercises.map((ex) {
              final name = ex['exercise'] as String;
              final series = ex['series'] as List;
              double maxW = 0;
              int maxR = 0;
              for (final s in series) {
                final w = (s['w'] ?? 0.0).toDouble();
                final r = (s['r'] ?? 0) as int;
                if (w > maxW) { maxW = w; maxR = r; }
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(color: _isDarkCtx(context) ? Colors.white70 : Colors.black87, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${maxW.toStringAsFixed(maxW % 1 == 0 ? 0 : 1)} kg × $maxR rep',
                      style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
          if (_showStreak || _showWeeklyBadges || _showSessionProgress) ...[
            Divider(color: _isDarkCtx(context) ? Colors.white12 : Colors.black12),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_showStreak)
                  _badgeChip(
                    icon: '🔥',
                    label: 'Streak',
                    value: '${widget.streak} micro',
                    accent: Colors.orange,
                  ),
                if (_showSessionProgress && widget.progressPercent != null)
                  _badgeChip(
                    icon: widget.progressPercent! >= 0 ? '📈' : '📉',
                    label: 'vs prec.',
                    value: '${widget.progressPercent! >= 0 ? '+' : ''}${widget.progressPercent!.toStringAsFixed(1)}%',
                    accent: widget.progressPercent! >= 0 ? Colors.greenAccent : Colors.redAccent,
                  ),
              ],
            ),
            if (_showWeeklyBadges) ...[
              const SizedBox(height: 8),
              Builder(builder: (ctx) {
                final names = widget.allSessionNames.isNotEmpty
                    ? widget.allSessionNames
                    : widget.streakDoneNames.toList();
                final doneCount = widget.streakDoneNames.length;
                final total = names.length;
                return SizedBox(
                  width: double.infinity,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      children: names.map((name) {
                        final done = widget.streakDoneNames.contains(name);
                        return Container(
                          width: 60,
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: done ? const LinearGradient(
                              colors: [Color(0xFFFF6B00), Color(0xFFFFAB00)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ) : null,
                            color: done ? null : Colors.white10,
                            border: Border.all(color: done ? Colors.orange : Colors.white12),
                            boxShadow: done ? [BoxShadow(color: Colors.orange.withAlpha(60), blurRadius: 6)] : null,
                          ),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: ColorFiltered(
                                  colorFilter: done
                                      ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                                      : const ColorFilter.matrix([
                                          0.2126, 0.7152, 0.0722, 0, 0,
                                          0.2126, 0.7152, 0.0722, 0, 0,
                                          0.2126, 0.7152, 0.0722, 0, 0,
                                          0,      0,      0,      1, 0,
                                        ]),
                                  child: Transform.scale(
                                    scale: 1.18,
                                    child: Image.asset('assets/icon_client.png', width: 28, height: 28,
                                        errorBuilder: (_, __, ___) => Icon(Icons.fitness_center, color: done ? Colors.white : Colors.white24, size: 24)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                name,
                                style: TextStyle(fontSize: 7, color: done ? Colors.white : Colors.white38, fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$doneCount/$total questo microciclo',
                      style: TextStyle(color: _isDarkCtx(context) ? Colors.white54 : Colors.black54, fontSize: 9),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 6),
          Center(
            child: Text(
              '',
              style: TextStyle(color: accent.withAlpha(120), fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeChip({
    required String icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(80)),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          Text(value, style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 14)),
          Text(label, style: TextStyle(color: _isDarkCtx(context) ? Colors.white54 : Colors.black54, fontSize: 10)),
        ],
      ),
    );
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 4.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/gymapp_workout.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Container(
      decoration: BoxDecoration(
        color: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: _isDarkCtx(context) ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text(
            'Condividi allenamento',
            style: TextStyle(color: _isDarkCtx(context) ? Colors.white : Colors.black87, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 14),
          RepaintBoundary(key: _cardKey, child: _buildCard(accent)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _toggleChip('Esercizi', _showExercises, () => setState(() => _showExercises = !_showExercises), accent),
              _toggleChip('Streak 🔥', _showStreak, () => setState(() => _showStreak = !_showStreak), Colors.orange),
              _toggleChip('Badge microciclo', _showWeeklyBadges, () => setState(() => _showWeeklyBadges = !_showWeeklyBadges), Colors.amber),
              if (widget.progressPercent != null)
                _toggleChip('vs prec.', _showSessionProgress, () => setState(() => _showSessionProgress = !_showSessionProgress), Colors.greenAccent),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.share_rounded),
              label: const Text('Condividi immagine'),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleChip(String label, bool active, VoidCallback onTap, Color c) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.withAlpha(40) : Colors.white12,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? c : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? c : Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── STREAK SHARE SHEET ───────────────────────────────────────────────────────
class _StreakShareSheet extends StatefulWidget {
  final int streak;
  final Set<String> streakDoneNames;
  final List<String> allSessionNames;
  final Color accent;
  const _StreakShareSheet({
    required this.streak,
    required this.streakDoneNames,
    required this.allSessionNames,
    required this.accent,
  });
  @override
  State<_StreakShareSheet> createState() => _StreakShareSheetState();
}

class _StreakShareSheetState extends State<_StreakShareSheet> {
  bool _sharing = false;
  bool _showBadges = true;
  final GlobalKey _cardKey = GlobalKey();

  Widget _buildStoryCard() {
    final doneCount = widget.streakDoneNames.intersection(widget.allSessionNames.toSet()).length;
    final total = widget.allSessionNames.length;

    return Container(
      width: 340,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A0A0C), Color(0xFF1A0D00), Color(0xFF0A0A0C)],
          stops: [0.0, 0.5, 1.0],
        ),
        border: Border.all(color: Colors.orange.withAlpha(60)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.orange.withAlpha(60), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/icon_client.png',
                        width: 72,
                        height: 72,
                        errorBuilder: (_, __, ___) => const Text('💪', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'GymApp',
                      style: TextStyle(
                        color: widget.accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Text('🔥', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 8),
                Text(
                  '${widget.streak}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 96,
                    fontWeight: FontWeight.w900,
                    height: 0.9,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.streak == 1 ? 'micro' : 'micro'} di fila! 🔥',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 32),
                if (_showBadges && widget.allSessionNames.isNotEmpty) ...[
                  Text(
                    'Questo microciclo',
                    style: TextStyle(color: _isDarkCtx(context) ? Colors.white38 : Colors.black38, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: List.generate(widget.allSessionNames.length, (i) {
                      final name = widget.allSessionNames[i];
                      final done = widget.streakDoneNames.contains(name);
                      return Container(
                        width: 72,
                        height: 84,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: done
                              ? const LinearGradient(
                                  colors: [Color(0xFFFF6B00), Color(0xFFFFAB00)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: done ? null : Colors.white10,
                          border: Border.all(color: done ? Colors.orange : Colors.white12),
                          boxShadow: done
                              ? [BoxShadow(color: Colors.orange.withAlpha(80), blurRadius: 8)]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: done
                                  ? Image.asset('assets/icon_client.png', width: 36, height: 36,
                                      errorBuilder: (_, __, ___) => Icon(Icons.fitness_center, color: _isDarkCtx(context) ? Colors.white : Colors.black87, size: 32))
                                  : ColorFiltered(
                                      colorFilter: const ColorFilter.matrix([
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0,      0,      0,      0.3, 0,
                                      ]),
                                      child: Image.asset('assets/icon_client.png', width: 36, height: 36,
                                          errorBuilder: (_, __, ___) => Icon(Icons.fitness_center, color: _isDarkCtx(context) ? Colors.white24 : Colors.black26, size: 32)),
                                    ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 9,
                                color: done ? Colors.white : Colors.white24,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
                const Spacer(),
                Text(
                  '',
                  style: TextStyle(color: widget.accent.withAlpha(100), fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 4.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/gymapp_streak.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '🔥 ${widget.streak} ${widget.streak == 1 ? 'micro' : 'micro'} di fila!',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: _isDarkCtx(context) ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text(
            'Condividi Streak 🔥',
            style: TextStyle(color: _isDarkCtx(context) ? Colors.white : Colors.black87, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _toggleChip(label: '🏅 Badge', active: _showBadges, onTap: () => setState(() => _showBadges = !_showBadges)),
            ],
          ),
          const SizedBox(height: 14),
          RepaintBoundary(key: _cardKey, child: _buildStoryCard()),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('🔥', style: TextStyle(fontSize: 16)),
              label: const Text('Condividi nelle Storie'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleChip({required String label, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.orange.withAlpha(40) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? Colors.orange : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? Colors.orange : Colors.white54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── PROGRESS SHARE SHEET ─────────────────────────────────────────────────────
class _ProgressShareSheet extends StatefulWidget {
  final GlobalKey? chartKey;
  final int streak;
  final List<_SessionPoint> points;
  final Color accent;
  const _ProgressShareSheet({
    this.chartKey,
    required this.streak,
    required this.points,
    required this.accent,
  });
  @override
  State<_ProgressShareSheet> createState() => _ProgressShareSheetState();
}

class _ProgressShareSheetState extends State<_ProgressShareSheet> {
  bool _sharing = false;
  bool _includeStreak = true;
  bool _includeSessionCount = true;
  bool _includeTrend = true;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      // Get chart image: from widget capture if chartKey available, else programmatic render
      ui.Image chartImage;
      if (widget.chartKey != null) {
        final boundary = widget.chartKey!.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) { setState(() => _sharing = false); return; }
        chartImage = await boundary.toImage(pixelRatio: 6.0);
      } else {
        const double chartRenderW = 1040.0;
        const double chartRenderH = 290.0;
        final chartRecorder = ui.PictureRecorder();
        final chartCanvas = Canvas(chartRecorder);
        _OverallProgressPainter(points: widget.points, accent: widget.accent)
            .paint(chartCanvas, const Size(chartRenderW, chartRenderH));
        final chartPicture = chartRecorder.endRecording();
        chartImage = await chartPicture.toImage(chartRenderW.toInt(), chartRenderH.toInt());
      }
      final chartBytes = await chartImage.toByteData(format: ui.ImageByteFormat.png);
      if (chartBytes == null) return;

      const double s = 2.0;
      const double w = 1080 * s;
      const double hPad = 20.0 * s;
      final double chartW = w - 2 * hPad;
      const double cardSize = 220.0 * s;
      final double badgesH = (_includeStreak || _includeSessionCount || _includeTrend) ? (cardSize + 40.0 * s) : 0.0;
      const double headerH = 260.0 * s;
      const double gap = 16.0 * s;
      final double chartAspect = chartImage.width / chartImage.height;
      final double chartH = chartW / chartAspect;
      final double totalH = headerH + chartH + badgesH + 40 * s;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      canvas.clipRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, totalH), const Radius.circular(32 * s)));

      final bgPaint = Paint()..color = const Color(0xFF0E0E10);
      canvas.drawRect(Rect.fromLTWH(0, 0, w, totalH), bgPaint);

      final borderPaint = Paint()
        ..color = widget.accent.withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * s;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, totalH), const Radius.circular(32 * s)),
        borderPaint,
      );

      // Header: icon + "GymApp"
      final codec = await ui.instantiateImageCodec(
        (await rootBundle.load('assets/icon_client.png')).buffer.asUint8List(),
        targetWidth: (180 * s).round(),
        targetHeight: (180 * s).round(),
      );
      final frame = await codec.getNextFrame();
      const double iconSz = 180.0 * s;
      final iconX = (w - iconSz) / 2;
      canvas.drawImageRect(
        frame.image,
        Rect.fromLTWH(0, 0, frame.image.width.toDouble(), frame.image.height.toDouble()),
        Rect.fromLTWH(iconX, 16 * s, iconSz, iconSz),
        Paint(),
      );
      final iconBorderPaint = Paint()
        ..color = widget.accent.withAlpha(150)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * s;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(iconX, 16 * s, iconSz, iconSz), Radius.circular(16 * s)),
        iconBorderPaint,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: 'GymApp',
          style: TextStyle(
            color: widget.accent,
            fontSize: 48 * s,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((w - tp.width) / 2, (16 + 180 + 12) * s));

      // Chart background
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(hPad, headerH, chartW, chartH), const Radius.circular(16 * s)),
        Paint()..color = const Color(0xFF1C1C1E),
      );

      // Draw chart filling content width
      final chartUi = await ui.instantiateImageCodec(chartBytes.buffer.asUint8List());
      final chartFrame = await chartUi.getNextFrame();
      const double innerPad = 12.0 * s;
      canvas.drawImageRect(
        chartFrame.image,
        Rect.fromLTWH(0, 0, chartImage.width.toDouble(), chartImage.height.toDouble()),
        Rect.fromLTWH(hPad + innerPad, headerH + innerPad, chartW - 2 * innerPad, chartH - 2 * innerPad),
        Paint(),
      );

      // Stat cards row
      if (_includeStreak || _includeSessionCount || _includeTrend) {
        final double bY = headerH + chartH + 16 * s;
        final trendPct = widget.points.length >= 2 && widget.points.first.score > 0
            ? ((widget.points.last.score - widget.points.first.score) / widget.points.first.score * 100)
            : 0.0;
        final trendUp = trendPct >= 0;
        final isMicrocycle = widget.points.isNotEmpty && widget.points.first.dayName.startsWith('Microciclo');

        final activeCards = <(Color, String, String, String)>[];
        if (_includeSessionCount) activeCards.add((const Color(0xFF00BCD4), '📅', '${widget.points.length}', isMicrocycle ? 'Microcicli' : 'Sessioni'));
        if (_includeStreak) activeCards.add((const Color(0xFFFF6B00), '🔥', '${widget.streak}', 'Streak'));
        if (_includeTrend) activeCards.add((trendUp ? Colors.greenAccent : Colors.redAccent, trendUp ? '📈' : '📉', '${trendUp ? '+' : ''}${trendPct.toStringAsFixed(0)}%', 'Trend'));

        if (activeCards.isNotEmpty) {
          final double totalCardsW = activeCards.length * cardSize + (activeCards.length + 1) * gap;
          final double firstCardX = (w - totalCardsW) / 2 + gap;

          void drawStatCard(Canvas c, double cx, Color cardColor, String emoji, String val, String lbl) {
            final rect = RRect.fromRectAndRadius(
              Rect.fromLTWH(cx, bY, cardSize, cardSize),
              Radius.circular(24 * s),
            );
            c.drawRRect(rect, Paint()..color = cardColor.withAlpha(25));
            c.drawRRect(rect, Paint()..color = cardColor.withAlpha(130)..style = PaintingStyle.stroke..strokeWidth = 2 * s);
            c.drawRRect(rect, Paint()..color = Colors.white.withAlpha(15)..style = PaintingStyle.stroke..strokeWidth = 1 * s);
            final emojiTp = TextPainter(
              text: TextSpan(text: emoji, style: TextStyle(fontSize: 44 * s)),
              textDirection: TextDirection.ltr,
            )..layout();
            emojiTp.paint(c, Offset(cx + (cardSize - emojiTp.width) / 2, bY + cardSize * 0.10));
            final valTp = TextPainter(
              text: TextSpan(text: val, style: TextStyle(color: cardColor, fontSize: 48 * s, fontWeight: FontWeight.w900)),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: cardSize - 8 * s);
            valTp.paint(c, Offset(cx + (cardSize - valTp.width) / 2, bY + cardSize * 0.42));
            final lblTp = TextPainter(
              text: TextSpan(text: lbl, style: TextStyle(color: _isDarkCtx(context) ? Colors.white54 : Colors.black54, fontSize: 20 * s)),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: cardSize - 8 * s);
            lblTp.paint(c, Offset(cx + (cardSize - lblTp.width) / 2, bY + cardSize * 0.74));
          }

          for (int ci = 0; ci < activeCards.length; ci++) {
            final cx = firstCardX + ci * (cardSize + gap);
            drawStatCard(canvas, cx, activeCards[ci].$1, activeCards[ci].$2, activeCards[ci].$3, activeCards[ci].$4);
          }
        }
      }

      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(w.toInt(), totalH.toInt());
      final finalBytes = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      if (finalBytes == null) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/gymapp_progress.png');
      await file.writeAsBytes(finalBytes.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '💪 I miei progressi su GymApp!',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Widget _toggleChip({required String label, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? widget.accent.withAlpha(40) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? widget.accent : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? widget.accent : Colors.white54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkCtx(context) ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: _isDarkCtx(context) ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text(
            'Condividi Progressi 📊',
            style: TextStyle(color: _isDarkCtx(context) ? Colors.white : Colors.black87, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            'Scegli cosa includere:',
            style: TextStyle(color: _isDarkCtx(context) ? Colors.white54 : Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _toggleChip(label: '🔥 Streak', active: _includeStreak, onTap: () => setState(() => _includeStreak = !_includeStreak)),
              _toggleChip(label: '🏋 Sessioni', active: _includeSessionCount, onTap: () => setState(() => _includeSessionCount = !_includeSessionCount)),
              _toggleChip(label: '📈 Trend', active: _includeTrend, onTap: () => setState(() => _includeTrend = !_includeTrend)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.share_rounded),
              label: const Text('Condividi Progressi'),
              style: FilledButton.styleFrom(
                backgroundColor: widget.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


