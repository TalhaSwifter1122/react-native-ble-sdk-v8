import { NativeModules, NativeEventEmitter, PermissionsAndroid, Platform } from 'react-native';

// ─────────────────────────────────────────────────────────────────────────────
// Server upload & sleep logic — re-exported so the RN app only needs one import
// ─────────────────────────────────────────────────────────────────────────────
export {
    configureServer,
    startAutoUpload,
    stopAutoUpload,
    setAutoUploadSleepContextEnabled,
    resetAutoUploadSleepContext,
    uploadData,
    uploadToEndpoint,
} from './src/serverUpload';

export {
    configureSleepLogic,
    processSleepPayload,
    processSleepRecord,
} from './src/sleepLogic';

export {
    buildSleepWindows,
    isSleepingAt,
    isSleepingFromBlePayload,
    buildHealthContext,
    estimateMentalWellnessFromPayload,
    getMentalWellnessState,
    classifyBlePayload,
    isSleepPayload,
    resetSleepContextState,
    getSleepContextState,
    updateSleepContextWithPayload,
    enrichBlePayloadWithSleepContext,
    resolveSleepStatusFromBleData,
    getCurrentSleepStatus,
} from './src/healthInsights';

const { RNBleSdkV8 } = NativeModules;

if (!RNBleSdkV8) {
    throw new Error(
        'RNBleSdkV8 native module is not linked. ' +
        (Platform.OS === 'ios' ? 'Run `cd ios && pod install` then rebuild the app.' : 'Rebuild the Android app with the SDK linked.')
    );
}

const isAndroid = Platform.OS === 'android';
let scanGeneration = 0;
let permissionRequest;

const androidEvents = {
    BleDeviceFound: 'RNBleSdkV8.scanResult',
    BleLog: 'RNBleSdkV8.log',
    BleConnected: 'RNBleSdkV8.connected',
    BleDisconnected: 'RNBleSdkV8.disconnected',
    BleConnectFailed: 'RNBleSdkV8.error',
    BleData: 'RNBleSdkV8.data',
    BlePowerStateChanged: 'RNBleSdkV8.state',
};

const eventEmitter = new NativeEventEmitter(RNBleSdkV8);

// ─────────────────────────────────────────────────────────────────────────────
// Event names emitted from the native side
// ─────────────────────────────────────────────────────────────────────────────
export const BleEvents = {
    /** A BLE peripheral was found during scan */
    DEVICE_FOUND: 'BleDeviceFound',
    SCAN_RESULT: 'BleDeviceFound',
    LOG: isAndroid ? 'BleLog' : 'BleData',
    /** Successfully connected and communication enabled */
    CONNECTED: 'BleConnected',
    /** Device disconnected */
    DISCONNECTED: 'BleDisconnected',
    /** Connection attempt failed */
    CONNECT_FAILED: 'BleConnectFailed',
    /** Parsed device data arrived (all types) */
    DATA: 'BleData',
    /** BLE state changed (poweredOn / poweredOff / etc.) */
    BLE_STATE_CHANGED: 'BlePowerStateChanged',
};

// ─────────────────────────────────────────────────────────────────────────────
// Subscription helpers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Subscribe to a BLE event.
 * Returns a subscription object; call .remove() to unsubscribe.
 *
 * @param {string} eventName  One of the BleEvents constants
 * @param {Function} callback Receives the event payload
 */
export function addBleListener(eventName, callback) {
    if (!eventName || typeof callback !== 'function') return { remove() {} };
    const nativeEvent = isAndroid ? androidEvents[eventName] || eventName : eventName;
    return eventEmitter.addListener(nativeEvent, payload => {
        switch (eventName) {
            case BleEvents.DEVICE_FOUND:
            case BleEvents.CONNECTED: {
                const address = payload?.address || payload?.uuid;
                const device = address && !payload?.address ? { ...payload, address } : payload;
                callback(isAndroid && eventName === BleEvents.CONNECTED ? { ...device, connected: true } : device);
                break;
            }
            case BleEvents.DISCONNECTED:
                callback(isAndroid ? { ...payload, connected: false } : payload);
                break;
            case BleEvents.CONNECT_FAILED: {
                const message = payload?.message ?? payload?.error;
                callback({ ...payload, message, error: payload?.error ?? message });
                break;
            }
            case BleEvents.DATA:
                if (isAndroid && payload?.dataType === undefined) return;
                if (payload?.data?.TempData == null && payload?.data?.temperature != null) {
                    callback({ ...payload, data: { ...payload.data, TempData: payload.data.temperature } });
                } else {
                    callback(payload);
                }
                break;
            default:
                callback(payload);
        }
    });
}

