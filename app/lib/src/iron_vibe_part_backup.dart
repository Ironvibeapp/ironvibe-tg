part of 'package:fitness_app/main.dart';

const int _kBackupNudgeIntervalDays = 28;
const String _kPrefsKeyBackupNudgeAt = 'ironvibe_backup_nudge_at';

bool ironVibeHasBackupWorthyData() {
  if (workoutHistory.isNotEmpty) return true;
  if (clients.isNotEmpty) return true;
  return trainerSchedule.any(ironVibeTrainerSessionIsCompleted);
}

bool ironVibeBackupNudgeIsDue({
  required DateTime now,
  required DateTime? lastAcknowledgedAt,
  required bool hasBackupWorthyData,
}) {
  if (!hasBackupWorthyData) return false;
  if (lastAcknowledgedAt == null) return false;
  return now.difference(lastAcknowledgedAt) >=
      const Duration(days: _kBackupNudgeIntervalDays);
}

Future<DateTime?> ironVibeLoadBackupNudgeAt() async {
  final raw = await IronVibeStore.kv.getString(_kPrefsKeyBackupNudgeAt);
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

Future<void> ironVibeMarkBackupNudgeAcknowledged([DateTime? at]) async {
  await IronVibeStore.kv.setString(
    _kPrefsKeyBackupNudgeAt,
    (at ?? DateTime.now()).toIso8601String(),
  );
}

Future<void> ironVibeEnsureBackupNudgeClock() async {
  final existing = await ironVibeLoadBackupNudgeAt();
  if (existing != null) return;
  await ironVibeMarkBackupNudgeAcknowledged();
}

bool _backupNudgePrefersTrainerExport() {
  return workoutHistory.isEmpty &&
      (clients.isNotEmpty ||
          trainerSchedule.any(ironVibeTrainerSessionIsCompleted));
}

enum IronVibeAthleteImportStatus { success, nameEmpty, nameTaken, nothingNew }

class IronVibeAthleteImportOutcome {
  final IronVibeAthleteImportStatus status;
  final int addedSessionCount;
  final int skippedSessionCount;
  const IronVibeAthleteImportOutcome({
    required this.status,
    this.addedSessionCount = 0,
    this.skippedSessionCount = 0,
  });
}

bool ironVibeBackupHasAthleteWorkouts(Map<String, dynamic> data) {
  final list = data['workoutHistory'];
  return list is List && list.isNotEmpty;
}

bool ironVibeBackupLooksLikeAthleteOnly(Map<String, dynamic> data) {
  if (!ironVibeBackupHasAthleteWorkouts(data)) return false;
  final clientsList = data['clients'];
  final schedule = data['trainerSchedule'];
  final hasClients = clientsList is List && clientsList.isNotEmpty;
  final hasSchedule = schedule is List && schedule.isNotEmpty;
  return !hasClients && !hasSchedule;
}

List<WorkoutLog> ironVibeAthleteWorkoutsFromBackupMap(Map<String, dynamic> data) {
  final list = data['workoutHistory'];
  if (list is! List) return const [];
  final out = <WorkoutLog>[];
  for (final item in list) {
    final map = _jsonMap(item);
    if (map == null) continue;
    out.add(WorkoutLog.fromJson(map));
  }
  return out;
}

String ironVibeAthleteImportSessionId(WorkoutLog w) {
  final existing = w.id?.trim();
  if (existing != null && existing.isNotEmpty) return existing;
  final parts = <String>[w.date.toIso8601String()];
  for (final ex in w.exercises) {
    parts.add(normalizeExerciseName(ex.name));
    parts.add('${ex.sets.length}');
    for (final s in ex.sets) {
      parts.add(
        '${s.weight}|${s.reps}|${s.rir}|${s.isCardio}|${s.duration}|${s.intensity}',
      );
    }
  }
  return 'athleteImport:${parts.join('~')}';
}

IronVibeAthleteImportOutcome ironVibeImportAthleteHistory({
  required List<WorkoutLog> workouts,
  required String clientName,
  String weight = '',
  String height = '',
}) {
  final name = clientName.trim();
  if (name.isEmpty) {
    return const IronVibeAthleteImportOutcome(
      status: IronVibeAthleteImportStatus.nameEmpty,
    );
  }
  if (ironVibeClientNameTaken(name)) {
    return const IronVibeAthleteImportOutcome(
      status: IronVibeAthleteImportStatus.nameTaken,
    );
  }

  final existingIds = trainerSchedule.map((s) => s.id).whereType<String>().toSet();
  final sessions = <TrainerSession>[];
  var skipped = 0;
  for (final w in workouts) {
    final id = ironVibeAthleteImportSessionId(w);
    if (existingIds.contains(id)) {
      skipped++;
      continue;
    }
    existingIds.add(id);
    sessions.add(
      TrainerSession(
        w.date,
        name,
        '',
        exercises: [
          for (final ex in w.exercises)
            ExerciseLog(ex.name, List<SetLog>.from(ex.sets), isCardio: ex.isCardio),
        ],
        id: id,
        isCompleted: true,
        isImportedHistory: true,
      ),
    );
  }

  if (sessions.isEmpty) {
    return IronVibeAthleteImportOutcome(
      status: IronVibeAthleteImportStatus.nothingNew,
      skippedSessionCount: skipped,
    );
  }

  clients.add(
    Client(name, '', weight: weight.trim(), height: height.trim()),
  );
  trainerSchedule.addAll(sessions);
  trainerSchedule.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  return IronVibeAthleteImportOutcome(
    status: IronVibeAthleteImportStatus.success,
    addedSessionCount: sessions.length,
    skippedSessionCount: skipped,
  );
}

Future<void> ironVibeMaybeShowBackupNudge(BuildContext context) async {
  await ironVibeEnsureBackupNudgeClock();
  if (!context.mounted) return;
  final last = await ironVibeLoadBackupNudgeAt();
  if (!ironVibeBackupNudgeIsDue(
    now: DateTime.now(),
    lastAcknowledgedAt: last,
    hasBackupWorthyData: ironVibeHasBackupWorthyData(),
  )) {
    return;
  }
  if (!context.mounted) return;

  final l = AppLocalizations.of(context)!;
  final pal = IronVibePalette.of(context);
  final share = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final dpal = IronVibePalette.of(ctx);
      return AlertDialog(
        backgroundColor: dpal.dialog,
        shape: ironVibeDialogShape(dpal),
        title: Text(
          l.backupNudgeTitle,
          style: TextStyle(
            color: dpal.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          l.backupNudgeBody,
          style: TextStyle(color: dpal.textSecondary, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l.backupNudgeLater,
              style: TextStyle(color: pal.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l.backupNudgeShare,
              style: TextStyle(
                color: dpal.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    },
  );
  await ironVibeMarkBackupNudgeAcknowledged();
  if (!context.mounted || share != true) return;
  await _exportToJson(
    context,
    _backupNudgePrefersTrainerExport(),
    popHostDialog: false,
  );
}

Future<void> _exportToJson(
  BuildContext context,
  bool isTrainer, {
  bool popHostDialog = true,
}) async {
  final locale = AppLocalizations.of(context)!;
  var loadingOpen = false;
  try {
    const uuid = Uuid();
    if (!isTrainer) {
      for (var w in workoutHistory) {
        w.id ??= uuid.v4();
      }
    } else {
      for (var s in trainerSchedule) {
        s.id ??= uuid.v4();
      }
    }
    await DataService.saveData();

    final Map<String, dynamic> payload = {
      'version': _kExportDataVersion,
      'exerciseBank': exerciseBank,
      if (!isTrainer)
        'workoutHistory': workoutHistory.map((e) => e.toJson()).toList(),
      if (!isTrainer) 'favoriteExercises': ironVibeAthleteFavoriteExercises,
      'exerciseMuscleGroups': ironVibeExerciseMuscleGroupsToJsonMap(),
      if (isTrainer) ...{
        'clients': clients.map((e) => e.toJson()).toList(),
        'trainerSchedule': trainerSchedule.map((e) => e.toJson()).toList(),
      },
    };

    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final pal = IronVibePalette.of(ctx);
        return Center(
          child: Material(
            color: Colors.transparent,
            child: CircularProgressIndicator(color: pal.iconPrimary),
          ),
        );
      },
    );
    loadingOpen = true;

    final jsonString = await compute(_encodeJsonPayload, payload);
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    final now = DateTime.now();
    final datePart =
        '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';
    final baseName = isTrainer ? 'IronVibe_Backup_Coach' : 'IronVibe_Backup';
    final safeFileName = '${baseName}_$datePart.json';

    if (!context.mounted) return;
    Navigator.of(context).pop();
    loadingOpen = false;
    if (popHostDialog) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
    }

    try {
      await ironVibeShareFile(
        bytes: bytes,
        filename: safeFileName,
        mimeType: 'application/json',
        text: locale.shareText,
      );
      await ironVibeMarkBackupNudgeAcknowledged();
    } catch (shareError) {
      debugPrint('Share error: $shareError');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${locale.exportError} $shareError'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('Export JSON Error: $e');
    if (loadingOpen && context.mounted) {
      Navigator.of(context).pop();
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${locale.exportError} $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

void _showImportSnackBar(
  BuildContext context,
  String message, {
  Color backgroundColor = Colors.redAccent,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor,
      duration: const Duration(seconds: 3),
    ),
  );
}

Future<Map<String, dynamic>?> _pickBackupJsonMap(BuildContext context) async {
  final locale = AppLocalizations.of(context)!;
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final name = file.name.toLowerCase();
    if (!name.endsWith('.json')) {
      _showImportSnackBar(context, locale.importInvalidBackupFile);
      return null;
    }
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showImportSnackBar(context, locale.importInvalidBackupFile);
      return null;
    }

    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      _showImportSnackBar(context, locale.importInvalidBackupFile);
      return null;
    }

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        _showImportSnackBar(context, locale.importInvalidBackupFile);
        return null;
      }
      data = decoded;
    } on FormatException {
      _showImportSnackBar(context, locale.importInvalidBackupFile);
      return null;
    }

    final version = data['version'] as int? ?? 1;
    if (version > _kExportDataVersion) {
      _showImportSnackBar(
        context,
        locale.importNewerVersion,
        backgroundColor: Colors.orange,
      );
      return null;
    }
    return data;
  } catch (e, stack) {
    debugPrint('Import pick error: $e\n$stack');
    _showImportSnackBar(context, locale.importInvalidBackupFile);
    return null;
  }
}

