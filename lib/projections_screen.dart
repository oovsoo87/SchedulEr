import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:scheduler/home_screen.dart';
import 'package:scheduler/models.dart';
import 'package:scheduler/providers/plan_provider.dart';
import 'package:scheduler/site_screen.dart';
import 'package:scheduler/widgets/custom_app_bar.dart';
import 'package:scheduler/widgets/upgrade_dialog.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart';

// --- Data Structures for the UI ---
class ProjectionComparisonData {
  final Site site;
  final double projectedHours;
  final double scheduledHours;
  final double difference;

  ProjectionComparisonData({
    required this.site,
    required this.projectedHours,
    required this.scheduledHours,
    required this.difference,
  });
}

// --- State Management (Providers) ---
final siteProjectionProvider = StateNotifierProvider<SiteProjectionNotifier, List<SiteProjection>>((ref) {
  return SiteProjectionNotifier();
});

final comparisonProvider = Provider<List<ProjectionComparisonData>>((ref) {
  final sites = ref.watch(siteProvider);
  final scheduleEntries = ref.watch(scheduleProvider);
  final projections = ref.watch(siteProjectionProvider);
  final selectedDay = ref.watch(selectedDayProvider);

  final firstDayOfWeek = selectedDay.subtract(Duration(days: selectedDay.weekday - 1));
  final lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));

  List<ProjectionComparisonData> comparisonList = [];

  for (final site in sites) {
    final projection = projections.firstWhere(
          (p) => p.siteKey == site.key.toString() && isSameDay(p.weekStartDate, firstDayOfWeek),
      orElse: () => SiteProjection(siteKey: site.key.toString(), projectedHours: 0.0, weekStartDate: firstDayOfWeek),
    );

    final relevantEntries = scheduleEntries.where((entry) {
      return entry.siteKey == site.key &&
          !entry.date.isBefore(firstDayOfWeek) &&
          !entry.date.isAfter(lastDayOfWeek);
    });

    double totalScheduledSeconds = 0;
    for (final entry in relevantEntries) {
      totalScheduledSeconds += entry.finishTime.difference(entry.startTime).inSeconds;
    }
    final double scheduledHours = totalScheduledSeconds / 3600;

    comparisonList.add(
      ProjectionComparisonData(
        site: site,
        projectedHours: projection.projectedHours,
        scheduledHours: scheduledHours,
        difference: scheduledHours - projection.projectedHours,
      ),
    );
  }

  comparisonList.sort((a, b) => a.site.orderIndex.compareTo(b.site.orderIndex));
  return comparisonList;
});

// --- Business Logic (Notifier) ---
class SiteProjectionNotifier extends StateNotifier<List<SiteProjection>> {
  final Box<SiteProjection> _box = Hive.box<SiteProjection>('site_projections');

  SiteProjectionNotifier() : super([]) {
    state = _box.values.toList();
    _box.listenable().addListener(() {
      state = _box.values.toList();
    });
  }

  Future<void> setProjection(String siteKey, double hours, DateTime weekStartDate) async {
    final key = '${siteKey}_${DateFormat('yyyy-MM-dd').format(weekStartDate)}';
    await _box.put(key, SiteProjection(siteKey: siteKey, projectedHours: hours, weekStartDate: weekStartDate));
  }
}

// --- UI (Screen) ---
class ProjectionsScreen extends ConsumerStatefulWidget {
  const ProjectionsScreen({super.key});

  @override
  ConsumerState<ProjectionsScreen> createState() => _ProjectionsScreenState();
}

class _ProjectionsScreenState extends ConsumerState<ProjectionsScreen> {
  int _selectedViewIndex = 0;

