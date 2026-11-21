import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/main.dart';
import 'package:fitness_app/l10n/app_localizations.dart';
import 'package:fitness_app/l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

TrainerSession _session({
  String client = 'Vasya',
  DateTime? date,
  List<ExerciseLog>? exercises,
  String note = '',
}) {
  return TrainerSession(
    date ?? DateTime(2026, 9, 2, 18, 30),
    client,
    note,
    exercises: exercises ?? const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('print rows skip empty names, empty sets, and RIR-only sets', () {
    final session = _session(
      exercises: [
        ExerciseLog('', [SetLog('60', '8', '2')]),
        ExerciseLog('Squat', [SetLog('', '', '1')]),
        ExerciseLog('Bench', [
          SetLog('', '', ''),
          SetLog('60', '8', '2'),
          SetLog('62.5', '8', '1'),
        ]),
      ],
    );
    final rows = ironVibeSessionPrintRows(session);
    expect(rows, hasLength(1));
    expect(rows.single.name, 'BENCH');
    expect(rows.single.detail, '60×8  ·  62.5×8');
  });

  test('print rows format cardio as time · intensity', () {
    final session = _session(
      exercises: [
        ExerciseLog('Row', [
          SetLog('', '', '', isCardio: true, duration: '20', intensity: '7'),
        ], isCardio: true),
      ],
    );
    final rows = ironVibeSessionPrintRows(session);
    expect(rows, hasLength(1));
    expect(rows.single.name, 'ROW');
    expect(rows.single.detail, '20 · 7');
  });

  test('print rows keep one line per named exercise', () {
    final session = _session(
      exercises: [
        ExerciseLog('Squat', [SetLog('100', '5', '2')]),
        ExerciseLog('Bench', [SetLog('60', '8', '2')]),
        ExerciseLog('Row', [SetLog('70', '10', '1')]),
        ExerciseLog('Curl', [SetLog('12', '12', '0')]),
      ],
    );
    final rows = ironVibeSessionPrintRows(session);
    expect(rows.map((r) => r.name).toList(), ['SQUAT', 'BENCH', 'ROW', 'CURL']);
  });

  test('print file stem sanitizes the client name and date', () {
    expect(
      ironVibeSessionPrintFileStem('Серёжа / A', DateTime(2026, 9, 2, 18, 5)),
      'IronVibe_Серёжа_A_2026_09_02',
    );
    expect(
      ironVibeSessionPrintFileStem('   ', DateTime(2026, 1, 1)),
      'IronVibe_Client_2026_01_01',
    );
  });

  test('print when matches the session header clock', () {
    expect(
      ironVibeSessionPrintWhen(DateTime(2026, 9, 2, 18, 5)),
      '02.09.2026 · 18:05',
    );
  });

  test('typical session pdf starts with the PDF header', () async {
    final session = _session(
      note: 'Starter',
      exercises: [
        ExerciseLog('Squat', [SetLog('100', '5', '2')]),
        ExerciseLog('Bench', [
          SetLog('60', '8', '2'),
          SetLog('62.5', '8', '1'),
        ]),
        ExerciseLog('Row', [SetLog('70', '10', '1')]),
        ExerciseLog('Curl', [SetLog('12', '12', '0')]),
      ],
    );
    final bytes = await ironVibeBuildSessionPdfBytes(
      session: session,
      l: AppLocalizationsEn(),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(4000));
  });

  test(
    'history blocks keep date order and the note, and skip empty sessions',
    () {
      final blocks = ironVibeClientHistoryPrintBlocks([
        _session(
          date: DateTime(2026, 1, 3, 9, 0),
          note: '  knees ok  ',
          exercises: [
            ExerciseLog('Squat', [SetLog('100', '5', '2')]),
          ],
        ),
        _session(
          date: DateTime(2026, 3, 1, 18, 15),
          exercises: [
            ExerciseLog('Bench', [SetLog('60', '8', '2')]),
          ],
        ),
        _session(
          date: DateTime(2026, 2, 1, 12, 0),
          note: 'only a note',
          exercises: [
            ExerciseLog('Row', [SetLog('', '', '')]),
          ],
        ),
      ]);

      expect(blocks, hasLength(2));
      expect(blocks.first.dateTime, DateTime(2026, 3, 1, 18, 15));
      expect(blocks.first.note, isEmpty);
      expect(
        ironVibeSessionPrintWhen(blocks.first.dateTime),
        '01.03.2026 · 18:15',
      );
      expect(blocks.last.note, 'knees ok');
      expect(
        ironVibeClientHistoryPrintRange(blocks),
        '03.01.2026 — 01.03.2026',
      );
      expect(
        ironVibeClientHistoryPrintRange([
          blocks.first,
          IronVibeClientHistoryPrintBlock(
            dateTime: DateTime(2026, 3, 1, 8, 0),
            note: '',
            rows: blocks.first.rows,
          ),
        ]),
        '01.03.2026',
      );
    },
  );

  test('history print file stem keeps the client and drops the day', () {
    expect(
      ironVibeClientHistoryPrintFileStem('Серёжа / A'),
      'IronVibe_Серёжа_A_sessions',
    );
  });

  test('client history print keeps only that client\'s finished sessions', () {
    final saved = List.of(trainerSchedule);
    addTearDown(() {
      trainerSchedule
        ..clear()
        ..addAll(saved);
    });
    final anna = Client('Anna', '', id: 'a');
    trainerSchedule
      ..clear()
      ..addAll([
        TrainerSession(
          DateTime(2024, 1, 2, 9, 15),
          'Anna',
          '',
          clientId: 'a',
          isCompleted: true,
          exercises: [
            ExerciseLog('Squat', [SetLog('100', '5', '2')]),
          ],
        ),
        TrainerSession(
          DateTime(2026, 1, 3, 9),
          'Anna',
          'plan',
          clientId: 'a',
          isScheduledPlan: true,
          exercises: [
            ExerciseLog('Squat', [SetLog('80', '5', '2')]),
          ],
        ),
        TrainerSession(
          DateTime(2099, 1, 1, 9),
          'Anna',
          '',
          clientId: 'a',
          isCompleted: true,
          exercises: [
            ExerciseLog('Squat', [SetLog('80', '5', '2')]),
          ],
        ),
        TrainerSession(
          DateTime(2026, 1, 4, 9),
          'Boris',
          '',
          clientId: 'b',
          isCompleted: true,
          exercises: [
            ExerciseLog('Row', [SetLog('70', '10', '1')]),
          ],
        ),
      ]);

    final picked = ironVibeSessionsForClientHistoryPrint(anna);
    expect(picked, hasLength(1));
    expect(picked.single.dateTime, DateTime(2024, 1, 2, 9, 15));
  });

  test(
    'several short sessions share a sheet instead of one page each',
    () async {
      final sessions = [
        for (var i = 0; i < 8; i++)
          _session(
            date: DateTime(2026, 1, 1 + i, 18, 30),
            note: i == 3 ? 'easy day' : '',
            exercises: [
              ExerciseLog('Squat', [SetLog('100', '5', '2')]),
              ExerciseLog('Bench', [SetLog('60', '8', '1')]),
            ],
          ),
      ];
      final bytes = await ironVibeBuildClientHistoryPdfBytes(
        clientLabel: 'Anna',
        sessions: sessions,
        l: AppLocalizationsEn(),
      );
      final pages = _pdfPageCount(bytes);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(pages, 1);
    },
  );

  test('a long session continues on the next sheet', () async {
    final session = _session(
      note: 'long day',
      exercises: [
        for (var i = 0; i < 50; i++)
          ExerciseLog('Move $i', [
            SetLog('40', '10', '2'),
            SetLog('40', '8', '1'),
          ]),
      ],
    );
    final bytes = await ironVibeBuildClientHistoryPdfBytes(
      clientLabel: 'Anna',
      sessions: [session],
      l: AppLocalizationsEn(),
    );
    final pages = _pdfPageCount(bytes);
    expect(pages, greaterThan(1));
    expect(pages, lessThan(8));
  });

  testWidgets('client profile print sits in the empty top corner', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final savedSchedule = List.of(trainerSchedule);
    final savedClients = List.of(clients);
    addTearDown(() {
      trainerSchedule
        ..clear()
        ..addAll(savedSchedule);
      clients
        ..clear()
        ..addAll(savedClients);
    });
    trainerSchedule.clear();
    clients.clear();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ironVibeBuildTheme(Brightness.dark),
        home: ClientProfileScreen(client: Client('Anna', '', id: 'c1')),
      ),
    );
    await tester.pump();

    final printIcon = find.byTooltip('Print all sessions');
    expect(printIcon, findsOneWidget);
    final printBox = tester.getRect(printIcon);
    final backBox = tester.getRect(find.byIcon(Icons.arrow_back));
    final loadBox = tester.getRect(find.byType(IronVibeMuscleLoadCard));
    expect(printBox.center.dx, greaterThan(backBox.center.dx));
    expect(printBox.center.dx, greaterThan(390 / 2));
    expect(printBox.bottom, lessThan(loadBox.top));

    await tester.tap(printIcon);
    await tester.pump();
    expect(
      find.text('Nothing to print yet. Finish at least one session.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

int _pdfPageCount(List<int> bytes) {
  final text = String.fromCharCodes(bytes);
  return RegExp(r'/Type\s*/Page(?!s)').allMatches(text).length;
}
