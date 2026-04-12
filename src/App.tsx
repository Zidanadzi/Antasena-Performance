import React, { useState, useEffect, useRef } from 'react';
import { 
  View, 
  Text, 
  TouchableOpacity, 
  ScrollView, 
  TextInput, 
  SafeAreaView, 
  StatusBar, 
  Platform, 
  Dimensions, 
  Alert, 
  PermissionsAndroid,
  BackHandler,
  Modal,
  ActivityIndicator
} from 'react-native';
import { 
  Bluetooth, 
  Settings2, 
  Gauge, 
  Zap, 
  Save, 
  RefreshCw, 
  Activity, 
  Power, 
  LogOut, 
  ChevronRight, 
  AlertCircle,
  MapPin,
  Timer,
  TrendingUp,
  RotateCcw,
  Trash2
} from 'lucide-react-native';
import tw from 'twrnc';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { BleManager, Device, State } from 'react-native-ble-plx';
import RNBluetoothClassic, { BluetoothDevice } from 'react-native-bluetooth-classic';
import * as Location from 'expo-location';
import Toast from 'react-native-toast-message';
import { Buffer } from 'buffer';

const { width } = Dimensions.get('window');

// --- CONSTANTS ---
const SERVICE_UUID = "0000ffe0-0000-1000-8000-00805f9b34fb";
const CHAR_UUID = "0000ffe1-0000-1000-8000-00805f9b34fb";

interface RunMetric {
  time: string;
  speed: string;
}

interface RunMetrics {
  '0-100': RunMetric | null;
  '201m': RunMetric | null;
  '402m': RunMetric | null;
}