  @override
  Widget build(BuildContext context) {
    final comparisonData = ref.watch(comparisonProvider);
    final selectedDay = ref.watch(selectedDayProvider);
    final firstDayOfWeek = selectedDay.subtract(Duration(days: selectedDay.weekday - 1));
    final endOfWeek = firstDayOfWeek.add(const Duration(days: 6));

    return Scaffold(
      appBar: const CustomAppBar(title: 'Projections'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              "Comparison for Week Ending ${DateFormat('dd/MM/yyyy').format(endOfWeek)}",
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ToggleButtons(
            isSelected: [_selectedViewIndex == 0, _selectedViewIndex == 1],
            onPressed: (index) {
              setState(() {
                _selectedViewIndex = index;
              });
            },
            borderRadius: BorderRadius.circular(8),
            constraints: const BoxConstraints(minHeight: 40.0, minWidth: 100.0),
            children: const [
              Text('Table'),
              Text('Charts'),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
              child: comparisonData.isEmpty
                  ? const Center(child: Text('No sites found. Add sites in the "Sites" tab.'))
                  : AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _selectedViewIndex == 0
                    ? TableView(key: const ValueKey('table'), comparisonData: comparisonData)
                    : ChartsView(key: const ValueKey('charts'), comparisonData: comparisonData),
              )
          ),
        ],
      ),
    );
  }
}

