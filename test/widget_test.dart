// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:scheduler/main.dart';
import 'package:scheduler/models.dart';
import 'package:scheduler/set_passcode_screen.dart';

void main() {
  setUpAll(() async {
    // It's necessary to initialize Hive for tests
    await Hive.initFlutter('test');

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(StaffAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(SiteAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(ScheduleEntryAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(SiteProjectionAdapter());

    // Open boxes
    await Hive.openBox<Staff>('staff');
    await Hive.openBox<Site>('sites');
    await Hive.openBox<ScheduleEntry>('schedule_entries');
    await Hive.openBox<SiteProjection>('site_projections');
    await Hive.openBox('settings');
  });

  testWidgets('Password screen shows correctly when passcode is set', (WidgetTester tester) async {
    // Build our app with isPasscodeSet: true.
    await tester.pumpWidget(const ProviderScope(
      // The required isPasscodeSet parameter is now provided.
      child: SchedulerApp(isPasscodeSet: true),
    ));

    // Verify that the regular password screen is displayed.
    expect(find.byType(PasswordScreen), findsOneWidget);
    expect(find.text('Enter Passcode'), findsOneWidget); // Text field label
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget); // Login Button
  });

  testWidgets('Set Passcode screen shows correctly on first run', (WidgetTester tester) async {
    // Build our app with isPasscodeSet: false.
    await tester.pumpWidget(const ProviderScope(
      child: SchedulerApp(isPasscodeSet: false),
    ));

    // Verify that the "Set Passcode" screen is displayed.
    expect(find.byType(SetPasscodeScreen), findsOneWidget);
    expect(find.text('Enter New Passcode'), findsOneWidget);
    expect(find.text('Confirm Passcode'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Save and Continue'), findsOneWidget);
  });
}