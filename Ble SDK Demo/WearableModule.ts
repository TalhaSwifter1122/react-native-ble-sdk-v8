/**
 * WearableModule.ts
 *
 * TypeScript interface for the X3 Wearable Native Module.
 * Drop this file into your React Native project (e.g. src/modules/).
 *
 * USAGE
 * -----
 * import WearableModule, { useWearable } from './WearableModule';
 *
 * // Scan & connect
 * WearableModule.startScan();
 * WearableModule.connectDevice(deviceId);
 *
 * // Listen for events
 * const { heartRate, spo2, connected } = useWearable();
 */

import { NativeModules, NativeEventEmitter, Platform } from 'react-native';

// ----------------------------------------------------------------
// Guard — fail early on Android (iOS-only module)
// ----------------------------------------------------------------
if (Platform.OS !== 'ios') {
    console.warn('[WearableModule] This module is iOS-only.');
}

const { WearableModule: _NativeWearable } = NativeModules;

if (!_NativeWearable) {
    throw new Error(
        '[WearableModule] Native module not found. ' +
        'Did you add WearableRNModule.swift + WearableRNModule.m to your Xcode project and rebuild?'
    );
}

// ----------------------------------------------------------------
// Types
// ----------------------------------------------------------------

export type ConnectionState =
    | 'idle'
    | 'scanning'
    | 'connecting'
    | 'connected'
    | 'disconnected';

export interface DeviceFoundPayload {
    id: string;       // UUID — pass this to connectDevice()
    name: string;
    rssi: number;
}

export interface HeartRateRecord {
    date: string;                  // "YYYY-MM-DD"
    heartbeatPerMinute: number[];  // one value per minute recorded
}

export interface SingleHeartRateRecord {
    date: string;
    singleHR: number;
}

export interface SpO2Record {
    date: string;
    spo2: number; // percentage
}

export interface SleepRecord {
    date: string;
    sleepStages: Array<Record<string, unknown>>;
}

export interface ActivityRecord {
    date: string;
    steps: number;
    calories: number;
    distance: number; // metres
}

export interface TemperatureRecord {
    date: string;
    temperature: number; // °C
}

export interface HRVRecord {
    date: string;
    hrv: number;
}

export interface RealtimeStepData {
    steps: number;
    calories: number;
    distance: number;
}

export interface DeviceInfo {
    macAddress: string;
    version: string;
    batteryLevel: number; // -1 if unknown
}

export interface PersonalInfoOptions {
    gender?: 0 | 1;  // 0 = male, 1 = female
    age?: number;
    height?: number; // cm
    weight?: number; // kg
    stride?: number; // cm
}

// Universal BLE scanner types (any peripheral, not only X3)
export interface UniversalDeviceFoundPayload {
    id: string;                    // UUID — pass to connectUniversal()
    name: string;
    rssi: number;
    localName?: string;
    manufacturerDataHex?: string;  // hex bytes e.g. "4C 00 02 15 ..."
    serviceUUIDs: string[];
}

export interface UniversalCharacteristicInfo {
    uuid: string;
    properties: string;            // e.g. "Read, Notify"
}

export interface UniversalServiceInfo {
    uuid: string;
    characteristics: UniversalCharacteristicInfo[];
}

// ----------------------------------------------------------------
// Event emitter
// ----------------------------------------------------------------
export const WearableEmitter = new NativeEventEmitter(_NativeWearable);

