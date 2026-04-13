import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

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

// --- STATE MANAGEMENT ---
class AppState extends ChangeNotifier {
  // Engine Data
  int _rpm = 0;
  double _speed = 0;
  
  // Settings
  double _minRpmActive = 3000;
  double _rpmCalibration = 1.0;
  List<int> _tableRpm = [4000, 6000, 8000, 10000];
  List<int> _tableKill = [95, 85, 75, 65];
  
  // Connection
  bool _isConnected = false;
  String? _deviceName;
  
  // Racebox
  double _raceTime = 0;
  String _raceStatus = 'IDLE'; // IDLE, RUNNING, FINISHED
  
  // Getters
  int get rpm => _rpm;
  double get speed => _speed;
  double get minRpmActive => _minRpmActive;
  double get rpmCalibration => _rpmCalibration;
  List<int> get tableRpm => _tableRpm;
  List<int> get tableKill => _tableKill;
  bool get isConnected => _isConnected;
  String? get deviceName => _deviceName;
  double get raceTime => _raceTime;
  String get raceStatus => _raceStatus;

  AppState() {
    _loadSettings();
    _initGps();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _minRpmActive = prefs.getDouble('minRpmActive') ?? 3000;
    _rpmCalibration = prefs.getDouble('rpmCalibration') ?? 1.0;
    final savedRpm = prefs.getStringList('tableRpm');
    if (savedRpm != null) _tableRpm = savedRpm.map(int.parse).toList();
    final savedKill = prefs.getStringList('tableKill');
    if (savedKill != null) _tableKill = savedKill.map(int.parse).toList();
    notifyListeners();
  }

  void updateRpm(int val) {
    _rpm = (val * _rpmCalibration).round();
    notifyListeners();
  }

  void setRpmCalibration(double val) {
    _rpmCalibration = val;
    notifyListeners();
  }

  void setMinRpm(double val) {
    _minRpmActive = val;
    notifyListeners();
  }

  void _initGps() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      _speed = position.speed * 3.6; // m/s to km/h
      notifyListeners();
    });
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('minRpmActive', _minRpmActive);
    await prefs.setDouble('rpmCalibration', _rpmCalibration);
    await prefs.setStringList('tableRpm', _tableRpm.map((e) => e.toString()).toList());
    await prefs.setStringList('tableKill', _tableKill.map((e) => e.toString()).toList());
    notifyListeners();
  }
}

// --- MAIN APP ---
class AntasenaApp extends StatelessWidget {
  const AntasenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antasena Performance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050505),
        primaryColor: const Color(0xFFEF4444),
        textTheme: GoogleFonts.orbitronTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFEF4444),
          secondary: Color(0xFFEF4444),
          surface: Color(0xFF0F0F0F),
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
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    const TuningPage(),
    const RaceboxPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: const Color(0xFF0A0A0A),
          selectedItemColor: const Color(0xFFEF4444),
          unselectedItemColor: Colors.white.withOpacity(0.3),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.speed), label: 'DASH'),
            BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'TUNING'),
            BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'RACE'),
          ],
        ),
      ),
    );
  }
}

// --- DASHBOARD PAGE ---
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ANTASENA', style: GoogleFonts.orbitron(fontSize: 20, fontWeight: FontWeight.black, color: Colors.white, letterSpacing: 1)),
                    Text('PERFORMANCE', style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444), letterSpacing: 4)),
                  ],
                ),
                _buildStatusIndicator(state),
              ],
            ),
            const SizedBox(height: 40),
            
            // Main RPM Gauge
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('ENGINE RPM', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Text(state.rpm.toString(), style: GoogleFonts.jetBrainsMono(fontSize: 80, fontWeight: FontWeight.bold, letterSpacing: -4)),
                    const SizedBox(height: 20),
                    // RPM Bar
                    _buildRpmBar(state.rpm),
                  ],
                ),
              ),
            ),
            
            // Speed & Stats
            Row(
              children: [
                _buildMiniStat('SPEED', state.speed.round().toString(), 'KM/H', const Color(0xFFEF4444)),
                const SizedBox(width: 16),
                _buildMiniStat('MIN RPM', state.minRpmActive.round().toString(), 'RPM', Colors.white.withOpacity(0.5)),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(AppState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: state.isConnected ? Colors.green : Colors.red,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: (state.isConnected ? Colors.green : Colors.red).withOpacity(0.5), blurRadius: 4)],
            ),
          ),
          const SizedBox(width: 8),
          Text(state.isConnected ? 'CONNECTED' : 'OFFLINE', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRpmBar(int rpm) {
    return Container(
      height: 40,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: List.generate(20, (index) {
            double threshold = (index / 20) * 14000;
            bool active = rpm > threshold;
            Color color = Colors.white.withOpacity(0.05);
            if (active) {
              if (index < 12) color = Colors.green;
              else if (index < 16) color = Colors.yellow;
              else color = Colors.red;
            }
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                color: color,
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(width: 4),
                Text(unit, style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- TUNING PAGE ---
class TuningPage extends StatelessWidget {
  const TuningPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text('TUNING SYSTEM', style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTuningCard('MINIMUM RPM', state.minRpmActive.round().toString(), 'RPM', Icons.keyboard_double_arrow_up),
            const SizedBox(height: 16),
            _buildCalibrationSelector(state),
            const SizedBox(height: 16),
            _buildKillTable(state),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () => state.saveSettings(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text('WRITE TO MODULE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTuningCard(String label, String value, String unit, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 12, color: const Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  Text(label, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text(unit, style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 12)),
                ],
              ),
            ],
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white10),
        ],
      ),
    );
  }

  Widget _buildCalibrationSelector(AppState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RPM CALIBRATION', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [0.8, 1.0, 1.2, 1.5].map((v) {
              bool selected = state.rpmCalibration == v;
              return Expanded(
                child: GestureDetector(
                  onTap: () => state.setRpmCalibration(v),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFEF4444) : Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? Colors.transparent : Colors.white10),
                    ),
                    child: Text('${v}x', textAlign: TextAlign.center, style: TextStyle(color: selected ? Colors.white : Colors.white30, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildKillTable(AppState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('KILL TIME TABLE (MS)', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ...List.generate(4, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text('S${i+1}', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildTableInput(state.tableRpm[i].toString(), 'RPM')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTableInput(state.tableKill[i].toString(), 'MS')),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTableInput(String val, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(val, style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
          Text(unit, style: const TextStyle(color: Colors.white10, fontSize: 9)),
        ],
      ),
    );
  }
}

// --- RACEBOX PAGE ---
class RaceboxPage extends StatelessWidget {
  const RaceboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text('RACEBOX GPS', style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  Text('CURRENT TIME', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10, letterSpacing: 2)),
                  const SizedBox(height: 16),
                  Text(state.raceTime.toStringAsFixed(2), style: GoogleFonts.jetBrainsMono(fontSize: 70, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRaceButton('START', const Color(0xFF10B981), () {}),
                      const SizedBox(width: 16),
                      _buildRaceButton('RESET', Colors.white10, () {}),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildMetricRow('0-100 KM/H', '-- s'),
            _buildMetricRow('201 METER', '-- s'),
            _buildMetricRow('402 METER', '-- s'),
          ],
        ),
      ),
    );
  }

  Widget _buildRaceButton(String label, Color color, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.3), fontWeight: FontWeight.bold, fontSize: 11)),
          Text(value, style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}
