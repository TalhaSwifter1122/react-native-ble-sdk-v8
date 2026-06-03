/**
 * serverUpload.js
 *
 * Native-driven server upload control.
 *
 * API calls are performed by the iOS native SDK bridge (RNBleSdkV8.m),
 * not by the React Native app layer.
 */

import { NativeEventEmitter, NativeModules, Platform } from 'react-native';
import {
    enrichBlePayloadWithSleepContext,
    resetSleepContextState,
} from './healthInsights';

const UPLOAD_STATUS_EVENT = 'BleUploadStatus';

let _serverConfig = {
    baseUrl: 'http://167.172.132.179:5000',
    authToken: 'Bearer YOUR_TOKEN',
    deviceId: 'test-device-001',
    timeoutMs: 30000,
    retryCount: 0,
    endpoint: '/JC_band_data_dump',
    enableSleepContext: true,
};

let _onUploadSuccess = null;
let _onUploadError = null;
let _onUploadRequest = null;
let _uploadStatusSubscription = null;

function _nativeModule() {
    return NativeModules?.RNBleSdkV8;
}

function _ensureNativeSupport() {
    const native = _nativeModule();

    if (!native) {
        throw new Error('[BleSDK] RNBleSdkV8 native module is not linked');
    }

    if (Platform.OS !== 'ios') {
        console.warn('[BleSDK] Native server upload is currently implemented for iOS only');
    }

    return native;
}

function _ensureUploadStatusListener() {
    if (_uploadStatusSubscription) return;

    const native = _nativeModule();
    if (!native) return;

    const emitter = new NativeEventEmitter(native);

    _uploadStatusSubscription = emitter.addListener(UPLOAD_STATUS_EVENT, event => {
        const stage = event?.stage;
        const requestBody = event?.request?.body || null;

        if (stage === 'request') {
            if (_onUploadRequest) _onUploadRequest(event);
            return;
        }

        if (stage === 'success') {
            if (_onUploadSuccess) _onUploadSuccess(requestBody, event);
            return;
        }

        if (stage === 'error') {
            const message = event?.message || event?.error || 'Upload failed';
            if (_onUploadError) {
                _onUploadError(new Error(message), requestBody, event);
            } else {
                console.warn('[BleSDK] Upload failed:', message, '| dataType:', requestBody?.dataType);
            }
        }
    });
}

function _toNativeConfig(config) {
    return {
        baseUrl: config.baseUrl,
        authToken: config.authToken,
        deviceId: config.deviceId,
        endpoint: config.endpoint,
        timeoutMs: config.timeoutMs,
        retryCount: config.retryCount,
    };
}

export function configureServer(config = {}) {
    _serverConfig = { ..._serverConfig, ...config };
    _onUploadRequest = config.onRequest || _onUploadRequest;
    _onUploadSuccess = config.onSuccess || _onUploadSuccess;
    _onUploadError = config.onError || _onUploadError;

    const native = _ensureNativeSupport();
    _ensureUploadStatusListener();

    native.configureServerUpload?.(_toNativeConfig(_serverConfig));
}

export function startAutoUpload(options = {}) {
    if (!_serverConfig.baseUrl) {
        throw new Error('[BleSDK] Call configureServer() before startAutoUpload()');
    }

    if (typeof options.enableSleepContext === 'boolean') {
        _serverConfig.enableSleepContext = options.enableSleepContext;
    }

    const native = _ensureNativeSupport();
    _ensureUploadStatusListener();

    // Ensure native side has the latest config before enabling auto-upload.
    native.configureServerUpload?.(_toNativeConfig(_serverConfig));

    // Keep existing behavior: ask wearable to stream realtime data while uploading.
    try {
        native.setRealtimeData?.(1);
    } catch (err) {
        console.warn('[BleSDK] Unable to enable realtime data stream:', err?.message || err);
    }

    native.startNativeAutoUpload?.({ enableSleepContext: _serverConfig.enableSleepContext });
}

export function stopAutoUpload() {
    const native = _nativeModule();
    native?.stopNativeAutoUpload?.();
}

export function setAutoUploadSleepContextEnabled(enabled) {
    _serverConfig.enableSleepContext = !!enabled;
}

export function resetAutoUploadSleepContext() {
    resetSleepContextState();
}

export async function uploadData(blePayload) {
    const native = _ensureNativeSupport();
    _ensureUploadStatusListener();

    const payload = _serverConfig.enableSleepContext
        ? enrichBlePayloadWithSleepContext(blePayload)
        : blePayload;

    native.configureServerUpload?.(_toNativeConfig(_serverConfig));
    native.uploadDataNative?.(payload || {});
}

export async function uploadToEndpoint(endpoint, data) {
    const native = _ensureNativeSupport();
    _ensureUploadStatusListener();

    native.configureServerUpload?.(_toNativeConfig(_serverConfig));
    native.uploadToEndpointNative?.(endpoint, data || {});
}
