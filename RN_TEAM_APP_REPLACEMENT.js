import React, { useEffect, useRef, useState } from 'react';
import {
    SafeAreaView,
    ScrollView,
    StyleSheet,
    Text,
    View,
} from 'react-native';

import RNBootSplash from 'react-native-bootsplash';
import BleScreen from 'react-native-ble-sdk-v8/src/BleScreen';

import {
    BleEvents,
    addBleListener,
    startAutoUpload,
    stopAutoUpload,
    setRealtimeData,
    configureSleepLogic,
    processSleepPayload,
    getDeviceTime,
    getPersonalInfo,
    getSleepHistory,
    getSleepAndActivityHistory,
    getTotalActivityData,
    getDetailActivityData,
    getActivityModeHistory,
    getContinuousHRHistory,
    getSingleHRHistory,
    getAutomaticSpo2History,
    getManualSpo2History,
    getTemperatureHistory,
    getHRVHistory,
    getPPIHistory,
    getBatteryLevel,
    getDeviceVersion,
    getStepGoal,
    getMacAddress,
} from 'react-native-ble-sdk-v8';

const MAX_EVENTS = 80;
const SLEEP_RULES = {
    sleepStartHour: 21,
    sleepEndHour: 10,
    minimumInactiveMinutes: 45,
    maxStepsInWindow: 10,
    maxHeartRate: 80,
    minimumConfidence: 70,
};

const asArray = value => {
    if (Array.isArray(value)) return value;
    if (value && typeof value === 'object') return [value];
    return [];
};

const toNumberOrNull = value => {
    const parsed = typeof value === 'number' ? value : Number(value);
    return Number.isFinite(parsed) ? parsed : null;
};

const parseSdkDate = value => {
    if (!value) return null;
    if (value instanceof Date) return value;

    if (typeof value === 'number') {
        const millis = value < 1e12 ? value * 1000 : value;
        const numericDate = new Date(millis);
        return Number.isNaN(numericDate.getTime()) ? null : numericDate;
    }

    if (typeof value === 'string' && /^\d+$/.test(value.trim())) {
        const numericValue = Number(value.trim());

        if (Number.isFinite(numericValue)) {
            const millis = numericValue < 1e12 ? numericValue * 1000 : numericValue;
            const numericDate = new Date(millis);

            if (!Number.isNaN(numericDate.getTime())) {
                return numericDate;
            }
        }
    }

    const normalized =
        typeof value === 'string'
            ? value.replace(/\./g, '-').replace(' ', 'T')
            : value;

    const date = new Date(normalized);
    return Number.isNaN(date.getTime()) ? null : date;
};

const formatLocalDateTime = value => {
    const date = parseSdkDate(value);

    return date
        ? date.toLocaleString([], {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
        })
        : '--';
};

const formatDurationMinutes = value => {
    const minutes = toNumberOrNull(value);

    if (minutes === null) return '--';

    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;

    return hours <= 0 ? `${mins}m` : `${hours}h ${mins}m`;
};

const getDateKey = value => {
    const date = parseSdkDate(value);
    if (!date) return null;
    return date.toISOString().split('T')[0];
};

const getWeekStart = dateValue => {
    const date = parseSdkDate(dateValue);
    if (!date) return null;

    const cloned = new Date(date);
    const day = cloned.getDay();
    const diff = cloned.getDate() - day + (day === 0 ? -6 : 1);

    cloned.setDate(diff);
    cloned.setHours(0, 0, 0, 0);

    return cloned;
};

const isCurrentWeek = value => {
    const date = parseSdkDate(value);
    if (!date) return false;

    const currentWeekStart = getWeekStart(new Date());
    if (!currentWeekStart) return false;

    const nextWeekStart = new Date(currentWeekStart);
    nextWeekStart.setDate(nextWeekStart.getDate() + 7);

    return date >= currentWeekStart && date < nextWeekStart;
};

const getSleepRecordRange = record => {
    if (!record) return { start: null, end: null };

    const start = parseSdkDate(
        record.startTime_SleepData ??
        record.startTime ??
        record.startDate ??
        record.beginTime ??
        record.date,
    );

    const minutes = toNumberOrNull(
        record.totalSleepTime ??
        record.sleepTotalTime ??
        record.sleepMinutes ??
        record.totalMinutes ??
        record.duration,
    );

    const explicitEnd = parseSdkDate(
        record.endTime_SleepData ??
        record.endTime ??
        record.endDate ??
        record.stopTime ??
        record.finishTime,
    );

    const end =
        explicitEnd ||
        (start && minutes ? new Date(start.getTime() + minutes * 60000) : null);

    return { start, end };
};

const getSleepRecordMinutes = record => {
    if (!record) return null;

    const explicitMinutes = toNumberOrNull(
        record.totalSleepTime ??
        record.sleepTotalTime ??
        record.sleepMinutes ??
        record.totalMinutes ??
        record.duration,
    );

    if (explicitMinutes !== null) return explicitMinutes;

    const { start, end } = getSleepRecordRange(record);
    if (!start || !end) return null;

    const diffMinutes = Math.round((end.getTime() - start.getTime()) / 60000);
    return diffMinutes > 0 ? diffMinutes : null;
};

const getSleepRecordTimeValue = record => {
    const { end, start } = getSleepRecordRange(record);
    return (end || start)?.getTime() || 0;
};

const mergeHistoryEntries = (prev, incoming) => {
    const combined = [...incoming, ...prev].filter(
        item => item?.value !== null && item?.value !== undefined,
    );

    const dedupedMap = new Map();

    combined.forEach(item => {
        const date = parseSdkDate(item.time);
        const iso = date ? date.toISOString() : String(item.time || '');
        const key = `${item.value}-${iso}`;

        if (!dedupedMap.has(key)) {
            dedupedMap.set(key, {
                value: item.value,
                time: date || item.time || new Date(),
            });
        }
    });

    return [...dedupedMap.values()]
        .sort((a, b) => {
            const aTime = parseSdkDate(a.time)?.getTime() || 0;
            const bTime = parseSdkDate(b.time)?.getTime() || 0;
            return bTime - aTime;
        });
};

