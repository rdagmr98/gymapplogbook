import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_cliente/app_l.dart';
import 'package:app_cliente/main.dart';

Future<void> _loadTestFonts() async {
  const sdkFontDir = r'C:\tools\flutter\bin\cache\artifacts\material_fonts';
  final robotoFiles = [
    '$sdkFontDir\\roboto-regular.ttf',
    '$sdkFontDir\\roboto-medium.ttf',
    '$sdkFontDir\\roboto-bold.ttf',
    '$sdkFontDir\\roboto-black.ttf',
  ];
  final robotoLoader = FontLoader('Roboto');
  var loadedRoboto = false;
  for (final path in robotoFiles) {
    final file = File(path);
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      robotoLoader.addFont(Future.value(ByteData.sublistView(bytes)));
      loadedRoboto = true;
    }
  }
  if (loadedRoboto) {
    await robotoLoader.load();
  }

  for (final iconPath in [
    '$sdkFontDir\\materialicons-regular.otf',
    'assets/fonts/MaterialIcons-Regular.otf',
  ]) {
    final file = File(iconPath);
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      final iconLoader = FontLoader('MaterialIcons');
      iconLoader.addFont(Future.value(ByteData.sublistView(bytes)));
      await iconLoader.load();
      break;
    }
  }
}

Finder _card() => find.byWidgetPredicate((w) => w is RepaintBoundary && w.key is GlobalKey).last;

// la riga da [left] a [right] deve stare al centro della card
void _expectCentered(WidgetTester tester, Finder left, Finder right) {
  final mid = (tester.getRect(left).left + tester.getRect(right).right) / 2;
  expect(mid, closeTo(tester.getCenter(_card()).dx, 1.5));
}

// la riga da [left] a [right] deve toccare i due margini interni (padding 12 + bordo 1)
void _expectJustified(WidgetTester tester, Finder left, Finder right) {
  expect(tester.getRect(left).left, closeTo(tester.getRect(_card()).left + 13, 1.5));
  expect(tester.getRect(right).right, closeTo(tester.getRect(_card()).right - 13, 1.5));
}

// [a] e [b] sulla stessa riga
void _expectInline(WidgetTester tester, Finder a, Finder b) {
  expect(tester.getCenter(a).dy, closeTo(tester.getCenter(b).dy, 2));
}

