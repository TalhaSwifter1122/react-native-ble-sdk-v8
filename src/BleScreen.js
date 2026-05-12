/**
 * BleScreen.js
 *
 * Drop-in React Native screen for the X3 wearable band.
 *
 * FEATURES
 *  • Scan for nearby BLE devices
 *  • Tap a device to connect
 *  • Live "Connected / Disconnected" status badge
 *  • "Send All Data to Server" button — fetches every data type from the band
 *    and streams each response to http://167.172.132.179:5000/JC_band_data_dump
 *
 * USAGE — paste into your app's navigator, e.g. App.tsx:
 *
 *   import BleScreen from 'react-native-ble-sdk-v8/src/BleScreen';
 *   // or copy this file into your own src/ folder and import locally.
 *
 *   <Stack.Screen name="Band" component={BleScreen} />
 */

import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
    ActivityIndicator,
    Alert,
    FlatList,
    SafeAreaView,
    StyleSheet,
    Text,
    TouchableOpacity,
    View,
} from 'react-native';

import {
    addBleListener,
    BleEvents,
    connect,
    disconnect,
    getContinuousHRHistory,
    getDetailActivityData,
    getHRVHistory,
    getPPIHistory,
    getSleepHistory,
    getAutomaticSpo2History,
    getTemperatureHistory,
    getTotalActivityData,
    startAutoUpload,
    startScan,
    stopScan,
} from 'react-native-ble-sdk-v8';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────
const SERVER_URL = 'http://167.172.132.179:5000/JC_band_data_dump';
const SCAN_TIMEOUT_MS = 10_000; // auto-stop scan after 10 s

