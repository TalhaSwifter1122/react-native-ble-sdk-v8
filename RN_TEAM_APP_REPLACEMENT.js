import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
    FlatList,
    SafeAreaView,
    StyleSheet,
    Text,
    View,
} from 'react-native';

import RNBootSplash from 'react-native-bootsplash';
import BleScreen from 'react-native-ble-sdk-v8/src/BleScreen';
import {
    BleEvents,
    addBleListener,
    configureServer,
    startAutoUpload,
    stopAutoUpload,
    setRealtimeData,
    configureSleepLogic,
    processSleepPayload,
    getSleepAndActivityHistory,
    getTotalActivityData,
    getContinuousHRHistory,
    getSingleHRHistory,
    getAutomaticSpo2History,
    getManualSpo2History,
    getTemperatureHistory,
    getHRVHistory,
    getBatteryLevel,
    getDeviceVersion,
} from 'react-native-ble-sdk-v8';

const MAX_EVENTS = 120;
const MAX_API_LOGS = 80;

const dataTypeName = {
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

const formatMaybeNumber = (value, suffix = '') => {
    if (value === null || value === undefined || Number.isNaN(Number(value))) {
        return '--';
    }
    return `${Number(value)}${suffix}`;
};

const toNumberOrNull = value => {
    const parsed = typeof value === 'number' ? value : Number(value);
    return Number.isFinite(parsed) ? parsed : null;
};

const parseSdkDate = value => {
    if (!value) return null;

    if (value instanceof Date && !Number.isNaN(value.getTime())) return value;

    if (typeof value === 'number') {
        const fromNumber = new Date(value);
        return Number.isNaN(fromNumber.getTime()) ? null : fromNumber;
    }

    if (typeof value !== 'string') return null;

    // Native Date parse handles ISO with timezone correctly.
    const direct = new Date(value);
    if (!Number.isNaN(direct.getTime())) return direct;

    // SDK often sends local-ish strings like "yy-MM-dd HH:mm[:ss]".
    const normalized = value.replace(/[/.]/g, '-').trim();
    const match = normalized.match(/^(\d{2}|\d{4})-(\d{1,2})-(\d{1,2})(?:\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?$/);
    if (!match) return null;

    const yearRaw = Number(match[1]);
    const year = yearRaw < 100 ? 2000 + yearRaw : yearRaw;
    const month = Number(match[2]) - 1;
    const day = Number(match[3]);
    const hour = Number(match[4] || 0);
    const minute = Number(match[5] || 0);
    const second = Number(match[6] || 0);

    const localDate = new Date(year, month, day, hour, minute, second);
    return Number.isNaN(localDate.getTime()) ? null : localDate;
};

const formatLocalDateTime = value => {
    const date = parseSdkDate(value);
    return date ? date.toLocaleString() : '--';
};

const getLast = arr => {
    return Array.isArray(arr) && arr.length > 0 ? arr[arr.length - 1] : null;
};

const toJsonSafe = value => {
    try {
        return JSON.stringify(value);
    } catch (err) {
        return String(value);
    }
};

const truncateText = (text, maxLen = 240) => {
    if (!text || text.length <= maxLen) return text || '--';
    return `${text.slice(0, maxLen)}...`;
};

const extractRealtime = payload => {
    const data = payload?.data || {};
    return {
        steps: toNumberOrNull(
            data.steps ?? data.step ?? data.stepCount ?? data.totalSteps
        ),
        heartRate: toNumberOrNull(data.heartRate ?? data.hr),
        calories: toNumberOrNull(data.calories),
        distance: toNumberOrNull(data.distance),
    };
};

const extractLatestHistory = payload => {
    const data = payload?.data || {};

    const activity = getLast(data.arrayActivity) || getLast(data.arrayDetailActivityData);
    const singleHR = getLast(data.arraySingleHR);
    const continuousHR = getLast(data.arrayContinuousHR);
    const spo2Manual = getLast(data.arrayManualSpo2Data);
    const spo2Auto = getLast(data.arrayAutomaticSpo2Data);
    const temperature = getLast(data.arrayTemperatureData) || getLast(data.arrayemperatureData);
    const hrv = getLast(data.arrayHRVData);

    const continuousArray = continuousHR?.arrayHR;
    const continuousHRLast =
        Array.isArray(continuousArray) && continuousArray.length
            ? continuousArray[continuousArray.length - 1]
            : null;

    return {
        steps: toNumberOrNull(activity?.steps),
        calories: toNumberOrNull(activity?.calories),
        distance: toNumberOrNull(activity?.distance),
        heartRate: toNumberOrNull(singleHR?.singleHR ?? continuousHRLast),
        spo2: toNumberOrNull(spo2Manual?.manualSpo2Data ?? spo2Auto?.automaticSpo2Data),
        temperature: toNumberOrNull(temperature?.temperature),
        hrv: toNumberOrNull(hrv?.hrv),
        recordDate: activity?.date || singleHR?.date || spo2Manual?.date || spo2Auto?.date || temperature?.date || hrv?.date || null,
    };
};

const App = () => {
    const [events, setEvents] = useState([]);
    const [apiLogs, setApiLogs] = useState([]);
    const [connectionText, setConnectionText] = useState('Waiting for connection');

    const [isSleeping, setIsSleeping] = useState(null);
    const [lastSleepWindowText, setLastSleepWindowText] = useState('--');

    const [steps, setSteps] = useState(null);
    const [calories, setCalories] = useState(null);
    const [distance, setDistance] = useState(null);

    const [heartRate, setHeartRate] = useState(null);
    const [spo2, setSpo2] = useState(null);
    const [temperature, setTemperature] = useState(null);
    const [hrv, setHrv] = useState(null);

    const [lastDataDate, setLastDataDate] = useState('--');
    const [streamState, setStreamState] = useState('idle');

    const realtimeKeepAliveRef = useRef(null);
    const dataRefreshRef = useRef(null);
    const streamWatchdogRef = useRef(null);
    const lastRealtimePacketTsRef = useRef(0);

    const pushEvent = msg => {
        setEvents(prev => [msg, ...prev].slice(0, MAX_EVENTS));
    };

    const pushApiLog = (entry) => {
        setApiLogs(prev => [entry, ...prev].slice(0, MAX_API_LOGS));
    };

    const statusText = useMemo(() => {
        if (isSleeping === true) return 'Sleeping';
        if (isSleeping === false) return 'Awake';
        return 'Unknown';
    }, [isSleeping]);

    const requestInitialSync = () => {
        getSleepAndActivityHistory(0);
        getTotalActivityData(0);
        getContinuousHRHistory(0);
        getSingleHRHistory(0);
        getAutomaticSpo2History(0);
        getManualSpo2History(0);
        getTemperatureHistory(0);
        getHRVHistory(0);
        getBatteryLevel();
        getDeviceVersion();
    };

    const requestPeriodicRefresh = () => {
        // Lightweight set for latest values when realtime packet gaps happen.
        getSingleHRHistory(0);
        getAutomaticSpo2History(0);
        getTemperatureHistory(0);
        getHRVHistory(0);
        getTotalActivityData(0);
    };

    const stopRealtimeLoops = () => {
        if (realtimeKeepAliveRef.current) {
            clearInterval(realtimeKeepAliveRef.current);
            realtimeKeepAliveRef.current = null;
        }
        if (dataRefreshRef.current) {
            clearInterval(dataRefreshRef.current);
            dataRefreshRef.current = null;
        }
        if (streamWatchdogRef.current) {
            clearInterval(streamWatchdogRef.current);
            streamWatchdogRef.current = null;
        }
    };

    const startRealtimeLoops = () => {
        stopRealtimeLoops();

        // Immediately request realtime stream.
        setRealtimeData(true);
        lastRealtimePacketTsRef.current = Date.now();
        setStreamState('starting');

        // Re-arm realtime stream periodically to handle firmware idle drops.
        realtimeKeepAliveRef.current = setInterval(() => {
            setRealtimeData(true);
        }, 8000);

        // Pull latest history values in case a given metric is not fully realtime.
        dataRefreshRef.current = setInterval(() => {
            requestPeriodicRefresh();
        }, 15000);

        // Stream watchdog: if no realtime packet for too long, force refresh.
        streamWatchdogRef.current = setInterval(() => {
            const ageMs = Date.now() - lastRealtimePacketTsRef.current;
            if (ageMs > 20000) {
                setStreamState('recovering');
                setRealtimeData(true);
                requestPeriodicRefresh();
                pushEvent('Realtime stream stale, recovering...');
            }
        }, 5000);
    };

    useEffect(() => {
        RNBootSplash.hide({ fade: true });

        configureServer({
            baseUrl: 'https://api.yourserver.com',
            authToken: 'Bearer YOUR_TOKEN',
            deviceId: 'test-device-001',
            endpoint: '/JC_band_data_dump',
            timeoutMs: 30000,
            retryCount: 0,
            onRequest: meta => {
                const row = {
                    time: new Date().toLocaleTimeString(),
                    type: 'REQUEST',
                    status: `attempt ${meta?.attempt}`,
                    details: {
                        url: meta?.url,
                        retriesLeft: meta?.retriesLeft,
                        request: meta?.request,
                    },
                };
                pushApiLog(row);
                pushEvent(`API Request | attempt ${meta?.attempt} | retriesLeft ${meta?.retriesLeft}`);
                console.log('[BLE SDK][UPLOAD][REQUEST]', row.details);
            },
            onSuccess: (sentBody, meta) => {
                const status = `${meta?.response?.status || 200} ${meta?.response?.statusText || ''}`.trim();
                const row = {
                    time: new Date().toLocaleTimeString(),
                    type: 'SUCCESS',
                    status,
                    details: {
                        url: meta?.url,
                        request: meta?.request,
                        response: meta?.response,
                        sentBody,
                    },
                };
                pushApiLog(row);
                pushEvent(`API Success | ${status} | ${dataTypeName[sentBody?.dataType] || `Type-${sentBody?.dataType}`}`);
                console.log('[BLE SDK][UPLOAD][SUCCESS]', row.details);
            },
            onError: (err, sentBody, meta) => {
                const status = meta?.response?.status
                    ? `${meta.response.status} ${meta?.response?.statusText || ''}`.trim()
                    : 'NO_RESPONSE';
                const row = {
                    time: new Date().toLocaleTimeString(),
                    type: 'ERROR',
                    status,
                    details: {
                        message: err?.message,
                        url: meta?.url,
                        request: meta?.request,
                        response: meta?.response,
                        sentBody,
                    },
                };
                pushApiLog(row);
                pushEvent(`API Error | ${status} | ${err?.message || 'unknown'}`);
                console.log('[BLE SDK][UPLOAD][ERROR]', row.details);
            },
        });

        configureSleepLogic({
            awakeWindowToIgnoreMinutes: 3,
            minimumSleepSessionMinutes: 20,
            totalSleepTimeSource: 'computed',
        });

        startAutoUpload({ enableSleepContext: true });

        const subs = [
            addBleListener(BleEvents.CONNECTED, device => {
                const deviceName = device?.name || device?.uuid || 'device';
                setConnectionText(`Connected: ${deviceName}`);
                pushEvent(`Connected: ${deviceName}`);

                // Start robust realtime pipeline after every reconnect.
                startRealtimeLoops();
                startAutoUpload({ enableSleepContext: true });

                requestInitialSync();
            }),

            addBleListener(BleEvents.DISCONNECTED, device => {
                const deviceName = device?.name || device?.uuid || 'device';
                setConnectionText(`Disconnected: ${deviceName}`);
                pushEvent(`Disconnected: ${deviceName}`);
                setStreamState('stopped');
                stopRealtimeLoops();
            }),

            addBleListener(BleEvents.DATA, rawPayload => {
                try {
                    const payload = processSleepPayload(rawPayload);
                    const type = Number(payload?.dataType);

                    const realtime = extractRealtime(payload);
                    const history = extractLatestHistory(payload);

                    if (payload?.isSleeping !== undefined && payload?.isSleeping !== null) {
                        setIsSleeping(Boolean(payload.isSleeping));
                    }

                    if (payload?.lastSleepWindow?.start || payload?.sleepContext?.lastSleepWindow?.start) {
                        const window = payload?.lastSleepWindow || payload?.sleepContext?.lastSleepWindow;
                        const start = formatLocalDateTime(window?.start);
                        const end = formatLocalDateTime(window?.end);
                        setLastSleepWindowText(`${start} -> ${end}`);
                    }

                    if (realtime.steps !== null) setSteps(realtime.steps);
                    if (history.steps !== null && realtime.steps === null) setSteps(history.steps);

                    if (realtime.calories !== null) setCalories(realtime.calories);
                    if (history.calories !== null && realtime.calories === null) setCalories(history.calories);

                    if (realtime.distance !== null) setDistance(realtime.distance);
                    if (history.distance !== null && realtime.distance === null) setDistance(history.distance);

                    if (realtime.heartRate !== null) setHeartRate(realtime.heartRate);
                    if (history.heartRate !== null && realtime.heartRate === null) setHeartRate(history.heartRate);

                    if (history.spo2 !== null) setSpo2(history.spo2);
                    if (history.temperature !== null) setTemperature(history.temperature);
                    if (history.hrv !== null) setHrv(history.hrv);

                    if (history.recordDate) {
                        setLastDataDate(formatLocalDateTime(history.recordDate));
                    }

                    if (type === 24) {
                        lastRealtimePacketTsRef.current = Date.now();
                        setStreamState('live');
                    }

                    pushEvent(`Data: ${dataTypeName[type] || `Type-${type}`} | end=${Boolean(payload?.dataEnd)}`);
                } catch (err) {
                    pushEvent(`Processing error: ${err?.message || 'unknown'}`);
                }
            }),
        ];

        return () => {
            stopRealtimeLoops();
            stopAutoUpload();
            subs.forEach(sub => {
                if (sub?.remove) sub.remove();
            });
        };
    }, []);

    return (
        <SafeAreaView style={styles.container}>
            <View style={styles.bleContainer}>
                <BleScreen />
            </View>

            <View style={styles.eventsContainer}>
                <Text style={styles.heading}>Connection</Text>
                <View style={styles.statusCard}>
                    <Text style={styles.statusText}>{connectionText}</Text>
                    <Text style={styles.statusText}>Realtime Stream: {streamState}</Text>
                </View>

                <Text style={styles.heading}>Health Status</Text>
                <View style={styles.statusCard}>
                    <Text style={styles.statusText}>Sleep: {statusText}</Text>
                    <Text style={styles.statusText}>Last Sleep Window: {lastSleepWindowText}</Text>
                    <Text style={styles.statusText}>Last Day/Record Date: {lastDataDate}</Text>
                </View>

                <Text style={styles.heading}>Vitals</Text>
                <View style={styles.statusCard}>
                    <Text style={styles.statusText}>Steps: {formatMaybeNumber(steps)}</Text>
                    <Text style={styles.statusText}>Calories: {formatMaybeNumber(calories)}</Text>
                    <Text style={styles.statusText}>Distance: {formatMaybeNumber(distance, ' m')}</Text>
                    <Text style={styles.statusText}>Heart Rate: {formatMaybeNumber(heartRate, ' bpm')}</Text>
                    <Text style={styles.statusText}>SpO2: {formatMaybeNumber(spo2, ' %')}</Text>
                    <Text style={styles.statusText}>Temperature: {formatMaybeNumber(temperature, ' C')}</Text>
                    <Text style={styles.statusText}>HRV: {formatMaybeNumber(hrv)}</Text>
                </View>

                <Text style={styles.heading}>Events</Text>
                <FlatList
                    data={events}
                    keyExtractor={(_, index) => index.toString()}
                    showsVerticalScrollIndicator={false}
                    contentContainerStyle={styles.eventsContent}
                    renderItem={({ item }) => (
                        <View style={styles.eventItem}>
                            <Text style={styles.eventText}>{item}</Text>
                        </View>
                    )}
                    ListEmptyComponent={<Text style={styles.emptyText}>No events yet</Text>}
                />

                <Text style={styles.heading}>API Upload Debug (Latest)</Text>
                <FlatList
                    data={apiLogs}
                    keyExtractor={(_, index) => `api-${index}`}
                    showsVerticalScrollIndicator={false}
                    contentContainerStyle={styles.eventsContent}
                    renderItem={({ item }) => (
                        <View style={styles.eventItem}>
                            <Text style={styles.eventText}>
                                [{item.time}] {item.type} | {item.status}
                            </Text>
                            <Text style={styles.eventTextMuted}>
                                {truncateText(toJsonSafe(item.details))}
                            </Text>
                        </View>
                    )}
                    ListEmptyComponent={<Text style={styles.emptyText}>No API logs yet</Text>}
                />
            </View>
        </SafeAreaView>
    );
};

export default App;

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#0B0B0B',
    },

    bleContainer: {
        flex: 1,
    },

    eventsContainer: {
        flex: 1,
        paddingHorizontal: 16,
        paddingBottom: 16,
    },

    heading: {
        color: '#FFFFFF',
        fontSize: 18,
        fontWeight: '700',
        marginBottom: 12,
        marginTop: 10,
    },

    statusCard: {
        backgroundColor: '#1C1C1E',
        padding: 14,
        borderRadius: 12,
        marginBottom: 10,
    },

    statusText: {
        color: '#FFFFFF',
        fontSize: 15,
        fontWeight: '600',
        marginBottom: 6,
    },

    eventsContent: {
        paddingBottom: 30,
    },

    eventItem: {
        backgroundColor: '#1C1C1E',
        padding: 12,
        borderRadius: 10,
        marginBottom: 10,
    },

    eventText: {
        color: '#FFFFFF',
        fontSize: 13,
    },

    eventTextMuted: {
        color: '#B5B5B5',
        fontSize: 12,
        marginTop: 6,
    },

    emptyText: {
        color: '#FFFFFF',
        textAlign: 'center',
        marginTop: 30,
    },
});
