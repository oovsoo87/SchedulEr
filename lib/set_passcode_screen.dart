import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:scheduler/main.dart';

class SetPasscodeScreen extends StatefulWidget {
  const SetPasscodeScreen({super.key});

  @override
  State<SetPasscodeScreen> createState() => _SetPasscodeScreenState();
}

class _SetPasscodeScreenState extends State<SetPasscodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passcodeController = TextEditingController();
  final _confirmPasscodeController = TextEditingController();
  final _settingsBox = Hive.box('settings');

  void _savePasscode() {
    if (_formKey.currentState!.validate()) {
      // Save the new passcode
      _settingsBox.put('password', _passcodeController.text);
      // Set a flag indicating the passcode has been set
      _settingsBox.put('passcode_set', true);

      // Navigate to the main app screen, replacing the setup screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Welcome to SchedulEr',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text('Please set a passcode to secure your app.'),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _passcodeController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'Enter New Passcode'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a passcode.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasscodeController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'Confirm Passcode'),
                  validator: (value) {
                    if (value != _passcodeController.text) {
                      return 'Passcodes do not match.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _savePasscode,
                  child: const Text('Save and Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}