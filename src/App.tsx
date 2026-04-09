import React, { useState, useEffect, useRef } from 'react';
import { View, Text, TouchableOpacity, ScrollView, TextInput, Switch, Modal, SafeAreaView, StatusBar, Platform, Dimensions, Alert, BackHandler, PermissionsAndroid } from 'react-native';
import { Bluetooth, BluetoothConnected, Settings2, Gauge, Zap, Save, RefreshCw, Activity, Power, Timer, MapPin, Flag, TrendingUp, Play, Square, RotateCcw, LogOut, Trash2 } from 'lucide-react-native';
import tw from 'twrnc';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Location from 'expo-location';
import { BleManager } from 'react-native-ble-plx';

const { width } = Dimensions.get('window');
const bleManager = new BleManager();

export default function App() {
  const [isConnected, setIsConnected] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [activeTab, setActiveTab] = useState('cut time');
  const [showPermissionModal, setShowPermissionModal] = useState(false);
  const [permissions, setPermissions] = useState({ location: 'prompt' });

  // Racebox State
  const [raceMode, setRaceMode] = useState<'metric' | 'imperial'>('metric');
  const [raceStatus, setRaceStatus] = useState<'idle' | 'running' | 'stopped'>('idle');
  const [raceTime, setRaceTime] = useState(0);
  const [runMetrics, setRunMetrics] = useState({
    metric: { '18m': null, '0-100': null, '201m': null, '402m': null },
    imperial: { '60ft': null, '0-60': null, '1/8': null, '1/4': null }
  });

  const [shortHistory, setShortHistory] = useState([
    { run: 4, time: '6.80s', speedMetric: '165 km/h', speedImperial: '102 mph', diff: '-0.10s', better: true },
    { run: 3, time: '6.90s', speedMetric: '163 km/h', speedImperial: '101 mph', diff: '+0.05s', better: false },
    { run: 2, time: '6.85s', speedMetric: '164 km/h', speedImperial: '101 mph', diff: '-0.20s', better: true },
    { run: 1, time: '7.05s', speedMetric: '160 km/h', speedImperial: '99 mph', diff: '--', better: null },
  ]);

  const [longHistory, setLongHistory] = useState([
    { run: 4, time: '10.21s', speedMetric: '215 km/h', speedImperial: '133 mph', diff: '-0.15s', better: true },
    { run: 3, time: '10.36s', speedMetric: '212 km/h', speedImperial: '131 mph', diff: '+0.05s', better: false },
    { run: 2, time: '10.31s', speedMetric: '213 km/h', speedImperial: '132 mph', diff: '-0.40s', better: true },
    { run: 1, time: '10.71s', speedMetric: '208 km/h', speedImperial: '129 mph', diff: '--', better: null },
  ]);

  // Mock Telemetry
  const [rpm, setRpm] = useState(0);
  const [speed, setSpeed] = useState(0);

  // Settings State
  const [killTimes, setKillTimes] = useState([
    { id: 1, rpm: 4000, time: 75 },
    { id: 2, rpm: 7000, time: 65 },
    { id: 3, rpm: 10000, time: 55 },
    { id: 4, rpm: 13000, time: 50 },
  ]);
  const [minRpm, setMinRpm] = useState(3000);
  const [sensitivity, setSensitivity] = useState(60);

  // Load Settings
  useEffect(() => {
    const loadSettings = async () => {
      try {
        const savedKillTimes = await AsyncStorage.getItem('antasena_killTimes');
        if (savedKillTimes) setKillTimes(JSON.parse(savedKillTimes));
        const savedMinRpm = await AsyncStorage.getItem('antasena_minRpm');
        if (savedMinRpm) setMinRpm(parseInt(savedMinRpm, 10));
        const savedSensitivity = await AsyncStorage.getItem('antasena_sensitivity');
        if (savedSensitivity) setSensitivity(parseInt(savedSensitivity, 10));
      } catch (e) {
        console.error("Failed to load settings", e);
      }
    };
    loadSettings();
  }, []);

  // Auto-save settings
  useEffect(() => {
    AsyncStorage.setItem('antasena_killTimes', JSON.stringify(killTimes));
  }, [killTimes]);

  useEffect(() => {
    AsyncStorage.setItem('antasena_minRpm', minRpm.toString());
  }, [minRpm]);

  useEffect(() => {
    AsyncStorage.setItem('antasena_sensitivity', sensitivity.toString());
  }, [sensitivity]);

  // Permissions & Initialization
  useEffect(() => {
    const initApp = async () => {
      let { status: locStatus } = await Location.getForegroundPermissionsAsync();
      
      let btStatus = 'undetermined';
      if (Platform.OS === 'android') {
        const hasBtConnect = await PermissionsAndroid.check(PermissionsAndroid.PERMISSIONS.BLUETOOTH_CONNECT);
        const hasBtScan = await PermissionsAndroid.check(PermissionsAndroid.PERMISSIONS.BLUETOOTH_SCAN);
        btStatus = (hasBtConnect && hasBtScan) ? 'granted' : 'denied';
      }

      setPermissions({ location: locStatus, bluetooth: btStatus });
      
      if (locStatus === 'granted' && (Platform.OS !== 'android' || btStatus === 'granted')) {
        // Automatically "connect" and ensure GPS/BT is on
        setIsConnected(true);
        try {
          if (Platform.OS === 'android') {
            await Location.enableNetworkProviderAsync();
            await bleManager.enable();
          }
        } catch (e) {
          console.log("Services activation error or already enabled");
        }
      } else {
        setShowPermissionModal(true);
      }
    };
    
    initApp();
  }, []);

  const requestPermissions = async () => {
    try {
      // 1. Request Location
      let { status: locStatus } = await Location.requestForegroundPermissionsAsync();
      
      // 2. Request Bluetooth (Android 12+)
      let btStatus = 'granted';
      if (Platform.OS === 'android' && Platform.Version >= 31) {
        const result = await PermissionsAndroid.requestMultiple([
          PermissionsAndroid.PERMISSIONS.BLUETOOTH_SCAN,
          PermissionsAndroid.PERMISSIONS.BLUETOOTH_CONNECT,
          PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
        ]);
        
        const allGranted = result['android.permission.BLUETOOTH_SCAN'] === PermissionsAndroid.RESULTS.GRANTED &&
                           result['android.permission.BLUETOOTH_CONNECT'] === PermissionsAndroid.RESULTS.GRANTED;
        btStatus = allGranted ? 'granted' : 'denied';
      }

      setPermissions({ location: locStatus, bluetooth: btStatus });
      
      if (locStatus === 'granted' && btStatus === 'granted') {
        setIsConnected(true);
        try {
          if (Platform.OS === 'android') {
            await Location.enableNetworkProviderAsync();
            await bleManager.enable();
          }
        } catch (e) {
          console.log("Services activation error");
        }
      }
    } catch (err) {
      console.warn(err);
    } finally {
      setShowPermissionModal(false);
    }
  };

  // Simulation Logic (DISABLED DEMO MODE)
  useEffect(() => {
    if (!isConnected) {
      setRpm(0);
      setSpeed(0);
    }
    // Real data would be handled via Bluetooth connection
  }, [isConnected]);

  const [locationSubscription, setLocationSubscription] = useState<Location.LocationSubscription | null>(null);
  const startLocation = useRef<Location.LocationObject | null>(null);
  const lastLocation = useRef<Location.LocationObject | null>(null);
  const totalDistance = useRef(0);

  // Haversine formula to calculate distance between two points in meters
  const getDistance = (lat1: number, lon1: number, lat2: number, lon2: number) => {
    const R = 6371e3; // metres
    const φ1 = lat1 * Math.PI/180;
    const φ2 = lat2 * Math.PI/180;
    const Δφ = (lat2-lat1) * Math.PI/180;
    const Δλ = (lon2-lon1) * Math.PI/180;

    const a = Math.sin(Δφ/2) * Math.sin(Δφ/2) +
              Math.cos(φ1) * Math.cos(φ2) *
              Math.sin(Δλ/2) * Math.sin(Δλ/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));

    return R * c;
  };

  // Main GPS Tracking
  useEffect(() => {
    let sub: Location.LocationSubscription | null = null;
    
    const startWatching = async () => {
      if (permissions.location !== 'granted') return;
      
      sub = await Location.watchPositionAsync(
        {
          accuracy: Location.Accuracy.BestForNavigation,
          timeInterval: 100,
          distanceInterval: 0,
        },
        (location) => {
          const speedMs = location.coords.speed || 0;
          const speedKmh = Math.max(0, speedMs * 3.6);
          setSpeed(Math.round(speedKmh));

          if (raceStatus === 'running') {
            if (!startLocation.current) {
              startLocation.current = location;
              lastLocation.current = location;
              totalDistance.current = 0;
            } else if (lastLocation.current) {
              const d = getDistance(
                lastLocation.current.coords.latitude,
                lastLocation.current.coords.longitude,
                location.coords.latitude,
                location.coords.longitude
              );
              totalDistance.current += d;
              lastLocation.current = location;

              const currentDist = totalDistance.current;
              const currentTime = Date.now() - (raceTimeStart.current || Date.now());
              const speedMph = speedKmh * 0.621371;
              const distanceFt = currentDist * 3.28084;

              setRunMetrics(prev => {
                const next = { ...prev };
                let updated = false;
                const check = (val: number, limit: number, key: string, type: 'metric' | 'imperial', label: string) => {
                  if (!next[type][key] && val >= limit) {
                    next[type][key] = { 
                      time: (currentTime/1000).toFixed(2) + 's', 
                      speed: Math.round(type === 'metric' ? speedKmh : speedMph) + (type === 'metric' ? ' km/h' : ' mph') 
                    };
                    updated = true;
                    if (label === 'finish') setRaceStatus('stopped');
                  }
                };

                // Metric Checks
                check(currentDist, 18, '18m', 'metric', '');
                check(speedKmh, 100, '0-100', 'metric', '');
                check(currentDist, 201, '201m', 'metric', '');
                check(currentDist, 402, '402m', 'metric', 'finish');

                // Imperial Checks
                check(distanceFt, 60, '60ft', 'imperial', '');
                check(speedMph, 60, '0-60', 'imperial', '');
                check(distanceFt, 660, '1/8', 'imperial', '');
                check(distanceFt, 1320, '1/4', 'imperial', 'finish');

                return updated ? { ...next } : prev;
              });
            }
          }
        }
      );
      setLocationSubscription(sub);
    };

    startWatching();

    return () => {
      if (sub) sub.remove();
    };
  }, [permissions.location, raceStatus]);

  const raceTimeStart = useRef<number | null>(null);

  useEffect(() => {
    let interval: any;
    if (raceStatus === 'running') {
      if (!raceTimeStart.current) raceTimeStart.current = Date.now() - raceTime;
      interval = setInterval(() => {
        setRaceTime(Date.now() - (raceTimeStart.current || Date.now()));
      }, 10);
    } else {
      raceTimeStart.current = null;
      startLocation.current = null;
      lastLocation.current = null;
    }
    return () => clearInterval(interval);
  }, [raceStatus]);

  const handleSave = () => {
    setIsSaving(true);
    setTimeout(() => setIsSaving(false), 800);
  };

  const MAX_RPM = 14000;
  const SEGMENTS = 30;
  const RPM_PER_SEGMENT = MAX_RPM / SEGMENTS;
  const isShiftLightActive = rpm > 12500;

  const renderMetricRow = (label: string, data: any) => (
    <View style={tw`flex-row items-center justify-between p-3 rounded bg-neutral-900 border border-neutral-800 mb-2`}>
      <Text style={tw`font-bold text-neutral-300 text-xs`}>{label}</Text>
      <View style={tw`flex-row items-center`}>
        <Text style={tw`text-[10px] text-neutral-500 font-mono mr-3`}>{data?.speed || '--'}</Text>
        <Text style={tw`font-mono font-bold text-white text-sm`}>{data?.time || '--'}</Text>
      </View>
    </View>
  );

  return (
    <SafeAreaView style={tw`flex-1 bg-neutral-950`}>
      <StatusBar barStyle="light-content" />
      
      {/* Header */}
      <View style={tw`px-4 h-16 flex-row items-center justify-between border-b border-neutral-800`}>
        <View style={tw`flex-row items-center`}>
          <View style={tw`w-8 h-8 rounded bg-red-600 items-center justify-center mr-2`}>
            <Zap size={18} color="white" />
          </View>
          <View>
            <Text style={tw`text-sm font-bold italic text-white leading-tight`}>ANTASENA</Text>
            <Text style={tw`text-sm font-bold italic text-red-500 leading-tight`}>PERFORMANCE</Text>
          </View>
        </View>
        <View style={tw`flex-row items-center gap-2`}>
          <TouchableOpacity 
            onPress={async () => {
              if (!isConnected) {
                try {
                  if (Platform.OS === 'android') {
                    await Location.enableNetworkProviderAsync();
                    await bleManager.enable();
                  }
                  setIsConnected(true);
                } catch (e) {
                  Alert.alert("Connection Error", "Please ensure Bluetooth and Location are enabled.");
                }
              } else {
                setIsConnected(false);
              }
            }} 
            style={tw`px-3 py-2 rounded border ${isConnected ? 'bg-emerald-500/10 border-emerald-500/30' : 'bg-neutral-800 border-neutral-700'}`}
          >
            <Text style={tw`text-[10px] font-bold uppercase ${isConnected ? 'text-emerald-400' : 'text-neutral-400'}`}>
              {isConnected ? 'DISCONNECT' : 'CONNECT'}
            </Text>
          </TouchableOpacity>

          <TouchableOpacity 
            onPress={() => {
              Alert.alert(
                "Exit App",
                "Are you sure you want to exit Antasena Performance?",
                [
                  { text: "Cancel", style: "cancel" },
                  { text: "Exit", onPress: () => BackHandler.exitApp() }
                ]
              );
            }} 
            style={tw`w-10 h-10 items-center justify-center rounded border bg-neutral-800 border-neutral-700`}
          >
            <LogOut size={20} color="#ef4444" />
          </TouchableOpacity>
        </View>
      </View>

      <ScrollView style={tw`flex-1 px-4 py-4`} contentContainerStyle={tw`pb-24`}>
        {/* RPM Bar */}
        <View style={tw`bg-neutral-900 border-2 rounded-xl p-4 mb-4 ${isShiftLightActive ? 'border-red-500' : 'border-neutral-800'}`}>
          <View style={tw`flex-row gap-0.5 h-8 mb-4`}>
            {Array.from({ length: SEGMENTS }).map((_, i) => {
              const threshold = (i + 1) * RPM_PER_SEGMENT;
              const active = rpm >= threshold;
              let color = 'bg-neutral-800';
              if (active) color = threshold <= 8000 ? 'bg-emerald-500' : threshold <= 11500 ? 'bg-yellow-400' : 'bg-red-500';
              return <View key={i} style={tw`flex-1 rounded-sm ${color}`} />;
            })}
          </View>
          <View style={tw`items-center`}>
            <Text style={tw`text-neutral-500 text-[10px] font-bold uppercase mb-1`}>GPS SPEED (KM/H)</Text>
            <Text style={tw`font-mono text-6xl font-black text-white`}>{speed}</Text>
            <Text style={tw`text-neutral-500 text-[10px] font-bold uppercase mt-2`}>ENGINE RPM</Text>
            <Text style={tw`font-mono text-3xl font-bold text-neutral-300`}>{Math.floor(rpm).toLocaleString()}</Text>
          </View>
        </View>

        {/* Tabs */}
        <View style={tw`flex-row mb-4 bg-neutral-900 p-1 rounded-lg`}>
          {['cut time', 'sensor', 'racebox'].map(tab => (
            <TouchableOpacity key={tab} onPress={() => setActiveTab(tab)} style={tw`flex-1 py-2 items-center rounded ${activeTab === tab ? 'bg-neutral-800' : ''}`}>
              <Text style={tw`text-[10px] font-bold uppercase ${activeTab === tab ? 'text-red-500' : 'text-neutral-500'}`}>{tab}</Text>
            </TouchableOpacity>
          ))}
        </View>

        {/* Tab Content */}
        {activeTab === 'cut time' && (
          <View style={tw`bg-neutral-900 p-4 rounded-xl border border-neutral-800`}>
            <Text style={tw`text-white font-bold uppercase mb-4`}>Ignition Kill Times</Text>
            {killTimes.map(row => (
              <View key={row.id} style={tw`flex-row items-center justify-between mb-3 pb-3 border-b border-neutral-800/50`}>
                <View style={tw`flex-row items-center`}>
                  <TextInput 
                    keyboardType="numeric" 
                    value={row.rpm.toString()} 
                    onChangeText={v => setKillTimes(prev => prev.map(t => t.id === row.id ? {...t, rpm: parseInt(v)||0} : t))}
                    style={tw`bg-neutral-800 text-white px-3 py-2 rounded border border-neutral-700 font-mono w-24 text-sm mr-2`}
                  />
                  <Text style={tw`text-neutral-500 text-xs font-bold`}>RPM</Text>
                </View>
                <View style={tw`flex-row items-center`}>
                  <TextInput 
                    keyboardType="numeric" 
                    value={row.time.toString()} 
                    onChangeText={v => setKillTimes(prev => prev.map(t => t.id === row.id ? {...t, time: parseInt(v)||0} : t))}
                    style={tw`bg-neutral-800 text-red-400 px-3 py-2 rounded border border-neutral-700 font-mono w-16 text-sm mr-2`}
                  />
                  <Text style={tw`text-neutral-500 text-xs font-bold`}>ms</Text>
                </View>
              </View>
            ))}
          </View>
        )}

        {activeTab === 'sensor' && (
          <View style={tw`bg-neutral-900 p-4 rounded-xl border border-neutral-800`}>
            <Text style={tw`text-white font-bold uppercase mb-4`}>Global Parameters</Text>
            
            <View style={tw`flex-row items-center justify-between mb-3 pb-3 border-b border-neutral-800/50`}>
              <View style={tw`flex-row items-center`}>
                <Text style={tw`text-neutral-300 text-xs font-bold uppercase mr-3`}>Minimum RPM</Text>
              </View>
              <View style={tw`flex-row items-center`}>
                <TextInput 
                  keyboardType="numeric" 
                  value={minRpm.toString()} 
                  onChangeText={v => setMinRpm(parseInt(v) || 0)}
                  style={tw`bg-neutral-800 text-white px-3 py-2 rounded border border-neutral-700 font-mono w-24 text-sm mr-2`}
                />
                <Text style={tw`text-neutral-500 text-xs font-bold`}>RPM</Text>
              </View>
            </View>

            <View style={tw`flex-row items-center justify-between mb-3 pb-3 border-b border-neutral-800/50`}>
              <View style={tw`flex-row items-center`}>
                <Text style={tw`text-neutral-300 text-xs font-bold uppercase mr-3`}>Sensitivity</Text>
              </View>
              <View style={tw`flex-row items-center`}>
                <TextInput 
                  keyboardType="numeric" 
                  value={sensitivity.toString()} 
                  onChangeText={v => setSensitivity(parseInt(v) || 0)}
                  style={tw`bg-neutral-800 text-red-400 px-3 py-2 rounded border border-neutral-700 font-mono w-16 text-sm mr-2`}
                />
                <Text style={tw`text-neutral-500 text-xs font-bold`}>%</Text>
              </View>
            </View>
          </View>
        )}

        {activeTab === 'racebox' && (
          <View>
            <View style={tw`bg-neutral-950 border border-neutral-800 rounded-xl p-6 items-center mb-4`}>
              <Text style={tw`text-neutral-500 text-[10px] font-bold uppercase mb-2`}>{raceStatus === 'running' ? 'RECORDING...' : 'READY TO LAUNCH'}</Text>
              <Text style={tw`font-mono text-6xl font-black text-white`}>{(raceTime / 1000).toFixed(2)}s</Text>
              <View style={tw`flex-row mt-6 gap-3`}>
                <TouchableOpacity onPress={() => setRaceStatus(raceStatus === 'running' ? 'stopped' : 'running')} style={tw`px-6 py-3 rounded-lg ${raceStatus === 'running' ? 'bg-red-600' : 'bg-emerald-600'}`}>
                  <Text style={tw`text-white font-bold uppercase`}>{raceStatus === 'running' ? 'STOP' : 'START'}</Text>
                </TouchableOpacity>
                <TouchableOpacity onPress={() => {setRaceStatus('idle'); setRaceTime(0);}} style={tw`px-6 py-3 bg-neutral-800 rounded-lg`}>
                  <Text style={tw`text-white font-bold uppercase`}>RESET</Text>
                </TouchableOpacity>
              </View>
            </View>
            <View style={tw`bg-neutral-900 p-4 rounded-xl border border-neutral-800`}>
              <Text style={tw`text-neutral-400 font-bold uppercase text-xs mb-4`}>Latest Run Breakdown</Text>
              {raceMode === 'metric' ? (
                <>
                  {renderMetricRow('18m (60ft)', runMetrics.metric['18m'])}
                  {renderMetricRow('0 - 100 km/h', runMetrics.metric['0-100'])}
                  {renderMetricRow('201 Meter', runMetrics.metric['201m'])}
                  {renderMetricRow('402 Meter', runMetrics.metric['402m'])}
                </>
              ) : (
                <>
                  {renderMetricRow('60 ft', runMetrics.imperial['60ft'])}
                  {renderMetricRow('0 - 60 mph', runMetrics.imperial['0-60'])}
                  {renderMetricRow('1/8 Mile', runMetrics.imperial['1/8'])}
                  {renderMetricRow('1/4 Mile', runMetrics.imperial['1/4'])}
                </>
              )}
            </View>
          </View>
        )}

        {/* Save Button */}
        <TouchableOpacity onPress={handleSave} disabled={!isConnected || isSaving} style={tw`mt-6 py-4 rounded-xl items-center justify-center flex-row ${isConnected ? 'bg-red-600' : 'bg-neutral-800'}`}>
          {isSaving ? <RefreshCw size={20} color="white" style={tw`mr-2`} /> : <Save size={20} color="white" style={tw`mr-2`} />}
          <Text style={tw`text-white font-bold uppercase tracking-wider`}>{isSaving ? 'SAVING SETTING...' : 'SAVE SETTING'}</Text>
        </TouchableOpacity>
      </ScrollView>

      {/* Permission Modal */}
      <Modal visible={showPermissionModal} transparent animationType="fade">
        <View style={tw`flex-1 bg-black/80 items-center justify-center p-6`}>
          <View style={tw`bg-neutral-900 border border-neutral-800 rounded-2xl p-6 w-full max-w-sm items-center`}>
            <View style={tw`w-16 h-16 rounded-full bg-red-500/20 items-center justify-center mb-4`}>
              <Bluetooth size={32} color="#ef4444" />
            </View>
            <Text style={tw`text-xl font-bold text-white mb-2`}>Permissions Required</Text>
            <Text style={tw`text-neutral-400 text-center text-sm mb-6`}>Antasena Performance needs Bluetooth and Location access to link with your ECU and track race metrics accurately.</Text>
            <TouchableOpacity onPress={requestPermissions} style={tw`w-full py-4 bg-red-600 rounded-xl mb-3 items-center`}>
              <Text style={tw`text-white font-bold`}>Grant Permissions</Text>
            </TouchableOpacity>
            <TouchableOpacity onPress={() => setShowPermissionModal(false)} style={tw`w-full py-4 bg-neutral-800 rounded-xl items-center`}>
              <Text style={tw`text-neutral-400 font-bold`}>Maybe Later</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}