// ─────────────────────────────────────────────────────────────────────────────
// Scanning
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Start scanning for BLE peripherals.
 * Scans for ALL nearby BLE devices — no service UUID filter — so devices
 * like JCVital / V8 bands that don't advertise their service UUID are visible.
 *
 * @param {string} [nameFilter]  Optional: only emit devices whose name contains
 *                               this string (case-insensitive). e.g. "JCVital"
 *                               Leave empty to see every BLE device in range.
 */
export function startScan(nameFilter = '') {
    if (!isAndroid) return RNBleSdkV8.startScan(nameFilter || null);
    const generation = ++scanGeneration;
    return requestBlePermissions().then(granted => {
        if (generation !== scanGeneration) return;
        if (granted) {
            RNBleSdkV8.startScan(nameFilter || null);
        } else {
            eventEmitter.emit(androidEvents.BleConnectFailed, { message: 'Bluetooth scan permission denied' });
        }
    });
}

/** Request the scan and connection permissions required by Android. */
export async function requestBlePermissions() {
    if (!isAndroid) return true;
    if (permissionRequest) return permissionRequest;

    const permissions = Platform.Version >= 31
        ? [PermissionsAndroid.PERMISSIONS.BLUETOOTH_SCAN, PermissionsAndroid.PERMISSIONS.BLUETOOTH_CONNECT]
        : [PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION];
    permissionRequest = Promise.resolve()
        .then(() => PermissionsAndroid.requestMultiple(permissions))
        .then(result => permissions.every(permission => result[permission] === PermissionsAndroid.RESULTS.GRANTED))
        .catch(() => false)
        .finally(() => { permissionRequest = undefined; });
    return permissionRequest;
}

/** Stop an ongoing BLE scan. */
export function stopScan() {
    scanGeneration++;
    RNBleSdkV8.stopScan();
}

// ─────────────────────────────────────────────────────────────────────────────
// Connection
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Connect to a peripheral by its UUID string.
 * @param {string} peripheralUUID  UUID from the DEVICE_FOUND event
 */
export function connect(peripheralUUID, deviceName = null) {
    scanGeneration++;
    if (isAndroid) return RNBleSdkV8.connect(peripheralUUID, deviceName || null);
    RNBleSdkV8.connect(peripheralUUID);
}

/** Disconnect from the currently connected device. */
export function disconnect() {
    scanGeneration++;
    RNBleSdkV8.disconnect();
}

// ─────────────────────────────────────────────────────────────────────────────
// Value transformation config
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Set numeric offsets applied to sensor values BEFORE they are emitted to JS.
 * This is how you customise the SDK output without having its source code.
 *
 * @param {Object} config
 * @param {number} [config.spo2Offset=0]            Added to every SpO2 (%) reading
 * @param {number} [config.heartRateOffset=0]        Added to every heart-rate (bpm) reading
 * @param {number} [config.temperatureOffset=0]      Added to every temperature reading
 * @param {number} [config.awakeDurationOffset=0]    Added to awake-time minutes in sleep data
 * @param {number} [config.totalSleepTimeOffset=0]   Added to total sleep time in minutes
 * @param {number} [config.hrvOffset=0]              Added to every HRV reading
 * @param {number} [config.stepsOffset=0]            Added to step counts
 */
export function setTransformConfig(config) {
    RNBleSdkV8.setTransformConfig(config || {});
}

// ─────────────────────────────────────────────────────────────────────────────
// Data fetch commands
// Each resolves with the raw NSData bytes sent to the device; the actual
// response arrives later via the BleEvents.DATA event.
// ─────────────────────────────────────────────────────────────────────────────

export function getDeviceTime() { RNBleSdkV8.getDeviceTime(); }
export function getPersonalInfo() { RNBleSdkV8.getPersonalInfo(); }
export function getBatteryLevel() { RNBleSdkV8.getBatteryLevel(); }
export function getDeviceVersion() { RNBleSdkV8.getDeviceVersion(); }
export function getStepGoal() { RNBleSdkV8.getStepGoal(); }
export function getMacAddress() { RNBleSdkV8.getMacAddress(); }

function callHistoryCommand(nativeMethod, mode = 0, startDate = null) {
    let iso = startDate instanceof Date ? startDate.toISOString() : null;
    if (iso && isAndroid) {
        const pad = value => String(value).padStart(2, '0');
        iso = `${startDate.getFullYear()}-${pad(startDate.getMonth() + 1)}-${pad(startDate.getDate())} ` +
            `${pad(startDate.getHours())}:${pad(startDate.getMinutes())}:${pad(startDate.getSeconds())}`;
    }
    nativeMethod(mode, iso);
}

/**
 * @param {number} mode  0 = latest 50, 2 = next page, 0x99 = delete all
 * @param {Date|null} startDate
 */
export function getSleepHistory(mode = 0, startDate = null) {
    callHistoryCommand(RNBleSdkV8.getSleepHistory, mode, startDate);
}

