import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:scheduler/models.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:table_calendar/table_calendar.dart';

Future<Uint8List> generateTeamTimesheetPdfBytes({
  required DateTimeRange dateRange,
  required Map<String, List<ScheduleEntry>> data,
  String? teamName,
}) async {
  final siteBox = Hive.box<Site>('sites');
  final pdf = pw.Document();
  final startOfWeek = dateRange.start;
  final endOfWeek = dateRange.end;

  final List<String> headers = ['Staff Member'];
  final List<DateTime> weekDays = [];
  for (int i = 0; i < 7; i++) {
    final day = startOfWeek.add(Duration(days: i));
    weekDays.add(day);
    headers.add('${DateFormat.E().format(day)}\n${DateFormat('dd/MM').format(day)}');
  }

  final List<List<dynamic>> tableData = [];
  final staffNames = data.keys.toList()..sort();

  for (var i = 0; i < staffNames.length; i++) {
    final staffName = staffNames[i];
    final row = <dynamic>[pw.Text(staffName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))];
    for (final day in weekDays) {
      final entriesForDay = data[staffName]!.where((e) => isSameDay(e.date, day)).toList();
      if (entriesForDay.isEmpty) {
        row.add('');
      } else {
        final cellText = entriesForDay.map((e) {
          final siteColorValue = siteBox.get(e.siteKey)?.colorValue ?? Colors.grey.toARGB32();

          // Create a transparent version of the color
          const int alpha = 51; // ~20% opacity (0.2 * 255)
          final int transparentColorValue = (alpha << 24) | (siteColorValue & 0x00FFFFFF);
          final transparentColor = PdfColor.fromInt(transparentColorValue);

          final siteName = siteBox.get(e.siteKey)?.name ?? 'N/A';
          final startTime = DateFormat.Hm().format(e.startTime);
          final finishTime = DateFormat.Hm().format(e.finishTime);

          return pw.Container(
              padding: const pw.EdgeInsets.all(2),
              margin: const pw.EdgeInsets.only(bottom: 2),
              decoration: pw.BoxDecoration(
                color: transparentColor,
                borderRadius: pw.BorderRadius.circular(2),
              ),
              child: pw.Text('$startTime-$finishTime\n@ $siteName', style: const pw.TextStyle(fontSize: 7))
          );
        }).toList();
        row.add(pw.Column(children: cellText));
      }
    }
    tableData.add(row);
  }

  pdf.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    header: (context) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Team Weekly Schedule for Week Ending ${DateFormat('dd/MM/yy').format(endOfWeek)}', style: pw.Theme.of(context).header3),
                if (teamName != null && teamName.isNotEmpty)
                  pw.Text('Team: $teamName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ]
          )
      ),
    ),
    build: (context) => [
      pw.Table(
        border: pw.TableBorder.all(),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.IntrinsicColumnWidth(),
          2: const pw.IntrinsicColumnWidth(),
          3: const pw.IntrinsicColumnWidth(),
          4: const pw.IntrinsicColumnWidth(),
          5: const pw.IntrinsicColumnWidth(),
          6: const pw.IntrinsicColumnWidth(),
          7: const pw.IntrinsicColumnWidth(),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            children: headers.map((h) => pw.Center(
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.center),
              ),
            )).toList(),
          ),
          ...tableData.asMap().entries.map((entry) {
            int rowIndex = entry.key;
            List<dynamic> rowData = entry.value;
            return pw.TableRow(
              verticalAlignment: pw.TableCellVerticalAlignment.middle,
              decoration: pw.BoxDecoration(color: rowIndex % 2 == 0 ? PdfColors.blue50 : PdfColors.yellow50),
              children: rowData.map((cellData) => pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Center(child: cellData is pw.Widget ? cellData : pw.Text(cellData.toString(), style: const pw.TextStyle(fontSize: 8))),
              )).toList(),
            );
          }),
        ],
      ),
    ],
  ));

  return await pdf.save();
}