Future<void> _importFromJson(BuildContext context, bool isTrainer) async {
  final locale = AppLocalizations.of(context)!;
  void showError(String message) {
    _showImportSnackBar(context, message);
  }

  try {
    final data = await _pickBackupJsonMap(context);
    if (data == null) return;

    if (isTrainer && ironVibeBackupLooksLikeAthleteOnly(data)) {
      _showImportSnackBar(
        context,
        locale.importAthleteUseDedicatedButton,
        backgroundColor: Colors.orange,
      );
      return;
    }

    final existingWorkoutIds = workoutHistory
        .map((w) => w.id)
        .whereType<String>()
        .toSet();
    final existingSessionIds = trainerSchedule
        .map((s) => s.id)
        .whereType<String>()
        .toSet();
    final existingClientNames = clients.map((c) => c.name).toSet();

    try {
      if (!isTrainer) {
        final list = data['workoutHistory'] as List? ?? [];
        for (var item in list) {
          final map = _jsonMap(item);
          if (map == null) continue;
          final id = map['id'] as String?;
          if (id != null && existingWorkoutIds.contains(id)) continue;
          final w = WorkoutLog.fromJson(map);
          if (w.id != null) existingWorkoutIds.add(w.id!);
          workoutHistory.add(w);
        }
      } else {
        final clientList = data['clients'] as List? ?? [];
        for (var item in clientList) {
          final map = _jsonMap(item);
          if (map == null) continue;
          final c = Client.fromJson(map);
          if (existingClientNames.contains(c.name)) continue;
          existingClientNames.add(c.name);
          clients.add(c);
        }
        final scheduleList = data['trainerSchedule'] as List? ?? [];
        for (var item in scheduleList) {
          final map = _jsonMap(item);
          if (map == null) continue;
          final id = map['id'] as String?;
          if (id != null && existingSessionIds.contains(id)) continue;
          final s = TrainerSession.fromJson(map);
          if (s.id != null) existingSessionIds.add(s.id!);
          trainerSchedule.add(s);
        }
      }

      final bank = data['exerciseBank'] as List? ?? [];
      for (var name in bank) {
        final s = normalizeExerciseName(
          name is String ? name : name.toString(),
        );
        if (s.isNotEmpty) ensureExerciseInBank(s);
      }

      if (!isTrainer) {
        final favorites = data['favoriteExercises'] as List? ?? [];
        for (var name in favorites) {
          final s = normalizeExerciseName(
            name is String ? name : name.toString(),
          );
          if (s.isEmpty) continue;
          if (!ironVibeAthleteFavoriteExercises.any(
            (e) => normalizeExerciseName(e) == s,
          )) {
            ironVibeAthleteFavoriteExercises.add(s);
          }
        }
      }

      ironVibeMergeMuscleGroupsFromBackup(data['exerciseMuscleGroups']);

      exerciseBank = _dedupeNormalizedExerciseBank(exerciseBank);
      ironVibeAthleteFavoriteExercises =
          _dedupeNormalizedExerciseBank(ironVibeAthleteFavoriteExercises);
      for (final client in clients) {
        client.favoriteExercises =
            _dedupeNormalizedExerciseBank(client.favoriteExercises);
      }
      workoutHistory = workoutHistory
          .map(_normalizeWorkoutLogExerciseNames)
          .toList();
      trainerSchedule = trainerSchedule
          .map(_normalizeTrainerSessionExerciseNames)
          .toList();
      ironVibeRebuildExerciseBankFromCompletedWorkouts();

      if (!isTrainer) {
        workoutHistory.sort((a, b) => a.date.compareTo(b.date));
      } else {
        trainerSchedule.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      }
      await DataService.saveData();

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locale.importSuccess),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('Import parse error: $e\n$stack');
      showError(locale.importInvalidBackupFile);
    }
  } catch (e, stack) {
    debugPrint('Import error: $e\n$stack');
    _showImportSnackBar(context, locale.importInvalidBackupFile);
  }
}

