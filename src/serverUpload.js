/**
 * serverUpload.js
 *
 * Handles sending all wearable data to your backend server.
 *
 * FLOW:
 *   Wearable (BLE) → SDK parses bytes → Bridge transforms values
 *     → BleEvents.DATA fires in JS → THIS FILE posts to your server
 *
 * SETUP (call once at app start, before BleSdk.startScan()):
 *   import { configureServer, startAutoUpload } from 'react-native-ble-sdk-v8';
 *
 *   configureServer({
 *     baseUrl:   'https://api.yourserver.com',
 *     authToken: 'Bearer eyJ...',   // your auth header value
 *     deviceId:  'user-123',        // ties data to a user/device on your backend
 *   });
 *   startAutoUpload();
 *
 * After that, every data packet from the wearable is automatically POSTed
 * to your server. No extra code needed in your app.
 */

import { NativeEventEmitter, NativeModules } from 'react-native';
import {
    enrichBlePayloadWithSleepContext,
    resetSleepContextState,
} from './healthInsights';

// Event name constant — duplicated here to avoid a circular import with index.js
const DATA_EVENT = 'BleData';

const DATA_TYPE_NAMES = {
    24: 'RealTimeStep',
    25: 'TotalActivityData',
    26: 'DetailActivityData',
    27: 'DetailSleepData',
    28: 'DynamicHR',
    29: 'StaticHR',
    41: 'HRVData',
    45: 'AutomaticSpo2Data',
    46: 'ManualSpo2Data',
    48: 'TemperatureData',
    81: 'DetailSleepAndActivityData',
};

// ─────────────────────────────────────────────────────────────────────────────
// Internal state
// ─────────────────────────────────────────────────────────────────────────────
let _serverConfig = {
    baseUrl: 'http://167.172.132.179:5000',
    authToken: '',
    deviceId: '',
    timeoutMs: 10000,
    retryCount: 2,
    endpoint: '/JC_band_data_dump',
    enableSleepContext: true,
};

let _autoUploadSubscription = null;
let _onUploadSuccess = null;
let _onUploadError = null;

// ─────────────────────────────────────────────────────────────────────────────
// Configuration
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Configure the server connection. Call this once before startAutoUpload().
 *
 * @param {Object} config
 * @param {string} config.baseUrl       Your server base URL, e.g. 'https://api.example.com'
 * @param {string} [config.authToken]   Value for the Authorization header
 * @param {string} [config.deviceId]    ID sent with every payload to identify the user/device
 * @param {string} [config.endpoint]    Path to POST data to (default: '/api/wearable/data')
 * @param {number} [config.timeoutMs]   Request timeout in ms (default: 10000)
 * @param {number} [config.retryCount]  How many times to retry a failed upload (default: 2)
 * @param {Function} [config.onSuccess] Called after each successful upload
 * @param {Function} [config.onError]   Called when an upload finally fails after all retries
 */
