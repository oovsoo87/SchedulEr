import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:scheduler/models.dart';
import 'package:scheduler/staff_screen.dart';
import 'package:scheduler/site_screen.dart';
import 'package:scheduler/widgets/custom_app_bar.dart';
import 'package:table_calendar/table_calendar.dart';

// --- State Management (Providers) ---
final scheduleProvider = StateNotifierProvider<ScheduleNotifier, List<ScheduleEntry>>((ref) {
  return ScheduleNotifier();
});
final selectedDayProvider = StateProvider<DateTime>((ref) => DateTime.now());
final eventsForSelectedDayProvider = Provider<List<ScheduleEntry>>((ref) {
  final allEntries = ref.watch(scheduleProvider);
  final selectedDay = ref.watch(selectedDayProvider);
  return allEntries.where((entry) => isSameDay(entry.date, selectedDay)).toList();
});

// --- Business Logic (Notifier) ---
class ScheduleNotifier extends StateNotifier<List<ScheduleEntry>> {
  final Box<ScheduleEntry> _box = Hive.box<ScheduleEntry>('schedule_entries');

  ScheduleNotifier() : super([]) {
    state = _box.values.toList();
    _box.listenable().addListener(() {
      state = _box.values.toList();
    });
  }

  Future<void> addScheduleEntry(ScheduleEntry entry) async => await _box.add(entry);
  Future<void> addMultipleEntries(List<ScheduleEntry> entries) async => await _box.addAll(entries);
  Future<void> updateScheduleEntry(dynamic key, ScheduleEntry entry) async => await _box.put(key, entry);
  Future<void> deleteScheduleEntry(dynamic key) async => await _box.delete(key);
  Future<void> deleteMultipleEntries(Iterable<dynamic> keys) async => await _box.deleteAll(keys);
}

