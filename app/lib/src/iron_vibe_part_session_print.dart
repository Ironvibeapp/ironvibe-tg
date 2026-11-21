part of 'package:fitness_app/main.dart';

const PdfColor _kPrintSteel = PdfColor.fromInt(0xFF2A3140);
const PdfColor _kPrintGold = PdfColor.fromInt(0xFFC4A06A);

const String _kPrintFontRegular = 'assets/fonts/NotoSans-Regular.ttf';
const String _kPrintFontBold = 'assets/fonts/NotoSans-Bold.ttf';
const String _kPrintFontSc = 'assets/fonts/NotoSansSC-Regular.ttf';
const String _kPrintFontAr = 'assets/fonts/NotoSansArabic-Regular.ttf';
const String _kPrintFontHi = 'assets/fonts/NotoSansDevanagari-Regular.ttf';
const String _kPrintLogoAsset = 'assets/logo_on_light.svg';

pw.Font? _printFontRegular;
pw.Font? _printFontBold;
pw.Font? _printFontSc;
pw.Font? _printFontAr;
pw.Font? _printFontHi;
Uint8List? _printLogoPng;

class IronVibeSessionPrintRow {
  final String name;
  final String detail;

  const IronVibeSessionPrintRow({required this.name, required this.detail});
}

/// One paper row per named exercise that has at least one filled set.
/// Strength: weight×reps only (RIR stays off the sheet). Cardio: time · intensity.
List<IronVibeSessionPrintRow> ironVibeSessionPrintRows(TrainerSession session) {
  final rows = <IronVibeSessionPrintRow>[];
  for (final ex in session.exercises) {
    final name = normalizeExerciseName(ex.name);
    if (name.isEmpty) continue;
    final detail = ex.isCardio
        ? _printCardioDetail(ex)
        : _printStrengthDetail(ex);
    if (detail.isEmpty) continue;
    rows.add(IronVibeSessionPrintRow(name: name, detail: detail));
  }
  return rows;
}

String ironVibeSessionPrintDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

String ironVibeSessionPrintWhen(DateTime date) {
  final timeStr =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  return '${ironVibeSessionPrintDate(date)} · $timeStr';
}

String _printSafeClientToken(String clientName) {
  var cleaned = clientName
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
  if (cleaned.isEmpty) cleaned = 'Client';
  if (cleaned.length > 40) cleaned = cleaned.substring(0, 40);
  return cleaned;
}

String ironVibeSessionPrintFileStem(String clientName, DateTime date) {
  final datePart =
      '${date.year}_${date.month.toString().padLeft(2, '0')}_${date.day.toString().padLeft(2, '0')}';
  return 'IronVibe_${_printSafeClientToken(clientName)}_$datePart';
}

String ironVibeClientHistoryPrintFileStem(String clientName) {
  return 'IronVibe_${_printSafeClientToken(clientName)}_sessions';
}

class IronVibeClientHistoryPrintBlock {
  final DateTime dateTime;
  final String note;
  final List<IronVibeSessionPrintRow> rows;

  const IronVibeClientHistoryPrintBlock({
    required this.dateTime,
    required this.note,
    required this.rows,
  });
}

/// Finished sessions for [client] that have something to put on paper.
List<TrainerSession> ironVibeSessionsForClientHistoryPrint(Client client) {
  return [
    for (final session in trainerSchedule)
      if (ironVibeSessionBelongsToClientRecord(session, client) &&
          ironVibeTrainerSessionInClientHistory(session))
        session,
  ];
}

/// Newest session first, matching the history on the client profile.
/// Sessions with no filled sets are left out.
List<IronVibeClientHistoryPrintBlock> ironVibeClientHistoryPrintBlocks(
  Iterable<TrainerSession> sessions,
) {
  final blocks = <IronVibeClientHistoryPrintBlock>[];
  for (final session in sessions) {
    final rows = ironVibeSessionPrintRows(session);
    if (rows.isEmpty) continue;
    blocks.add(
      IronVibeClientHistoryPrintBlock(
        dateTime: session.dateTime,
        note: session.note.trim(),
        rows: rows,
      ),
    );
  }
  blocks.sort((a, b) => b.dateTime.compareTo(a.dateTime));
  return blocks;
}

String ironVibeClientHistoryPrintRange(
  List<IronVibeClientHistoryPrintBlock> blocks,
) {
  if (blocks.isEmpty) return '';
  final newest = ironVibeSessionPrintDate(blocks.first.dateTime);
  final oldest = ironVibeSessionPrintDate(blocks.last.dateTime);
  if (newest == oldest) return newest;
  return '$oldest — $newest';
}

