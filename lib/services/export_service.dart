import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/utils/formatters.dart';
import '../core/utils/money.dart';
import '../models/models.dart';

class ExportService {
  static CellValue _cell(Object? v) {
    if (v == null) return TextCellValue('');
    if (v is int) return IntCellValue(v);
    if (v is double) return DoubleCellValue(v);
    if (v is DateTime) return TextCellValue(fmtDate(v));
    return TextCellValue(v.toString());
  }

  static double _rs(int paise) => paise / 100;

  static void _sheet(Excel x, String name, List<String> headers, List<List<Object?>> rows) {
    final s = x[name];
    s.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (final r in rows) {
      s.appendRow(r.map(_cell).toList());
    }
  }

  static List<Object?> _billRow(Bill b) => [
        b.date, b.eventName, b.reason, b.paidTo, b.category, _rs(b.amount), b.doneBy,
        b.isVoid ? 'Void' : 'Active', b.receiptName ?? '',
      ];
  static const _billHeaders = [
    'Date', 'Event', 'Reason', 'Paid to', 'Category', 'Amount (Rs)', 'Done by', 'Status', 'Receipt file',
  ];

  // ------------------------------------------------------------- Excel
  static Uint8List fullBackup({
    required Club club, required Summary summary, required List<Bill> bills,
    required List<Income> income, required List<EventItem> events,
    required List<ReimbursementEntry> entries, required List<BudgetLog> log,
  }) {
    final x = Excel.createExcel();
    x.rename('Sheet1', 'Summary');
    final s = x['Summary'];
    s.appendRow([TextCellValue('Club'), TextCellValue(club.name)]);
    for (final e in {
      'Budget (Rs)': summary.budget,
      'Income (Rs)': summary.income,
      'Bills total (Rs)': summary.gross,
      'Reimbursement applied (Rs)': summary.appliedReimbursement,
      'Total spent after reimbursement (Rs)': summary.spent,
      'Remaining (Rs)': summary.remaining,
      'Reimbursement expected (Rs)': summary.declared,
      'Reimbursement received (Rs)': summary.received,
      'Reimbursement left to use (Rs)': summary.leftToUse,
      'Reimbursement left to receive (Rs)': summary.left,
    }.entries) {
      s.appendRow([TextCellValue(e.key), DoubleCellValue(_rs(e.value))]);
    }
    s.appendRow([TextCellValue('Generated'), TextCellValue(fmtDateTime(DateTime.now()))]);

    _sheet(x, 'Bills', _billHeaders, bills.map(_billRow).toList());
    _sheet(
      x, 'Events',
      ['Date', 'Event', 'Bills total (Rs)', 'Reimbursement expected (Rs)', 'Expenditure after reimbursement (Rs)', 'Received (Rs)', 'Left to use (Rs)', 'Left to receive (Rs)'],
      events.map((e) {
        final st = EventStats.of(e, bills, entries);
        return <Object?>[e.date, e.name, _rs(st.gross), _rs(st.declared), _rs(st.net), _rs(st.received), _rs(st.leftToUse), _rs(st.left)];
      }).toList(),
    );
    _sheet(x, 'Reimbursements received', ['Date', 'Event', 'Amount (Rs)', 'Done by', 'Status', 'Note'],
        entries.map((r) => [r.date, r.eventName, _rs(r.amount), r.doneBy, r.isVoid ? 'Void' : 'Active', r.note]).toList());
    _sheet(x, 'Income', ['Date', 'Source', 'Type', 'Amount (Rs)', 'Done by', 'Status', 'Note'],
        income.map((i) => [i.date, i.source, i.type, _rs(i.amount), i.doneBy, i.isVoid ? 'Void' : 'Active', i.note]).toList());
    _sheet(x, 'Budget changes', ['When', 'Old (Rs)', 'New (Rs)', 'By', 'Reason'],
        log.map((l) => [fmtDateTime(l.at), _rs(l.oldBudget), _rs(l.newBudget), l.by, l.reason]).toList());
    return Uint8List.fromList(x.encode()!);
  }

  static Uint8List billsReport(String sheetName, List<Bill> bills,
      {List<Income> income = const [], List<String> notes = const []}) {
    final x = Excel.createExcel();
    x.rename('Sheet1', sheetName);
    final active = bills.where((b) => !b.isVoid).toList();
    _sheet(x, sheetName, _billHeaders, active.map(_billRow).toList());
    final total = active.fold<int>(0, (a, b) => a + b.amount);
    final sh = x[sheetName];
    sh.appendRow([TextCellValue('TOTAL'), null, null, null, null, DoubleCellValue(_rs(total))]);
    for (final n in notes) {
      sh.appendRow([TextCellValue(n)]);
    }
    final inc = income.where((i) => !i.isVoid).toList();
    if (inc.isNotEmpty) {
      _sheet(x, 'Income', ['Date', 'Source', 'Type', 'Amount (Rs)', 'Done by'],
          inc.map((i) => [i.date, i.source, i.type, _rs(i.amount), i.doneBy]).toList());
    }
    return Uint8List.fromList(x.encode()!);
  }

  // --------------------------------------------------------------- PDF
  static Future<Uint8List> billsPdf({
    required String clubName, required String title, required String subtitle,
    required List<Bill> bills, List<Income> income = const [], List<String> notes = const [],
  }) async {
    final active = bills.where((b) => !b.isVoid).toList();
    final inc = income.where((i) => !i.isVoid).toList();
    final spent = active.fold<int>(0, (a, b) => a + b.amount);
    final earned = inc.fold<int>(0, (a, i) => a + i.amount);

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => [
        pw.Text('Vaulta  |  $clubName', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Text(subtitle),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Event', 'Reason', 'Category', 'Done by', 'Amount'],
          data: [
            for (final b in active)
              [fmtDate(b.date), b.eventName, b.reason, b.category, b.doneBy, Money.forPdf(b.amount)],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF3D7584)),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignments: {5: pw.Alignment.centerRight},
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Bills total: ${Money.forPdf(spent)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        ),
        if (notes.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          for (final n in notes) pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(n, style: const pw.TextStyle(fontSize: 10))),
        ],
        if (inc.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('Income', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Source', 'Type', 'Amount'],
            data: [for (final i in inc) [fmtDate(i.date), i.source, i.type, Money.forPdf(i.amount)]],
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {3: pw.Alignment.centerRight},
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Total income: ${Money.forPdf(earned)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
        ],
        pw.SizedBox(height: 18),
        pw.Text('Generated ${fmtDateTime(DateTime.now())}. Voided records are excluded.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ],
    ));
    return doc.save();
  }

  // ------------------------------------------------------------- Share
  static Future<void> share(Uint8List bytes, String fileName, String mime) =>
      Share.shareXFiles([XFile.fromData(bytes, mimeType: mime)], fileNameOverrides: [fileName]);

  static const xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static const pdfMime = 'application/pdf';
}