// --- UI (Screen) ---
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.twoWeeks;

  Future<void> _copyWeek() async {
    final selectedDay = ref.read(selectedDayProvider);
    final allEvents = ref.read(scheduleProvider);
    final firstDayOfWeek = selectedDay.subtract(Duration(days: selectedDay.weekday - 1));
    final lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));

    final weekEvents = allEvents.where((event) {
      return (event.date.isAfter(firstDayOfWeek) || isSameDay(event.date, firstDayOfWeek)) &&
          (event.date.isBefore(lastDayOfWeek) || isSameDay(event.date, lastDayOfWeek));
    }).toList();

    if (weekEvents.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No events in the selected week to copy.')));
      return;
    }

    if (!mounted) return;
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copy Schedule'),
        content: Text('Copy ${weekEvents.length} shifts from this week to the next?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Copy')),
        ],
      ),
    );

    if (confirmed != true) return;

    final List<ScheduleEntry> newEntries = [];
    for (final event in weekEvents) {
      final nextWeekDate = event.date.add(const Duration(days: 7));
      newEntries.add(
        ScheduleEntry(
          date: nextWeekDate,
          staffKey: event.staffKey,
          siteKey: event.siteKey,
          startTime: event.startTime.add(const Duration(days: 7)),
          finishTime: event.finishTime.add(const Duration(days: 7)),
          notes: event.notes,
        ),
      );
    }

    await ref.read(scheduleProvider.notifier).addMultipleEntries(newEntries);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule copied to next week successfully!'), backgroundColor: Colors.green));
  }

  Future<void> _copyShiftToNextDay(ScheduleEntry entry) async {
    final nextDay = entry.date.add(const Duration(days: 1));
    final staffName = Hive.box<Staff>('staff').get(entry.staffKey)?.name ?? 'this shift';

    if (!mounted) return;
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copy Shift'),
        content: Text('Copy $staffName\'s shift to the next day (${DateFormat.MMMEd().format(nextDay)})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Copy')),
        ],
      ),
    );

    if (confirmed != true) return;

    final newEntry = ScheduleEntry(
      date: nextDay,
      staffKey: entry.staffKey,
      siteKey: entry.siteKey,
      startTime: entry.startTime.add(const Duration(days: 1)),
      finishTime: entry.finishTime.add(const Duration(days: 1)),
      notes: entry.notes,
    );

    final allEntries = ref.read(scheduleProvider);
    final conflictingShifts = allEntries.where((e) {
      return e.staffKey == newEntry.staffKey && isSameDay(e.date, newEntry.date);
    });

    for (final existingShift in conflictingShifts) {
      if (newEntry.startTime.isBefore(existingShift.finishTime) && newEntry.finishTime.isAfter(existingShift.startTime)) {
        if (!mounted) return;
        showDialog(context: context, builder: (context) => AlertDialog(
          title: const Text('Schedule Conflict'),
          content: const Text('This staff member is already scheduled for an overlapping shift on the next day.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ));
        return;
      }
    }

    await ref.read(scheduleProvider.notifier).addScheduleEntry(newEntry);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shift copied successfully!'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = ref.watch(selectedDayProvider);
    final eventsForDay = ref.watch(eventsForSelectedDayProvider);
    final allEvents = ref.watch(scheduleProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Schedule',
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy Week',
            onPressed: _copyWeek,
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: selectedDay,
            calendarFormat: _calendarFormat,
            startingDayOfWeek: StartingDayOfWeek.monday,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
              CalendarFormat.twoWeeks: '2 Weeks',
              CalendarFormat.week: 'Week',
            },
            selectedDayPredicate: (day) => isSameDay(selectedDay, day),
            onDaySelected: (newSelectedDay, newFocusedDay) {
              ref.read(selectedDayProvider.notifier).state = newSelectedDay;
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            eventLoader: (day) {
              return allEvents.where((event) => isSameDay(event.date, day)).toList();
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withAlpha(128),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;
                final siteBox = Hive.box<Site>('sites');
                final uniqueSiteKeys = events.map((e) => (e as ScheduleEntry).siteKey).toSet();

                final eventCount = uniqueSiteKeys.length;
                const displayLimit = 4;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    eventCount > displayLimit ? displayLimit : eventCount,
                        (index) {
                      if (index == displayLimit - 1 && eventCount > displayLimit) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 1.5),
                          child: CircleAvatar(
                            radius: 4.0,
                            backgroundColor: Colors.white70,
                            child: Text('+', style: TextStyle(color: Colors.black, fontSize: 7, fontWeight: FontWeight.bold)),
                          ),
                        );
                      }

                      final site = siteBox.get(uniqueSiteKeys.elementAt(index));
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: CircleAvatar(
                          radius: 4.0,
                          backgroundColor: site != null ? Color(site.colorValue) : Colors.grey,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              DateFormat('dd/MM/yyyy').format(selectedDay),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: eventsForDay.isEmpty
                ? const Center(child: Text('No schedule for this day.'))
                : ListView.builder(
              itemCount: eventsForDay.length,
              itemBuilder: (context, index) {
                final event = eventsForDay[index];
                final staff = Hive.box<Staff>('staff').get(event.staffKey);
                final site = Hive.box<Site>('sites').get(event.siteKey);

                return ListTile(
                  tileColor: index.isEven ? null : Theme.of(context).colorScheme.surface.withAlpha(128),
                  leading: CircleAvatar(backgroundColor: site != null ? Color(site.colorValue) : Colors.grey, radius: 5),
                  title: Text(staff?.name ?? 'Unknown Staff'),
                  subtitle: Text(site?.name ?? 'Unknown Site'),
                  trailing: Text('${DateFormat.Hm().format(event.startTime)} - ${DateFormat.Hm().format(event.finishTime)}'),
                  onTap: () => _showNotesDialog(context, ref, event),
                  onLongPress: () => _copyShiftToNextDay(event),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final staffList = ref.read(staffProvider);
          final siteList = ref.read(siteProvider);
          if (staffList.isEmpty || siteList.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Please add at least one staff member and one site first.'),
              backgroundColor: Colors.redAccent,
            ));
            return;
          }
          _showAddEditScheduleDialog(context, ref, selectedDay);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showNotesDialog(BuildContext context, WidgetRef ref, ScheduleEntry entry) {
    final selectedDay = ref.read(selectedDayProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Shift Notes'),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                Navigator.pop(context);
                _showAddEditScheduleDialog(context, ref, selectedDay, entry: entry);
              },
            )
          ],
        ),
        content: Text(
          (entry.notes != null && entry.notes!.isNotEmpty)
              ? entry.notes!
              : 'No notes for this shift.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddEditScheduleDialog(BuildContext context, WidgetRef ref, DateTime selectedDate, {ScheduleEntry? entry}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(entry != null ? 'Edit Schedule' : 'Add Schedule'),
          content: _AddEditScheduleDialogContent(
            selectedDate: selectedDate,
            entry: entry,
          ),
        );
      },
    );
  }
}

