import { NativeModules, NativeEventEmitter, Platform } from 'react-native';

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
        'Run `cd ios && pod install` then rebuild the app.'
    );
}

const eventEmitter = new NativeEventEmitter(RNBleSdkV8);

// ─────────────────────────────────────────────────────────────────────────────
// Event names emitted from the native side
// ─────────────────────────────────────────────────────────────────────────────
export const BleEvents = {
    /** A BLE peripheral was found during scan */
    DEVICE_FOUND: 'BleDeviceFound',
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
    return eventEmitter.addListener(eventName, callback);
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
    RNBleSdkV8.startScan(nameFilter || null);
}

/** Stop an ongoing BLE scan. */
export function stopScan() {
    RNBleSdkV8.stopScan();
}

// ─────────────────────────────────────────────────────────────────────────────
// Connection
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Connect to a peripheral by its UUID string.
 * @param {string} peripheralUUID  UUID from the DEVICE_FOUND event
 */
export function connect(peripheralUUID) {
    RNBleSdkV8.connect(peripheralUUID);
}

/** Disconnect from the currently connected device. */
export function disconnect() {
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

/**
 * @param {number} mode  0 = latest 50, 2 = next page, 0x99 = delete all
 * @param {Date|null} startDate
 */
export function getSleepHistory(mode = 0, startDate = null) {
    RNBleSdkV8.getSleepHistory(mode, startDate ? startDate.toISOString() : null);
}

export function getSleepAndActivityHistory(mode = 0, startDate = null) {
    RNBleSdkV8.getSleepAndActivityHistory(mode, startDate ? startDate.toISOString() : null);
}

export function getContinuousHRHistory(mode = 0, startDate = null) {
    RNBleSdkV8.getContinuousHRHistory(mode, startDate ? startDate.toISOString() : null);
}

export function getSingleHRHistory(mode = 0, startDate = null) {
    RNBleSdkV8.getSingleHRHistory(mode, startDate ? startDate.toISOString() : null);
}

export function getAutomaticSpo2History(mode = 0, startDate = null) {
    RNBleSdkV8.getAutomaticSpo2History(mode, startDate ? startDate.toISOString() : null);
}

export function getManualSpo2History(mode = 0, startDate = null) {
    RNBleSdkV8.getManualSpo2History(mode, startDate ? startDate.toISOString() : null);
}

export function getTemperatureHistory(mode = 0, startDate = null) {
    RNBleSdkV8.getTemperatureHistory(mode, startDate ? startDate.toISOString() : null);
}

export function getHRVHistory(mode = 0, startDate = null) {
    RNBleSdkV8.getHRVHistory(mode, startDate ? startDate.toISOString() : null);
}

export function getPPIHistory(mode = 0, startDate = null) {
    RNBleSdkV8.getPPIHistory(mode, startDate ? startDate.toISOString() : null);
}

export function getTotalActivityData(mode = 0, startDate = null) {
    RNBleSdkV8.getTotalActivityData(mode, startDate ? startDate.toISOString() : null);
}

export function getDetailActivityData(mode = 0, startDate = null) {
    RNBleSdkV8.getDetailActivityData(mode, startDate ? startDate.toISOString() : null);
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
    classifyBlePayload,
    isSleepPayload,
    resetSleepContextState,
    getSleepContextState,
    updateSleepContextWithPayload,
    enrichBlePayloadWithSleepContext,
    resolveSleepStatusFromBleData,
    getCurrentSleepStatus,
};
