import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:scheduler/home_screen.dart';
import 'package:scheduler/main.dart';
import 'package:scheduler/widgets/custom_app_bar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _showBulkDeleteDialog(BuildContext context, WidgetRef ref) async {
    final confirmedProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule Data'),
        content: const Text('This will permanently delete schedule entries within a date range you select. This action cannot be undone.\n\nAre you sure you want to proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Proceed', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmedProceed != true) return;

    if (!context.mounted) return;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (range == null) return;

    final allEntries = ref.read(scheduleProvider);
    final inclusiveEndDate = range.end.add(const Duration(days: 1));
    final entriesToDelete = allEntries.where((e) {
      return e.date.isAfter(range.start.subtract(const Duration(days: 1))) && e.date.isBefore(inclusiveEndDate);
    }).toList();

    if (entriesToDelete.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No schedule entries found in that date range.')));
      return;
    }

    if (!context.mounted) return;
    final confirmedDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('FINAL CONFIRMATION'),
        content: Text('You are about to permanently delete ${entriesToDelete.length} schedule entries.\n\nAre you absolutely sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmedDelete == true) {
      final keysToDelete = entriesToDelete.map((e) => e.key);
      await ref.read(scheduleProvider.notifier).deleteMultipleEntries(keysToDelete);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${keysToDelete.length} entries deleted.'), backgroundColor: Colors.green));
    }
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final settingsBox = Hive.box('settings');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Passcode'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPasswordController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Current Passcode'),
                validator: (value) {
                  final storedPassword = settingsBox.get('password', defaultValue: '1987');
                  if (value != storedPassword) {
                    return 'Incorrect passcode';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: newPasswordController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'New Passcode'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new passcode';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Confirm New Passcode'),
                validator: (value) {
                  if (value != newPasswordController.text) {
                    return 'Passcodes do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                settingsBox.put('password', newPasswordController.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passcode changed successfully!'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Settings', actions: []),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Switch between light and dark themes.'),
            value: isDarkMode,
            onChanged: (value) {
              ref.read(themeProvider.notifier).toggleTheme(value);
            },
            secondary: Icon(isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Passcode'),
            onTap: () => _showChangePasswordDialog(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: const Text('Delete Schedule Data', style: TextStyle(color: Colors.redAccent)),
            subtitle: const Text('Permanently delete entries in a date range.'),
            onTap: () => _showBulkDeleteDialog(context, ref),
          ),
          const Divider(),
        ],
      ),
    );
  }
}