String _printStrengthDetail(ExerciseLog ex) {
  final parts = <String>[];
  for (final s in ex.sets) {
    if (s.isCardio) continue;
    final w = s.weight.trim();
    final r = s.reps.trim();
    if (w.isEmpty && r.isEmpty) continue;
    if (w.isEmpty) {
      parts.add(r);
    } else if (r.isEmpty) {
      parts.add(w);
    } else {
      parts.add('$w×$r');
    }
  }
  return parts.join('  ·  ');
}

String _printCardioDetail(ExerciseLog ex) {
  final parts = <String>[];
  for (final s in ex.sets) {
    final bits = <String>[];
    final d = s.duration.trim();
    final i = s.intensity.trim();
    if (d.isNotEmpty) bits.add(d);
    if (i.isNotEmpty) bits.add(i);
    if (bits.isNotEmpty) parts.add(bits.join(' · '));
  }
  return parts.join('  ·  ');
}

Future<void> _ensurePrintAssets() async {
  _printFontRegular ??= pw.Font.ttf(await rootBundle.load(_kPrintFontRegular));
  _printFontBold ??= pw.Font.ttf(await rootBundle.load(_kPrintFontBold));
  _printFontSc ??= pw.Font.ttf(await rootBundle.load(_kPrintFontSc));
  _printFontAr ??= pw.Font.ttf(await rootBundle.load(_kPrintFontAr));
  _printFontHi ??= pw.Font.ttf(await rootBundle.load(_kPrintFontHi));
  _printLogoPng ??= await _rasterizePrintLogo();
}

Future<Uint8List> _rasterizePrintLogo() async {
  const width = 400;
  const height = 560;
  final pictureInfo = await vg.loadPicture(
    const SvgAssetLoader(_kPrintLogoAsset),
    null,
  );
  try {
    final image = await pictureInfo.picture.toImage(width, height);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw StateError('Could not rasterize print logo');
      }
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    pictureInfo.picture.dispose();
  }
}

Future<Uint8List> ironVibeBuildSessionPdfBytes({
  required TrainerSession session,
  required AppLocalizations l,
}) async {
  await _ensurePrintAssets();
  final rows = ironVibeSessionPrintRows(session);
  final logo = pw.MemoryImage(_printLogoPng!);
  final theme = pw.ThemeData.withFont(
    base: _printFontRegular!,
    bold: _printFontBold!,
    fontFallback: [_printFontSc!, _printFontAr!, _printFontHi!],
  );

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 36, 48, 40),
      theme: theme,
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : _printContinuationHeader(session),
      footer: (context) => _printFooter(context),
      build: (context) => [
        _printBrandHeader(session, l, logo),
        pw.SizedBox(height: 18),
        _printExerciseTable(rows, l),
      ],
    ),
  );
  return doc.save();
}

pw.Widget _printBrandHeader(
  TrainerSession session,
  AppLocalizations l,
  pw.ImageProvider logo,
) {
  final note = session.note.trim();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Image(logo, height: 22 * PdfPageFormat.mm, fit: pw.BoxFit.contain),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  l.appName,
                  style: pw.TextStyle(
                    color: _kPrintSteel,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  ironVibeSessionClientLabel(session),
                  style: pw.TextStyle(
                    color: _kPrintSteel,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  ironVibeSessionPrintWhen(session.dateTime),
                  style: const pw.TextStyle(color: _kPrintSteel, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Container(height: 0.6, color: _kPrintGold),
      if (note.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Text(
          note,
          style: const pw.TextStyle(color: _kPrintSteel, fontSize: 10),
        ),
      ],
    ],
  );
}

pw.Widget _printContinuationHeader(TrainerSession session) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          '${ironVibeSessionClientLabel(session)}  ·  ${ironVibeSessionPrintWhen(session.dateTime)}',
          style: const pw.TextStyle(color: _kPrintSteel, fontSize: 9),
        ),
        pw.SizedBox(height: 4),
        pw.Container(height: 0.4, color: _kPrintGold),
      ],
    ),
  );
}

pw.Widget _printFooter(pw.Context context) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 8),
    child: pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        '${context.pageNumber} / ${context.pagesCount}',
        style: const pw.TextStyle(color: _kPrintSteel, fontSize: 8),
      ),
    ),
  );
}

pw.Widget _printExerciseTable(
  List<IronVibeSessionPrintRow> rows,
  AppLocalizations l,
) {
  pw.Widget cell(String text, {bool bold = false, bool header = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: _kPrintSteel,
          fontSize: header ? 9 : 10.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          letterSpacing: header ? 0.4 : 0,
        ),
      ),
    );
  }

  return pw.Table(
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _kPrintSteel, width: 0.25),
    ),
    columnWidths: const {
      0: pw.FlexColumnWidth(1.15),
      1: pw.FlexColumnWidth(1.85),
    },
    children: [
      pw.TableRow(
        children: [
          cell(l.exerciseHeader, bold: true, header: true),
          cell(l.sets, bold: true, header: true),
        ],
      ),
      ...rows.map(
        (row) => pw.TableRow(
          children: [cell(row.name, bold: true), cell(row.detail)],
        ),
      ),
    ],
  );
}