// ─────────────────────────────────────────────────────────────────────────────
// BleScreen component
// ─────────────────────────────────────────────────────────────────────────────
export default function BleScreen() {
    const [isScanning, setIsScanning] = useState(false);
    const [devices, setDevices] = useState([]);          // [{id, name, rssi}]
    const [connectedId, setConnectedId] = useState(null);        // UUID of connected device
    const [connectionStatus, setStatus] = useState('idle');      // idle | connecting | connected | disconnected
    const [isSending, setIsSending] = useState(false);       // true while fetching+uploading
    const [lastUploadTime, setLastUploadTime] = useState(null);        // timestamp of last successful upload
    const [uploadLog, setUploadLog] = useState([]);          // last few upload results

    const scanTimer = useRef(null);

    // ── Start auto-upload pipeline once on mount ──────────────────────────
    useEffect(() => {
        // This hooks into BleEvents.DATA and POSTs every packet automatically.
        startAutoUpload();
    }, []);

    // ── BLE event listeners ───────────────────────────────────────────────
    useEffect(() => {
        const onDeviceFound = addBleListener(BleEvents.DEVICE_FOUND, (device) => {
            setDevices((prev) => {
                const exists = prev.find((d) => d.id === device.id);
                if (exists) return prev;
                return [...prev, device];
            });
        });

        const onConnected = addBleListener(BleEvents.CONNECTED, (info) => {
            setConnectedId(info?.peripheralUUID ?? info?.id ?? null);
            setStatus('connected');
        });

        const onDisconnected = addBleListener(BleEvents.DISCONNECTED, () => {
            setConnectedId(null);
            setStatus('disconnected');
            setIsSending(false);
        });

        const onConnectFailed = addBleListener(BleEvents.CONNECT_FAILED, () => {
            setStatus('disconnected');
            Alert.alert('Connection failed', 'Could not connect to the device. Please try again.');
        });

        const onData = addBleListener(BleEvents.DATA, (payload) => {
            const label = `${payload.dataType ?? 'data'} @ ${new Date().toLocaleTimeString()}`;
            setUploadLog((prev) => [label, ...prev].slice(0, 8));
            setLastUploadTime(new Date().toLocaleTimeString());
        });

        return () => {
            onDeviceFound.remove();
            onConnected.remove();
            onDisconnected.remove();
            onConnectFailed.remove();
            onData.remove();
        };
    }, []);

    // ── Scan helpers ──────────────────────────────────────────────────────
    const handleStartScan = useCallback(() => {
        setDevices([]);
        setIsScanning(true);
        startScan(); // no filter — show all nearby BLE devices

        scanTimer.current = setTimeout(() => {
            stopScan();
            setIsScanning(false);
        }, SCAN_TIMEOUT_MS);
    }, []);

    const handleStopScan = useCallback(() => {
        stopScan();
        setIsScanning(false);
        clearTimeout(scanTimer.current);
    }, []);

    // ── Connect / disconnect ──────────────────────────────────────────────
    const handleConnect = useCallback((deviceId) => {
        setStatus('connecting');
        connect(deviceId);
    }, []);

    const handleDisconnect = useCallback(() => {
        disconnect();
        setStatus('idle');
        setConnectedId(null);
    }, []);

    // ── Send all band data to server ──────────────────────────────────────
    /**
     * Fires every "get" command one after another.
     * The native SDK responds via BleEvents.DATA; startAutoUpload() picks up
     * each packet and POSTs it to the server automatically.
     */
    const handleSendToServer = useCallback(() => {
        if (connectionStatus !== 'connected') {
            Alert.alert('Not connected', 'Please connect to a band first.');
            return;
        }
        setIsSending(true);
        setUploadLog([]);

        try {
            // Fetch all data types — each response fires BleEvents.DATA which
            // is automatically uploaded by startAutoUpload().
            getSleepHistory(0);
            getContinuousHRHistory(0);
            getAutomaticSpo2History(0);
            getTemperatureHistory(0);
            getHRVHistory(0);
            getPPIHistory(0);
            getTotalActivityData(0);
            getDetailActivityData(0);
        } catch (err) {
            Alert.alert('Error', err.message);
        }

        // Re-enable button after 5 s (data arrives asynchronously)
        setTimeout(() => setIsSending(false), 5000);
    }, [connectionStatus]);

    // ── Render helpers ────────────────────────────────────────────────────
    const statusColor = {
        idle: '#888',
        scanning: '#f0a500',
        connecting: '#f0a500',
        connected: '#2ecc71',
        disconnected: '#e74c3c',
    }[connectionStatus] ?? '#888';

    const statusLabel = {
        idle: 'Idle',
        scanning: 'Scanning…',
        connecting: 'Connecting…',
        connected: 'Connected',
        disconnected: 'Disconnected',
    }[connectionStatus] ?? 'Unknown';

    const renderDevice = ({ item }) => {
        const isConnected = item.id === connectedId;
        return (
            <TouchableOpacity
                style={[styles.deviceRow, isConnected && styles.deviceRowActive]}
                onPress={() => isConnected ? handleDisconnect() : handleConnect(item.id)}
            >
                <View style={{ flex: 1 }}>
                    <Text style={styles.deviceName}>{item.name || 'Unknown Device'}</Text>
                    <Text style={styles.deviceSub}>UUID: {item.id}</Text>
                    <Text style={styles.deviceSub}>RSSI: {item.rssi} dBm</Text>
                </View>
                <Text style={[styles.connectBtn, isConnected && { color: '#e74c3c' }]}>
                    {isConnected ? 'Disconnect' : 'Connect'}
                </Text>
            </TouchableOpacity>
        );
    };

    // ── UI ────────────────────────────────────────────────────────────────
    return (
        <SafeAreaView style={styles.container}>

            {/* ── Status badge ── */}
            <View style={styles.statusBar}>
                <View style={[styles.statusDot, { backgroundColor: statusColor }]} />
                <Text style={[styles.statusText, { color: statusColor }]}>{statusLabel}</Text>
                {connectionStatus === 'connected' && (
                    <Text style={styles.serverHint} numberOfLines={1}>
                        → {SERVER_URL}
                    </Text>
                )}
            </View>

            {/* ── Scan controls ── */}
            <View style={styles.row}>
                <TouchableOpacity
                    style={[styles.btn, isScanning && styles.btnSecondary]}
                    onPress={isScanning ? handleStopScan : handleStartScan}
                    disabled={connectionStatus === 'connecting'}
                >
                    {isScanning
                        ? <ActivityIndicator color="#fff" />
                        : <Text style={styles.btnText}>Scan for Devices</Text>
                    }
                </TouchableOpacity>
            </View>

            {/* ── Device list ── */}
            {devices.length === 0 && !isScanning ? (
                <Text style={styles.empty}>No devices found. Tap "Scan for Devices".</Text>
            ) : (
                <FlatList
                    data={devices}
                    keyExtractor={(d) => d.id}
                    renderItem={renderDevice}
                    style={styles.list}
                    contentContainerStyle={{ paddingBottom: 12 }}
                />
            )}

            {/* ── Send to server button (only when connected) ── */}
            {connectionStatus === 'connected' && (
                <View style={styles.footer}>
                    <TouchableOpacity
                        style={[styles.btn, styles.btnGreen, isSending && styles.btnDisabled]}
                        onPress={handleSendToServer}
                        disabled={isSending}
                    >
                        {isSending
                            ? <ActivityIndicator color="#fff" />
                            : <Text style={styles.btnText}>Send Band Data to Server</Text>
                        }
                    </TouchableOpacity>

                    {lastUploadTime && (
                        <Text style={styles.uploadHint}>Last upload: {lastUploadTime}</Text>
                    )}

                    {uploadLog.length > 0 && (
                        <View style={styles.logBox}>
                            {uploadLog.map((line, i) => (
                                <Text key={i} style={styles.logLine}>✓ {line}</Text>
                            ))}
                        </View>
                    )}
                </View>
            )}
        </SafeAreaView>
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// Styles
// ─────────────────────────────────────────────────────────────────────────────
const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#0f1117',
        paddingHorizontal: 16,
    },

    // Status
    statusBar: {
        flexDirection: 'row',
        alignItems: 'center',
        paddingVertical: 14,
        borderBottomWidth: StyleSheet.hairlineWidth,
        borderBottomColor: '#2a2a3a',
        marginBottom: 8,
    },
    statusDot: {
        width: 10,
        height: 10,
        borderRadius: 5,
        marginRight: 8,
    },
    statusText: {
        fontSize: 15,
        fontWeight: '600',
        marginRight: 8,
    },
    serverHint: {
        fontSize: 10,
        color: '#555',
        flex: 1,
    },

    // Scan row
    row: {
        marginVertical: 10,
    },

    // Device list
    list: {
        flex: 1,
        marginTop: 4,
    },
    deviceRow: {
        flexDirection: 'row',
        alignItems: 'center',
        backgroundColor: '#1a1d2e',
        borderRadius: 10,
        padding: 14,
        marginBottom: 8,
    },
    deviceRowActive: {
        borderWidth: 1.5,
        borderColor: '#2ecc71',
    },
    deviceName: {
        color: '#fff',
        fontSize: 15,
        fontWeight: '600',
        marginBottom: 2,
    },
    deviceSub: {
        color: '#888',
        fontSize: 11,
    },
    connectBtn: {
        color: '#4a90e2',
        fontWeight: '700',
        fontSize: 14,
        marginLeft: 12,
    },

    empty: {
        color: '#555',
        textAlign: 'center',
        marginTop: 40,
        fontSize: 14,
    },

    // Footer
    footer: {
        paddingBottom: 20,
        paddingTop: 8,
        borderTopWidth: StyleSheet.hairlineWidth,
        borderTopColor: '#2a2a3a',
    },
    uploadHint: {
        color: '#888',
        fontSize: 12,
        textAlign: 'center',
        marginTop: 6,
    },
    logBox: {
        marginTop: 10,
        backgroundColor: '#1a1d2e',
        borderRadius: 8,
        padding: 10,
    },
    logLine: {
        color: '#2ecc71',
        fontSize: 11,
        marginBottom: 2,
    },

    // Buttons
    btn: {
        backgroundColor: '#4a90e2',
        borderRadius: 10,
        paddingVertical: 14,
        alignItems: 'center',
        justifyContent: 'center',
        minHeight: 50,
    },
    btnSecondary: {
        backgroundColor: '#444',
    },
    btnGreen: {
        backgroundColor: '#27ae60',
    },
    btnDisabled: {
        opacity: 0.5,
    },
    btnText: {
        color: '#fff',
        fontWeight: '700',
        fontSize: 15,
    },
});
