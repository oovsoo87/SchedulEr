import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

// This provider will return 'true' if the user is on the Pro plan, and 'false' for Lite.
final planProvider = StateNotifierProvider<PlanNotifier, bool>((ref) {
  return PlanNotifier();
});

class PlanNotifier extends StateNotifier<bool> {
  final Box _settingsBox = Hive.box('settings');

  // By default, the user is on the Lite plan ('isPro' is false).
  // The provider reads this value from Hive when the app starts.
  PlanNotifier() : super(Hive.box('settings').get('isPro', defaultValue: false));

  // This function will be called after a successful upgrade.
  // It saves the Pro status to local storage and updates the app's state.
  Future<void> upgradeToPro() async {
    await _settingsBox.put('isPro', true);
    state = true;
  }
}