class _AddEditScheduleDialogContent extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final ScheduleEntry? entry;

  const _AddEditScheduleDialogContent({
    required this.selectedDate,
    this.entry,
  });

  @override
  ConsumerState<_AddEditScheduleDialogContent> createState() => _AddEditScheduleDialogContentState();
}

class _AddEditScheduleDialogContentState extends ConsumerState<_AddEditScheduleDialogContent> {
  late bool isEditing;
  late int? selectedStaffKey;
  late int? selectedSiteKey;
  late TimeOfDay startTime;
  late TimeOfDay finishTime;
  late TextEditingController notesController;
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    isEditing = widget.entry != null;
    selectedStaffKey = isEditing ? widget.entry!.staffKey : null;
    selectedSiteKey = isEditing ? widget.entry!.siteKey : null;
    startTime = isEditing ? TimeOfDay.fromDateTime(widget.entry!.startTime) : const TimeOfDay(hour: 9, minute: 0);
    finishTime = isEditing ? TimeOfDay.fromDateTime(widget.entry!.finishTime) : const TimeOfDay(hour: 17, minute: 0);
    notesController = TextEditingController(text: widget.entry?.notes ?? '');
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  Future<void> onSave() async {
    if (formKey.currentState?.validate() ?? false) {
      final newStartTime = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, startTime.hour, startTime.minute);
      final newFinishTime = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, finishTime.hour, finishTime.minute);