const mergeSleepRecords = (prev, incoming) => {
    const combined = [...prev, ...incoming];
    const dedupedMap = new Map();

    combined.forEach(item => {
        const { start, end } = getSleepRecordRange(item);
        const key = `${start?.toISOString() || ''}-${end?.toISOString() || ''}-${getSleepRecordMinutes(item) ?? 'na'
            }`;

        if (!dedupedMap.has(key)) {
            dedupedMap.set(key, item);
        }
    });

    return [...dedupedMap.values()]
        .sort((a, b) => getSleepRecordTimeValue(a) - getSleepRecordTimeValue(b));
};

const extractSleepRecords = data => {
    if (!data) return [];

    const possibleArrays = [
        data.arrayDetailSleepData,
        data.arraySleepData,
        data.sleepData,
        data.arraySleepDetailData,
    ];

    return possibleArrays.find(Array.isArray) || [];
};

const extractSleepAndActivityRecords = data => {
    if (!data) return [];

    const possibleArrays = [
        data.arrayDetailSleepAndActivityData,
        data.arraySleepAndActivityData,
    ];

    return possibleArrays.find(Array.isArray) || [];
};

const getSleepActivityRecordStart = record => {
    if (!record) return null;

    return parseSdkDate(
        record.startTime_SleepData ??
        record.startTime ??
        record.startDate ??
        record.beginTime ??
        record.date,
    );
};

const getSleepActivityRecordMinutes = record => {
    if (!record) return null;

    const explicitMinutes = toNumberOrNull(
        record.totalSleepTime ?? record.sleepTotalTime ?? record.totalMinutes,
    );

    if (explicitMinutes !== null && explicitMinutes > 0) return explicitMinutes;

    const sleepQuality = Array.isArray(record.arraySleepQuality)
        ? record.arraySleepQuality
        : [];

    const unitLength = toNumberOrNull(record.sleepUnitLength) || 1;

    if (sleepQuality.length === 0) return null;

    const sleepingUnits = sleepQuality.filter(value =>
        [1, 2, 3].includes(Number(value)),
    ).length;

    return sleepingUnits > 0 ? sleepingUnits * unitLength : null;
};

const getSleepActivityRecordEnd = record => {
    if (!record) return null;

    const explicitEnd = parseSdkDate(
        record.endTime_SleepData ??
        record.endTime ??
        record.endDate ??
        record.stopTime,
    );

    if (explicitEnd) return explicitEnd;

    const start = getSleepActivityRecordStart(record);
    const minutes = getSleepActivityRecordMinutes(record);

    if (!start || minutes === null) return null;

    return new Date(start.getTime() + minutes * 60000);
};

const mergeSleepActivityRecords = (prev, incoming) => {
    const combined = [...prev, ...incoming];
    const dedupedMap = new Map();

    combined.forEach(item => {
        const start = getSleepActivityRecordStart(item);
        const minutes = getSleepActivityRecordMinutes(item);
        const key = `${start?.toISOString() || ''}-${minutes ?? 'na'}`;

        if (!dedupedMap.has(key)) {
            dedupedMap.set(key, item);
        }
    });

    return [...dedupedMap.values()]
        .sort((a, b) => {
            const aTime = getSleepActivityRecordStart(a)?.getTime() || 0;
            const bTime = getSleepActivityRecordStart(b)?.getTime() || 0;
            return aTime - bTime;
        });
};

const getSleepStageMinutes = record => {
    const unitLength = toNumberOrNull(record?.sleepUnitLength) || 1;

    const stages = Array.isArray(record?.arraySleepQuality)
        ? record.arraySleepQuality
        : [];

    if (stages.length === 0) {
        return (
            toNumberOrNull(
                record?.totalSleepTime ??
                record?.sleepTotalTime ??
                record?.sleepMinutes ??
                record?.totalMinutes ??
                record?.duration,
            ) || 0
        );
    }

    return (
        stages.filter(value => [1, 2, 3].includes(Number(value))).length *
        unitLength
    );
};

const syncSleepDurationFromType27 = records => {
    const normalized = records
        .map(item => {
            const start = parseSdkDate(
                item.startTime_SleepData ??
                item.startTime ??
                item.startDate ??
                item.beginTime ??
                item.date,
            );

            const totalMinutes = toNumberOrNull(
                item.totalSleepTime ??
                item.sleepTotalTime ??
                item.sleepMinutes ??
                item.totalMinutes ??
                item.duration,
            );

            const asleepMinutes = getSleepStageMinutes(item);

            if (!start || !totalMinutes || asleepMinutes <= 0) return null;

            const end = new Date(start.getTime() + totalMinutes * 60000);

            return {
                start,
                end,
                minutes: asleepMinutes,
                rawMinutes: totalMinutes,
            };
        })
        .filter(Boolean)
        .sort((a, b) => a.start.getTime() - b.start.getTime());

    if (normalized.length === 0) return null;

    const latestEnd = normalized[normalized.length - 1].end;

    const nightEnd = new Date(latestEnd);
    nightEnd.setHours(12, 0, 0, 0);

    const nightStart = new Date(nightEnd);
    nightStart.setDate(nightStart.getDate() - 1);
    nightStart.setHours(18, 0, 0, 0);

    const nightRecords = normalized.filter(item => {
        return item.end > nightStart && item.start < nightEnd;
    });

    if (nightRecords.length === 0) return null;

    const sessions = [];

    nightRecords.forEach(item => {
        const last = sessions[sessions.length - 1];

        if (!last) {
            sessions.push({ ...item });
            return;
        }

        const gapMinutes = Math.round(
            (item.start.getTime() - last.end.getTime()) / 60000,
        );

        if (gapMinutes <= 90) {
            last.end = item.end > last.end ? item.end : last.end;
            last.minutes += item.minutes;
            last.rawMinutes += item.rawMinutes;
        } else {
            sessions.push({ ...item });
        }
    });

    return sessions.reduce((best, item) => {
        if (!best) return item;
        return item.minutes > best.minutes ? item : best;
    }, null);
};

