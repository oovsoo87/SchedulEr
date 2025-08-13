import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:scheduler/models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:scheduler/report_service.dart';
import 'package:scheduler/widgets/custom_app_bar.dart';
import 'package:table_calendar/table_calendar.dart';

class ExportTimesheetsScreen extends ConsumerWidget {
  const ExportTimesheetsScreen({super.key});

  Future<List<String>?> _showStaffFilterDialog(BuildContext context) async {
    final staffBox = Hive.box<Staff>('staff');
    final allStaff = staffBox.values.toList();
    final Map<int, bool> selectedStaff = {
      for (var staff in allStaff) staff.key: true
    };

    return await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filter Report by Staff'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allStaff.length,
                  itemBuilder: (context, index) {
                    final staffMember = allStaff[index];
                    return CheckboxListTile(
                      title: Text(staffMember.name),
                      value: selectedStaff[staffMember.key],
                      onChanged: (bool? value) {
                        setState(() {
                          selectedStaff[staffMember.key] = value!;
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final names = selectedStaff.entries
                        .where((entry) => entry.value)
                        .map((entry) => allStaff.firstWhere((s) => s.key == entry.key).name)
                        .toList();
                    Navigator.pop(context, names);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _showTeamNameDialog(BuildContext context) async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Team Name (Optional)'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g., Morning Crew'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add Name'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndShare(BuildContext context, String format) async {
    try {
      final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (pickedDate == null) return;

      final startOfWeek = pickedDate.subtract(Duration(days: pickedDate.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      final reportDateRange = DateTimeRange(start: startOfWeek, end: endOfWeek);

      if (!context.mounted) return;
      final List<String>? selectedStaffNames = await _showStaffFilterDialog(context);
      if (selectedStaffNames == null || selectedStaffNames.isEmpty) return;

      String? teamName;
      if (format == 'pdf' || format == 'team_pdf') {
        if (!context.mounted) return;
        teamName = await _showTeamNameDialog(context);
      }

      final scheduleBox = Hive.box<ScheduleEntry>('schedule_entries');
      final staffBox = Hive.box<Staff>('staff');

      final inclusiveEndDate = endOfWeek.add(const Duration(days: 1));
      final filteredEntries = scheduleBox.values.where((entry) {
        final staffMember = staffBox.get(entry.staffKey);
        if (staffMember == null) return false;

        final isDateInRange = !entry.date.isBefore(startOfWeek) && entry.date.isBefore(inclusiveEndDate);
        final isStaffSelected = selectedStaffNames.contains(staffMember.name);
        return isDateInRange && isStaffSelected;
      }).toList();

      if (filteredEntries.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No schedule entries found for the selected week.')));
        return;
      }

      final Map<String, List<ScheduleEntry>> groupedByStaff = {};
      for (final entry in filteredEntries) {
        final staffName = staffBox.get(entry.staffKey)!.name;
        groupedByStaff.putIfAbsent(staffName, () => []).add(entry);
      }

      final Directory dir = await getApplicationDocumentsDirectory();
      final formattedSunday = DateFormat('ddMMyy').format(endOfWeek);

      String fileName;
      if (format == 'pdf') {
        fileName = 'weekly_schedule_we_${formattedSunday}manager.pdf';
      } else if (format == 'team_pdf') {
        fileName = 'weekly_schedule_we_${formattedSunday}team.pdf';
      } else {
        fileName = 'weekly_schedule_we_${formattedSunday}manager.csv';
      }
      final String path = '${dir.path}/$fileName';

      final siteBox = Hive.box<Site>('sites');
      final projectionBox = Hive.box<SiteProjection>('site_projections');

      if (format == 'csv') {
        await _generateCsv(path, groupedByStaff, siteBox);
      } else if (format == 'pdf') {
        await _generateManagerPdf(path, groupedByStaff, siteBox, projectionBox, reportDateRange, filteredEntries, teamName);
      } else if (format == 'team_pdf') {
        final pdfBytes = await generateTeamTimesheetPdfBytes(dateRange: reportDateRange, data: groupedByStaff, teamName: teamName);
        await File(path).writeAsBytes(pdfBytes);
      }
      if (!context.mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        await Share.shareXFiles(
          [XFile(path)],
          text: 'Scheduler Weekly Schedule',
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _generateCsv(String path, Map<String, List<ScheduleEntry>> data, Box<Site> siteBox) async {
    List<List<dynamic>> rows = [];
    rows.add(['Staff Name', 'Site Name', 'Date', 'Start Time', 'Finish Time', 'Hours']);
    double grandTotalSeconds = 0;

    final dateFormat = DateFormat('dd/MM/yy');
    final timeFormat = DateFormat('HH:mm');

    final staffInReport = data.keys.toList()..sort();

    for (final staffName in staffInReport) {
      final entries = data[staffName]!;
      double staffTotalSeconds = 0;
      for (final entry in entries) {
        final duration = entry.finishTime.difference(entry.startTime);
        staffTotalSeconds += duration.inSeconds;
        rows.add([
          staffName,
          siteBox.get(entry.siteKey)?.name ?? 'Unknown Site',
          dateFormat.format(entry.date),
          timeFormat.format(entry.startTime),
          timeFormat.format(entry.finishTime),
          (duration.inSeconds / 3600).toStringAsFixed(2),
        ]);
      }
      grandTotalSeconds += staffTotalSeconds;
      rows.add(['', '', '', '', 'Subtotal for $staffName', (staffTotalSeconds / 3600).toStringAsFixed(2)]);
      rows.add([]);
    }

    rows.add(['', '', '', '', 'Grand Total', (grandTotalSeconds / 3600).toStringAsFixed(2)]);

    final csvData = const ListToCsvConverter().convert(rows);
    await File(path).writeAsString(csvData);
  }

  Future<void> _generateManagerPdf(String path, Map<String, List<ScheduleEntry>> data, Box<Site> siteBox, Box<SiteProjection> projectionBox, DateTimeRange dateRange, List<ScheduleEntry> filteredEntries, String? teamName) async {
    final pdf = pw.Document();

    final dateFormat = DateFormat('dd/MM/yy');
    final timeFormat = DateFormat('HH:mm');

    final List<pw.Widget> contentWidgets = [];
    final staffInReport = data.keys.toList()..sort();

    for (final staffName in staffInReport) {
      final entries = data[staffName]!..sort((a,b) => a.date.compareTo(b.date));
      double staffTotalSeconds = 0;

      final tableData = entries.map((entry) {
        final duration = entry.finishTime.difference(entry.startTime);
        staffTotalSeconds += duration.inSeconds;
        return [
          siteBox.get(entry.siteKey)?.name ?? 'Unknown',
          dateFormat.format(entry.date),
          timeFormat.format(entry.startTime),
          timeFormat.format(entry.finishTime),
          (duration.inSeconds / 3600).toStringAsFixed(2),
        ];
      }).toList();

      contentWidgets.add(pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Header(text: 'Weekly Schedule for $staffName'),
          pw.TableHelper.fromTextArray(
            headers: ['Site', 'Date', 'Start', 'Finish', 'Hours'],
            data: tableData,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.center,
          ),
          pw.SizedBox(height: 10),
          pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total Hours: ${(staffTotalSeconds / 3600).toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
              )
          ),
          pw.Divider(height: 30),
        ],
      ));
    }

    contentWidgets.add(pw.Header(text: 'Site Projections vs. Scheduled Summary'));
    final allSites = siteBox.values.toList()..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final List<List<String>> summaryData = [];
    final startOfWeek = dateRange.start;

    for (final site in allSites) {
      final projectionKey = '${site.key}_${DateFormat('yyyy-MM-dd').format(startOfWeek)}';
      final projection = projectionBox.get(projectionKey)?.projectedHours ?? 0.0;

      double scheduledSeconds = 0;
      for (final entry in filteredEntries) {
        if (entry.siteKey == site.key) {
          scheduledSeconds += entry.finishTime.difference(entry.startTime).inSeconds;
        }
      }
      final scheduledHours = scheduledSeconds / 3600;
      final difference = scheduledHours - projection;

      summaryData.add([
        site.name,
        projection.toStringAsFixed(2),
        scheduledHours.toStringAsFixed(2),
        difference.toStringAsFixed(2),
      ]);
    }

    contentWidgets.add(pw.TableHelper.fromTextArray(
      headers: ['Site', 'Projected', 'Scheduled', 'Difference'],
      data: summaryData,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.center,
    ));

    // *** NEW: Logic to build the daily site summary table ***
    contentWidgets.add(pw.Divider(height: 30));
    contentWidgets.add(pw.Header(text: 'Daily Hours by Site Summary'));

    final List<String> dailyHeaders = ['Site'];
    final List<DateTime> weekDays = [];
    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      weekDays.add(day);
      dailyHeaders.add(DateFormat.E().format(day)); // Mon, Tue, etc.
    }
    dailyHeaders.add('Total');

    final List<List<String>> dailySiteData = [];
    for (final site in allSites) {
      final List<String> row = [site.name];
      double weeklyTotalSeconds = 0;
      for (final day in weekDays) {
        double dailyTotalSeconds = 0;
        final dailyEntries = filteredEntries.where((e) => e.siteKey == site.key && isSameDay(e.date, day));
        for (final entry in dailyEntries) {
          dailyTotalSeconds += entry.finishTime.difference(entry.startTime).inSeconds;
        }
        weeklyTotalSeconds += dailyTotalSeconds;
        row.add((dailyTotalSeconds / 3600).toStringAsFixed(2));
      }
      row.add((weeklyTotalSeconds / 3600).toStringAsFixed(2));
      dailySiteData.add(row);
    }

    contentWidgets.add(pw.TableHelper.fromTextArray(
      headers: dailyHeaders,
      data: dailySiteData,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.center,
    ));
    // *** End of new table logic ***

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.portrait,
      header: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 20),
        child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Manager Weekly Schedule', style: pw.Theme.of(context).header3),
                  if (teamName != null && teamName.isNotEmpty)
                    pw.Text('Team: $teamName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ]
            )
        ),
      ),
      footer: (context) {
        return pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10.0),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.Theme.of(context).defaultTextStyle.copyWith(color: PdfColors.grey),
          ),
        );
      },
      build: (context) => contentWidgets,
    ));

    await File(path).writeAsBytes(await pdf.save());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Export Schedules'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Manager Weekly Schedule (Detailed List)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _generateAndShare(context, 'pdf'),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export Detailed PDF'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _generateAndShare(context, 'csv'),
                icon: const Icon(Icons.table_chart),
                label: const Text('Export Detailed CSV'),
              ),
              const Divider(height: 48, thickness: 1),
              const Text('Team Weekly Schedule (Weekly Grid)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _generateAndShare(context, 'team_pdf'),
                icon: const Icon(Icons.grid_on_outlined),
                label: const Text('Export Team PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}