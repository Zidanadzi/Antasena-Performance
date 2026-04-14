import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';

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
    
    // Shift Light Logic: Flash screen if RPM is high
    bool isShiftPoint = state.rpm > 12000;

    return Scaffold(
      backgroundColor: isShiftPoint ? const Color(0xFFEF4444) : Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Background Pattern (Subtle Grid)
            Opacity(
              opacity: 0.05,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10),
                itemBuilder: (context, index) => Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Info Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ANTASENA', style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.w900, color: isShiftPoint ? Colors.black : Colors.white, letterSpacing: 1)),
                          Text('STEALTH HUD', style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: isShiftPoint ? Colors.black : const Color(0xFFEF4444), letterSpacing: 2)),
                        ],
                      ),
                      _buildStatusIndicator(state, isShiftPoint),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  // GIANT RPM DISPLAY
                  Center(
                    child: Column(
                      children: [
                        Text(state.rpm.toString(), 
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 110, 
                            fontWeight: FontWeight.w900, 
                            letterSpacing: -8,
                            color: isShiftPoint ? Colors.black : Colors.white,
                          )
                        ),
                        Text('RPM', style: TextStyle(color: isShiftPoint ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.2), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 4)),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // SPEED & STATS (BOTTOM)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Giant Speed
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SPEED', style: TextStyle(color: isShiftPoint ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.2), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(state.speed.round().toString(), 
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 64, 
                                    fontWeight: FontWeight.bold, 
                                    color: isShiftPoint ? Colors.black : const Color(0xFFEF4444)
                                  )
                                ),
                                const SizedBox(width: 8),
                                Text('KM/H', style: TextStyle(color: isShiftPoint ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.1), fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Secondary Stats
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildCompactStat('MIN RPM', state.minRpmActive.round().toString(), isShiftPoint),
                            const SizedBox(height: 12),
                            _buildCompactStat('CALIB', '${state.rpmCalibration}x', isShiftPoint),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Bottom Progress Bar (RPM Range)
                  _buildStealthRpmBar(state.rpm, isShiftPoint),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(AppState state, bool isShiftPoint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isShiftPoint ? Colors.black.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isShiftPoint ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: state.isConnected ? const Color(0xFF00FF00) : const Color(0xFFFF0000),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(state.isConnected ? 'LIVE' : 'DISCONNECTED', 
            style: TextStyle(
              fontSize: 8, 
              fontWeight: FontWeight.w900, 
              color: isShiftPoint ? Colors.black : Colors.white
            )
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String label, String value, bool isShiftPoint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(color: isShiftPoint ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.2), fontSize: 8, fontWeight: FontWeight.bold)),
        Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.bold, color: isShiftPoint ? Colors.black : Colors.white)),
      ],
    );
  }

  Widget _buildStealthRpmBar(int rpm, bool isShiftPoint) {
    return Container(
      height: 6,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isShiftPoint ? Colors.black.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: (rpm / 14000).clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: isShiftPoint ? Colors.black : const Color(0xFFEF4444),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              if (!isShiftPoint) BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.5), blurRadius: 10)
            ],
          ),
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('TUNING SYSTEM', style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.white.withOpacity(0.05), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            _buildSectionHeader('QUICKSHIFTER CONFIG'),
            const SizedBox(height: 20),
            
            _buildStealthTuningCard('MINIMUM RPM', state.minRpmActive.round().toString(), 'RPM'),
            const SizedBox(height: 16),
            _buildStealthCalibrationSelector(state),
            
            const SizedBox(height: 32),
            _buildSectionHeader('KILL TIME MATRIX'),
            const SizedBox(height: 20),
            _buildStealthKillMatrix(state),
            
            const SizedBox(height: 40),
            
            // Write Button
            GestureDetector(
              onTap: () => state.saveSettings(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.3), blurRadius: 20)],
                ),
                child: Center(
                  child: Text('WRITE TO MODULE', 
                    style: GoogleFonts.orbitron(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 14, color: const Color(0xFFEF4444)),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white.withOpacity(0.5))),
      ],
    );
  }

  Widget _buildStealthTuningCard(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 8, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Text(unit, style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 10)),
                ],
              ),
            ],
          ),
          const Icon(Icons.tune, size: 20, color: Colors.white10),
        ],
      ),
    );
  }

  Widget _buildStealthCalibrationSelector(AppState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RPM CALIBRATION', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 8, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [0.8, 1.0, 1.2, 1.5].map((v) {
              bool selected = state.rpmCalibration == v;
              return Expanded(
                child: GestureDetector(
                  onTap: () => state.setRpmCalibration(v),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFEF4444) : Colors.black,
                      border: Border.all(color: selected ? Colors.transparent : Colors.white.withOpacity(0.05)),
                    ),
                    child: Text('${v}x', textAlign: TextAlign.center, style: TextStyle(color: selected ? Colors.white : Colors.white.withOpacity(0.2), fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStealthKillMatrix(AppState state) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.white.withOpacity(0.02),
            child: Row(
              children: [
                const Expanded(child: Text('STAGE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white30))),
                const Expanded(flex: 2, child: Text('RPM THRESHOLD', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white30))),
                const Expanded(child: Text('KILL (MS)', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white30))),
              ],
            ),
          ),
          // Table Rows
          ...List.generate(4, (i) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
              ),
              child: Row(
                children: [
                  Expanded(child: Text('S${i+1}', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900, fontSize: 12))),
                  Expanded(flex: 2, child: Text(state.tableRpm[i].toString(), style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 14))),
                  Expanded(child: Text(state.tableKill[i].toString(), style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF00FF00)))),
                ],
              ),
            );
          }),
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('RACEBOX GPS', style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.white.withOpacity(0.05), height: 1),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Main Timer Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  Text('SESSION TIMER', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 16),
                  Text(state.raceTime.toStringAsFixed(2), 
                    style: GoogleFonts.jetBrainsMono(fontSize: 80, fontWeight: FontWeight.w900, letterSpacing: -4)
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStealthRaceButton('START', const Color(0xFF00FF00), () {}),
                      const SizedBox(width: 12),
                      _buildStealthRaceButton('RESET', Colors.white.withOpacity(0.05), () {}),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Metrics Header
            Row(
              children: [
                Container(width: 4, height: 14, color: const Color(0xFFEF4444)),
                const SizedBox(width: 10),
                Text('PERFORMANCE METRICS', style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white.withOpacity(0.5))),
              ],
            ),
            const SizedBox(height: 20),
            
            _buildStealthMetricRow('0-100 KM/H', '-- s'),
            _buildStealthMetricRow('201 METER', '-- s'),
            _buildStealthMetricRow('402 METER', '-- s'),
          ],
        ),
      ),
    );
  }

  Widget _buildStealthRaceButton(String label, Color color, VoidCallback onTap) {
    bool isAction = color != Colors.white.withOpacity(0.05);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(label, 
        style: TextStyle(
          fontWeight: FontWeight.w900, 
          fontSize: 10, 
          letterSpacing: 1,
          color: isAction ? Colors.black : Colors.white
        )
      ),
    );
  }

  Widget _buildStealthMetricRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.3), fontWeight: FontWeight.bold, fontSize: 10)),
          Text(value, style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 20, color: const Color(0xFFEF4444))),
        ],
      ),
    );
  }
}
