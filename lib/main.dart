import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const AntasenaApp(),
    ),
  );
}

class AppState extends ChangeNotifier {
  int rpm = 0;
  double speed = 0;
  double minRpm = 3000;
  double rpmCalibration = 1.0;
  List<int> tableRpm = [4000, 6000, 8000, 10000];
  List<int> tableKill = [95, 85, 75, 65];
  
  bool isConnected = false;
  bool isConnecting = false;
  String? connectedDeviceName;
  
  double raceTime = 0;
  String raceStatus = 'idle'; // idle, running, stopped
  Map<String, String> runMetrics = {
    '0-100': '--',
    '201m': '--',
    '402m': '--',
  };

  Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;

  AppState() {
    _loadSettings();
    _initGps();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    minRpm = prefs.getDouble('minRpm') ?? 3000;
    rpmCalibration = prefs.getDouble('rpmCalibration') ?? 1.0;
    final savedTableRpm = prefs.getStringList('tableRpm');
    if (savedTableRpm != null) tableRpm = savedTableRpm.map(int.parse).toList();
    final savedTableKill = prefs.getStringList('tableKill');
    if (savedTableKill != null) tableKill = savedTableKill.map(int.parse).toList();
    notifyListeners();
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('minRpm', minRpm);
    await prefs.setDouble('rpmCalibration', rpmCalibration);
    await prefs.setStringList('tableRpm', tableRpm.map((e) => e.toString()).toList());
    await prefs.setStringList('tableKill', tableKill.map((e) => e.toString()).toList());
    notifyListeners();
  }

  void _initGps() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      speed = (position.speed * 3.6); // m/s to km/h
      if (speed < 0) speed = 0;
      notifyListeners();
    });
  }

  void startRace() {
    raceStatus = 'running';
    raceTime = 0;
    _stopwatch.reset();
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      raceTime = _stopwatch.elapsedMilliseconds / 1000.0;
      notifyListeners();
    });
    notifyListeners();
  }

  void stopRace() {
    raceStatus = 'stopped';
    _stopwatch.stop();
    _timer?.cancel();
    notifyListeners();
  }

  void resetRace() {
    raceStatus = 'idle';
    raceTime = 0;
    _stopwatch.reset();
    _timer?.cancel();
    runMetrics = {'0-100': '--', '201m': '--', '402m': '--'};
    notifyListeners();
  }

  void updateRpm(int rawRpm) {
    rpm = (rawRpm * rpmCalibration).round();
    notifyListeners();
  }
}

class AntasenaApp extends StatelessWidget {
  const AntasenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antasena Performance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFEF4444),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF121212),
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const TuningScreen(),
    const RaceboxScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFFEF4444),
          unselectedItemColor: Colors.white.withOpacity(0.3),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.speed), label: 'DASHBOARD'),
            BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'TUNING'),
            BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'RACEBOX'),
          ],
        ),
      ),
    );
  }
}