export function getSleepAndActivityHistory(mode = 0, startDate = null) {
    callHistoryCommand(RNBleSdkV8.getSleepAndActivityHistory, mode, startDate);
}

export function getContinuousHRHistory(mode = 0, startDate = null) {
    callHistoryCommand(RNBleSdkV8.getContinuousHRHistory, mode, startDate);
}

export function getSingleHRHistory(mode = 0, startDate = null) {
    callHistoryCommand(RNBleSdkV8.getSingleHRHistory, mode, startDate);
}

export function getAutomaticSpo2History(mode = 0, startDate = null) {
    callHistoryCommand(RNBleSdkV8.getAutomaticSpo2History, mode, startDate);
}

export function getManualSpo2History(mode = 0, startDate = null) {
    callHistoryCommand(RNBleSdkV8.getManualSpo2History, mode, startDate);
}

export function getTemperatureHistory(mode = 0, startDate = null) {
    callHistoryCommand(RNBleSdkV8.getTemperatureHistory, mode, startDate);
}

export function getHRVHistory(mode = 0, startDate = null) {
    callHistoryCommand(RNBleSdkV8.getHRVHistory, mode, startDate);
}

export function getPPIHistory(mode = 0, startDate = null) {
    callHistoryCommand(RNBleSdkV8.getPPIHistory, mode, startDate);
}

export function getTotalActivityData(mode = 0, startDate = null) {
    callHistoryCommand(RNBleSdkV8.getTotalActivityData, mode, startDate);
}

export function getDetailActivityData(mode = 0, startDate = null) {
    callHistoryCommand(RNBleSdkV8.getDetailActivityData, mode, startDate);
}

export function getActivityModeHistory(mode = 0, startDate = null) {
    callHistoryCommand(RNBleSdkV8.getActivityModeHistory, mode, startDate);
}

/** Start real-time step + HR streaming (dataType 1 = on, 0 = off). */
export function setRealtimeData(enabled) {
    RNBleSdkV8.setRealtimeData(enabled ? 1 : 0);
}

/** Start PPG measurement. ppgMode: 1=start, 3=stop, 5=quit */
export function ppgControl(ppgMode, ppgStatus = 0) {
    RNBleSdkV8.ppgControl(ppgMode, ppgStatus);
}

export function clearAllHistoryData() {
    RNBleSdkV8.clearAllHistoryData();
}

// ─────────────────────────────────────────────────────────────────────────────
// Default export: all methods + event constants in one object
// ─────────────────────────────────────────────────────────────────────────────
import {
    configureServer,
    startAutoUpload,
    stopAutoUpload,
    setAutoUploadSleepContextEnabled,
    resetAutoUploadSleepContext,
    uploadData,
    uploadToEndpoint,
} from './src/serverUpload';

import {
    configureSleepLogic,
    processSleepPayload,
    processSleepRecord,
} from './src/sleepLogic';

import {
    buildSleepWindows,
    isSleepingAt,
    isSleepingFromBlePayload,
    buildHealthContext,
    estimateMentalWellnessFromPayload,
    getMentalWellnessState,
    classifyBlePayload,
    isSleepPayload,
    resetSleepContextState,
    getSleepContextState,
    updateSleepContextWithPayload,
    enrichBlePayloadWithSleepContext,
    resolveSleepStatusFromBleData,
    getCurrentSleepStatus,
} from './src/healthInsights';

export default {
    BleEvents,
    addBleListener,
    requestBlePermissions,
    startScan,
    stopScan,
    connect,
    disconnect,
    setTransformConfig,
    getDeviceTime,
    getPersonalInfo,
    getBatteryLevel,
    getDeviceVersion,
    getStepGoal,
    getMacAddress,
    getSleepHistory,
    getSleepAndActivityHistory,
    getContinuousHRHistory,
    getSingleHRHistory,
    getAutomaticSpo2History,
    getManualSpo2History,
    getTemperatureHistory,
    getHRVHistory,
    getPPIHistory,
    getTotalActivityData,
    getDetailActivityData,
    getActivityModeHistory,
    setRealtimeData,
    ppgControl,
    clearAllHistoryData,
    // server
    configureServer,
    startAutoUpload,
    stopAutoUpload,
    setAutoUploadSleepContextEnabled,
    resetAutoUploadSleepContext,
    uploadData,
    uploadToEndpoint,
    // sleep logic
    configureSleepLogic,
    processSleepPayload,
    processSleepRecord,
    // health context
    buildSleepWindows,
    isSleepingAt,
    isSleepingFromBlePayload,
    buildHealthContext,
    estimateMentalWellnessFromPayload,
    getMentalWellnessState,
    classifyBlePayload,
    isSleepPayload,
    resetSleepContextState,
    getSleepContextState,
    updateSleepContextWithPayload,
    enrichBlePayloadWithSleepContext,
    resolveSleepStatusFromBleData,
    getCurrentSleepStatus,
};
