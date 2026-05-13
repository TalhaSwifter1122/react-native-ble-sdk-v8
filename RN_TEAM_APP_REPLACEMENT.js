import React, { useEffect, useMemo, useState } from 'react';
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

const getLast = arr => {
    return Array.isArray(arr) && arr.length > 0 ? arr[arr.length - 1] : null;
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

    const pushEvent = msg => {
        setEvents(prev => [msg, ...prev].slice(0, MAX_EVENTS));
    };

    const statusText = useMemo(() => {
        if (isSleeping === true) return 'Sleeping';
        if (isSleeping === false) return 'Awake';
        return 'Unknown';
    }, [isSleeping]);

    const requestInitialSync = () => {
        getSleepAndActivityHistory(0, null);
        getTotalActivityData(0, null);
        getContinuousHRHistory(0, null);
        getSingleHRHistory(0, null);
        getAutomaticSpo2History(0, null);
        getManualSpo2History(0, null);
        getTemperatureHistory(0, null);
        getHRVHistory(0, null);
        getBatteryLevel();
        getDeviceVersion();
    };

    useEffect(() => {
        RNBootSplash.hide({ fade: true });

        configureServer({
            baseUrl: 'https://api.yourserver.com',
            authToken: 'Bearer YOUR_TOKEN',
            deviceId: 'test-device-001',
            endpoint: '/JC_band_data_dump',
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

                // Re-enable stream after every reconnect.
                setRealtimeData(true);
                startAutoUpload({ enableSleepContext: true });

                requestInitialSync();
            }),

            addBleListener(BleEvents.DISCONNECTED, device => {
                const deviceName = device?.name || device?.uuid || 'device';
                setConnectionText(`Disconnected: ${deviceName}`);
                pushEvent(`Disconnected: ${deviceName}`);
            }),

            addBleListener(BleEvents.DATA, rawPayload => {
                try {
                    const payload = processSleepPayload(rawPayload);

                    const realtime = extractRealtime(payload);
                    const history = extractLatestHistory(payload);

                    if (payload?.isSleeping !== undefined && payload?.isSleeping !== null) {
                        setIsSleeping(Boolean(payload.isSleeping));
                    }

                    if (payload?.lastSleepWindow?.start || payload?.sleepContext?.lastSleepWindow?.start) {
                        const window = payload?.lastSleepWindow || payload?.sleepContext?.lastSleepWindow;
                        const start = window?.start ? new Date(window.start).toLocaleString() : '--';
                        const end = window?.end ? new Date(window.end).toLocaleString() : '--';
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
                        setLastDataDate(history.recordDate);
                    }

                    const type = Number(payload?.dataType);
                    pushEvent(`Data: ${dataTypeName[type] || `Type-${type}`} | end=${Boolean(payload?.dataEnd)}`);
                } catch (err) {
                    pushEvent(`Processing error: ${err?.message || 'unknown'}`);
                }
            }),
        ];

        return () => {
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

    emptyText: {
        color: '#FFFFFF',
        textAlign: 'center',
        marginTop: 30,
    },
});
