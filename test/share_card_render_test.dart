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

Future<void> _captureStoryPng(
  WidgetTester tester,
  String outPath,
) async {
  await tester.runAsync(() async {
    final ctx = tester.element(find.byType(Scaffold));
    await precacheImage(const AssetImage('assets/icon_client.png'), ctx);
  });
  await tester.pump();

  final boundaryFinder = find
      .ancestor(
        of: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 360 && w.height == 640,
        ),
        matching: find.byType(RepaintBoundary),
      )
      .first;
  final boundary =
      tester.renderObject(boundaryFinder) as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3.0);
    expect(image.width, 1080);
    expect(image.height, 1920);
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

  testWidgets('Workout share card renders 9:16 PNG with improvements & PRs under light theme',
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
    expect(find.text('+4.8%'), findsOneWidget);
    expect(find.text('58 min'), findsOneWidget);
    expect(find.textContaining('0 kg'), findsNothing);
    expect(find.textContaining('16 reps'), findsOneWidget);

    await _captureStoryPng(tester, 'build/share_previews/workout_share_card.png');

    // Verify toggling chips cleanly updates the card without layout errors
    await tester.tap(find.text(AppL.vsPrevious));
    await tester.pumpAndSettle();
    expect(find.text('+4.8%'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(AppL.chartRecord));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
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
  });

  testWidgets('Streak share card renders 9:16 PNG cleanly',
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
    await _captureStoryPng(tester, 'build/share_previews/streak_share_card.png');
  });

  testWidgets('Progress share card renders 9:16 PNG cleanly',
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
    await _captureStoryPng(tester, 'build/share_previews/progress_share_card.png');
  });
}
