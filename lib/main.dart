import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:scheduler/export_screen.dart';
import 'package:scheduler/home_screen.dart';
import 'package:scheduler/models.dart';
import 'package:scheduler/projections_screen.dart';
import 'package:scheduler/site_screen.dart';
import 'package:scheduler/staff_screen.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final Box _box = Hive.box('settings');
  ThemeNotifier() : super(ThemeMode.dark) {
    final isDarkMode = _box.get('isDarkMode', defaultValue: true);
    state = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  void toggleTheme(bool isDarkMode) {
    state = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    _box.put('isDarkMode', isDarkMode);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(StaffAdapter());
  Hive.registerAdapter(SiteAdapter());
  Hive.registerAdapter(ScheduleEntryAdapter());
  Hive.registerAdapter(SiteProjectionAdapter());

  await Hive.openBox<Staff>('staff');
  await Hive.openBox<Site>('sites');
  await Hive.openBox<ScheduleEntry>('schedule_entries');
  await Hive.openBox<SiteProjection>('site_projections');
  await Hive.openBox('settings');

  // **NEW**: Check for and store the first launch date for the trial period
  final settingsBox = Hive.box('settings');
  if (settingsBox.get('firstLaunchDate') == null) {
    settingsBox.put('firstLaunchDate', DateTime.now().toIso8601String());
  }

  runApp(Phoenix(child: const ProviderScope(child: SchedulerApp())));
}

class SchedulerApp extends ConsumerWidget {
  const SchedulerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    return MaterialApp(
      title: 'Scheduler',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
          brightness: Brightness.light,
          primaryColor: Colors.cyan,
          scaffoldBackgroundColor: Colors.grey.shade200,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan, brightness: Brightness.light, surface: Colors.white),
          textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 1,
            iconTheme: IconThemeData(color: Colors.grey.shade800),
            titleTextStyle: GoogleFonts.poppins(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: Colors.white,
            selectedItemColor: Colors.cyan,
            unselectedItemColor: Colors.grey.shade600,
          )
      ),
      darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212),
          primaryColor: Colors.cyanAccent,
          colorScheme: const ColorScheme.dark(
            primary: Colors.cyanAccent,
            secondary: Colors.tealAccent,
            surface: Color(0xFF1e1e1e),
          ),
          textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xFF1e1e1e),
            elevation: 1,
            titleTextStyle: GoogleFonts.poppins(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Color(0xFF1e1e1e),
            selectedItemColor: Colors.cyanAccent,
            unselectedItemColor: Colors.grey,
          )
      ),
      home: const PasswordScreen(),
    );
  }
}

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});
  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final Box _settingsBox = Hive.box('settings');

  void _login() {
    final storedPassword = _settingsBox.get('password', defaultValue: '1987');
    if (_passwordController.text == storedPassword) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect Passcode'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Scheduler', style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Theme.of(context).primaryColor)),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'Enter Passcode'),
                  onSubmitted: (_) => _login(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _login, child: const Text('Login')),
            ],
          ),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = <Widget>[
    HomeScreen(),
    AddStaffScreen(),
    AddSiteScreen(),
    ProjectionsScreen(),
    ExportTimesheetsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _screens.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Schedule'),
          BottomNavigationBarItem(icon: Icon(Icons.person_add), label: 'Staff'),
          BottomNavigationBarItem(icon: Icon(Icons.business), label: 'Sites'),
          BottomNavigationBarItem(icon: Icon(Icons.assessment), label: 'Projections'),
          BottomNavigationBarItem(icon: Icon(Icons.download), label: 'Export'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}