      if (!newFinishTime.isAfter(newStartTime)) {
        if (!context.mounted) return;
        showDialog(context: context, builder: (context) => AlertDialog(
          title: const Text('Invalid Time'),
          content: const Text('The finish time must be after the start time.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ));
        return;
      }

      final allEntries = ref.read(scheduleProvider);
      final conflictingShifts = allEntries.where((e) {
        return e.staffKey == selectedStaffKey &&
            isSameDay(e.date, widget.selectedDate) &&
            (isEditing ? e.key != widget.entry!.key : true);
      });

      for (final existingShift in conflictingShifts) {
        if (newStartTime.isBefore(existingShift.finishTime) && newFinishTime.isAfter(existingShift.startTime)) {
          if (!context.mounted) return;
          showDialog(context: context, builder: (context) => AlertDialog(
            title: const Text('Schedule Conflict'),
            content: const Text('This staff member is already scheduled for an overlapping shift at this time.'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ));
          return;
        }
      }

      final projectionBox = Hive.box<SiteProjection>('site_projections');
      final siteProjection = projectionBox.get(selectedSiteKey.toString());
      if (siteProjection != null && siteProjection.projectedHours > 0) {
        final startOfWeek = widget.selectedDate.subtract(Duration(days: widget.selectedDate.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        final weekEntries = allEntries.where((e) => e.siteKey == selectedSiteKey && !e.date.isBefore(startOfWeek) && !e.date.isAfter(endOfWeek) && (isEditing ? e.key != widget.entry!.key : true));
        double currentScheduledSeconds = weekEntries.fold(0, (prev, e) => prev + e.finishTime.difference(e.startTime).inSeconds);
        final newShiftSeconds = newFinishTime.difference(newStartTime).inSeconds;
        final potentialTotalHours = (currentScheduledSeconds + newShiftSeconds) / 3600;

        if (potentialTotalHours > siteProjection.projectedHours) {
          if (!context.mounted) return;
          final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
            title: const Text('Projection Warning'),
            content: Text('This shift will cause the site to be overscheduled for the week.\n\nProjected: ${siteProjection.projectedHours.toStringAsFixed(1)} hrs\nScheduled: ${potentialTotalHours.toStringAsFixed(1)} hrs\n\nSave anyway?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save Anyway')),
            ],
          ));
          if (confirmed != true) return;
        }
      }

      final newEntry = ScheduleEntry(
        date: widget.selectedDate,
        staffKey: selectedStaffKey!,
        siteKey: selectedSiteKey!,
        startTime: newStartTime,
        finishTime: newFinishTime,
        notes: notesController.text.trim(),
      );

      if (isEditing) {
        ref.read(scheduleProvider.notifier).updateScheduleEntry(widget.entry!.key, newEntry);
      } else {
        ref.read(scheduleProvider.notifier).addScheduleEntry(newEntry);
      }
      if (!context.mounted) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StaffDropdown(
              selectedStaffKey: selectedStaffKey,
              onChanged: (value) => setState(() => selectedStaffKey = value),
            ),
            _SiteDropdown(
              selectedSiteKey: selectedSiteKey,
              onChanged: (value) {
                setState(() {
                  selectedSiteKey = value;
                  if (value != null && !isEditing) {
                    final site = ref.read(siteProvider).firstWhere((s) => s.key == value);
                    if (site.presetStartTime != null && site.presetStartTime!.isNotEmpty) {
                      final parts = site.presetStartTime!.split(':');
                      startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
                    }
                    if (site.presetFinishTime != null && site.presetFinishTime!.isNotEmpty) {
                      final parts = site.presetFinishTime!.split(':');
                      finishTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
                    }
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            _TimePickerButtons(
              startTime: startTime,
              finishTime: finishTime,
              onStartTimePressed: () async {
                final time = await showTimePicker(context: context, initialTime: startTime);
                if (time != null) {
                  setState(() => startTime = time);
                  if (!context.mounted) return;
                  final finish = await showTimePicker(context: context, initialTime: finishTime);
                  if (finish != null) setState(() => finishTime = finish);
                }
              },
              onFinishTimePressed: () async {
                final time = await showTimePicker(context: context, initialTime: finishTime);
                if (time != null) setState(() => finishTime = time);
              },
            ),
            const SizedBox(height: 8),
            _NotesTextField(controller: notesController),
            const SizedBox(height: 16),
            _DialogActions(
              isEditing: isEditing,
              onCancel: () => Navigator.pop(context),
              onSave: onSave,
              onDelete: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Deletion'),
                    content: const Text('Delete this schedule entry?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                );
                if (confirmed == true) {
                  ref.read(scheduleProvider.notifier).deleteScheduleEntry(widget.entry!.key);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffDropdown extends ConsumerWidget {
  final int? selectedStaffKey;
  final ValueChanged<int?> onChanged;

  const _StaffDropdown({required this.selectedStaffKey, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffList = ref.watch(staffProvider);
    return DropdownButtonFormField<int>(
      value: selectedStaffKey,
      hint: const Text('Select Staff'),
      items: staffList.map((staff) => DropdownMenuItem(value: staff.key as int, child: Text(staff.name))).toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Please select staff' : null,
    );
  }
}

class _SiteDropdown extends ConsumerWidget {
  final int? selectedSiteKey;
  final ValueChanged<int?> onChanged;

  const _SiteDropdown({required this.selectedSiteKey, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final siteList = ref.watch(siteProvider);
    return DropdownButtonFormField<int>(
      value: selectedSiteKey,
      hint: const Text('Select Site'),
      items: siteList.map((site) => DropdownMenuItem(value: site.key as int, child: Text(site.name))).toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Please select a site' : null,
    );
  }
}

class _TimePickerButtons extends StatelessWidget {
  final TimeOfDay startTime;
  final TimeOfDay finishTime;
  final VoidCallback onStartTimePressed;
  final VoidCallback onFinishTimePressed;

  const _TimePickerButtons({
    required this.startTime,
    required this.finishTime,
    required this.onStartTimePressed,
    required this.onFinishTimePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(
          children: [
            const Text('Start Time'),
            ElevatedButton(
              onPressed: onStartTimePressed,
              child: Text(startTime.format(context)),
            ),
          ],
        ),
        Column(
          children: [
            const Text('Finish Time'),
            ElevatedButton(
              onPressed: onFinishTimePressed,
              child: Text(finishTime.format(context)),
            ),
          ],
        ),
      ],
    );
  }
}

class _NotesTextField extends StatelessWidget {
  final TextEditingController controller;

  const _NotesTextField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(labelText: 'Notes (Optional)'),
      textCapitalization: TextCapitalization.sentences,
    );
  }
}

class _DialogActions extends StatelessWidget {
  final bool isEditing;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  const _DialogActions({
    required this.isEditing,
    required this.onCancel,
    required this.onSave,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isEditing)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: onDelete,
          ),
        const Spacer(),
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ElevatedButton(onPressed: onSave, child: const Text('Save')),
      ],
    );
  }
}