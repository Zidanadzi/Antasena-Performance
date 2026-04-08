import React, { useState, useEffect, useRef } from 'react';
import { View, Text, TouchableOpacity, ScrollView, TextInput, Switch, Modal, SafeAreaView, StatusBar, Platform, Dimensions, Alert } from 'react-native';
import { Bluetooth, BluetoothConnected, Settings2, Gauge, Zap, Save, RefreshCw, Activity, Power, Timer, MapPin, Flag, TrendingUp, Play, Square, RotateCcw, LogOut, Trash2 } from 'lucide-react-native';
import tw from 'twrnc';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Location from 'expo-location';

const { width } = Dimensions.get('window');

export default function App() {
  const [isConnected, setIsConnected] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [activeTab, setActiveTab] = useState('telemetry');
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

  // Permissions
  useEffect(() => {
    (async () => {
      let { status } = await Location.getForegroundPermissionsAsync();
      setPermissions({ location: status });
      if (status !== 'granted') {
        setShowPermissionModal(true);
      }
    })();
  }, []);

  const requestPermissions = async () => {
    let { status } = await Location.requestForegroundPermissionsAsync();
    setPermissions({ location: status });
    setShowPermissionModal(false);
  };

  // Simulation Logic (same as web)
  useEffect(() => {
    let interval: any;
    let currentRpm = 1500;
    if (isConnected) {
      interval = setInterval(() => {
        if (currentRpm > 1600) currentRpm -= Math.random() * 800 + 200;
        else currentRpm = 1500 + (Math.random() * 150 - 75);
        setRpm(Math.max(0, currentRpm));
        setSpeed(currentRpm > 1600 ? Math.floor((currentRpm / 14000) * 299) : 0);
      }, 50);
    } else {
      setRpm(0);
      setSpeed(0);
    }
    return () => clearInterval(interval);
  }, [isConnected]);

  useEffect(() => {
    let interval: any;
    if (raceStatus === 'running') {
      let currentDistance = 0, currentSpeedMs = 0, currentTime = 0;
      setRunMetrics({
        metric: { '18m': null, '0-100': null, '201m': null, '402m': null },
        imperial: { '60ft': null, '0-60': null, '1/8': null, '1/4': null }
      });
      interval = setInterval(() => {
        currentTime += 10;
        setRaceTime(currentTime);
        let acceleration = Math.max(2, 10 - (currentSpeedMs * 0.1));
        currentSpeedMs += acceleration * 0.01;
        currentDistance += currentSpeedMs * 0.01;
        let speedKmh = currentSpeedMs * 3.6, speedMph = speedKmh * 0.621371, distanceFt = currentDistance * 3.28084;
        setRunMetrics(prev => {
          const next = { ...prev };
          let updated = false;
          const check = (dist: number, limit: number, key: string, type: 'metric' | 'imperial', label: string) => {
            if (!next[type][key] && dist >= limit) {
              next[type][key] = { time: (currentTime/1000).toFixed(2) + 's', speed: Math.round(type === 'metric' ? speedKmh : speedMph) + (type === 'metric' ? ' km/h' : ' mph') };
              updated = true;
              if (label === 'finish') setRaceStatus('stopped');
            }
          };
          check(currentDistance, 18, '18m', 'metric', '');
          check(speedKmh, 100, '0-100', 'metric', '');
          check(currentDistance, 201, '201m', 'metric', '');
          check(currentDistance, 402, '402m', 'metric', 'finish');
          check(distanceFt, 60, '60ft', 'imperial', '');
          check(speedMph, 60, '0-60', 'imperial', '');
          check(distanceFt, 660, '1/8', 'imperial', '');
          check(distanceFt, 1320, '1/4', 'imperial', 'finish');
          return updated ? { ...next } : prev;
        });
      }, 10);
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
          <Text style={tw`text-lg font-bold italic text-white`}>ANTASENA <Text style={tw`text-red-500`}>PERFORMANCE</Text></Text>
        </View>
        <TouchableOpacity onPress={() => setIsConnected(!isConnected)} style={tw`px-3 py-2 rounded border ${isConnected ? 'bg-emerald-500/10 border-emerald-500/30' : 'bg-neutral-800 border-neutral-700'}`}>
          <Text style={tw`text-xs font-bold uppercase ${isConnected ? 'text-emerald-400' : 'text-neutral-400'}`}>{isConnected ? 'LINKED' : 'LINK ECU'}</Text>
        </TouchableOpacity>
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
          {['telemetry', 'sensor', 'racebox'].map(tab => (
            <TouchableOpacity key={tab} onPress={() => setActiveTab(tab)} style={tw`flex-1 py-2 items-center rounded ${activeTab === tab ? 'bg-neutral-800' : ''}`}>
              <Text style={tw`text-[10px] font-bold uppercase ${activeTab === tab ? 'text-red-500' : 'text-neutral-500'}`}>{tab}</Text>
            </TouchableOpacity>
          ))}
        </View>

        {/* Tab Content */}
        {activeTab === 'telemetry' && (
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
            <View style={tw`mb-6`}>
              <View style={tw`flex-row justify-between mb-2`}>
                <Text style={tw`text-neutral-300 text-xs font-bold uppercase`}>Minimum RPM</Text>
                <Text style={tw`text-white font-mono font-bold`}>{minRpm}</Text>
              </View>
              <View style={tw`h-1 bg-neutral-800 rounded-full overflow-hidden`}>
                <View style={tw`h-full bg-red-500 w-[${(minRpm-2000)/60}%]`} />
              </View>
            </View>
            <View>
              <View style={tw`flex-row justify-between mb-2`}>
                <Text style={tw`text-neutral-300 text-xs font-bold uppercase`}>Sensitivity</Text>
                <Text style={tw`text-white font-mono font-bold`}>{sensitivity}%</Text>
              </View>
              <View style={tw`h-1 bg-neutral-800 rounded-full overflow-hidden`}>
                <View style={tw`h-full bg-red-500 w-[${sensitivity}%]`} />
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
          <Text style={tw`text-white font-bold uppercase tracking-wider`}>{isSaving ? 'WRITING TO ECU...' : 'FLASH TO ECU'}</Text>
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