// ----------------------------------------------------------------
// Module API
// ----------------------------------------------------------------
const WearableModule = {
    /**
     * Configure the server endpoint and start the upload pipeline.
     * Call this ONCE at app startup before scanning.
     *
     * @param baseURL  Your server base URL, e.g. "https://api.yourcompany.com/v1"
     *                 For quick testing use a free webhook: https://webhook.site
     * @param token    Optional Bearer auth token. Pass undefined if not needed.
     *
     * @example
     *   // In App.tsx useEffect / componentDidMount:
     *   WearableModule.configure('https://webhook.site/YOUR-ID');
     *   // or with auth:
     *   WearableModule.configure('https://api.yourcompany.com/v1', 'my-token');
     */
    configure(baseURL: string, token?: string): void {
        _NativeWearable.configure(baseURL, token ?? null);
    },

    /** Start BLE scanning. Listen to `onDeviceFound` events for results. */
    startScan(): void {
        _NativeWearable.startScan();
    },

    /** Stop BLE scanning. */
    stopScan(): void {
        _NativeWearable.stopScan();
    },

    /**
     * Connect to a device.
     * @param deviceId UUID string from the `onDeviceFound` event.
     */
    connectDevice(deviceId: string): void {
        _NativeWearable.connectDevice(deviceId);
    },

    /** Disconnect from the current device. */
    disconnect(): void {
        _NativeWearable.disconnect();
    },

    // ---- Data sync --------------------------------------------------

    /** Fetch continuous heart rate history.
     * @param startDateISO Optional ISO-8601 date string e.g. "2026-01-01T00:00:00Z"
     */
    fetchHeartRateHistory(startDateISO?: string): void {
        _NativeWearable.fetchHeartRateHistory(startDateISO ?? null);
    },

    fetchSpo2History(startDateISO?: string): void {
        _NativeWearable.fetchSpo2History(startDateISO ?? null);
    },

    fetchSleepHistory(startDateISO?: string): void {
        _NativeWearable.fetchSleepHistory(startDateISO ?? null);
    },

    fetchActivityHistory(startDateISO?: string): void {
        _NativeWearable.fetchActivityHistory(startDateISO ?? null);
    },

    fetchTemperatureHistory(startDateISO?: string): void {
        _NativeWearable.fetchTemperatureHistory(startDateISO ?? null);
    },

    fetchHRVHistory(startDateISO?: string): void {
        _NativeWearable.fetchHRVHistory(startDateISO ?? null);
    },

    /** Start streaming real-time step count. Listen to `onRealtimeStepData`. */
    enableRealtimeSteps(): void {
        _NativeWearable.enableRealtimeSteps();
    },

    disableRealtimeSteps(): void {
        _NativeWearable.disableRealtimeSteps();
    },

    /** Fetch device MAC, firmware version, and battery level. */
    fetchDeviceInfo(): void {
        _NativeWearable.fetchDeviceInfo();
    },

    /**
     * Sync ALL data types in one call.
     * @param startDateISO Fetch data from this date onwards.
     */
    syncAll(startDateISO?: string): void {
        _NativeWearable.syncAll(startDateISO ?? null);
    },

    // ---- Device settings --------------------------------------------

    /** Write user profile to the device for accurate metric calculation. */
    setPersonalInfo(options: PersonalInfoOptions): void {
        _NativeWearable.setPersonalInfo(options);
    },

    /** Trigger the device motor vibration. */
    vibrate(): void {
        _NativeWearable.vibrate();
    },

    // ---- Universal BLE (any peripheral) -----------------------------

    /**
     * Scan for ALL nearby BLE peripherals — not limited to X3 devices.
     * Listen to `onUniversalDeviceFound` for results as they appear.
     * Deduplication by UUID is handled in the hook; raw events may repeat
     * as RSSI updates arrive.
     */
    startUniversalScan(): void {
        _NativeWearable.startUniversalScan();
    },

    /** Stop the universal BLE scan. */
    stopUniversalScan(): void {
        _NativeWearable.stopUniversalScan();
    },

    /**
     * Connect to any BLE peripheral found during a universal scan.
     * On success:
     *   - `onUniversalConnectionState` fires `"connected"`
     *   - `onUniversalServicesDiscovered` fires with the full GATT profile
     *
     * @param deviceId UUID string from the `onUniversalDeviceFound` event.
     */
    connectUniversal(deviceId: string): void {
        _NativeWearable.connectUniversal(deviceId);
    },

    /** Disconnect from the currently connected universal BLE peripheral. */
    disconnectUniversal(): void {
        _NativeWearable.disconnectUniversal();
    },
};

export default WearableModule;

// ----------------------------------------------------------------
// React Hook  (optional convenience)
// ----------------------------------------------------------------
import { useState, useEffect, useRef } from 'react';