const calculateWeeklySteps = records => {
    const weeklyRecords = records.filter(item => isCurrentWeek(item.date));
    const grouped = {};

    weeklyRecords.forEach(item => {
        const key = getDateKey(item.date);
        if (!key) return;

        if (!grouped[key]) {
            grouped[key] = {
                date: key,
                steps: 0,
                calories: 0,
                distance: 0,
            };
        }

        grouped[key].steps += Number(item.step || item.steps || 0);
        grouped[key].calories += Number(item.calories || 0);
        grouped[key].distance += Number(item.distance || 0);
    });

    const daily = Object.values(grouped);

    return {
        totalSteps: daily.reduce((sum, item) => sum + item.steps, 0),
        totalCalories: daily.reduce((sum, item) => sum + item.calories, 0),
        totalDistance: daily.reduce((sum, item) => sum + item.distance, 0),
        averageSteps: daily.length
            ? Math.round(daily.reduce((sum, item) => sum + item.steps, 0) / daily.length)
            : 0,
        daily,
    };
};

const calculateWeeklySleep = records => {
    const grouped = {};

    records.forEach(item => {
        const start = parseSdkDate(
            item.startTime_SleepData ??
            item.startTime ??
            item.startDate ??
            item.beginTime ??
            item.date,
        );

        if (!start || !isCurrentWeek(start)) return;

        const key = getDateKey(start);
        if (!key) return;

        if (!grouped[key]) {
            grouped[key] = {
                date: key,
                sleepMinutes: 0,
            };
        }

        grouped[key].sleepMinutes += getSleepStageMinutes(item);
    });

    const daily = Object.values(grouped);

    return {
        totalSleepMinutes: daily.reduce((sum, item) => sum + item.sleepMinutes, 0),
        averageSleepMinutes: daily.length
            ? Math.round(
                daily.reduce((sum, item) => sum + item.sleepMinutes, 0) / daily.length,
            )
            : 0,
        daily,
    };
};

const extractRealtime = payload => {
    const data = payload?.data || {};

    return {
        steps: toNumberOrNull(data.steps ?? data.step ?? data.stepCount),
        calories: toNumberOrNull(data.calories),
        distance: toNumberOrNull(data.distance),
        heartRate: toNumberOrNull(data.heartRate ?? data.hr),
    };
};

const RR_ARRAY_KEYS = [
    'arrayPPIData',
    'arrayPpiData',
    'arrayPPI',
    'arrayPpi',
    'arrayRRIntervalData',
    'arrayRRIntervals',
    'arrayRRInterval',
    'ppiData',
    'ppi',
    'rrData',
    'RRIntervalData',
];

const extractRRRecords = data => {
    if (!data) return [];

    const records = [];

    RR_ARRAY_KEYS.forEach(key => {
        const value = data[key];

        if (Array.isArray(value)) {
            value.forEach(item => {
                if (item && typeof item === 'object') {
                    records.push(item);
                } else if (item !== null && item !== undefined) {
                    records.push({ rrInterval: item });
                }
            });
        } else if (value && typeof value === 'object') {
            records.push(value);
        } else if (value !== null && value !== undefined) {
            records.push({ rrInterval: value });
        }
    });

    return records;
};

const getRRRecordValue = record => {
    if (!record) return undefined;

    return (
        record.rrInterval ??
        record.RRInterval ??
        record.RRIntervalData ??
        record.rrIntervalData ??
        record.rr ??
        record.RR ??
        record.ppi ??
        record.PPI ??
        record.ppiData ??
        record.PPIData ??
        record.ppiValue ??
        record.rrValue ??
        record.value
    );
};

const getRRRecordTime = record => (
    record?.measurementTime ??
    record?.measureTime ??
    record?.collectedAt ??
    record?.packetTimestamp ??
    record?.sensorTimestamp ??
    record?.receivedAt ??
    record?.timestamp ??
    record?.date ??
    record?.time ??
    new Date()
);

const mergeRawPackets = (prev, incoming) => {
    const combined = [...prev, ...incoming];
    const dedupedMap = new Map();

    combined.forEach(item => {
        const dataType = item?.dataType ?? 'unknown';
        const uuid = item?.uuid ?? '';
        const receivedAt = item?.receivedAt ?? '';
        const data = item?.data ? JSON.stringify(item.data) : '';
        const key = `${dataType}-${uuid}-${receivedAt}-${data}`;

        if (!dedupedMap.has(key)) {
            dedupedMap.set(key, item);
        }
    });

    return [...dedupedMap.values()];
};

const getRawPacketCounts = packets => (
    packets.reduce((counts, packet) => {
        const key = String(packet?.dataType ?? 'unknown');
        counts[key] = (counts[key] || 0) + 1;
        return counts;
    }, {})
);

const isInSleepTimeWindow = (date = new Date()) => {
    const hour = date.getHours();
    return hour >= SLEEP_RULES.sleepStartHour || hour <= SLEEP_RULES.sleepEndHour;
};

const calculateSleepConfidence = ({
    steps = 0,
    heartRate = null,
    inactiveMinutes = 0,
    isSdkSleeping = false,
    timestamp = new Date(),
}) => {
    let score = 0;

    if (isInSleepTimeWindow(timestamp)) score += 30;
    if (inactiveMinutes >= SLEEP_RULES.minimumInactiveMinutes) score += 30;
    if (steps <= SLEEP_RULES.maxStepsInWindow) score += 20;
    if (heartRate !== null && heartRate <= SLEEP_RULES.maxHeartRate) score += 15;
    if (isSdkSleeping) score += 5;

    return Math.min(score, 100);
};

const getCustomSleepStatus = ({
    steps,
    heartRate,
    inactiveMinutes,
    isSdkSleeping,
    timestamp,
}) => {
    const confidence = calculateSleepConfidence({
        steps,
        heartRate,
        inactiveMinutes,
        isSdkSleeping,
        timestamp,
    });

    return {
        isSleeping: confidence >= SLEEP_RULES.minimumConfidence,
        confidence,
    };
};

const MetricCard = ({ title, value, unit, color }) => (
    <View style={styles.metricCard}>
        <Text style={styles.metricTitle}>{title}</Text>

        <Text style={[styles.metricValue, color ? { color } : null]}>
            {value ?? '--'} {unit || ''}
        </Text>
    </View>
);

const HistoryRow = ({ label, value, time, unit }) => (
    <View style={styles.historyRow}>
        <Text style={styles.historyLabel}>{label}</Text>

        <View style={{ flex: 1, marginLeft: 20 }}>
            <Text style={styles.historyValue}>
                {value} {unit || ''}
            </Text>

            <Text style={styles.historyTime}>{formatLocalDateTime(time)}</Text>
        </View>
    </View>
);