export default function App() {
  // Bluetooth State
  const [isConnected, setIsConnected] = useState(false);
  const [isConnecting, setIsConnecting] = useState(false);
  const [connectionType, setConnectionType] = useState<'ble' | 'classic' | null>(null);
  const [connectedDevice, setConnectedDevice] = useState<Device | BluetoothDevice | null>(null);
  const [rpm, setRpm] = useState(0);
  const [activeTab, setActiveTab] = useState('dashboard');
  
  // Settings State
  const [tableRpm, setTableRpm] = useState([4000, 6000, 8000, 10000]);
  const [tableKill, setTableKill] = useState([95, 85, 75, 65]);
  const [minRpm, setMinRpm] = useState(3000);
  const [isSaving, setIsSaving] = useState(false);

  // Racebox State
  const [speed, setSpeed] = useState(0);
  const [raceTime, setRaceTime] = useState(0);
  const [raceStatus, setRaceStatus] = useState<'idle' | 'running' | 'stopped'>('idle');
  const [gpsAccuracy, setGpsAccuracy] = useState<number | null>(null);
  const [runMetrics, setRunMetrics] = useState<RunMetrics>({
    '0-100': null,
    '201m': null,
    '402m': null
  });

  const bleManager = useRef<BleManager | null>(null);
  const locationSubscription = useRef<Location.LocationSubscription | null>(null);
  const raceTimerRef = useRef<number | null>(null);
  const startTimeRef = useRef<number>(0);
  const startLocation = useRef<Location.LocationObjectCoords | null>(null);

  // Initialize BLE Manager
  useEffect(() => {
    if (Platform.OS !== 'web') {
      bleManager.current = new BleManager();
    }
    return () => {
      if (bleManager.current) bleManager.current.destroy();
    };
  }, []);

  // Load Settings
  useEffect(() => {
    const loadSettings = async () => {
      try {
        const savedRpm = await AsyncStorage.getItem('antasena_tableRpm');
        if (savedRpm) setTableRpm(JSON.parse(savedRpm));
        const savedKill = await AsyncStorage.getItem('antasena_tableKill');
        if (savedKill) setTableKill(JSON.parse(savedKill));
        const savedMin = await AsyncStorage.getItem('antasena_minRpm');
        if (savedMin) setMinRpm(parseInt(savedMin, 10));
      } catch (e) {
        console.error("Failed to load settings", e);
      }
    };
    loadSettings();
  }, []);

  // GPS Tracking
  useEffect(() => {
    const startLocationTracking = async () => {
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') {
        Toast.show({ type: 'error', text1: 'Permission Denied', text2: 'Location access is needed for GPS speed.' });
        return;
      }

      locationSubscription.current = await Location.watchPositionAsync(
        {
          accuracy: Location.Accuracy.BestForNavigation,
          timeInterval: 500,
          distanceInterval: 1,
        },
        (location) => {
          const currentSpeed = Math.round((location.coords.speed || 0) * 3.6);
          setSpeed(currentSpeed > 0 ? currentSpeed : 0);
          setGpsAccuracy(location.coords.accuracy);

          // Race Logic
          if (raceStatus === 'running') {
            if (!startLocation.current) {
              startLocation.current = location.coords;
            }
            
            const dist = calculateDistance(
              startLocation.current.latitude, startLocation.current.longitude,
              location.coords.latitude, location.coords.longitude
            );

            const currentTimeStr = (raceTime / 1000).toFixed(2) + 's';
            
            setRunMetrics(prev => {
              const next = { ...prev };
              let updated = false;
              
              if (!next['0-100'] && currentSpeed >= 100) {
                next['0-100'] = { time: currentTimeStr, speed: '100 km/h' };
                updated = true;
              }
              if (!next['201m'] && dist >= 201) {
                next['201m'] = { time: currentTimeStr, speed: currentSpeed + ' km/h' };
                updated = true;
              }
              if (!next['402m'] && dist >= 402) {
                next['402m'] = { time: currentTimeStr, speed: currentSpeed + ' km/h' };
                updated = true;
                setRaceStatus('stopped');
              }
              
              return updated ? next : prev;
            });
          }
        }
      );
    };

    startLocationTracking();
    return () => locationSubscription.current?.remove();
  }, [raceStatus, raceTime]);

  // Race Timer (requestAnimationFrame for smoothness)
  useEffect(() => {
    if (raceStatus === 'running') {
      startTimeRef.current = performance.now() - raceTime;
      const step = () => {
        setRaceTime(performance.now() - startTimeRef.current);
        raceTimerRef.current = requestAnimationFrame(step);
      };
      raceTimerRef.current = requestAnimationFrame(step);
    } else {
      if (raceTimerRef.current) cancelAnimationFrame(raceTimerRef.current);
    }
    return () => {
      if (raceTimerRef.current) cancelAnimationFrame(raceTimerRef.current);
    };
  }, [raceStatus]);

  const calculateDistance = (lat1: number, lon1: number, lat2: number, lon2: number) => {
    const R = 6371e3;
    const φ1 = lat1 * Math.PI / 180;
    const φ2 = lat2 * Math.PI / 180;
    const Δφ = (lat2 - lat1) * Math.PI / 180;
    const Δλ = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
              Math.cos(φ1) * Math.cos(φ2) *
              Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  };

  // Bluetooth Logic
  const requestPermissions = async () => {
    if (Platform.OS === 'android') {
      if (Platform.Version >= 31) {
        const result = await PermissionsAndroid.requestMultiple([
          PermissionsAndroid.PERMISSIONS.BLUETOOTH_SCAN,
          PermissionsAndroid.PERMISSIONS.BLUETOOTH_CONNECT,
          PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
        ]);
        return result['android.permission.BLUETOOTH_CONNECT'] === PermissionsAndroid.RESULTS.GRANTED;
      } else {
        const result = await PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION);
        return result === PermissionsAndroid.RESULTS.GRANTED;
      }
    }
    return true;
  };

  const handleConnect = async () => {
    if (isConnected) {
      if (connectionType === 'ble' && connectedDevice) {
        await (connectedDevice as Device).cancelConnection();
      } else if (connectionType === 'classic' && connectedDevice) {
        await (connectedDevice as BluetoothDevice).disconnect();
      }
      setIsConnected(false);
      setConnectedDevice(null);
      setConnectionType(null);
      return;
    }

    const hasPermission = await requestPermissions();
    if (!hasPermission) {
      Toast.show({ type: 'error', text1: 'Permission Denied', text2: 'Bluetooth permissions are required.' });
      return;
    }

    // Show selection modal or just try both?
    // For simplicity, let's try to scan for both or provide a choice.
    // Here we'll show an Alert to choose.
    Alert.alert(
      "Connection Mode",
      "Choose your Bluetooth module type:",
      [
        { text: "HM-10 / BLE", onPress: () => connectBLE() },
        { text: "HC-05 / Classic", onPress: () => connectClassic() },
        { text: "Cancel", style: "cancel" }
      ]
    );
  };

  const connectBLE = async () => {
    if (!bleManager.current) return;
    setIsConnecting(true);
    setConnectionType('ble');
    Toast.show({ type: 'info', text1: 'Scanning BLE...', text2: 'Searching for HM-10/Antasena...' });

    let found = false;
    bleManager.current.startDeviceScan(null, null, (error, device) => {
      if (error) {
        setIsConnecting(false);
        Toast.show({ type: 'error', text1: 'BLE Error', text2: error.message });
        return;
      }

      if (device && (device.name?.includes('Antasena') || device.name?.includes('HM-10') || device.name?.includes('BT05'))) {
        found = true;
        bleManager.current?.stopDeviceScan();
        
        device.connect()
          .then(d => d.discoverAllServicesAndCharacteristics())
          .then(d => {
            setConnectedDevice(d);
            setIsConnected(true);
            setIsConnecting(false);
            Toast.show({ type: 'success', text1: 'BLE Connected', text2: `Linked to ${d.name}` });

            d.monitorCharacteristicForService(SERVICE_UUID, CHAR_UUID, (err, char) => {
              if (char?.value) {
                const decoded = Buffer.from(char.value, 'base64').toString('ascii');
                const parts = decoded.split(',');
                if (parts.length >= 1) {
                  const val = parseInt(parts[0]);
                  if (!isNaN(val)) setRpm(val);
                }
              }
            });

            d.onDisconnected(() => {
              setIsConnected(false);
              setConnectedDevice(null);
              setConnectionType(null);
              Toast.show({ type: 'error', text1: 'Disconnected', text2: 'BLE link lost' });
            });
          })
          .catch(e => {
            setIsConnecting(false);
            Toast.show({ type: 'error', text1: 'Connection Failed', text2: e.message });
          });
      }
    });

    setTimeout(() => {
      if (!found && isConnecting && connectionType === 'ble') {
        bleManager.current?.stopDeviceScan();
        setIsConnecting(false);
        Toast.show({ type: 'error', text1: 'Not Found', text2: 'Could not find BLE device.' });
      }
    }, 10000);
  };

  const connectClassic = async () => {
    setIsConnecting(true);
    setConnectionType('classic');
    Toast.show({ type: 'info', text1: 'Scanning Classic...', text2: 'Searching for HC-05...' });

    try {
      // For Classic, we usually look at paired devices first
      const paired = await RNBluetoothClassic.getBondedDevices();
      const device = paired.find(d => d.name.includes('HC-05') || d.name.includes('Antasena') || d.name.includes('HC-06'));

      if (device) {
        const connected = await device.connect();
        if (connected) {
          setConnectedDevice(device);
          setIsConnected(true);
          setIsConnecting(false);
          Toast.show({ type: 'success', text1: 'Classic Connected', text2: `Linked to ${device.name}` });

          // Start reading data
          device.onDataReceived((event) => {
            const data = event.data;
            const parts = data.split(',');
            if (parts.length >= 1) {
              const val = parseInt(parts[0]);
              if (!isNaN(val)) setRpm(val);
            }
          });
        }
      } else {
        // If not paired, try to discover
        Toast.show({ type: 'info', text1: 'Not Paired', text2: 'Please pair HC-05 in phone settings first.' });
        setIsConnecting(false);
      }
    } catch (e: any) {
      setIsConnecting(false);
      Toast.show({ type: 'error', text1: 'Classic Error', text2: e.message });
    }
  };

  const handleSave = async () => {
    setIsSaving(true);
    try {
      await AsyncStorage.setItem('antasena_tableRpm', JSON.stringify(tableRpm));
      await AsyncStorage.setItem('antasena_tableKill', JSON.stringify(tableKill));
      await AsyncStorage.setItem('antasena_minRpm', minRpm.toString());

      if (isConnected && connectedDevice) {
        const commands = [];
        commands.push(`MIN:${minRpm}`);
        for (let i = 0; i < 4; i++) {
          commands.push(`T${i+1}R${tableRpm[i]}`);
          commands.push(`T${i+1}K${tableKill[i]}`);
        }

        if (connectionType === 'ble') {
          for (const cmd of commands) {
            const base64 = Buffer.from(cmd + '\n').toString('base64');
            await (connectedDevice as Device).writeCharacteristicWithResponseForService(SERVICE_UUID, CHAR_UUID, base64);
            await new Promise(r => setTimeout(r, 100));
          }
        } else if (connectionType === 'classic') {
          for (const cmd of commands) {
            await (connectedDevice as BluetoothDevice).write(cmd + '\n');
            await new Promise(r => setTimeout(r, 100));
          }
        }
      }
      
      Toast.show({ type: 'success', text1: 'Success', text2: 'Settings saved and synced.' });
    } catch (e) {
      Toast.show({ type: 'error', text1: 'Error', text2: 'Failed to save settings.' });
    } finally {
      setIsSaving(false);
    }
  };

  // --- UI COMPONENTS ---
  const RpmGauge = () => {
    const segments = 24;
    const maxRpm = 14000;
    const activeSegments = Math.floor((rpm / maxRpm) * segments);

    return (
      <View style={tw`w-full bg-neutral-900 border border-neutral-800 rounded-3xl p-5 mb-4`}>
        <View style={tw`flex-row justify-between items-center mb-6`}>
          <View>
            <Text style={tw`text-neutral-500 text-[9px] font-black tracking-widest uppercase mb-1`}>Engine RPM</Text>
            <View style={tw`flex-row items-baseline`}>
              <Text style={tw`text-5xl font-black text-white font-mono`}>{rpm.toLocaleString()}</Text>
              <Text style={tw`text-xs text-neutral-600 font-bold ml-2`}>RPM</Text>
            </View>
          </View>
          <View style={tw`items-end`}>
            <Text style={tw`text-neutral-500 text-[9px] font-black tracking-widest uppercase mb-1`}>GPS Speed</Text>
            <View style={tw`flex-row items-baseline`}>
              <Text style={tw`text-4xl font-black text-red-500 font-mono`}>{speed}</Text>
              <Text style={tw`text-[10px] text-neutral-600 font-bold ml-1`}>KM/H</Text>
            </View>
          </View>
        </View>

        <View style={tw`flex-row gap-1 h-8`}>
          {Array.from({ length: segments }).map((_, i) => {
            const isActive = i < activeSegments;
            let color = 'bg-neutral-800 opacity-30';
            if (isActive) {
              if (i < 14) color = 'bg-emerald-500 shadow-[0_0_10px_#10b981] opacity-100';
              else if (i < 20) color = 'bg-yellow-500 shadow-[0_0_10px_#f59e0b] opacity-100';
              else color = 'bg-red-500 shadow-[0_0_10px_#ef4444] opacity-100';
            }
            return <View key={i} style={tw`flex-1 rounded-sm ${color}`} />;
          })}
        </View>
      </View>
    );
  };

  return (
    <SafeAreaView style={tw`flex-1 bg-black`}>
      <StatusBar barStyle="light-content" />
      
      {/* Header */}
      <View style={tw`px-6 py-4 flex-row items-center justify-between border-b border-neutral-900`}>
        <View style={tw`flex-row items-center`}>
          <Zap size={24} color="#ef4444" style={tw`mr-2`} />
          <View>
            <Text style={tw`text-white font-black italic text-lg leading-none`}>ANTASENA</Text>
            <Text style={tw`text-red-600 font-black italic text-[10px] tracking-tighter`}>PERFORMANCE NATIVE</Text>
          </View>
        </View>
        <TouchableOpacity 
          onPress={handleConnect}
          disabled={isConnecting}
          style={tw`flex-row items-center bg-neutral-900 px-4 py-2 rounded-full border border-neutral-800`}
        >
          {isConnecting ? (
            <ActivityIndicator size="small" color="#ef4444" style={tw`mr-2`} />
          ) : (
            <Bluetooth size={16} color={isConnected ? "#10b981" : "#ef4444"} style={tw`mr-2`} />
          )}
          <Text style={tw`text-[10px] font-black text-white uppercase`}>
            {isConnected ? 'LIVE' : isConnecting ? 'SCANNING' : 'CONNECT'}
          </Text>
        </TouchableOpacity>
      </View>

      <ScrollView style={tw`flex-1 px-6 pt-4`} contentContainerStyle={tw`pb-32`}>
        {/* Tabs */}
        <View style={tw`flex-row mb-6 bg-neutral-900 p-1 rounded-2xl border border-neutral-800`}>
          {['dashboard', 'tuning', 'racebox'].map(tab => (
            <TouchableOpacity 
              key={tab} 
              onPress={() => setActiveTab(tab)} 
              style={tw`flex-1 py-3 items-center rounded-xl ${activeTab === tab ? 'bg-neutral-800 shadow-sm' : ''}`}
            >
              <Text style={tw`text-[10px] font-black uppercase tracking-widest ${activeTab === tab ? 'text-red-500' : 'text-neutral-500'}`}>
                {tab}
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        {activeTab === 'dashboard' && (
          <>
            <RpmGauge />
            
            <View style={tw`flex-row gap-4 mb-6`}>
              <View style={tw`flex-1 bg-neutral-900 p-5 rounded-3xl border border-neutral-800`}>
                <View style={tw`flex-row items-center mb-1`}>
                  <Activity size={12} color="#525252" style={tw`mr-1`} />
                  <Text style={tw`text-neutral-500 text-[9px] font-black uppercase`}>RPM Minimum</Text>
                </View>
                <View style={tw`flex-row items-baseline`}>
                  <Text style={tw`text-3xl font-black text-white font-mono`}>{minRpm}</Text>
                  <Text style={tw`text-[9px] text-neutral-600 font-bold ml-1`}>RPM</Text>
                </View>
              </View>
              <View style={tw`flex-1 bg-neutral-900 p-5 rounded-3xl border border-neutral-800`}>
                <View style={tw`flex-row items-center mb-1`}>
                  <Zap size={12} color="#525252" style={tw`mr-1`} />
                  <Text style={tw`text-neutral-500 text-[9px] font-black uppercase`}>Active Cut</Text>
                </View>
                <View style={tw`flex-row items-baseline`}>
                  <Text style={tw`text-3xl font-black text-red-500 font-mono`}>
                    {rpm > minRpm ? tableKill[0] : 0}
                  </Text>
                  <Text style={tw`text-[9px] text-neutral-600 font-bold ml-1`}>MS</Text>
                </View>
              </View>
            </View>

            <View style={tw`bg-neutral-900 rounded-3xl border border-neutral-800 p-6`}>
              <View style={tw`flex-row items-center justify-between mb-4`}>
                <View style={tw`flex-row items-center`}>
                  <MapPin size={16} color="#ef4444" style={tw`mr-2`} />
                  <Text style={tw`text-white font-black text-xs uppercase tracking-widest`}>GPS Status</Text>
                </View>
                <Text style={tw`text-[10px] font-bold ${gpsAccuracy && gpsAccuracy < 10 ? 'text-emerald-500' : 'text-yellow-500'}`}>
                  {gpsAccuracy ? `Accuracy: ${gpsAccuracy.toFixed(1)}m` : 'Searching...'}
                </Text>
              </View>
              <View style={tw`h-1 bg-neutral-800 rounded-full overflow-hidden`}>
                <View style={tw`h-full bg-red-600 w-1/3`} />
              </View>
            </View>
          </>
        )}

        {activeTab === 'tuning' && (
          <View>
            <View style={tw`bg-neutral-900 p-6 rounded-3xl border border-neutral-800 mb-6`}>
              <Text style={tw`text-neutral-500 text-[10px] font-black uppercase mb-4 tracking-widest`}>RPM Minimum Active</Text>
              <View style={tw`bg-black rounded-2xl border border-neutral-800 p-4 flex-row items-center`}>
                <TextInput 
                  keyboardType="numeric" 
                  value={minRpm.toString()} 
                  onChangeText={v => setMinRpm(parseInt(v) || 0)}
                  style={tw`flex-1 text-white font-mono text-2xl font-black`}
                />
                <Text style={tw`text-neutral-600 font-black`}>RPM</Text>
              </View>
            </View>

            <View style={tw`bg-neutral-900 p-5 rounded-3xl border border-neutral-800 mb-6`}>
              <Text style={tw`text-neutral-500 text-[10px] font-black uppercase mb-6 tracking-widest`}>Kill Time Configuration</Text>
              
              <View style={tw`flex-row mb-2 px-2`}>
                <Text style={tw`flex-1 text-neutral-600 text-[9px] font-black uppercase`}>Stage</Text>
                <Text style={tw`flex-1 text-neutral-600 text-[9px] font-black uppercase text-center`}>RPM Trigger</Text>
                <Text style={tw`w-24 text-neutral-600 text-[9px] font-black uppercase text-right`}>Kill (ms)</Text>
              </View>

              {tableRpm.map((r, i) => (
                <View key={i} style={tw`flex-row items-center bg-black rounded-2xl border border-neutral-800 p-3 mb-2`}>
                  <Text style={tw`flex-1 text-red-500 font-black italic text-xs`}>S{i+1}</Text>
                  <TextInput 
                    keyboardType="numeric" 
                    value={r.toString()} 
                    onChangeText={v => {
                      const newRpm = [...tableRpm];
                      newRpm[i] = parseInt(v) || 0;
                      setTableRpm(newRpm);
                    }}
                    style={tw`flex-1 text-white font-mono text-center font-bold`}
                  />
                  <TextInput 
                    keyboardType="numeric" 
                    value={tableKill[i].toString()} 
                    onChangeText={v => {
                      const newKill = [...tableKill];
                      newKill[i] = parseInt(v) || 0;
                      setTableKill(newKill);
                    }}
                    style={tw`w-24 text-red-500 font-mono text-right font-bold`}
                  />
                </View>
              ))}
            </View>

            <TouchableOpacity 
              onPress={handleSave}
              disabled={isSaving}
              style={tw`bg-red-600 py-5 rounded-3xl items-center flex-row justify-center shadow-lg shadow-red-900/40 mt-2`}
            >
              {isSaving ? <ActivityIndicator color="white" style={tw`mr-2`} /> : <Save size={20} color="white" style={tw`mr-2`} />}
              <Text style={tw`text-white font-black uppercase tracking-widest`}>
                {isSaving ? 'APPLYING...' : 'APPLY SETTING'}
              </Text>
            </TouchableOpacity>
          </View>
        )}

        {activeTab === 'racebox' && (
          <View>
            <View style={tw`bg-neutral-900 border border-neutral-800 rounded-3xl p-8 items-center mb-6`}>
              <Text style={tw`text-neutral-500 text-[10px] font-black uppercase mb-4 tracking-widest`}>
                {raceStatus === 'running' ? 'RECORDING RUN...' : 'READY FOR LAUNCH'}
              </Text>
              <Text style={tw`font-mono text-7xl font-black text-white`}>{(raceTime / 1000).toFixed(2)}s</Text>
              
              <View style={tw`flex-row mt-8 gap-4`}>
                <TouchableOpacity 
                  onPress={() => setRaceStatus(raceStatus === 'running' ? 'stopped' : 'running')} 
                  style={tw`px-10 py-4 rounded-2xl shadow-lg ${raceStatus === 'running' ? 'bg-red-600' : 'bg-emerald-600'}`}
                >
                  <Text style={tw`text-white font-black uppercase tracking-widest`}>
                    {raceStatus === 'running' ? 'STOP' : 'START'}
                  </Text>
                </TouchableOpacity>
                <TouchableOpacity 
                  onPress={() => {
                    setRaceStatus('idle');
                    setRaceTime(0);
                    startLocation.current = null;
                    setRunMetrics({ '0-100': null, '201m': null, '402m': null });
                  }} 
                  style={tw`w-14 h-14 bg-neutral-800 rounded-2xl items-center justify-center`}
                >
                  <RotateCcw size={24} color="white" />
                </TouchableOpacity>
              </View>
            </View>

            <View style={tw`bg-neutral-900 p-6 rounded-3xl border border-neutral-800`}>
              <Text style={tw`text-neutral-500 font-black uppercase text-[10px] mb-6 tracking-widest`}>Run Statistics</Text>
              
              {[
                { label: '0 - 100 KM/H', key: '0-100' },
                { label: '201 METER (1/8)', key: '201m' },
                { label: '402 METER (1/4)', key: '402m' }
              ].map(item => (
                <View key={item.key} style={tw`flex-row items-center justify-between p-4 rounded-2xl bg-black border border-neutral-800 mb-3`}>
                  <Text style={tw`font-black text-neutral-400 text-[10px]`}>{item.label}</Text>
                  <View style={tw`flex-row items-center`}>
                    <Text style={tw`text-[10px] text-neutral-600 font-mono mr-4`}>
                      {runMetrics[item.key as keyof RunMetrics]?.speed || '--'}
                    </Text>
                    <Text style={tw`font-mono font-black text-white text-lg`}>
                      {runMetrics[item.key as keyof RunMetrics]?.time || '--'}
                    </Text>
                  </View>
                </View>
              ))}
            </View>
          </View>
        )}
      </ScrollView>

      <Toast />
    </SafeAreaView>
  );
}