Future<void> _captureStoryPng(
  WidgetTester tester,
  String outPath,
) async {
  await tester.runAsync(() async {
    final ctx = tester.element(find.byType(Scaffold));
    await precacheImage(const AssetImage('assets/icon_client.png'), ctx);
  });
  await tester.pump();

  // la card condivisa è il RepaintBoundary con la GlobalKey (_cardKey)
  final boundaryFinder = find
      .byWidgetPredicate((w) => w is RepaintBoundary && w.key is GlobalKey)
      .last;
  final boundary =
      tester.renderObject(boundaryFinder) as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  final outFile = File(outPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsBytesSync(bytes!);
}

Widget _wrapSheet(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: brightness),
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: child,
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadTestFonts();
    AppL.setLang('it');
  });

  testWidgets('Workout share card renders PNG with improvements & PRs under light theme',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapSheet(
        brightness: Brightness.light,
        testWorkoutShareSheet(
          dayName: 'Push · Petto & Spalle',
          todayLabel: '16 nov 2026',
          durationMinutes: 58,
          progressPercent: 4.8,
          streak: 6,
          accent: const Color(0xFF00F2FF),
          allSessionNames: const ['Push', 'Pull', 'Legs', 'Upper'],
          streakDoneNames: const {'Push', 'Pull', 'Legs'},
          records: const [
            (exercise: 'Panca piana bilanciere', w: 85.0, r: 7),
          ],
          exercises: const [
            {
              'exercise': 'Panca piana bilanciere',
              'series': [
                {'w': 80.0, 'r': 8},
                {'w': 85.0, 'r': 7},
                {'w': 80.0, 'r': 8},
              ],
            },
            {
              'exercise': 'Spinte manubri su panca inclinata',
              'series': [
                {'w': 32.0, 'r': 10},
                {'w': 32.0, 'r': 9},
              ],
            },
            {
              'exercise': 'Alzate laterali manubri',
              'series': [
                {'w': 14.0, 'r': 14},
                {'w': 14.0, 'r': 13},
              ],
            },
            {
              'exercise': 'Dip alle parallele',
              'series': [
                {'w': 0.0, 'r': 16},
                {'w': 0.0, 'r': 14},
              ],
            },
            {
              'exercise': 'French press bilanciere EZ',
              'series': [
                {'w': 35.0, 'r': 10},
              ],
            },
          ],
          previousResults: const {
            'Panca piana bilanciere': [
              {'w': 80.0, 'r': 8},
              {'w': 82.5, 'r': 6},
              {'w': 77.5, 'r': 8},
            ],
            'Spinte manubri su panca inclinata': [
              {'w': 32.0, 'r': 8},
              {'w': 32.0, 'r': 8},
            ],
            'Alzate laterali manubri': [
              {'w': 12.0, 'r': 14},
              {'w': 12.0, 'r': 12},
            ],
            'Dip alle parallele': [
              {'w': 0.0, 'r': 14},
              {'w': 0.0, 'r': 13},
            ],
            'French press bilanciere EZ': [
              {'w': 35.0, 'r': 10},
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('58 min'), findsOneWidget);
    expect(find.textContaining('0 kg'), findsNothing);
    expect(find.textContaining('16 reps'), findsOneWidget);

    await _captureStoryPng(tester, 'build/share_previews/workout_share_card.png');

    // durata, streak e % in testa; i badge senza lucchetto
    expect(find.text('3/4'), findsNothing);
    expect(find.byIcon(Icons.lock_open_rounded), findsNothing);
    expect(find.text('Upper'), findsOneWidget);
    expect(tester.getSize(_card()).height, lessThanOrEqualTo(240));
    _expectInline(tester, find.text('GymApp'), find.text('58 min'));
    _expectInline(tester, find.text('GymApp'), find.text('6 ${AppL.microAbbr}'));
    _expectInline(tester, find.text(' · 16 nov 2026'), find.text('+4.8%'));
    expect(tester.getRect(find.text('Push · Petto & Spalle')).left,
        closeTo(tester.getRect(find.text('GymApp')).left, 1));
    _expectJustified(tester, find.text('French press bilanciere EZ'), find.text('35 kg × 10'));
    _expectCentered(tester, find.text('Push'), find.text('Upper'));

    // Verify toggling chips cleanly updates the card without layout errors
    await tester.tap(find.text(AppL.vsPrevious).last);
    await tester.pumpAndSettle();
    expect(find.text('+4.8%'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(AppL.vsPrevious).last);
    await tester.pumpAndSettle();
    expect(find.text('+4.8%'), findsOneWidget);
    await _captureStoryPng(tester, 'build/share_previews/workout_share_card_all.png');
  });

  testWidgets('Workout share card handles extreme lengths, lb units, and first session without overflow',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapSheet(
        brightness: Brightness.dark,
        testWorkoutShareSheet(
          dayName: 'Allenamento Forza Massimale Petto Tricipiti Spalle Avanzato',
          todayLabel: '16 novembre 2026',
          durationMinutes: 125,
          progressPercent: null,
          usePounds: true,
          streak: 0,
          accent: const Color(0xFFFFD740),
          allSessionNames: const [
            'Giorno A Petto Pesante',
            'Giorno B Dorso Spessore',
            'Giorno C Gambe Quadricipiti',
            'Giorno D Spalle Braccia',
            'Giorno E Richiamo Femorali',
            'Giorno F Conditioning Extra',
          ],
          streakDoneNames: const {'Giorno A Petto Pesante'},
          records: const [
            (
              exercise: 'Distensioni manubri su panca inclinata 30 gradi presa neutra',
              w: 40.0,
              r: 10,
            ),
            (exercise: 'Squat bilanciere profondo', w: 120.0, r: 6),
            (exercise: 'Trazioni alla sbarra presa prona', w: 0.0, r: 15),
          ],
          exercises: const [
            {
              'exercise': 'Distensioni manubri su panca inclinata 30 gradi presa neutra',
              'series': [{'w': 40.0, 'r': 10}],
            },
            {
              'exercise': 'Squat bilanciere profondo',
              'series': [{'w': 120.0, 'r': 6}],
            },
            {
              'exercise': 'Trazioni alla sbarra presa prona',
              'series': [{'w': 0.0, 'r': 15}],
            },
            {
              'exercise': 'Alzate laterali ai cavi bassi singolo braccio',
              'series': [{'w': 10.0, 'r': 15}],
            },
            {
              'exercise': 'Curl manubri su panca inclinata 45 gradi',
              'series': [{'w': 16.0, 'r': 12}],
            },
            {
              'exercise': 'Calf raise alla pressa orizzontale',
              'series': [{'w': 100.0, 'r': 20}],
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _captureStoryPng(tester, 'build/share_previews/workout_share_card_extreme.png');
  });

  testWidgets('Streak share card renders PNG cleanly',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapSheet(
        brightness: Brightness.light,
        testStreakShareSheet(
          streak: 12,
          allSessionNames: const ['Push', 'Pull', 'Legs', 'Upper'],
          streakDoneNames: const {'Push', 'Pull', 'Legs', 'Upper'},
          accent: const Color(0xFF00F2FF),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    _expectInline(tester, find.text('GymApp'), find.text(AppL.getItOnPlay));
    _expectJustified(tester, find.text('GymApp'), find.text(AppL.getItOnPlay));
    expect(find.byType(GestureDetector).evaluate().where((e) => (e.widget as GestureDetector).child is AnimatedContainer),
        isEmpty, reason: 'badge fissi, nessun comando');
    expect(tester.getSize(_card()).height, lessThanOrEqualTo(140));
    await _captureStoryPng(tester, 'build/share_previews/streak_share_card.png');
  });

  testWidgets('10 giorni e streak a 3 cifre a 320 dp, in tutte le lingue', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => AppL.setLang('it'));
    final days = [for (int i = 1; i <= 10; i++) 'Giorno $i Petto Pesante'];
    final done = days.take(4).toSet();
    for (final lang in ['en', 'es', 'pt', 'fr', 'de', 'el', 'ar', 'pl', 'ro', 'hu', 'it']) {
      AppL.setLang(lang);
      await tester.pumpWidget(_wrapSheet(
        brightness: Brightness.dark,
        testStreakShareSheet(
          streak: 128,
          allSessionNames: days,
          streakDoneNames: done,
          accent: const Color(0xFFFFD740),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: lang);
    }
    await _captureStoryPng(tester, 'build/share_previews/streak_share_card_extreme.png');

    for (final lang in ['en', 'es', 'pt', 'fr', 'de', 'el', 'ar', 'pl', 'ro', 'hu', 'it']) {
      AppL.setLang(lang);
      await tester.pumpWidget(_wrapSheet(
        testWorkoutShareSheet(
          dayName: days.first,
          todayLabel: '30 nov 2026', // il formato più lungo tra i due dell'app
          exercises: const [],
          durationMinutes: 125,
          progressPercent: -112.5,
          streak: 128,
          allSessionNames: days,
          streakDoneNames: done,
          accent: const Color(0xFF00F2FF),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: lang);
    }
    await _captureStoryPng(tester, 'build/share_previews/workout_share_card_320.png');
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'testo di sistema 1.3');
    await _captureStoryPng(tester, 'build/share_previews/workout_share_card_320_big.png');
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pumpAndSettle();

    await tester.pumpWidget(_wrapSheet(
      testWorkoutShareSheet(
        dayName: days.first,
        todayLabel: '16 novembre 2026',
        exercises: const [],
        streak: 128,
        allSessionNames: days,
        streakDoneNames: done,
        accent: const Color(0xFF00F2FF),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.descendant(of: _card(), matching: find.byType(Divider)), findsOneWidget);
    await _captureStoryPng(tester, 'build/share_previews/workout_share_card_10days.png');
  });

  testWidgets('Progress share card renders PNG cleanly',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final points = [
      for (int i = 0; i < 8; i++)
        (
          id: 'c_$i',
          date: DateTime(2026, 9, 20).add(Duration(days: i * 7)),
          score: 100.0 + i * 2.6 + (i.isEven ? 0.8 : -0.4),
          dayName: 'Microciclo ${i + 1}',
        ),
    ];
    await tester.pumpWidget(
      _wrapSheet(
        brightness: Brightness.light,
        testProgressShareSheet(
          streak: 8,
          points: points,
          accent: const Color(0xFF00F2FF),
          top: const [
            (
              name: 'Panca piana bilanciere',
              values: [80, 82.5, 85, 87.5],
              delta: 14.2,
              bodyweight: false,
              lastW: 85.0,
              lastR: 7,
            ),
            (
              name: 'Squat bilanciere',
              values: [100, 105, 110, 115],
              delta: 11.8,
              bodyweight: false,
              lastW: 115.0,
              lastR: 6,
            ),
            (
              name: 'Dip alle parallele',
              values: [10, 12, 14, 16],
              delta: 60.0,
              bodyweight: true,
              lastW: 0.0,
              lastR: 16,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(_card()).height, lessThanOrEqualTo(230));
    _expectJustified(tester, find.text('Squat bilanciere'), find.text('+12%'));
    _expectInline(tester, find.text('GymApp'), find.text('Streak').first);
    await _captureStoryPng(tester, 'build/share_previews/progress_share_card.png');

    await tester.binding.setSurfaceSize(const Size(320, 915));
    addTearDown(() => AppL.setLang('it'));
    for (final lang in ['en', 'es', 'pt', 'fr', 'el', 'ar', 'pl', 'ro', 'hu', 'de']) {
      AppL.setLang(lang);
      await tester.pumpWidget(_wrapSheet(
        testProgressShareSheet(streak: 128, points: points, top: const [], accent: const Color(0xFF00F2FF)),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: lang);
    }
    await _captureStoryPng(tester, 'build/share_previews/progress_share_card_320.png');
  });

  test('updateHistoryEntrySeries aggiorna la voce con stesso session_id ed exercise', () {
    final history = <dynamic>[
      {
        'exercise': 'Panca Piana',
        'series': [
          {'s': 1, 'w': 60.0, 'r': 10},
          {'s': 2, 'w': 60.0, 'r': 8},
        ],
        'date': '2026-11-10T18:00:00',
        'dayName': 'Push',
        'session_id': 'sid_1',
      },
      {
        'exercise': 'Panca Piana',
        'series': [
          {'s': 1, 'w': 62.5, 'r': 10},
          {'s': 2, 'w': 62.5, 'r': 9},
        ],
        'date': '2026-11-20T18:00:00',
        'dayName': 'Push',
        'session_id': 'sid_2',
      },
      {
        'exercise': 'Croci Cavi',
        'series': [
          {'s': 1, 'w': 15.0, 'r': 12},
        ],
        'date': '2026-11-20T18:15:00',
        'dayName': 'Push',
        'session_id': 'sid_2',
      },
    ];

    final updated = [
      {'s': 1, 'w': 65.0, 'r': 10},
      {'s': 2, 'w': 65.0, 'r': 8},
    ];
    final ok = updateHistoryEntrySeries(history, 'sid_2', 'Panca Piana', updated);
    expect(ok, isTrue);
    expect((history[1]['series'] as List)[0]['w'], 65.0);
    expect((history[1]['series'] as List)[1]['r'], 8);
    // Non tocca la sessione precedente né gli altri esercizi della stessa sessione
    expect((history[0]['series'] as List)[0]['w'], 60.0);
    expect((history[2]['series'] as List)[0]['w'], 15.0);

    // Non trova una voce inesistente
    expect(updateHistoryEntrySeries(history, 'sid_999', 'Panca Piana', updated), isFalse);
  });

  testWidgets('CancellazioneScreen (Gestione Dati) renders PNG cleanly in dark theme',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final cardKey = GlobalKey();
    final fakeRoutine = [
      WorkoutDay(
        dayName: 'Push · Petto & Spalle',
        bodyParts: const ['petto', 'spalle'],
        exercises: [
          ExerciseConfig(name: 'Panca piana bilanciere', targetSets: 3, repsList: [8, 8, 8], recoveryTime: 90),
          ExerciseConfig(name: 'Spinte manubri su panca inclinata', targetSets: 3, repsList: [10, 10, 10], recoveryTime: 90),
          ExerciseConfig(name: 'Alzate laterali manubri', targetSets: 3, repsList: [14, 14, 14], recoveryTime: 60),
        ],
      ),
      WorkoutDay(
        dayName: 'Pull · Dorso & Bicipiti',
        bodyParts: const ['dorso', 'braccia'],
        exercises: [
          ExerciseConfig(name: 'Lat machine avanti', targetSets: 3, repsList: [10, 10, 10], recoveryTime: 90),
          ExerciseConfig(name: 'Rematore bilanciere', targetSets: 3, repsList: [8, 8, 8], recoveryTime: 90),
        ],
      ),
      WorkoutDay(
        dayName: 'Legs · Gambe',
        bodyParts: const ['gambe'],
        exercises: [
          ExerciseConfig(name: 'Squat bilanciere', targetSets: 4, repsList: [6, 6, 8, 8], recoveryTime: 120),
        ],
      ),
    ];
    final fakeHistory = <dynamic>[
      {
        'exercise': 'Panca piana bilanciere',
        'dayName': 'Push · Petto & Spalle',
        'date': '2026-11-10T18:10:00',
        'session_id': 's1',
        'series': [
          {'s': 1, 'w': 80.0, 'r': 8},
          {'s': 2, 'w': 82.5, 'r': 7},
          {'s': 3, 'w': 80.0, 'r': 7},
        ],
      },
      {
        'exercise': 'Panca piana bilanciere',
        'dayName': 'Push · Petto & Spalle',
        'date': '2026-11-17T18:25:00',
        'session_id': 's4',
        'series': [
          {'s': 1, 'w': 82.5, 'r': 8},
          {'s': 2, 'w': 85.0, 'r': 7},
          {'s': 3, 'w': 80.0, 'r': 8},
        ],
      },
      {
        'exercise': 'Spinte manubri su panca inclinata',
        'dayName': 'Push · Petto & Spalle',
        'date': '2026-11-17T18:40:00',
        'session_id': 's4',
        'series': [
          {'s': 1, 'w': 32.0, 'r': 10},
          {'s': 2, 'w': 32.0, 'r': 9},
        ],
      },
      {
        'exercise': 'Alzate laterali manubri',
        'dayName': 'Push · Petto & Spalle',
        'date': '2026-11-17T18:55:00',
        'session_id': 's4',
        'series': [
          {'s': 1, 'w': 14.0, 'r': 14},
          {'s': 2, 'w': 14.0, 'r': 13},
        ],
      },
      {
        'exercise': 'Lat machine avanti',
        'dayName': 'Pull · Dorso & Bicipiti',
        'date': '2026-11-14T19:00:00',
        'session_id': 's2',
        'series': [
          {'s': 1, 'w': 65.0, 'r': 10},
          {'s': 2, 'w': 65.0, 'r': 9},
          {'s': 3, 'w': 60.0, 'r': 10},
        ],
      },
      {
        'exercise': 'Rematore bilanciere',
        'dayName': 'Pull · Dorso & Bicipiti',
        'date': '2026-11-14T19:15:00',
        'session_id': 's2',
        'series': [
          {'s': 1, 'w': 70.0, 'r': 8},
          {'s': 2, 'w': 70.0, 'r': 8},
        ],
      },
      {
        'exercise': 'Squat bilanciere',
        'dayName': 'Legs · Gambe',
        'date': '2026-11-15T17:30:00',
        'session_id': 's3',
        'series': [
          {'s': 1, 'w': 110.0, 'r': 6},
          {'s': 2, 'w': 115.0, 'r': 6},
          {'s': 3, 'w': 105.0, 'r': 8},
        ],
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: cardKey,
          child: CancellazioneScreen(
            history: fakeHistory,
            routine: fakeRoutine,
            onSave: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _captureStoryPng(tester, 'build/share_previews/gestione_dati.png');
  });
}
