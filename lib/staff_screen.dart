import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:scheduler/models.dart';
import 'package:scheduler/widgets/custom_app_bar.dart';

final staffProvider = StateNotifierProvider<StaffNotifier, List<Staff>>((ref) {
  return StaffNotifier();
});

class StaffNotifier extends StateNotifier<List<Staff>> {
  final Box<Staff> _box = Hive.box<Staff>('staff');

  StaffNotifier() : super([]) {
    state = _box.values.toList()..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    _box.listenable().addListener(() {
      state = _box.values.toList()..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    });
  }

  Future<void> addStaff(Staff staff) async {
    staff.orderIndex = state.length;
    await _box.add(staff);
  }

  Future<void> updateStaff(dynamic key, Staff staff) async {
    await _box.put(key, staff);
  }

  Future<void> deleteStaff(dynamic key) async {
    await _box.delete(key);
    _updateOrder();
  }

  Future<void> reorderStaff(int oldIndex, int newIndex) async {
    final list = List<Staff>.from(state);
    final item = list.removeAt(oldIndex);
    if (newIndex > oldIndex) newIndex -= 1;
    list.insert(newIndex, item);

    state = list;
    await _updateOrder();
  }

  Future<void> _updateOrder() async {
    final Map<dynamic, Staff> updates = {};
    for (int i = 0; i < state.length; i++) {
      final staff = state[i];
      if (staff.orderIndex != i) {
        staff.orderIndex = i;
        updates[staff.key] = staff;
      }
    }
    if (updates.isNotEmpty) {
      await _box.putAll(updates);
    }
  }
}

class AddStaffScreen extends ConsumerWidget {
  const AddStaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffList = ref.watch(staffProvider);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Staff'),
      body: staffList.isEmpty
          ? const Center(child: Text('No staff members added yet.'))
          : ReorderableListView.builder(
        itemCount: staffList.length,
        itemBuilder: (context, index) {
          final staff = staffList[index];
          return Dismissible(
            key: ValueKey(staff.key),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.redAccent,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Deletion'),
                  content: Text('Are you sure you want to delete ${staff.name}?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (direction) {
              ref.read(staffProvider.notifier).deleteStaff(staff.key);
            },
            child: ListTile(
              tileColor: index.isEven ? null : Theme.of(context).colorScheme.surface,
              title: Text(staff.name),
              subtitle: Text(staff.notes ?? ''),
              onTap: () => _showAddEditStaffDialog(context, ref, staff: staff),
              trailing: ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle),
              ),
            ),
          );
        },
        onReorder: (oldIndex, newIndex) {
          ref.read(staffProvider.notifier).reorderStaff(oldIndex, newIndex);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditStaffDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddEditStaffDialog(BuildContext context, WidgetRef ref, {Staff? staff}) {
    final isEditing = staff != null;
    final nameController = TextEditingController(text: staff?.name ?? '');
    final notesController = TextEditingController(text: staff?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Staff' : 'Add Staff'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final newName = nameController.text.trim();

                  final allStaff = ref.read(staffProvider);
                  final isDuplicate = allStaff.any((s) {
                    if (isEditing && s.key == staff.key) return false;
                    return s.name.toLowerCase() == newName.toLowerCase();
                  });

                  if (isDuplicate) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Duplicate Name'),
                        content: const Text('A staff member with this name already exists.'),
                        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                      ),
                    );
                    return;
                  }

                  final staffToSave = Staff(
                    name: newName,
                    notes: notesController.text.trim(),
                    orderIndex: staff?.orderIndex ?? 0,
                  );
                  if (isEditing) {
                    ref.read(staffProvider.notifier).updateStaff(staff.key, staffToSave);
                  } else {
                    ref.read(staffProvider.notifier).addStaff(staffToSave);
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}