export function useWearable() {
    const [connectionState, setConnectionState] = useState<ConnectionState>('idle');
    const [devices, setDevices] = useState<DeviceFoundPayload[]>([]);
    const [heartRate, setHeartRate] = useState<HeartRateRecord[]>([]);
    const [spo2, setSpo2] = useState<SpO2Record[]>([]);
    const [sleep, setSleep] = useState<SleepRecord[]>([]);
    const [activity, setActivity] = useState<ActivityRecord[]>([]);
    const [temperature, setTemperature] = useState<TemperatureRecord[]>([]);
    const [hrv, setHrv] = useState<HRVRecord[]>([]);
    const [realtimeSteps, setRealtimeSteps] = useState<RealtimeStepData | null>(null);
    const [deviceInfo, setDeviceInfo] = useState<DeviceInfo | null>(null);
    const [error, setError] = useState<string | null>(null);

    // Universal BLE scanner state
    const [universalConnectionState, setUniversalConnectionState] = useState<ConnectionState>('idle');
    const [universalDevices, setUniversalDevices] = useState<UniversalDeviceFoundPayload[]>([]);
    const [universalServices, setUniversalServices] = useState<UniversalServiceInfo[]>([]);
    const [universalError, setUniversalError] = useState<string | null>(null);

    const universalDeviceMapRef = useRef<Map<string, UniversalDeviceFoundPayload>>(new Map());

    const deviceMapRef = useRef<Map<string, DeviceFoundPayload>>(new Map());

    useEffect(() => {
        const subs = [
            WearableEmitter.addListener('onConnectionStateChanged', (state: ConnectionState) => {
                setConnectionState(state);
                if (state === 'scanning') {
                    setDevices([]);
                    deviceMapRef.current.clear();
                }
            }),
            WearableEmitter.addListener('onDeviceFound', (device: DeviceFoundPayload) => {
                deviceMapRef.current.set(device.id, device);
                setDevices(Array.from(deviceMapRef.current.values()));
            }),
            WearableEmitter.addListener('onHeartRateData', setHeartRate),
            WearableEmitter.addListener('onSpo2Data', setSpo2),
            WearableEmitter.addListener('onSleepData', setSleep),
            WearableEmitter.addListener('onActivityData', setActivity),
            WearableEmitter.addListener('onTemperatureData', setTemperature),
            WearableEmitter.addListener('onHRVData', setHrv),
            WearableEmitter.addListener('onRealtimeStepData', setRealtimeSteps),
            WearableEmitter.addListener('onDeviceInfo', setDeviceInfo),
            WearableEmitter.addListener('onError', (e: { message: string }) => setError(e.message)),

            // Universal BLE events
            WearableEmitter.addListener('onUniversalConnectionState', (state: ConnectionState) => {
                setUniversalConnectionState(state);
                if (state === 'scanning') {
                    setUniversalDevices([]);
                    universalDeviceMapRef.current.clear();
                    setUniversalServices([]);
                }
            }),
            WearableEmitter.addListener('onUniversalDeviceFound', (device: UniversalDeviceFoundPayload) => {
                universalDeviceMapRef.current.set(device.id, device);
                // Sort descending by RSSI so strongest signal is first
                const sorted = Array.from(universalDeviceMapRef.current.values())
                    .sort((a, b) => b.rssi - a.rssi);
                setUniversalDevices(sorted);
            }),
            WearableEmitter.addListener('onUniversalServicesDiscovered', (services: UniversalServiceInfo[]) => {
                setUniversalServices(services);
            }),
            WearableEmitter.addListener('onUniversalError', (e: { message: string }) => setUniversalError(e.message)),
        ];
        return () => subs.forEach(s => s.remove());
    }, []);

    return {
        connectionState,
        isConnected: connectionState === 'connected',
        isScanning: connectionState === 'scanning',
        devices,
        heartRate,
        spo2,
        sleep,
        activity,
        temperature,
        hrv,
        realtimeSteps,
        deviceInfo,
        error,

        // Universal BLE (any peripheral)
        universalConnectionState,
        isUniversalConnected: universalConnectionState === 'connected',
        isUniversalScanning: universalConnectionState === 'scanning',
        universalDevices,
        universalServices,
        universalError,
    };
}
