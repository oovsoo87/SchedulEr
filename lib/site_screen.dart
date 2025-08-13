import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:scheduler/models.dart';
import 'package:scheduler/widgets/custom_app_bar.dart';

// *** MODIFIED: Added more, lighter color options ***
const List<Color> siteColors = [
  Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red,
  Colors.teal, Colors.pink, Colors.indigo, Colors.amber, Colors.cyan,
  Color(0xFFB2DFDB), Color(0xFFF8BBD0), Color(0xFFD1C4E9), Color(0xFFC5CAE9), Color(0xFFBBDEFB),
  Color(0xFFFFF9C4), Color(0xFFFFE0B2), Color(0xFFD7CCC8), Color(0xFFCFD8DC),
];

final siteProvider = StateNotifierProvider<SiteNotifier, List<Site>>((ref) {
  return SiteNotifier();
});

class SiteNotifier extends StateNotifier<List<Site>> {
  final Box<Site> _box = Hive.box<Site>('sites');

  SiteNotifier() : super([]) {
    state = _box.values.toList()..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    _box.listenable().addListener(() {
      state = _box.values.toList()..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    });
  }

  Future<void> addSite(Site site) async {
    site.orderIndex = state.length;
    await _box.add(site);
  }

  Future<void> updateSite(dynamic key, Site site) async {
    await _box.put(key, site);
  }

  Future<void> deleteSite(dynamic key) async {
    await _box.delete(key);
    _updateOrder();
  }

  Future<void> reorderSite(int oldIndex, int newIndex) async {
    final list = List<Site>.from(state);
    final item = list.removeAt(oldIndex);
    if (newIndex > oldIndex) newIndex -= 1;
    list.insert(newIndex, item);

    state = list;
    await _updateOrder();
  }

  Future<void> _updateOrder() async {
    final Map<dynamic, Site> updates = {};
    for (int i = 0; i < state.length; i++) {
      final site = state[i];
      if (site.orderIndex != i) {
        site.orderIndex = i;
        updates[site.key] = site;
      }
    }
    if (updates.isNotEmpty) {
      await _box.putAll(updates);
    }
  }
}

class AddSiteScreen extends ConsumerWidget {
  const AddSiteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final siteList = ref.watch(siteProvider);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Sites'),
      body: siteList.isEmpty
          ? const Center(child: Text('No sites added yet.'))
          : ReorderableListView.builder(
        itemCount: siteList.length,
        itemBuilder: (context, index) {
          final site = siteList[index];
          return Dismissible(
            key: ValueKey(site.key),
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
                  content: Text('Are you sure you want to delete ${site.name}?'),
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
              ref.read(siteProvider.notifier).deleteSite(site.key);
            },
            child: ListTile(
              tileColor: index.isEven ? null : Theme.of(context).colorScheme.surface,
              leading: CircleAvatar(backgroundColor: Color(site.colorValue), radius: 15),
              title: Text(site.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if(site.groupName != null && site.groupName!.isNotEmpty)
                    Text(site.groupName!, style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade400)),
                  if(site.address != null && site.address!.isNotEmpty) Text(site.address!),
                  if(site.notes != null && site.notes!.isNotEmpty) Text(site.notes!),
                ],
              ),
              onTap: () => _showAddEditSiteDialog(context, ref, site: site),
              trailing: ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle),
              ),
            ),
          );
        },
        onReorder: (oldIndex, newIndex) {
          ref.read(siteProvider.notifier).reorderSite(oldIndex, newIndex);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditSiteDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddEditSiteDialog(BuildContext context, WidgetRef ref, {Site? site}) {
    final isEditing = site != null;
    final nameController = TextEditingController(text: site?.name ?? '');
    final groupNameController = TextEditingController(text: site?.groupName ?? '');
    final addressController = TextEditingController(text: site?.address ?? '');
    final notesController = TextEditingController(text: site?.notes ?? '');
    final formKey = GlobalKey<FormState>();
    Color selectedColor = isEditing ? Color(site.colorValue) : siteColors.first;

    TimeOfDay? presetStartTime;
    if (site?.presetStartTime != null) {
      final parts = site!.presetStartTime!.split(':');
      presetStartTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    TimeOfDay? presetFinishTime;
    if (site?.presetFinishTime != null) {
      final parts = site!.presetFinishTime!.split(':');
      presetFinishTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Site' : 'Add Site'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Please enter a name';
                          return null;
                        },
                      ),
                      TextFormField(controller: groupNameController, decoration: const InputDecoration(labelText: 'Group Name (Optional)')),
                      TextFormField(controller: addressController, decoration: const InputDecoration(labelText: 'Address (Optional)')),
                      TextFormField(controller: notesController, decoration: const InputDecoration(labelText: 'Notes (Optional)')),

                      const Divider(height: 30),
                      const Text('Preset Shift Times (Optional)'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.access_time),
                            label: Text(presetStartTime?.format(context) ?? 'Start Time'),
                            onPressed: () async {
                              final time = await showTimePicker(context: context, initialTime: presetStartTime ?? const TimeOfDay(hour: 9, minute: 0));
                              if (time != null) setState(() => presetStartTime = time);
                            },
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.access_time_filled),
                            label: Text(presetFinishTime?.format(context) ?? 'Finish Time'),
                            onPressed: () async {
                              final time = await showTimePicker(context: context, initialTime: presetFinishTime ?? const TimeOfDay(hour: 17, minute: 0));
                              if (time != null) setState(() => presetFinishTime = time);
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 30),

                      const Text('Site Color'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: siteColors.map((color) => GestureDetector(
                          onTap: () => setState(() => selectedColor = color),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: color,
                            child: selectedColor == color ? const Icon(Icons.check, color: Colors.white) : null,
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final newName = nameController.text.trim();

                      final allSites = ref.read(siteProvider);
                      final isDuplicate = allSites.any((s) {
                        if (isEditing && s.key == site.key) return false;
                        return s.name.toLowerCase() == newName.toLowerCase();
                      });

                      if (isDuplicate) {
                        showDialog(context: context, builder: (context) => AlertDialog(
                          title: const Text('Duplicate Name'),
                          content: const Text('A site with this name already exists.'),
                          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                        ));
                        return;
                      }

                      final newSite = Site(
                        name: newName,
                        groupName: groupNameController.text.trim(),
                        address: addressController.text.trim(),
                        notes: notesController.text.trim(),
                        colorValue: selectedColor.toARGB32(),
                        orderIndex: site?.orderIndex ?? 0,
                        presetStartTime: presetStartTime != null ? '${presetStartTime!.hour}:${presetStartTime!.minute}' : null,
                        presetFinishTime: presetFinishTime != null ? '${presetFinishTime!.hour}:${presetFinishTime!.minute}' : null,
                      );
                      if (isEditing) {
                        ref.read(siteProvider.notifier).updateSite(site.key, newSite);
                      } else {
                        ref.read(siteProvider.notifier).addSite(newSite);
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
      },
    );
  }
}