const PdfColor _kPrintHairline = PdfColor.fromInt(0x592A3140);
const int _kPrintNoteChunk = 480;

Future<Uint8List> ironVibeBuildClientHistoryPdfBytes({
  required String clientLabel,
  required List<TrainerSession> sessions,
  required AppLocalizations l,
}) async {
  await _ensurePrintAssets();
  final blocks = ironVibeClientHistoryPrintBlocks(sessions);
  final logo = pw.MemoryImage(_printLogoPng!);
  final theme = pw.ThemeData.withFont(
    base: _printFontRegular!,
    bold: _printFontBold!,
    fontFallback: [_printFontSc!, _printFontAr!, _printFontHi!],
  );
  final body = <pw.Widget>[
    _printHistoryBrandHeader(
      clientLabel: clientLabel,
      blocks: blocks,
      l: l,
      logo: logo,
    ),
    _printHistoryColumnLabels(l),
    for (var i = 0; i < blocks.length; i++)
      ..._printHistorySessionWidgets(blocks[i], leadingRule: i > 0),
  ];

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 28, 40, 32),
      theme: theme,
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : _printHistoryContinuationHeader(clientLabel, l),
      footer: (context) => _printFooter(context),
      build: (context) => body,
    ),
  );
  return doc.save();
}

pw.Widget _printHistoryBrandHeader({
  required String clientLabel,
  required List<IronVibeClientHistoryPrintBlock> blocks,
  required AppLocalizations l,
  required pw.ImageProvider logo,
}) {
  final range = ironVibeClientHistoryPrintRange(blocks);
  final name = clientLabel.trim().isEmpty
      ? l.printClientHistoryHeading
      : clientLabel.trim();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Image(logo, height: 16 * PdfPageFormat.mm, fit: pw.BoxFit.contain),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  l.appName,
                  style: pw.TextStyle(
                    color: _kPrintSteel,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  name,
                  style: pw.TextStyle(
                    color: _kPrintSteel,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  l.printClientHistoryHeading,
                  style: const pw.TextStyle(color: _kPrintSteel, fontSize: 10),
                ),
                if (range.isNotEmpty) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(
                    l.printClientHistorySpan(blocks.length, range),
                    style: const pw.TextStyle(color: _kPrintSteel, fontSize: 9),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Container(height: 0.6, color: _kPrintGold),
    ],
  );
}

pw.Widget _printHistoryContinuationHeader(
  String clientLabel,
  AppLocalizations l,
) {
  final name = clientLabel.trim().isEmpty
      ? l.printClientHistoryHeading
      : clientLabel.trim();
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          '$name  ·  ${l.printClientHistoryHeading}',
          style: const pw.TextStyle(color: _kPrintSteel, fontSize: 9),
        ),
        pw.SizedBox(height: 3),
        pw.Container(height: 0.4, color: _kPrintGold),
      ],
    ),
  );
}

pw.Widget _printHistoryColumnLabels(AppLocalizations l) {
  pw.Widget label(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        color: _kPrintSteel,
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 0.4,
      ),
    );
  }

  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 6, bottom: 1),
    child: pw.Row(
      children: [
        pw.Expanded(flex: 5, child: label(l.exerciseHeader)),
        pw.SizedBox(width: 12),
        pw.Expanded(flex: 8, child: label(l.sets)),
      ],
    ),
  );
}

/// Date, note, and the first exercise stay together. Later rows are separate
/// widgets so the sheet keeps filling until it is actually full.
List<pw.Widget> _printHistorySessionWidgets(
  IronVibeClientHistoryPrintBlock block, {
  required bool leadingRule,
}) {
  final notes = _printNoteChunks(block.note);
  return [
    pw.Inseparable(
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (leadingRule) ...[
            pw.SizedBox(height: 7),
            pw.Container(height: 0.55, color: _kPrintGold),
            pw.SizedBox(height: 6),
          ] else
            pw.SizedBox(height: 3),
          pw.Text(
            ironVibeSessionPrintWhen(block.dateTime),
            style: pw.TextStyle(
              color: _kPrintSteel,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (notes.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            _printHistoryNote(notes.first),
          ],
          pw.SizedBox(height: 2),
          _printHistoryExerciseRow(block.rows.first),
        ],
      ),
    ),
    for (final extra in notes.skip(1)) ...[
      pw.SizedBox(height: 2),
      _printHistoryNote(extra),
    ],
    for (final row in block.rows.skip(1)) _printHistoryExerciseRow(row),
  ];
}

