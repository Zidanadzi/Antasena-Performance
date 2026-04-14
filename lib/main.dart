import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;
import 'package:intl/intl.dart';
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
  List<int> _tableRpm = [3000, 6000, 9000, 12000];
  List<int> _tableKill = [95, 85, 75, 65];
  
  // Connection
  bool _isConnected = false;
  bool _isScanning = false;
  String? _deviceName;
  classic.BluetoothConnection? _classicConnection;
  List<classic.BluetoothDevice> _classicDevices = [];
  
  // Racebox
  double _raceTime = 0;
  double _raceDistance = 0;
  String _raceStatus = 'IDLE'; // IDLE, RUNNING, FINISHED
  Timer? _raceTimer;
  
  // Performance Metrics
  double? _zeroToHundred;
  double? _twoHundredMeter;
  double? _fourHundredMeter;
  
  // Simulation / Demo Mode
  bool _isDemoMode = false;
  Timer? _demoTimer;
  
  // GPS Data
  double _gpsAccuracy = 0;
  
  // Race History & Real-time Data
  List<RaceRecord> _history = [];
  List<DataPoint> _currentRaceData = [];
  
  // Getters
  int get rpm => _rpm;
  double get speed => _speed;
  double get minRpmActive => _minRpmActive;
  double get rpmCalibration => _rpmCalibration;
  List<int> get tableRpm => _tableRpm;
  List<int> get tableKill => _tableKill;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  String? get deviceName => _deviceName;
  List<classic.BluetoothDevice> get classicDevices => _classicDevices;
  double get raceTime => _raceTime;
  String get raceStatus => _raceStatus;
  bool get isDemoMode => _isDemoMode;
  double? get zeroToHundred => _zeroToHundred;
  double? get twoHundredMeter => _twoHundredMeter;
  double? get fourHundredMeter => _fourHundredMeter;
  double get gpsAccuracy => _gpsAccuracy;
  List<RaceRecord> get history => _history;
  List<DataPoint> get currentRaceData => _currentRaceData;

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

  void setConnected(bool val, {String? name}) {
    _isConnected = val;
    _deviceName = val ? name : null;
    _isScanning = false;
    notifyListeners();
  }

  void setScanning(bool val) {
    _isScanning = val;
    if (val) _isConnected = false;
    notifyListeners();
  }

  Future<void> startClassicScan() async {
    // Check if Bluetooth is enabled
    bool? isEnabled = await classic.FlutterBluetoothSerial.instance.isEnabled;
    if (isEnabled == false) {
      await classic.FlutterBluetoothSerial.instance.requestEnable();
    }

    _isScanning = true;
    _classicDevices = [];
    notifyListeners();

    try {
      // Get bonded devices first (HC-05 is usually paired manually in Android settings)
      _classicDevices = await classic.FlutterBluetoothSerial.instance.getBondedDevices();
      notifyListeners();
      
      // Also start discovery for new devices
      classic.FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
        final existingIndex = _classicDevices.indexWhere((element) => element.address == r.device.address);
        if (existingIndex >= 0) {
          _classicDevices[existingIndex] = r.device;
        } else {
          _classicDevices.add(r.device);
        }
        notifyListeners();
      });

      Future.delayed(const Duration(seconds: 10), () {
        _isScanning = false;
        notifyListeners();
      });
    } catch (e) {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> connectToClassic(classic.BluetoothDevice device) async {
    try {
      _isScanning = false;
      _classicConnection = await classic.BluetoothConnection.toAddress(device.address);
      _isConnected = true;
      _deviceName = device.name ?? device.address;
      
      _classicConnection!.input!.listen((Uint8List data) {
        // Handle incoming data from HC-05 here
        // Example: Parsing RPM data sent as string
        String msg = String.fromCharCodes(data);
        if (msg.contains('RPM:')) {
          int? val = int.tryParse(msg.split(':')[1].trim());
          if (val != null) updateRpm(val);
        }
      }).onDone(() {
        _isConnected = false;
        _deviceName = null;
        notifyListeners();
      });
      
      notifyListeners();
    } catch (e) {
      _isConnected = false;
      notifyListeners();
    }
  }

  void disconnectClassic() {
    _classicConnection?.dispose();
    _classicConnection = null;
    _isConnected = false;
    _deviceName = null;
    notifyListeners();
  }

  void updateRaceTime(double val) {
    _raceTime = val;
    notifyListeners();
  }

  void setRaceStatus(String status) {
    _raceStatus = status;
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

  void setTableRpm(int index, int val) {
    _tableRpm[index] = val;
    notifyListeners();
  }

  void setTableKill(int index, int val) {
    _tableKill[index] = val;
    notifyListeners();
  }

  void toggleDemoMode() {
    _isDemoMode = !_isDemoMode;
    if (_isDemoMode) {
      _demoTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        // Simulate RPM sweep
        _rpm = (_rpm + 500) % 14000;
        // Simulate Speed
        if (_rpm > 10000) _speed = (_speed + 2) % 200;
        notifyListeners();
      });
    } else {
      _demoTimer?.cancel();
      _rpm = 0;
      _speed = 0;
    }
    notifyListeners();
  }

  void startRace() {
    if (_raceStatus == 'RUNNING') return;
    
    _raceTime = 0;
    _raceDistance = 0;
    _raceStatus = 'RUNNING';
    _zeroToHundred = null;
    _twoHundredMeter = null;
    _fourHundredMeter = null;
    _currentRaceData = [];
    
    _raceTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _raceTime += 0.1;
      
      // Calculate distance (Speed is in km/h, convert to m/s)
      double metersPerSecond = _speed / 3.6;
      _raceDistance += metersPerSecond * 0.1;

      // Capture data point for graph
      _currentRaceData.add(DataPoint(
        time: _raceTime,
        speed: _speed,
        rpm: _rpm.toDouble(),
      ));
      
      // Mock performance tracking
      if (_speed >= 100 && _zeroToHundred == null) {
        _zeroToHundred = _raceTime;
      }
      
      if (_raceDistance >= 201 && _twoHundredMeter == null) {
        _twoHundredMeter = _raceTime;
      }
      
      if (_raceDistance >= 402 && _fourHundredMeter == null) {
        _fourHundredMeter = _raceTime;
        stopRace();
      }
      
      notifyListeners();
    });
    notifyListeners();
  }

  void stopRace() {
    _raceTimer?.cancel();
    if (_raceStatus == 'RUNNING') {
      _raceStatus = 'FINISHED';
      // Save to history
      _history.insert(0, RaceRecord(
        date: DateTime.now(),
        time: _raceTime,
        topSpeed: _currentRaceData.isEmpty ? 0 : _currentRaceData.map((e) => e.speed).reduce((a, b) => a > b ? a : b),
        zeroToHundred: _zeroToHundred,
        twoHundredMeter: _twoHundredMeter,
        fourHundredMeter: _fourHundredMeter,
        dataPoints: List.from(_currentRaceData),
      ));
    }
    notifyListeners();
  }

  void resetRace() {
    _raceTimer?.cancel();
    _raceTime = 0;
    _raceDistance = 0;
    _raceStatus = 'IDLE';
    _zeroToHundred = null;
    _twoHundredMeter = null;
    _fourHundredMeter = null;
    _currentRaceData = [];
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
      _gpsAccuracy = position.accuracy;
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

// --- MODELS ---
class DataPoint {
  final double time;
  final double speed;
  final double rpm;

  DataPoint({required this.time, required this.speed, required this.rpm});
}

class RaceRecord {
  final DateTime date;
  final double time;
  final double topSpeed;
  final double? zeroToHundred;
  final double? twoHundredMeter;
  final double? fourHundredMeter;
  final List<DataPoint> dataPoints;

  RaceRecord({
    required this.date,
    required this.time,
    required this.topSpeed,
    this.zeroToHundred,
    this.twoHundredMeter,
    this.fourHundredMeter,
    required this.dataPoints,
  });
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
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  final List<Widget> _pages = [
    const DashboardPage(),
    const TuningPage(),
    const RaceboxPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            _pageController.animateToPage(
              i, 
              duration: const Duration(milliseconds: 400), 
              curve: Curves.easeInOutCubic
            );
          },
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
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => state.toggleDemoMode(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: state.isDemoMode ? const Color(0xFFEF4444) : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text('DEMO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: state.isDemoMode ? Colors.white : Colors.white.withOpacity(0.2))),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusIndicator(context, state, isShiftPoint),
                        ],
                      ),
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

  Widget _buildStatusIndicator(BuildContext context, AppState state, bool isShiftPoint) {
    return ConnectionStatusIndicator(
      isConnected: state.isConnected,
      isScanning: state.isScanning,
      deviceName: state.deviceName,
      isShiftPoint: isShiftPoint,
      onTap: () => _showBluetoothMock(context, state),
    );
  }

  void _showBluetoothMock(BuildContext context, AppState state) {
    if (!state.isConnected) {
      state.startClassicScan();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0A0A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BLUETOOTH SCANNER', style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      const SizedBox(height: 4),
                      Text('Classic (HC-05) & BLE Support', style: TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.2), letterSpacing: 1)),
                    ],
                  ),
                  if (!state.isScanning && !state.isConnected)
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20, color: Color(0xFFEF4444)),
                      onPressed: () => state.startClassicScan(),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (state.isScanning)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF4444)),
                      ),
                      const SizedBox(width: 16),
                      Text('SCANNING FOR DEVICES...', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444), letterSpacing: 1)),
                    ],
                  ),
                ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (state.isConnected) ...[
                      _buildDeviceTile(state.deviceName ?? 'DEVICE', 'CONNECTED', true, () {
                        state.disconnectClassic();
                        Navigator.pop(context);
                      }),
                    ] else ...[
                      // Bonded/Paired Devices (HC-05 usually here)
                      if (state.classicDevices.isNotEmpty) ...[
                        Text('AVAILABLE DEVICES', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.3), letterSpacing: 1)),
                        const SizedBox(height: 12),
                        ...state.classicDevices.map((device) => _buildDeviceTile(
                          device.name ?? 'Unknown Device', 
                          device.address, 
                          false, 
                          () {
                            state.connectToClassic(device);
                            Navigator.pop(context);
                          }
                        )),
                      ] else if (!state.isScanning) ...[
                        const SizedBox(height: 60),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.02),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.bluetooth_disabled, color: Colors.white10, size: 48),
                              ),
                              const SizedBox(height: 20),
                              const Text('NO DEVICES FOUND', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white24, letterSpacing: 2)),
                              const SizedBox(height: 8),
                              Text('Make sure your device is in pairing mode', style: TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.1))),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceTile(String name, String status, bool connected, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(status, style: TextStyle(fontSize: 10, color: connected ? const Color(0xFF00FF00) : Colors.white24)),
      trailing: Icon(connected ? Icons.bluetooth_connected : Icons.bluetooth, color: connected ? const Color(0xFF00FF00) : Colors.white10),
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

class ConnectionStatusIndicator extends StatefulWidget {
  final bool isConnected;
  final bool isScanning;
  final String? deviceName;
  final bool isShiftPoint;
  final VoidCallback onTap;

  const ConnectionStatusIndicator({
    super.key,
    required this.isConnected,
    required this.isScanning,
    this.deviceName,
    required this.isShiftPoint,
    required this.onTap,
  });

  @override
  State<ConnectionStatusIndicator> createState() => _ConnectionStatusIndicatorState();
}

class _ConnectionStatusIndicatorState extends State<ConnectionStatusIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 2.0, end: 8.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = const Color(0xFFFF0000); // Red
    String statusText = 'DISCONNECTED';
    
    if (widget.isConnected) {
      statusColor = const Color(0xFF00FF00); // Green
      statusText = widget.deviceName ?? 'CONNECTED';
    } else if (widget.isScanning) {
      statusColor = const Color(0xFFFFFF00); // Yellow
      statusText = 'SCANNING...';
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: widget.isShiftPoint ? Colors.black.withOpacity(0.1) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: widget.isShiftPoint ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                bool shouldPulse = widget.isScanning || widget.isConnected;
                return Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.6),
                        blurRadius: shouldPulse ? _pulseAnimation.value : 4,
                        spreadRadius: shouldPulse ? _pulseAnimation.value / 4 : 0,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(statusText.toUpperCase(), 
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8, 
                  fontWeight: FontWeight.w900, 
                  color: widget.isShiftPoint ? Colors.black : Colors.white,
                  letterSpacing: 0.5,
                )
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TUNING PAGE ---
class TuningPage extends StatefulWidget {
  const TuningPage({super.key});

  @override
  State<TuningPage> createState() => _TuningPageState();
}

class _TuningPageState extends State<TuningPage> {
  int? _editingKillIndex;
  int? _editingRpmIndex;

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
            
            GestureDetector(
              onTap: () => _showEditDialog(context, 'MINIMUM RPM', state.minRpmActive.round().toString(), (val) {
                state.setMinRpm(double.tryParse(val) ?? 3000);
              }),
              child: _buildStealthTuningCard('MINIMUM RPM', state.minRpmActive.round().toString(), 'RPM'),
            ),
            const SizedBox(height: 16),
            _buildStealthCalibrationSelector(state),
            
            const SizedBox(height: 32),
            _buildSectionHeader('KILL TIME MATRIX'),
            const SizedBox(height: 20),
            _buildStealthKillMatrix(context, state),
            
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 6),
                  Text(unit, style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.tune, size: 20, color: Color(0xFFEF4444)),
          ),
        ],
      ),
    );
  }

  Widget _buildStealthCalibrationSelector(AppState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RPM CALIBRATION', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 16),
          Row(
            children: [0.8, 1.0, 1.2, 1.5].map((v) {
              bool selected = state.rpmCalibration == v;
              return Expanded(
                child: GestureDetector(
                  onTap: () => state.setRpmCalibration(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFEF4444) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: selected ? const Color(0xFFEF4444) : Colors.white.withOpacity(0.05),
                        width: 1,
                      ),
                      boxShadow: [
                        if (selected)
                          BoxShadow(
                            color: const Color(0xFFEF4444).withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                    child: Text(
                      '${v}x', 
                      textAlign: TextAlign.center, 
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white.withOpacity(0.3), 
                        fontWeight: FontWeight.w900, 
                        fontSize: 12,
                        letterSpacing: 0.5,
                      )
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStealthKillMatrix(BuildContext context, AppState state) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            color: Colors.white.withOpacity(0.03),
            child: const Row(
              children: [
                Expanded(child: Text('STAGE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white24, letterSpacing: 1))),
                Expanded(flex: 2, child: Text('RPM THRESHOLD', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white24, letterSpacing: 1))),
                Expanded(child: Text('KILL (MS)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white24, letterSpacing: 1))),
              ],
            ),
          ),
          // Table Rows
          ...List.generate(4, (i) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('S${i+1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                      ],
                    )
                  ),
                  Expanded(
                    flex: 2, 
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _editingRpmIndex = i);
                        _showEditDialog(context, 'RPM THRESHOLD S${i+1}', state.tableRpm[i].toString(), (val) {
                          state.setTableRpm(i, int.tryParse(val) ?? 0);
                        }, onDismiss: () => setState(() => _editingRpmIndex = null));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          state.tableRpm[i].toString(), 
                          style: GoogleFonts.jetBrainsMono(
                            fontWeight: FontWeight.bold, 
                            fontSize: 16,
                            color: _editingRpmIndex == i ? const Color(0xFFFFFFFF) : Colors.white.withOpacity(0.9),
                            shadows: _editingRpmIndex == i ? [
                              const Shadow(color: Colors.white, blurRadius: 10),
                            ] : null,
                          )
                        ),
                      )
                    )
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _editingKillIndex = i);
                        _showEditDialog(context, 'KILL TIME S${i+1}', state.tableKill[i].toString(), (val) {
                          state.setTableKill(i, int.tryParse(val) ?? 0);
                        }, onDismiss: () => setState(() => _editingKillIndex = null));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        alignment: Alignment.centerRight,
                        child: Text(
                          state.tableKill[i].toString(), 
                          style: GoogleFonts.jetBrainsMono(
                            fontWeight: FontWeight.w900, 
                            fontSize: 16, 
                            color: _editingKillIndex == i ? const Color(0xFF66FF66) : const Color(0xFF00FF00),
                            shadows: _editingKillIndex == i ? [
                              const Shadow(color: Color(0xFF00FF00), blurRadius: 15),
                            ] : null,
                          )
                        ),
                      )
                    )
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, String title, String current, Function(String) onSave, {VoidCallback? onDismiss}) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        title: Text(title, style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: GoogleFonts.jetBrainsMono(),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFEF4444))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.white24))),
          TextButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            }, 
            child: const Text('SAVE', style: TextStyle(color: Color(0xFFEF4444)))
          ),
        ],
      ),
    ).then((_) {
      if (onDismiss != null) onDismiss();
    });
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
        actions: [
          _buildGpsIndicator(state.gpsAccuracy),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.white.withOpacity(0.05), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Main Timer Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  Text('SESSION TIMER', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 12),
                  Text(state.raceTime.toStringAsFixed(2), 
                    style: GoogleFonts.jetBrainsMono(fontSize: 72, fontWeight: FontWeight.w900, letterSpacing: -4)
                  ),
                  
                  // Real-time Graph
                  if (state.currentRaceData.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      height: 100,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: CustomPaint(
                        painter: RaceGraphPainter(state.currentRaceData),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStealthRaceButton(
                        state.raceStatus == 'RUNNING' ? 'STOP' : 'START', 
                        state.raceStatus == 'RUNNING' ? const Color(0xFFEF4444) : const Color(0xFF00FF00), 
                        () => state.raceStatus == 'RUNNING' ? state.stopRace() : state.startRace()
                      ),
                      const SizedBox(width: 12),
                      _buildStealthRaceButton('RESET', Colors.white.withOpacity(0.05), () => state.resetRace()),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Performance Metrics Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF080808),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.03)),
              ),
              child: Column(
                children: [
                  // Metrics Header
                  Row(
                    children: [
                      Container(width: 4, height: 14, color: const Color(0xFFEF4444)),
                      const SizedBox(width: 10),
                      Text('CURRENT SESSION', style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white.withOpacity(0.5))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  _buildStealthMetricRow('0-100 KM/H', state.zeroToHundred != null ? '${state.zeroToHundred!.toStringAsFixed(2)} s' : '-- s'),
                  _buildStealthMetricRow('201 METER', state.twoHundredMeter != null ? '${state.twoHundredMeter!.toStringAsFixed(2)} s' : '-- s'),
                  _buildStealthMetricRow('402 METER', state.fourHundredMeter != null ? '${state.fourHundredMeter!.toStringAsFixed(2)} s' : '-- s'),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // History Section
            if (state.history.isNotEmpty) ...[
              Row(
                children: [
                  Container(width: 4, height: 14, color: Colors.blue),
                  const SizedBox(width: 10),
                  Text('RACE HISTORY', style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white.withOpacity(0.5))),
                ],
              ),
              const SizedBox(height: 16),
              ...state.history.map((record) => _buildHistoryCard(context, record)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStealthRaceButton(String label, Color color, VoidCallback onTap) {
    bool isAction = color != Colors.white.withOpacity(0.05);
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }

  Widget _buildStealthMetricRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
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

  Widget _buildGpsIndicator(double accuracy) {
    Color color;
    IconData icon;
    String quality;

    if (accuracy == 0) {
      color = Colors.white24;
      icon = Icons.gps_off;
      quality = 'NO FIX';
    } else if (accuracy < 5) {
      color = const Color(0xFF00FF00); // Excellent
      icon = Icons.gps_fixed;
      quality = 'EXCELLENT';
    } else if (accuracy < 15) {
      color = const Color(0xFFFFFF00); // Good
      icon = Icons.gps_fixed;
      quality = 'GOOD';
    } else {
      color = const Color(0xFFEF4444); // Poor
      icon = Icons.gps_not_fixed;
      quality = 'POOR';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(quality, style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            Text('${accuracy.round()}m', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(width: 8),
        Icon(icon, color: color, size: 16),
      ],
    );
  }

  Widget _buildHistoryCard(BuildContext context, RaceRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('MMM dd, HH:mm').format(record.date), style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold)),
              Text('${record.time.toStringAsFixed(2)}s', style: GoogleFonts.jetBrainsMono(color: const Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric('TOP', '${record.topSpeed.round()}'),
              _buildMiniMetric('0-100', record.zeroToHundred != null ? record.zeroToHundred!.toStringAsFixed(1) : '--'),
              _buildMiniMetric('201M', record.twoHundredMeter != null ? record.twoHundredMeter!.toStringAsFixed(1) : '--'),
              _buildMiniMetric('402M', record.fourHundredMeter != null ? record.fourHundredMeter!.toStringAsFixed(1) : '--'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 7, fontWeight: FontWeight.bold)),
        Text(value, style: GoogleFonts.jetBrainsMono(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class RaceGraphPainter extends CustomPainter {
  final List<DataPoint> data;
  RaceGraphPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paintSpeed = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintRpm = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final maxSpeed = data.map((e) => e.speed).reduce((a, b) => a > b ? a : b).clamp(100.0, 300.0);
    final maxRpm = data.map((e) => e.rpm).reduce((a, b) => a > b ? a : b).clamp(10000.0, 16000.0);
    final maxTime = data.last.time;

    final pathSpeed = Path();
    final pathRpm = Path();

    for (int i = 0; i < data.length; i++) {
      double x = (data[i].time / maxTime) * size.width;
      double ySpeed = size.height - (data[i].speed / maxSpeed) * size.height;
      double yRpm = size.height - (data[i].rpm / maxRpm) * size.height;

      if (i == 0) {
        pathSpeed.moveTo(x, ySpeed);
        pathRpm.moveTo(x, yRpm);
      } else {
        pathSpeed.lineTo(x, ySpeed);
        pathRpm.lineTo(x, yRpm);
      }
    }

    canvas.drawPath(pathRpm, paintRpm);
    canvas.drawPath(pathSpeed, paintSpeed);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
