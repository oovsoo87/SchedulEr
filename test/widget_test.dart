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

  testWidgets('Password screen shows correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: SchedulerApp()));

    // Verify that the password screen is displayed.
    expect(find.text('Scheduler'), findsOneWidget); // App Title
    expect(find.text('Enter Passcode'), findsOneWidget); // Text field label
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget); // Login Button
  });
}