// --- Table View Widget ---
class TableView extends ConsumerWidget {
  final List<ProjectionComparisonData> comparisonData;
  const TableView({super.key, required this.comparisonData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allSites = ref.watch(siteProvider);
    final selectedDay = ref.watch(selectedDayProvider);
    final firstDayOfWeek = selectedDay.subtract(Duration(days: selectedDay.weekday - 1));
    final uniqueGroups = allSites.map((s) => s.groupName).whereType<String>().where((g) => g.isNotEmpty).toSet().toList();

    final Map<String, List<ProjectionComparisonData>> groupedData = {};
    for (final data in comparisonData) {
      final groupName = (data.site.groupName != null && data.site.groupName!.isNotEmpty) ? data.site.groupName! : 'Unassigned';
      groupedData.putIfAbsent(groupName, () => []).add(data);
    }

    final groupEntries = groupedData.entries.toList()..sort((a,b) => a.key.compareTo(b.key));

    return ListView.builder(
      itemCount: groupEntries.length,
      itemBuilder: (context, index) {
        final group = groupEntries[index];
        final groupName = group.key;
        final sitesInGroup = group.value;

        final groupProjected = sitesInGroup.fold(0.0, (sum, item) => sum + item.projectedHours);
        final groupScheduled = sitesInGroup.fold(0.0, (sum, item) => sum + item.scheduledHours);
        final groupDiff = groupScheduled - groupProjected;
        final diffColor = _getDiffColor(groupDiff);

        return ExpansionTile(
          initiallyExpanded: true,
          title: Row(
            children: [
              Expanded(flex: 3, child: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text(groupProjected.toStringAsFixed(1), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text(groupScheduled.toStringAsFixed(1), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                flex: 2,
                child: Text(
                  groupDiff.toStringAsFixed(1),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: diffColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          children: sitesInGroup.map((data) {
            final siteDiffColor = _getDiffColor(data.difference);
            return ListTile(
              tileColor: Theme.of(context).colorScheme.surface.withAlpha(128),
              title: Row(
                children: [
                  Expanded(flex: 3, child: Padding(padding: const EdgeInsets.only(left: 16.0), child: Text(data.site.name, overflow: TextOverflow.ellipsis))),
                  Expanded(flex: 2, child: Text(data.projectedHours.toStringAsFixed(1), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text(data.scheduledHours.toStringAsFixed(1), textAlign: TextAlign.center)),
                  Expanded(
                    flex: 2,
                    child: Text(
                      data.difference.toStringAsFixed(1),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: siteDiffColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              onTap: () => _showEditProjectionDialog(context, ref, data.site, data.projectedHours, firstDayOfWeek),
              onLongPress: () => _showAssignGroupDialog(context, ref, data.site, uniqueGroups),
            );
          }).toList(),
        );
      },
    );
  }

  Color _getDiffColor(double difference) {
    if (difference > 0) return Colors.redAccent;
    if (difference < 0) return Colors.blue.shade300;
    return Colors.grey.shade400;
  }

  void _showEditProjectionDialog(BuildContext context, WidgetRef ref, Site site, double currentHours, DateTime weekStartDate) {
    final hoursController = TextEditingController(text: currentHours > 0 ? currentHours.toString() : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Projected Hours for ${site.name}'),
        content: TextField(
          controller: hoursController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Weekly Projected Hours'),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final isPro = ref.read(planProvider);
              final hours = double.tryParse(hoursController.text) ?? 0.0;
              final isNewProjection = currentHours == 0.0 && hours > 0.0;

              if (!isPro && isNewProjection) {
                final allProjections = ref.read(siteProjectionProvider);
                final projectionsForWeek = allProjections.where((p) => isSameDay(p.weekStartDate, weekStartDate) && p.projectedHours > 0);
                if (projectionsForWeek.isNotEmpty) {
                  Navigator.pop(context);
                  showUpgradeDialog(
                    context,
                    title: "Upgrade for More Projections",
                    message: "You can only set one projection per week on the Lite plan. Upgrade to Pro for unlimited projections.",
                  );
                  return;
                }
              }

              ref.read(siteProjectionProvider.notifier).setProjection(site.key.toString(), hours, weekStartDate);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAssignGroupDialog(BuildContext context, WidgetRef ref, Site site, List<String> existingGroups) {
    final newGroupController = TextEditingController();
    String? selectedGroup = site.groupName;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Assign Group for ${site.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (existingGroups.isNotEmpty) const Text('Select an existing group:'),
                    ...existingGroups.map((group) => RadioListTile<String>(
                      title: Text(group),
                      value: group,
                      groupValue: selectedGroup,
                      onChanged: (value) {
                        setState(() {
                          selectedGroup = value;
                          newGroupController.clear();
                        });
                      },
                    )),
                    if (existingGroups.isNotEmpty) const Divider(),
                    const Text('Or enter a new group name:'),
                    TextFormField(
                      controller: newGroupController,
                      decoration: const InputDecoration(labelText: 'New/Custom Group Name'),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          setState(() => selectedGroup = null);
                        }
                      },
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    String finalGroupName = newGroupController.text.trim();
                    if (finalGroupName.isEmpty) {
                      finalGroupName = selectedGroup ?? '';
                    }

                    final updatedSite = Site(
                      name: site.name,
                      address: site.address,
                      notes: site.notes,
                      colorValue: site.colorValue,
                      orderIndex: site.orderIndex,
                      groupName: finalGroupName,
                    );

                    ref.read(siteProvider.notifier).updateSite(site.key, updatedSite);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// --- Charts View Widget ---
class ChartsView extends StatelessWidget {
  final List<ProjectionComparisonData> comparisonData;
  const ChartsView({super.key, required this.comparisonData});

  @override
  Widget build(BuildContext context) {
    final scheduledSites = comparisonData.where((d) => d.scheduledHours > 0).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text('Scheduled Hours by Site', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(
            height: 250,
            child: scheduledSites.isEmpty
                ? const Center(child: Text('No hours scheduled this week.'))
                : PieChart(
              PieChartData(
                sections: scheduledSites.map((data) {
                  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                  return PieChartSectionData(
                    color: Color(data.site.colorValue),
                    value: data.scheduledHours,
                    title: '${data.scheduledHours.toStringAsFixed(1)}h',
                    radius: 100,
                    titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.black : Colors.white),
                  );
                }).toList(),
                centerSpaceRadius: 20,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: scheduledSites.map((data) => Chip(
              avatar: CircleAvatar(backgroundColor: Color(data.site.colorValue)),
              label: Text(data.site.name),
              side: BorderSide.none,
            )).toList(),
          ),

          const Divider(height: 50),

          Text('Projected vs. Scheduled', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barGroups: List.generate(comparisonData.length, (index) {
                  final data = comparisonData[index];
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(toY: data.projectedHours, color: Colors.grey.shade700, width: 15, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: data.scheduledHours, color: Color(data.site.colorValue), width: 15, borderRadius: BorderRadius.circular(4)),
                    ],
                  );
                }),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < comparisonData.length) {
                          // *** MODIFIED: Truncate long site names with an ellipsis ***
                          String name = comparisonData[value.toInt()].site.name;
                          if (name.length > 8) {
                            name = '${name.substring(0, 6)}...';
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            angle: -pi / 4,
                            child: Text(name, style: const TextStyle(fontSize: 10)),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 40,
                    ),
                  ),
                ),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}