Future<void> _importAthleteHistoryFromJson(BuildContext context) async {
  final locale = AppLocalizations.of(context)!;
  final data = await _pickBackupJsonMap(context);
  if (data == null) return;
  if (!context.mounted) return;

  if (!ironVibeBackupHasAthleteWorkouts(data)) {
    _showImportSnackBar(context, locale.importAthleteNotAthleteFile);
    return;
  }

  final workouts = ironVibeAthleteWorkoutsFromBackupMap(data);
  if (workouts.isEmpty) {
    _showImportSnackBar(context, locale.importAthleteEmpty);
    return;
  }

  final nameController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  try {
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String? error;
        final pal = IronVibePalette.of(ctx);
        final l = AppLocalizations.of(ctx)!;
        InputDecoration fieldDecoration(String hint) {
          return InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: pal.textHint),
            filled: true,
            fillColor: pal.inputFill,
          );
        }

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              backgroundColor: pal.dialog,
              shape: ironVibeDialogShape(pal),
              title: Text(
                l.importAthlete,
                style: TextStyle(
                  color: pal.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.importAthleteFound(workouts.length),
                      style: TextStyle(
                        color: pal.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SteelButton(
                      text: l.importAthleteBackupOwn,
                      icon: Icons.ios_share_rounded,
                      onPressed: () => _exportToJson(
                        ctx,
                        true,
                        popHostDialog: false,
                      ),
                      width: double.infinity,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: pal.textPrimary),
                      decoration: fieldDecoration(l.clientName),
                      onChanged: (_) {
                        if (error != null) setLocal(() => error = null);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.clientNameCannotChange,
                      style: TextStyle(
                        color: pal.textMuted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: heightController,
                      style: TextStyle(color: pal.textPrimary),
                      decoration: fieldDecoration(l.clientHeight),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: weightController,
                      style: TextStyle(color: pal.textPrimary),
                      decoration: fieldDecoration(l.clientWeight),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    l.importAthleteDecline,
                    style: TextStyle(color: pal.textMuted),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final outcome = ironVibeImportAthleteHistory(
                      workouts: workouts,
                      clientName: nameController.text,
                      weight: weightController.text,
                      height: heightController.text,
                    );
                    switch (outcome.status) {
                      case IronVibeAthleteImportStatus.nameEmpty:
                        return;
                      case IronVibeAthleteImportStatus.nameTaken:
                        setLocal(() => error = l.clientNameTaken);
                        return;
                      case IronVibeAthleteImportStatus.nothingNew:
                        Navigator.pop(ctx, false);
                        _showImportSnackBar(
                          context,
                          l.importAthleteAlreadyImported,
                          backgroundColor: Colors.orange,
                        );
                        return;
                      case IronVibeAthleteImportStatus.success:
                        Navigator.pop(ctx, true);
                        return;
                    }
                  },
                  child: Text(
                    l.add,
                    style: TextStyle(
                      color: pal.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (added != true) return;
    await DataService.saveData();
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(locale.importAthleteSuccess),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 2),
      ),
    );
  } finally {
    nameController.dispose();
    heightController.dispose();
    weightController.dispose();
  }
}

void _showStatistics(BuildContext context, bool isTrainer) {
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEndExclusive = DateTime(now.year, now.month + 1, 1);
  final yearStart = DateTime(now.year, 1, 1);
  final yearEndExclusive = DateTime(now.year + 1, 1, 1);
  int monthCount = 0;
  int yearCount = 0;
  int totalCount = 0;

  if (isTrainer) {
    final logged = trainerSchedule.where(ironVibeTrainerSessionCountsAsWork);
    totalCount = logged.length;
    for (var s in logged) {
      if (!s.dateTime.isBefore(monthStart) &&
          s.dateTime.isBefore(monthEndExclusive)) {
        monthCount++;
      }
      if (!s.dateTime.isBefore(yearStart) &&
          s.dateTime.isBefore(yearEndExclusive)) {
        yearCount++;
      }
    }
  } else {
    totalCount = workoutHistory.length;
    for (var w in workoutHistory) {
      if (!w.date.isBefore(monthStart) && w.date.isBefore(monthEndExclusive)) {
        monthCount++;
      }
      if (!w.date.isBefore(yearStart) && w.date.isBefore(yearEndExclusive)) {
        yearCount++;
      }
    }
  }

  showDialog(
    context: context,
    builder: (ctx) {
      final pal = IronVibePalette.of(ctx);
      final l = AppLocalizations.of(ctx)!;
      return AlertDialog(
        backgroundColor: pal.dialog,
        shape: ironVibeDialogShape(pal),
        title: Center(
          child: Text(
            l.statistics,
            style: TextStyle(
              color: pal.textPrimary,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              _buildStatItem(ctx, l.monthStats, '$monthCount'),
              const SizedBox(height: 20),
              _buildStatItem(ctx, l.yearStats, '$yearCount'),
              const SizedBox(height: 20),
              _buildStatItem(ctx, l.allTimeStats, '$totalCount'),
              const SizedBox(height: 40),
              SteelButton(
                text: l.exportHistory,
                icon: Icons.ios_share_rounded,
                onPressed: () => _exportToJson(ctx, isTrainer),
                width: double.infinity,
              ),
              const SizedBox(height: 10),
              SteelButton(
                text: l.importData,
                icon: Icons.download_rounded,
                onPressed: () => _importFromJson(ctx, isTrainer),
                width: double.infinity,
              ),
              if (isTrainer) ...[
                const SizedBox(height: 10),
                SteelButton(
                  text: l.importAthlete,
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: () => _importAthleteHistoryFromJson(ctx),
                  width: double.infinity,
                ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l.close,
              style: TextStyle(color: pal.textPrimary),
            ),
          ),
        ],
      );
    },
  );
}

Widget _buildStatItem(BuildContext context, String label, String value) {
  final pal = IronVibePalette.of(context);
  final bigColor = pal.brightness == Brightness.dark
      ? const Color(0xFFB0BEC5)
      : pal.iconPrimary;
  return Column(
    children: [
      Text(
        value,
        style: TextStyle(
          color: bigColor,
          fontSize: 48,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          color: pal.textMuted,
          fontSize: 12,
          letterSpacing: 1.5,
        ),
      ),
    ],
  );
}