export function configureServer(config = {}) {
    _serverConfig = { ..._serverConfig, ...config };
    _onUploadSuccess = config.onSuccess || null;
    _onUploadError = config.onError || null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Auto-upload
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Start automatically uploading every BleEvents.DATA packet to the server.
 * Requires configureServer() to have been called first.
 */
export function startAutoUpload(options = {}) {
    if (!_serverConfig.baseUrl) {
        throw new Error('[BleSDK] Call configureServer() before startAutoUpload()');
    }

    if (typeof options.enableSleepContext === 'boolean') {
        _serverConfig.enableSleepContext = options.enableSleepContext;
    }

    // Ask the device to stream live step/HR updates whenever upload is started.
    // This is safe to call repeatedly (e.g. on reconnect).
    try {
        NativeModules?.RNBleSdkV8?.setRealtimeData?.(1);
    } catch (err) {
        console.warn('[BleSDK] Unable to enable realtime data stream:', err?.message || err);
    }

    if (_autoUploadSubscription) return; // already running

    const emitter = new NativeEventEmitter(NativeModules.RNBleSdkV8);
    _autoUploadSubscription = emitter.addListener(DATA_EVENT, (payload) => {
        const finalPayload = _serverConfig.enableSleepContext
            ? enrichBlePayloadWithSleepContext(payload)
            : payload;
        uploadData(finalPayload);
    });
}

/** Stop the auto-upload listener. */
export function stopAutoUpload() {
    if (_autoUploadSubscription) {
        _autoUploadSubscription.remove();
        _autoUploadSubscription = null;
    }
}

/** Enable/disable sleep-context enrichment for auto-upload payloads. */
export function setAutoUploadSleepContextEnabled(enabled) {
    _serverConfig.enableSleepContext = !!enabled;
}

/** Clear cached sleep windows used for payload enrichment. */
export function resetAutoUploadSleepContext() {
    resetSleepContextState();
}

// ─────────────────────────────────────────────────────────────────────────────
// Manual upload
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Manually upload a single data payload to the server.
 * The payload is the same object received from BleEvents.DATA.
 *
 * @param {Object} blePayload  { dataType, dataEnd, data }
 * @returns {Promise<void>}
 */
export async function uploadData(blePayload) {
    const body = _buildServerBody(blePayload);

    await _postWithRetry(
        _serverConfig.baseUrl + _serverConfig.endpoint,
        body,
        _serverConfig.retryCount
    );
}

/**
 * Upload a specific data type with a custom endpoint.
 * Useful when your backend has separate routes for each data type.
 *
 * @param {string} endpoint   e.g. '/api/wearable/sleep'
 * @param {Object} data       Any serializable object
 */
export async function uploadToEndpoint(endpoint, data) {
    const body = {
        deviceId: _serverConfig.deviceId,
        timestamp: new Date().toISOString(),
        ...data,
    };
    await _postWithRetry(
        _serverConfig.baseUrl + endpoint,
        body,
        _serverConfig.retryCount
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal HTTP helper
// ─────────────────────────────────────────────────────────────────────────────

async function _postWithRetry(url, body, retriesLeft) {
    try {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), _serverConfig.timeoutMs);

        const headers = { 'Content-Type': 'application/json' };
        if (_serverConfig.authToken) {
            headers['Authorization'] = _serverConfig.authToken;
        }

        const response = await fetch(url, {
            method: 'POST',
            headers,
            body: JSON.stringify(body),
            signal: controller.signal,
        });

        clearTimeout(timer);

        if (!response.ok) {
            throw new Error(`Server responded ${response.status}`);
        }

        if (_onUploadSuccess) _onUploadSuccess(body);

    } catch (err) {
        // Distinguish ATS/connection errors from our own timeout abort
        const isTimeout = err.name === 'AbortError' || err.message === 'Aborted';
        const isNetworkError = err.message === 'Network request failed';

        if (retriesLeft > 0 && !isNetworkError) {
            // Network request failed = server unreachable, no point retrying immediately
            await _delay(500);
            return _postWithRetry(url, body, retriesLeft - 1);
        }

        const hint = isTimeout
            ? 'Request timed out. Check server is running and reachable.'
            : isNetworkError
                ? 'Cannot reach server. On iOS, ensure NSAllowsArbitraryLoads is set in Info.plist for HTTP URLs.'
                : err.message;

        if (_onUploadError) {
            _onUploadError(new Error(hint), body);
        } else {
            console.warn('[BleSDK] Upload failed:', hint, '| dataType:', body?.dataType);
        }
    }
}

function _delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

function _buildServerBody(blePayload) {
    const data = blePayload?.data && typeof blePayload.data === 'object'
        ? blePayload.data
        : {};

    const realtime = _extractRealtime(data);
    const latest = _extractLatestFromHistory(data);
    const sleepContext = blePayload?.sleepContext || null;
    const isSleeping = blePayload?.isSleeping
        ?? sleepContext?.isSleepingNow
        ?? null;

    return {
        schemaVersion: '1.1',
        deviceId: _serverConfig.deviceId,
        timestamp: new Date().toISOString(),
        dataType: Number(blePayload?.dataType ?? -1),
        dataTypeName: DATA_TYPE_NAMES[Number(blePayload?.dataType)] || 'Unknown',
        dataEnd: Boolean(blePayload?.dataEnd),
        healthStatus: {
            isSleeping,
            lastSleepWindow: sleepContext?.lastSleepWindow || blePayload?.lastSleepWindow || null,
            steps: _firstNonNull(realtime.steps, latest.steps),
            heartRate: _firstNonNull(realtime.heartRate, latest.heartRate),
            spo2: latest.spo2,
            temperature: latest.temperature,
            hrv: latest.hrv,
        },
        metrics: {
            realtime,
            latest,
            records: {
                sleep: _arrayLength(data.arrayDetailSleepData) + _arrayLength(data.arrayDetailSleepAndActivityData),
                activity: _arrayLength(data.arrayActivity) + _arrayLength(data.arrayDetailActivityData),
                heartRateContinuous: _arrayLength(data.arrayContinuousHR),
                heartRateSingle: _arrayLength(data.arraySingleHR),
                spo2Automatic: _arrayLength(data.arrayAutomaticSpo2Data),
                spo2Manual: _arrayLength(data.arrayManualSpo2Data),
                temperature: _arrayLength(data.arrayTemperatureData) + _arrayLength(data.arrayemperatureData),
                hrv: _arrayLength(data.arrayHRVData),
            },
        },
        sleepContext,
        // Backward-compatible keys
        data: blePayload?.data,
        payload: blePayload,
    };
}

function _extractRealtime(data) {
    return {
        steps: _toFiniteNumber(data.steps ?? data.step ?? data.stepCount ?? data.totalSteps),
        calories: _toFiniteNumber(data.calories),
        distance: _toFiniteNumber(data.distance),
        heartRate: _toFiniteNumber(data.heartRate ?? data.hr),
    };
}

function _extractLatestFromHistory(data) {
    const latestActivity = _lastItem(data.arrayActivity) || _lastItem(data.arrayDetailActivityData);
    const latestSingleHr = _lastItem(data.arraySingleHR);
    const latestContinuousHr = _lastItem(data.arrayContinuousHR);
    const latestSpo2Auto = _lastItem(data.arrayAutomaticSpo2Data);
    const latestSpo2Manual = _lastItem(data.arrayManualSpo2Data);
    const latestTemp = _lastItem(data.arrayTemperatureData) || _lastItem(data.arrayemperatureData);
    const latestHrv = _lastItem(data.arrayHRVData);

    const continuousHrLatest = _lastNumber(latestContinuousHr?.arrayHR);

    return {
        steps: _toFiniteNumber(latestActivity?.steps),
        calories: _toFiniteNumber(latestActivity?.calories),
        distance: _toFiniteNumber(latestActivity?.distance),
        heartRate: _firstNonNull(
            _toFiniteNumber(latestSingleHr?.singleHR),
            _toFiniteNumber(continuousHrLatest)
        ),
        spo2: _firstNonNull(
            _toFiniteNumber(latestSpo2Manual?.manualSpo2Data),
            _toFiniteNumber(latestSpo2Auto?.automaticSpo2Data)
        ),
        temperature: _toFiniteNumber(latestTemp?.temperature),
        hrv: _toFiniteNumber(latestHrv?.hrv),
    };
}

function _arrayLength(value) {
    return Array.isArray(value) ? value.length : 0;
}

function _lastItem(value) {
    return Array.isArray(value) && value.length > 0 ? value[value.length - 1] : null;
}

function _lastNumber(value) {
    return Array.isArray(value) && value.length > 0 ? value[value.length - 1] : null;
}

function _toFiniteNumber(value) {
    const parsed = typeof value === 'number' ? value : Number(value);
    return Number.isFinite(parsed) ? parsed : null;
}

function _firstNonNull(...values) {
    for (const value of values) {
        if (value !== null && value !== undefined) return value;
    }
    return null;
}