const App = () => {
    const [events, setEvents] = useState([]);

    const paginationLocksRef = useRef({});
    const lastSyncedSleepEndRef = useRef(null);
    const activeDeviceUuidRef = useRef(null);

    const [connectionText, setConnectionText] = useState('Waiting for device');
    const [streamState, setStreamState] = useState('idle');

    const [steps, setSteps] = useState(null);
    const [calories, setCalories] = useState(null);
    const [distance, setDistance] = useState(null);
    const [heartRate, setHeartRate] = useState(null);
    const [spo2, setSpo2] = useState(null);
    const [temperature, setTemperature] = useState(null);
    const [hrv, setHrv] = useState(null);
    const [rrInterval, setRrInterval] = useState(null);
    const [stressScore, setStressScore] = useState(null);
    const [stressLevel, setStressLevel] = useState('--');
    const [anxietyScore, setAnxietyScore] = useState(null);
    const [anxietyLevel, setAnxietyLevel] = useState('--');

    const [battery, setBattery] = useState(null);
    const [deviceVersion, setDeviceVersion] = useState('--');

    const [sleepStatus, setSleepStatus] = useState('Unknown');
    const [sleepMinutes, setSleepMinutes] = useState(null);
    const [sleepWindow, setSleepWindow] = useState('--');
    const [sleepHistory, setSleepHistory] = useState([]);

    const [detailActivityHistory, setDetailActivityHistory] = useState([]);
    const [activityModeHistory, setActivityModeHistory] = useState([]);
    const [sleepAndActivityHistory, setSleepAndActivityHistory] = useState([]);
    const [weeklyStepsSummary, setWeeklyStepsSummary] = useState(null);
    const [weeklySleepSummary, setWeeklySleepSummary] = useState(null);

    const [heartRateHistory, setHeartRateHistory] = useState([]);
    const [spo2History, setSpo2History] = useState([]);
    const [temperatureHistory, setTemperatureHistory] = useState([]);
    const [hrvHistory, setHrvHistory] = useState([]);
    const [rrHistory, setRrHistory] = useState([]);
    const [stepHistory, setStepHistory] = useState([]);
    const [rawPacketHistory, setRawPacketHistory] = useState([]);

    const pushEvent = msg => {
        setEvents(prev => [msg, ...prev].slice(0, MAX_EVENTS));
    };

    const addHistoryPoint = (setter, value) => {
        if (value === null || value === undefined) return;

        setter(prev =>
            mergeHistoryEntries(prev, [
                {
                    value,
                    time: new Date(),
                },
            ]),
        );
    };

    const addHistoryRecord = (setter, value, time) => {
        if (value === null || value === undefined) return;

        setter(prev =>
            mergeHistoryEntries(prev, [
                {
                    value,
                    time: time || new Date(),
                },
            ]),
        );
    };

    const resetDeviceDataState = () => {
        paginationLocksRef.current = {};
        lastSyncedSleepEndRef.current = null;

        setSteps(null);
        setCalories(null);
        setDistance(null);
        setHeartRate(null);
        setSpo2(null);
        setTemperature(null);
        setHrv(null);
        setRrInterval(null);
        setStressScore(null);
        setStressLevel('--');
        setAnxietyScore(null);
        setAnxietyLevel('--');

        setBattery(null);
        setDeviceVersion('--');

        setSleepStatus('Unknown');
        setSleepMinutes(null);
        setSleepWindow('--');
        setSleepHistory([]);

        setDetailActivityHistory([]);
        setActivityModeHistory([]);
        setSleepAndActivityHistory([]);
        setWeeklyStepsSummary(null);
        setWeeklySleepSummary(null);

        setHeartRateHistory([]);
        setSpo2History([]);
        setTemperatureHistory([]);
        setHrvHistory([]);
        setRrHistory([]);
        setStepHistory([]);
        setRawPacketHistory([]);
    };

    const requestNextPageIfNeeded = rawPayload => {
        const dataType = Number(rawPayload?.dataType);
        const dataEnd = Boolean(rawPayload?.dataEnd);

        if (dataEnd) {
            paginationLocksRef.current[dataType] = false;
            return;
        }

        if (paginationLocksRef.current[dataType]) return;

        paginationLocksRef.current[dataType] = true;

        setTimeout(() => {
            switch (dataType) {
                case 25:
                    getTotalActivityData(2);
                    break;
                case 26:
                    getDetailActivityData(2);
                    break;
                case 27:
                    getSleepHistory(2);
                    break;
                case 28:
                    getContinuousHRHistory(2);
                    break;
                case 29:
                    getSingleHRHistory(2);
                    break;
                case 30:
                    getActivityModeHistory(2);
                    break;
                case 41:
                    getHRVHistory(2);
                    break;
                case 45:
                    getAutomaticSpo2History(2);
                    break;
                case 46:
                    getManualSpo2History(2);
                    break;
                case 48:
                    getTemperatureHistory(2);
                    break;
                case 81:
                    getSleepAndActivityHistory(2);
                    break;
                case 82:
                    getPPIHistory(2);
                    break;
                default:
                    break;
            }

            paginationLocksRef.current[dataType] = false;
        }, 1200);
    };

    const requestAllHistory = () => {
        getSleepHistory(0);

        setTimeout(() => {
            getSleepAndActivityHistory(0);
        }, 1500);

        setTimeout(() => {
            getTotalActivityData(0);
        }, 3000);

        setTimeout(() => {
            getDetailActivityData(0);
        }, 4500);

        setTimeout(() => {
            getActivityModeHistory(0);
        }, 6000);

        setTimeout(() => {
            getContinuousHRHistory(0);
        }, 7500);

        setTimeout(() => {
            getSingleHRHistory(0);
        }, 9000);

        setTimeout(() => {
            getAutomaticSpo2History(0);
        }, 10500);

        setTimeout(() => {
            getManualSpo2History(0);
        }, 12000);

        setTimeout(() => {
            getTemperatureHistory(0);
        }, 13500);

        setTimeout(() => {
            getHRVHistory(0);
        }, 15000);

        setTimeout(() => {
            getPPIHistory(0);
        }, 16500);

        setTimeout(() => {
            getDeviceTime();
            getPersonalInfo();
            getBatteryLevel();
            getDeviceVersion();
            getStepGoal();
            getMacAddress();
        }, 18000);
    };

    useEffect(() => {
        RNBootSplash.hide({ fade: true });

        configureSleepLogic({
            awakeWindowToIgnoreMinutes: 5,
            minimumSleepSessionMinutes: 45,
            totalSleepTimeSource: 'sdk',
        });

        stopAutoUpload();
        startAutoUpload({ enableSleepContext: true });

        const listeners = [
            addBleListener(BleEvents.CONNECTED, device => {
                const uuid = typeof device?.uuid === 'string' ? device.uuid : null;
                const previousUuid = activeDeviceUuidRef.current;

                // New device session: clear stale values from previous band.
                if (uuid && previousUuid && uuid !== previousUuid) {
                    resetDeviceDataState();
                }

                activeDeviceUuidRef.current = uuid;

                const name = device?.name || uuid || 'Band';

                setConnectionText(`Connected: ${name}`);
                setStreamState('live');
                setRealtimeData(true);
                startAutoUpload({ enableSleepContext: true });

                setTimeout(() => {
                    requestAllHistory();
                }, 1000);

                pushEvent(`Connected: ${name}`);
            }),

            addBleListener(BleEvents.DISCONNECTED, device => {
                const name = device?.name || device?.uuid || 'Band';
                const disconnectedUuid = typeof device?.uuid === 'string' ? device.uuid : null;

                if (!disconnectedUuid || disconnectedUuid === activeDeviceUuidRef.current) {
                    activeDeviceUuidRef.current = null;
                    resetDeviceDataState();
                }

                setConnectionText(`Disconnected: ${name}`);
                setStreamState('stopped');

                pushEvent(`Disconnected: ${name}`);
            }),

            addBleListener(BleEvents.DATA, rawPayload => {
                try {
                    const payloadUuid = typeof rawPayload?.uuid === 'string' ? rawPayload.uuid : null;

                    // Ignore packets from old/stale device sessions when switching bands.
                    if (
                        activeDeviceUuidRef.current &&
                        payloadUuid &&
                        payloadUuid !== activeDeviceUuidRef.current
                    ) {
                        return;
                    }

                    requestNextPageIfNeeded(rawPayload);

                    const rawDataType = Number(rawPayload?.dataType);
                    const rawData = rawPayload?.data || {};

                    setRawPacketHistory(prev =>
                        mergeRawPackets(prev, [
                            {
                                ...rawPayload,
                                receivedAt: new Date().toISOString(),
                            },
                        ]),
                    );

                    if (rawDataType === 25) {
                        const totalRecords = asArray(rawData?.arrayTotalActivityData);

                        if (totalRecords.length > 0) {
                            setWeeklyStepsSummary(calculateWeeklySteps(totalRecords));
                        }
                    }

                    if (rawDataType === 26) {
                        const activityRecords = asArray(rawData?.arrayDetailActivityData);

                        setDetailActivityHistory(prev => {
                            const updated = [...prev, ...activityRecords];
                            setWeeklyStepsSummary(calculateWeeklySteps(updated));
                            return updated;
                        });
                    }

                    if (rawDataType === 30) {
                        const activityModeRecords = asArray(rawData?.arrayActivityModeData);

                        if (activityModeRecords.length > 0) {
                            setActivityModeHistory(prev => [...prev, ...activityModeRecords]);
                        }
                    }

                    if (rawDataType === 27) {
                        const records = extractSleepRecords(rawData);

                        setSleepHistory(prev => {
                            const updated = mergeSleepRecords(prev, records);

                            setWeeklySleepSummary(calculateWeeklySleep(updated));

                            const finalSleep = syncSleepDurationFromType27(updated);

                            if (finalSleep) {
                                setSleepMinutes(finalSleep.minutes);

                                setSleepWindow(
                                    `${formatLocalDateTime(finalSleep.start)} -> ${formatLocalDateTime(
                                        finalSleep.end,
                                    )}`,
                                );

                                lastSyncedSleepEndRef.current = finalSleep.end;
                                setSleepStatus('Awake (Sleep Synced)');
                            }

                            return updated;
                        });
                    }

                    if (rawDataType === 81) {
                        const records = extractSleepAndActivityRecords(rawData);

                        if (records.length > 0) {
                            setSleepAndActivityHistory(prev => {
                                const updated = mergeSleepActivityRecords(prev, records);
                                return updated;
                            });
                        }
                    }

                    const payload = processSleepPayload(rawPayload);
                    const realtime = extractRealtime(payload);
                    const data = payload?.data || {};

                    if (realtime.steps !== null) {
                        setSteps(realtime.steps);
                        addHistoryPoint(setStepHistory, realtime.steps);
                    }

                    if (realtime.calories !== null) {
                        setCalories(realtime.calories);
                    }

                    if (realtime.distance !== null) {
                        setDistance(realtime.distance);
                    }

                    if (realtime.heartRate !== null) {
                        setHeartRate(realtime.heartRate);
                        addHistoryPoint(setHeartRateHistory, realtime.heartRate);
                    }

                    const spo2Records = [
                        ...asArray(data?.arrayAutomaticSpo2Data),
                        ...asArray(data?.arrayManualSpo2Data),
                        ...asArray(rawData?.arrayAutomaticSpo2Data),
                        ...asArray(rawData?.arrayManualSpo2Data),
                    ];

                    if (spo2Records.length === 0 && data?.spo2 !== undefined) {
                        spo2Records.push({
                            automaticSpo2Data: data.spo2,
                            time: new Date(),
                        });
                    }

                    spo2Records.forEach(item => {
                        const value =
                            item.automaticSpo2Data ??
                            item.manualSpo2Data ??
                            item.spo2 ??
                            item.value;

                        const time =
                            item.date ??
                            item.time ??
                            item.measureTime ??
                            item.measurementTime ??
                            item.timestamp ??
                            new Date();

                        if (value !== undefined) {
                            setSpo2(value);
                            addHistoryRecord(setSpo2History, value, time);
                        }
                    });

                    const temperatureRecords = [
                        ...asArray(data?.arrayTemperatureData),
                        ...asArray(rawData?.arrayTemperatureData),
                    ];

                    if (temperatureRecords.length === 0 && data?.temperature !== undefined) {
                        temperatureRecords.push({
                            temperature: data.temperature,
                            time: new Date(),
                        });
                    }

                    temperatureRecords.forEach(item => {
                        const value =
                            item.temperature ??
                            item.bodyTemperature ??
                            item.axillaryTemperature ??
                            item.value;

                        const time =
                            item.date ??
                            item.time ??
                            item.measureTime ??
                            item.measurementTime ??
                            item.timestamp ??
                            new Date();

                        if (value !== undefined) {
                            const numericValue = toNumberOrNull(value);
                            const roundedValue =
                                numericValue === null ? value : Math.round(numericValue * 10) / 10;

                            setTemperature(roundedValue);
                            addHistoryRecord(setTemperatureHistory, roundedValue, time);
                        }
                    });

                    const hrvRecords = [
                        ...asArray(data?.arrayHRVData),
                        ...asArray(rawData?.arrayHRVData),
                    ];

                    hrvRecords.forEach(item => {
                        const value = item.hrv ?? item.hrvData ?? item.value;

                        const time =
                            item.date ??
                            item.time ??
                            item.measureTime ??
                            item.measurementTime ??
                            item.timestamp ??
                            new Date();

                        if (value !== undefined) {
                            setHrv(value);
                            addHistoryRecord(setHrvHistory, value, time);
                        }
                    });

                    const rrRecords = [
                        ...extractRRRecords(data),
                        ...extractRRRecords(rawData),
                    ];

                    rrRecords.forEach(item => {
                        const value = getRRRecordValue(item);
                        const time = getRRRecordTime(item);

                        if (value !== undefined) {
                            const numericValue = toNumberOrNull(value);
                            const nextValue = numericValue === null ? value : numericValue;

                            setRrInterval(nextValue);
                            addHistoryRecord(setRrHistory, nextValue, time);
                        }
                    });

                    const mental = payload?.mentalWellness || {};
                    const nextStress = toNumberOrNull(mental.stressScore);
                    const nextAnxiety = toNumberOrNull(mental.anxietyScore);

                    if (nextStress !== null) setStressScore(nextStress);
                    if (typeof mental.stressLevel === 'string') setStressLevel(mental.stressLevel);

                    if (nextAnxiety !== null) setAnxietyScore(nextAnxiety);
                    if (typeof mental.anxietyLevel === 'string') setAnxietyLevel(mental.anxietyLevel);

                    const inactiveMinutes =
                        payload?.sleepContext?.inactiveMinutes ??
                        payload?.inactiveMinutes ??
                        0;

                    const customSleep = getCustomSleepStatus({
                        steps: realtime.steps ?? 0,
                        heartRate: realtime.heartRate,
                        inactiveMinutes,
                        isSdkSleeping: payload?.isSleeping === true,
                        timestamp: new Date(),
                    });

                    const recentSleepEnd = lastSyncedSleepEndRef.current;
                    const hasRecentSyncedSleep =
                        recentSleepEnd &&
                        new Date().getTime() - recentSleepEnd.getTime() <= 18 * 60 * 60 * 1000;

                    if (!hasRecentSyncedSleep) {
                        setSleepStatus(
                            customSleep.isSleeping
                                ? `Sleeping (${customSleep.confidence}%)`
                                : `Awake (${customSleep.confidence}%)`,
                        );
                    }

                    if (data?.battery !== undefined) {
                        setBattery(data.battery);
                    }

                    if (data?.deviceVersion) {
                        setDeviceVersion(data.deviceVersion);
                    }

                    pushEvent(`Packet received type ${rawPayload?.dataType}`);
                } catch (err) {
                    pushEvent(`Error ${err?.message || 'Unknown error'}`);
                }
            }),
        ];

        return () => {
            stopAutoUpload();

            listeners.forEach(listener => {
                if (listener?.remove) {
                    listener.remove();
                }
            });
        };
    }, []);

    const rawPacketCounts = getRawPacketCounts(rawPacketHistory);
    const rawPacketTypeList = Object.entries(rawPacketCounts)
        .sort(([a], [b]) => {
            const aNumber = Number(a);
            const bNumber = Number(b);

            if (Number.isFinite(aNumber) && Number.isFinite(bNumber)) {
                return aNumber - bNumber;
            }

            return a.localeCompare(b);
        });

    return (
        <SafeAreaView style={styles.container}>
            <ScrollView
                showsVerticalScrollIndicator={false}
                contentContainerStyle={styles.scrollContent}
            >
                <View style={styles.topContainer}>
                    <BleScreen />
                </View>

                <View style={styles.connectionCard}>
                    <View
                        style={[
                            styles.liveBadge,
                            {
                                backgroundColor:
                                    streamState === 'live' ? '#00C853' : '#FF9800',
                            },
                        ]}
                    >
                        <Text style={styles.liveBadgeText}>
                            {streamState.toUpperCase()}
                        </Text>
                    </View>

                    <Text style={styles.connectionText}>{connectionText}</Text>

                    <Text style={styles.infoText}>
                        Upload: Managed by SDK
                    </Text>
                </View>

                <Text style={styles.sectionTitle}>Weekly Summary</Text>

                <View style={styles.summaryCard}>
                    <Text style={styles.summaryTitle}>Weekly Steps</Text>

                    <Text style={styles.summaryValue}>
                        {weeklyStepsSummary?.totalSteps || 0}
                    </Text>

                    <Text style={styles.summarySub}>
                        Average Daily: {weeklyStepsSummary?.averageSteps || 0}
                    </Text>

                    <View style={styles.summaryDivider} />

                    <Text style={styles.summaryTitle}>Weekly Sleep</Text>

                    <Text style={styles.summaryValue}>
                        {formatDurationMinutes(weeklySleepSummary?.totalSleepMinutes || 0)}
                    </Text>

                    <Text style={styles.summarySub}>
                        Average Nightly:{' '}
                        {formatDurationMinutes(weeklySleepSummary?.averageSleepMinutes || 0)}
                    </Text>
                </View>

                <Text style={styles.sectionTitle}>Health Overview</Text>

                <View style={styles.metricsGrid}>
                    <MetricCard title="Steps" value={steps} />
                    <MetricCard title="Calories" value={calories} />
                    <MetricCard title="Distance" value={distance} unit="m" />
                    <MetricCard
                        title="Heart Rate"
                        value={heartRate}
                        unit="bpm"
                        color="#FF5252"
                    />
                    <MetricCard title="SpO2" value={spo2} unit="%" color="#29B6F6" />
                    <MetricCard title="Temperature" value={temperature} unit="C" />
                    <MetricCard title="HRV" value={hrv} />
                    <MetricCard title="RR" value={rrInterval} unit="ms" />
                    <MetricCard title="Battery" value={battery} unit="%" color="#00C853" />
                    <MetricCard title="Stress" value={stressScore} unit="" color="#FFA726" />
                    <MetricCard title="Anxiety" value={anxietyScore} unit="" color="#FF7043" />
                </View>

                <Text style={styles.sectionTitle}>Computed Status</Text>

                <View style={styles.sleepCard}>
                    <Text style={styles.sleepLabel}>Stress Level</Text>
                    <Text style={styles.sleepValue}>{stressLevel}</Text>

                    <Text style={styles.sleepLabel}>Anxiety Level</Text>
                    <Text style={styles.sleepValue}>{anxietyLevel}</Text>
                </View>

                <Text style={styles.sectionTitle}>Sleep Analysis</Text>

                <View style={styles.sleepCard}>
                    <Text style={styles.sleepLabel}>Status</Text>
                    <Text style={styles.sleepValue}>{sleepStatus}</Text>

                    <Text style={styles.sleepLabel}>Last Sleep Duration</Text>
                    <Text style={styles.sleepValue}>
                        {formatDurationMinutes(sleepMinutes)}
                    </Text>

                    <Text style={styles.sleepLabel}>Sleep Window</Text>
                    <Text style={styles.sleepWindow}>{sleepWindow}</Text>

                    <Text style={styles.sleepLabel}>Sleep History Records</Text>
                    <Text style={styles.sleepValue}>{sleepHistory.length}</Text>
                </View>

                <Text style={styles.sectionTitle}>All Synced Data</Text>

                <View style={styles.infoCard}>
                    <Text style={styles.infoText}>Raw Packets: {rawPacketHistory.length}</Text>
                    <Text style={styles.infoText}>Sleep Records: {sleepHistory.length}</Text>
                    <Text style={styles.infoText}>
                        Sleep + Activity Records: {sleepAndActivityHistory.length}
                    </Text>
                    <Text style={styles.infoText}>
                        Detail Activity Records: {detailActivityHistory.length}
                    </Text>
                    <Text style={styles.infoText}>
                        Activity Mode Records: {activityModeHistory.length}
                    </Text>
                    <Text style={styles.infoText}>Heart Rate Records: {heartRateHistory.length}</Text>
                    <Text style={styles.infoText}>SpO2 Records: {spo2History.length}</Text>
                    <Text style={styles.infoText}>Temperature Records: {temperatureHistory.length}</Text>
                    <Text style={styles.infoText}>HRV Records: {hrvHistory.length}</Text>
                    <Text style={styles.infoText}>RR / PPI Records: {rrHistory.length}</Text>
                    {rawPacketTypeList.length > 0 ? (
                        <Text style={styles.infoText}>
                            Packet Types: {rawPacketTypeList.map(([type, count]) => `${type}:${count}`).join(', ')}
                        </Text>
                    ) : null}
                </View>

                <Text style={styles.sectionTitle}>Weekly Sleep History</Text>

                <View style={styles.historyCard}>
                    {!weeklySleepSummary?.daily?.length ? (
                        <Text style={styles.emptyText}>No Weekly Sleep Data</Text>
                    ) : (
                        weeklySleepSummary.daily.map((item, index) => (
                            <HistoryRow
                                key={`weekly-sleep-${index}`}
                                label="Sleep"
                                value={formatDurationMinutes(item.sleepMinutes)}
                                time={item.date}
                            />
                        ))
                    )}
                </View>

                <Text style={styles.sectionTitle}>Weekly Steps History</Text>

                <View style={styles.historyCard}>
                    {!weeklyStepsSummary?.daily?.length ? (
                        <Text style={styles.emptyText}>No Weekly Step Data</Text>
                    ) : (
                        weeklyStepsSummary.daily.map((item, index) => (
                            <HistoryRow
                                key={`weekly-step-${index}`}
                                label="Steps"
                                value={item.steps}
                                time={item.date}
                            />
                        ))
                    )}
                </View>

                <Text style={styles.sectionTitle}>Heart Rate History</Text>

                <View style={styles.historyCard}>
                    {heartRateHistory.length === 0 ? (
                        <Text style={styles.emptyText}>No Heart Rate History</Text>
                    ) : (
                        heartRateHistory.slice(0, 10).map((item, index) => (
                            <HistoryRow
                                key={`hr-${index}`}
                                label="Heart Rate"
                                value={item.value}
                                unit="bpm"
                                time={item.time}
                            />
                        ))
                    )}
                </View>

                <Text style={styles.sectionTitle}>SpO2 History</Text>

                <View style={styles.historyCard}>
                    {spo2History.length === 0 ? (
                        <Text style={styles.emptyText}>No SpO2 History</Text>
                    ) : (
                        spo2History.slice(0, 10).map((item, index) => (
                            <HistoryRow
                                key={`spo2-${index}`}
                                label="SpO2"
                                value={item.value}
                                unit="%"
                                time={item.time}
                            />
                        ))
                    )}
                </View>

                <Text style={styles.sectionTitle}>Temperature History</Text>

                <View style={styles.historyCard}>
                    {temperatureHistory.length === 0 ? (
                        <Text style={styles.emptyText}>No Temperature History</Text>
                    ) : (
                        temperatureHistory.slice(0, 10).map((item, index) => (
                            <HistoryRow
                                key={`temp-${index}`}
                                label="Temperature"
                                value={item.value}
                                unit="C"
                                time={item.time}
                            />
                        ))
                    )}
                </View>

                <Text style={styles.sectionTitle}>HRV History</Text>

                <View style={styles.historyCard}>
                    {hrvHistory.length === 0 ? (
                        <Text style={styles.emptyText}>No HRV History</Text>
                    ) : (
                        hrvHistory.slice(0, 10).map((item, index) => (
                            <HistoryRow
                                key={`hrv-${index}`}
                                label="HRV"
                                value={item.value}
                                time={item.time}
                            />
                        ))
                    )}
                </View>

                <Text style={styles.sectionTitle}>RR / PPI History</Text>

                <View style={styles.historyCard}>
                    {rrHistory.length === 0 ? (
                        <Text style={styles.emptyText}>No RR / PPI History</Text>
                    ) : (
                        rrHistory.slice(0, 10).map((item, index) => (
                            <HistoryRow
                                key={`rr-${index}`}
                                label="RR"
                                value={item.value}
                                unit="ms"
                                time={item.time}
                            />
                        ))
                    )}
                </View>

                <Text style={styles.sectionTitle}>Activity Mode History</Text>

                <View style={styles.historyCard}>
                    {activityModeHistory.length === 0 ? (
                        <Text style={styles.emptyText}>No Activity Mode History</Text>
                    ) : (
                        activityModeHistory.slice(0, 10).map((item, index) => (
                            <HistoryRow
                                key={`activity-mode-${index}`}
                                label={`Mode ${item.activityMode ?? item.mode ?? '--'}`}
                                value={item.heartRate ?? item.step ?? item.calories ?? '--'}
                                unit={item.heartRate ? 'bpm' : ''}
                                time={item.date ?? item.startTime ?? item.time}
                            />
                        ))
                    )}
                </View>

                <Text style={styles.sectionTitle}>Step History</Text>

                <View style={styles.historyCard}>
                    {stepHistory.length === 0 ? (
                        <Text style={styles.emptyText}>No Step History</Text>
                    ) : (
                        stepHistory.slice(0, 10).map((item, index) => (
                            <HistoryRow
                                key={`step-${index}`}
                                label="Steps"
                                value={item.value}
                                time={item.time}
                            />
                        ))
                    )}
                </View>

                <Text style={styles.sectionTitle}>Device Information</Text>

                <View style={styles.infoCard}>
                    <Text style={styles.infoText}>Firmware Version: {deviceVersion}</Text>
                    <Text style={styles.infoText}>Battery Level: {battery ?? '--'}%</Text>
                </View>

                <Text style={styles.sectionTitle}>Band Events</Text>

                <View style={styles.logsCard}>
                    {events.length === 0 ? (
                        <Text style={styles.emptyText}>No Events</Text>
                    ) : (
                        events.map((item, index) => (
                            <View key={index} style={styles.logItem}>
                                <Text style={styles.logText}>{item}</Text>
                            </View>
                        ))
                    )}
                </View>
            </ScrollView>
        </SafeAreaView>
    );
};

