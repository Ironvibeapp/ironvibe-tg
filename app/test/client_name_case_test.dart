import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/l10n/app_localizations.dart';
import 'package:fitness_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<WorkoutLog> savedHistory;
  late List<TrainerSession> savedSchedule;
  late List<Client> savedClients;
  late List<String> savedBank;
  late ActiveWorkoutDraft? savedDraft;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    savedHistory = List.of(workoutHistory);
    savedSchedule = List.of(trainerSchedule);
    savedClients = List.of(clients);
    savedBank = List.of(exerciseBank);
    savedDraft = activeWorkoutDraft;
    workoutHistory = [];
    trainerSchedule = [];
    clients = [];
    exerciseBank = [];
    activeWorkoutDraft = null;
  });

  tearDown(() {
    workoutHistory = savedHistory;
    trainerSchedule = savedSchedule;
    clients = savedClients;
    exerciseBank = savedBank;
    activeWorkoutDraft = savedDraft;
  });

  testWidgets('new client name and last name start with a capital letter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pump(tester, const ClientListScreen());
    await tester.tap(find.text('Добавить клиента'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(_labeledField('Имя'), 'анна-мария');
    await tester.enterText(_labeledField('Фамилия'), 'петрова');
    await tester.pump();

    expect(_fieldText(tester, 'Имя'), 'Анна-Мария');
    expect(_fieldText(tester, 'Фамилия'), 'Петрова');

    await tester.tap(find.widgetWithText(TextButton, 'Добавить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(clients, hasLength(1));
    expect(clients.single.name, 'Анна-Мария');
    expect(clients.single.lastName, 'Петрова');
  });

  testWidgets('client card last name starts with a capital letter', (
    tester,
  ) async {
    final client = Client('Анна', '', id: 'c1');
    clients.add(client);

    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pump(tester, ClientProfileScreen(client: client));
    await tester.pump();

    final field = _labeledField('Фамилия');
    await tester.ensureVisible(field);
    await tester.enterText(field, 'смирнова-петрова');
    await tester.pump();

    expect(_fieldText(tester, 'Фамилия'), 'Смирнова-Петрова');
  });
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ironVibeBuildTheme(Brightness.dark),
      home: home,
    ),
  );
  await tester.pump();
}

Finder _labeledField(String label) {
  return find.byWidgetPredicate((widget) {
    return widget is TextField && widget.decoration?.labelText == label;
  });
}

String _fieldText(WidgetTester tester, String label) {
  final editable = tester.widget<EditableText>(
    find.descendant(
      of: _labeledField(label),
      matching: find.byType(EditableText),
    ),
  );
  return editable.controller.text;
}
