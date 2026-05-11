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

// Event name constant — duplicated here to avoid a circular import with index.js
const DATA_EVENT = 'BleData';

// ─────────────────────────────────────────────────────────────────────────────
// Internal state
// ─────────────────────────────────────────────────────────────────────────────
let _serverConfig = {
    baseUrl: '',
    authToken: '',
    deviceId: '',
    timeoutMs: 10000,
    retryCount: 2,
    endpoint: '/api/wearable/data',   // override with configureServer if needed
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
export function configureServer(config) {
    if (!config.baseUrl) {
        throw new Error('[BleSDK] configureServer: baseUrl is required');
    }
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
export function startAutoUpload() {
    if (!_serverConfig.baseUrl) {
        throw new Error('[BleSDK] Call configureServer() before startAutoUpload()');
    }
    if (_autoUploadSubscription) return; // already running

    const emitter = new NativeEventEmitter(NativeModules.RNBleSdkV8);
    _autoUploadSubscription = emitter.addListener(DATA_EVENT, (payload) => {
        uploadData(payload);
    });
}

/** Stop the auto-upload listener. */
export function stopAutoUpload() {
    if (_autoUploadSubscription) {
        _autoUploadSubscription.remove();
        _autoUploadSubscription = null;
    }
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
    const body = {
        deviceId: _serverConfig.deviceId,
        timestamp: new Date().toISOString(),
        dataType: blePayload.dataType,
        dataEnd: blePayload.dataEnd,
        data: blePayload.data,
    };

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
        if (retriesLeft > 0) {
            await _delay(500);
            return _postWithRetry(url, body, retriesLeft - 1);
        }
        if (_onUploadError) {
            _onUploadError(err, body);
        } else {
            console.warn('[BleSDK] Upload failed after retries:', err.message);
        }
    }
}

function _delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}