pw.Widget _printHistoryNote(String note) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(left: 7, top: 1, bottom: 1),
    decoration: const pw.BoxDecoration(
      border: pw.Border(left: pw.BorderSide(color: _kPrintGold, width: 1.1)),
    ),
    child: pw.Text(
      note,
      style: const pw.TextStyle(color: _kPrintSteel, fontSize: 9),
    ),
  );
}

pw.Widget _printHistoryExerciseRow(IronVibeSessionPrintRow row) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 2.5, bottom: 3),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: _kPrintHairline, width: 0.4),
      ),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 5,
          child: pw.Text(
            row.name,
            style: pw.TextStyle(
              color: _kPrintSteel,
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          flex: 8,
          child: pw.Text(
            row.detail,
            style: const pw.TextStyle(color: _kPrintSteel, fontSize: 9.5),
          ),
        ),
      ],
    ),
  );
}

List<String> _printNoteChunks(String note) {
  final text = note.trim();
  if (text.isEmpty) return const [];
  if (text.length <= _kPrintNoteChunk) return [text];
  final chunks = <String>[];
  var start = 0;
  while (start < text.length) {
    var end = start + _kPrintNoteChunk;
    if (end >= text.length) {
      final tail = text.substring(start).trim();
      if (tail.isNotEmpty) chunks.add(tail);
      break;
    }
    var breakAt = text.lastIndexOf('\n', end);
    if (breakAt <= start + 80) breakAt = text.lastIndexOf(' ', end);
    if (breakAt <= start + 80) breakAt = end;
    final piece = text.substring(start, breakAt).trim();
    if (piece.isNotEmpty) chunks.add(piece);
    start = breakAt;
    while (start < text.length && (text[start] == ' ' || text[start] == '\n')) {
      start++;
    }
  }
  return chunks;
}

Future<void> ironVibeShareSessionPdf(
  BuildContext context,
  TrainerSession session,
) async {
  final l = AppLocalizations.of(context)!;
  final stem = ironVibeSessionPrintFileStem(
    ironVibeSessionClientLabel(session),
    session.dateTime,
  );
  await _shareBuiltPdf(
    context,
    buildBytes: (loc) => ironVibeBuildSessionPdfBytes(session: session, l: loc),
    fileName: '$stem.pdf',
    shareText: l.printSessionShareText,
    dialogTitle: l.printSession,
  );
}

Future<void> ironVibeShareClientHistoryPdf(
  BuildContext context, {
  required String clientLabel,
  required List<TrainerSession> sessions,
}) async {
  final l = AppLocalizations.of(context)!;
  final stem = ironVibeClientHistoryPrintFileStem(clientLabel);
  await _shareBuiltPdf(
    context,
    buildBytes: (loc) => ironVibeBuildClientHistoryPdfBytes(
      clientLabel: clientLabel,
      sessions: sessions,
      l: loc,
    ),
    fileName: '$stem.pdf',
    shareText: l.printClientHistoryShareText,
    dialogTitle: l.printClientHistory,
  );
}

Future<void> _shareBuiltPdf(
  BuildContext context, {
  required Future<Uint8List> Function(AppLocalizations l) buildBytes,
  required String fileName,
  required String shareText,
  required String dialogTitle,
}) async {
  final l = AppLocalizations.of(context)!;
  final pal = IronVibePalette.of(context);
  var loadingOpen = false;

  try {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: CircularProgressIndicator(color: pal.iconPrimary),
          ),
        );
      },
    );
    loadingOpen = true;

    final bytes = await buildBytes(l);

    if (!context.mounted) return;
    Navigator.of(context).pop();
    loadingOpen = false;

    if (kIsWeb) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          final dpal = IronVibePalette.of(ctx);
          return AlertDialog(
            backgroundColor: dpal.dialog,
            shape: ironVibeDialogShape(dpal),
            title: Text(
              dialogTitle,
              style: TextStyle(
                color: dpal.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.cancel, style: TextStyle(color: dpal.textMuted)),
              ),
              TextButton(
                onPressed: () {
                  ironVibeTriggerDownload(bytes, fileName, 'application/pdf');
                  Navigator.pop(ctx);
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(
                      content: Text(fileName),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
                child: Text(
                  l.save,
                  style: TextStyle(
                    color: dpal.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    try {
      await ironVibeShareFile(
        bytes: bytes,
        filename: fileName,
        mimeType: 'application/pdf',
        text: shareText,
      );
    } catch (shareError) {
      debugPrint('Share session PDF error: $shareError');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.exportError} $shareError'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('Build session PDF error: $e');
    if (loadingOpen && context.mounted) {
      Navigator.of(context).pop();
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.exportError} $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