// --- DASHBOARD SCREEN ---
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ANTASENA', style: GoogleFonts.inter(fontWeight: FontWeight.black, fontStyle: FontStyle.italic, fontSize: 20, letterSpacing: -1)),
                    Text('PERFORMANCE', style: GoogleFonts.inter(fontWeight: FontWeight.black, fontSize: 10, color: const Color(0xFFEF4444), letterSpacing: 2)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, py: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bluetooth, size: 14, color: state.isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                      const SizedBox(width: 6),
                      Text(state.isConnected ? 'LIVE' : 'CONNECT', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.black)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            
            // RPM Gauge (Minimalist Tech)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ENGINE RPM', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(state.rpm.toString(), style: GoogleFonts.jetBrainsMono(fontSize: 48, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Text('RPM', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('GPS SPEED', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(state.speed.round().toString(), style: GoogleFonts.jetBrainsMono(fontSize: 36, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444))),
                              const SizedBox(width: 4),
                              Text('KM/H', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  // Horizontal RPM Bar
                  SizedBox(
                    height: 8,
                    child: Row(
                      children: List.generate(24, (index) {
                        double threshold = (index / 24) * 14000;
                        bool isActive = state.rpm > threshold;
                        Color color = Colors.white.withOpacity(0.05);
                        if (isActive) {
                          if (index < 14) color = const Color(0xFF10B981);
                          else if (index < 20) color = const Color(0xFFFACC15);
                          else color = const Color(0xFFEF4444);
                        }
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: isActive ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)] : [],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard('RPM MINIMUM', '${state.minRpm.round()}', 'RPM', Icons.show_chart),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoCard('ACTIVE CUT', '${state.rpm > state.minRpm ? state.tableKill[0] : 0}', 'MS', Icons.bolt, color: const Color(0xFFEF4444)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, String unit, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.white.withOpacity(0.2)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 4),
              Text(unit, style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

// --- TUNING SCREEN ---
class TuningScreen extends StatelessWidget {
  const TuningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('TUNING', style: GoogleFonts.inter(fontWeight: FontWeight.black, fontSize: 14, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildSettingSection('RPM MINIMUM ACTIVE', state.minRpm.round().toString(), 'RPM'),
            const SizedBox(height: 20),
            _buildCalibrationSection(state),
            const SizedBox(height: 20),
            _buildKillTimeTable(state),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () => state.saveSettings(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: const Text('APPLY SETTING', style: TextStyle(fontWeight: FontWeight.black, letterSpacing: 1.5)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingSection(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              Text(unit, style: TextStyle(color: Colors.white.withOpacity(0.2), fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationSection(AppState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RPM CALIBRATION', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
              Text('x${state.rpmCalibration.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [0.8, 1.0, 1.2, 1.5].map((val) {
              bool isSelected = state.rpmCalibration == val;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    state.rpmCalibration = val;
                    state.notifyListeners();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEF4444) : Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.05)),
                    ),
                    child: Text('${val}x', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.white.withOpacity(0.3))),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildKillTimeTable(AppState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('KILL TIME CONFIGURATION', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(flex: 1, child: Text('STAGE', style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 8, fontWeight: FontWeight.black))),
              Expanded(flex: 2, child: Text('RPM TRIGGER', style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 8, fontWeight: FontWeight.black, textAlign: TextAlign.center))),
              Expanded(flex: 2, child: Text('KILL (MS)', style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 8, fontWeight: FontWeight.black, textAlign: TextAlign.right))),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(4, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.03)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 1, child: Text('S${index + 1}', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.black, fontStyle: FontStyle.italic))),
                  Expanded(flex: 2, child: Text(state.tableRpm[index].toString(), textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text(state.tableKill[index].toString(), textAlign: TextAlign.right, style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// --- RACEBOX SCREEN ---
class RaceboxScreen extends StatelessWidget {
  const RaceboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('RACEBOX', style: GoogleFonts.inter(fontWeight: FontWeight.black, fontSize: 14, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  Text(state.raceStatus == 'running' ? 'RECORDING RUN...' : 'READY FOR LAUNCH', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 20),
                  Text(state.raceTime.toStringAsFixed(2), style: GoogleFonts.jetBrainsMono(fontSize: 72, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => state.raceStatus == 'running' ? state.stopRace() : state.startRace(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                          decoration: BoxDecoration(
                            color: state.raceStatus == 'running' ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: (state.raceStatus == 'running' ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withOpacity(0.3), blurRadius: 20, spreadRadius: 2)],
                          ),
                          child: Text(state.raceStatus == 'running' ? 'STOP' : 'START', style: const TextStyle(fontWeight: FontWeight.black, letterSpacing: 2)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => state.resetRace(),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.refresh, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RUN STATISTICS', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 24),
                  _buildStatRow('0 - 100 KM/H', state.runMetrics['0-100']!),
                  _buildStatRow('201 METER (1/8)', state.runMetrics['201m']!),
                  _buildStatRow('402 METER (1/4)', state.runMetrics['402m']!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.bold)),
          Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}