export default App;

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#0B0B0B',
    },

    scrollContent: {
        paddingBottom: 60,
    },

    topContainer: {
        minHeight: 300,
    },

    connectionCard: {
        marginHorizontal: 16,
        marginTop: 12,
        backgroundColor: '#171717',
        borderRadius: 18,
        padding: 18,
    },

    connectionText: {
        color: '#FFFFFF',
        fontSize: 16,
        fontWeight: '600',
        marginTop: 12,
    },

    liveBadge: {
        alignSelf: 'flex-start',
        paddingHorizontal: 12,
        paddingVertical: 6,
        borderRadius: 50,
    },

    liveBadgeText: {
        color: '#FFFFFF',
        fontSize: 12,
        fontWeight: '700',
    },

    sectionTitle: {
        color: '#FFFFFF',
        fontSize: 20,
        fontWeight: '700',
        marginTop: 24,
        marginBottom: 14,
        marginHorizontal: 16,
    },

    metricsGrid: {
        flexDirection: 'row',
        flexWrap: 'wrap',
        justifyContent: 'space-between',
        paddingHorizontal: 16,
    },

    metricCard: {
        width: '48%',
        backgroundColor: '#171717',
        borderRadius: 18,
        padding: 18,
        marginBottom: 14,
    },

    metricTitle: {
        color: '#BDBDBD',
        fontSize: 14,
        marginBottom: 10,
    },

    metricValue: {
        color: '#FFFFFF',
        fontSize: 24,
        fontWeight: '700',
    },

    summaryCard: {
        backgroundColor: '#171717',
        borderRadius: 18,
        marginHorizontal: 16,
        padding: 20,
    },

    summaryTitle: {
        color: '#BDBDBD',
        fontSize: 14,
        marginTop: 12,
    },

    summaryValue: {
        color: '#FFFFFF',
        fontSize: 32,
        fontWeight: '700',
        marginTop: 6,
    },

    summarySub: {
        color: '#9E9E9E',
        fontSize: 14,
        marginTop: 4,
    },

    summaryDivider: {
        height: 1,
        backgroundColor: '#2A2A2A',
        marginVertical: 20,
    },

    sleepCard: {
        backgroundColor: '#171717',
        borderRadius: 18,
        marginHorizontal: 16,
        padding: 18,
    },

    sleepLabel: {
        color: '#BDBDBD',
        fontSize: 13,
        marginTop: 12,
    },

    sleepValue: {
        color: '#FFFFFF',
        fontSize: 26,
        fontWeight: '700',
        marginTop: 6,
    },

    sleepWindow: {
        color: '#FFFFFF',
        fontSize: 15,
        marginTop: 6,
        lineHeight: 24,
    },

    historyCard: {
        backgroundColor: '#171717',
        borderRadius: 18,
        marginHorizontal: 16,
        padding: 16,
    },

    historyRow: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        borderBottomWidth: 1,
        borderBottomColor: '#2A2A2A',
        paddingVertical: 12,
    },

    historyLabel: {
        color: '#FFFFFF',
        fontSize: 14,
        fontWeight: '600',
    },

    historyValue: {
        color: '#FFFFFF',
        fontSize: 16,
        fontWeight: '700',
        textAlign: 'right',
    },

    historyTime: {
        color: '#9E9E9E',
        fontSize: 12,
        marginTop: 4,
        textAlign: 'right',
    },

    infoCard: {
        backgroundColor: '#171717',
        borderRadius: 18,
        marginHorizontal: 16,
        padding: 18,
    },

    infoText: {
        color: '#FFFFFF',
        fontSize: 15,
        marginTop: 8,
    },

    logsCard: {
        backgroundColor: '#171717',
        borderRadius: 18,
        marginHorizontal: 16,
        padding: 16,
    },

    logItem: {
        paddingVertical: 10,
        borderBottomWidth: 1,
        borderBottomColor: '#2A2A2A',
    },

    logText: {
        color: '#FFFFFF',
        fontSize: 13,
        lineHeight: 20,
    },

    emptyText: {
        color: '#9E9E9E',
        textAlign: 'center',
        marginVertical: 20,
    },
});
