/**
 * healthInsights.js
 *
 * Utilities to infer sleep state and attach sleep context to other vitals.
 *
 * Why this exists:
 * - The SDK gives sleep stages and vital histories as separate payloads.
 * - Apps usually need one answer: "Was user sleeping when this vital was measured?"
 */

const DATA_TYPE = {
    DETAIL_SLEEP: 27,
    DYNAMIC_HR: 28,
    STATIC_HR: 29,
    AUTO_SPO2: 45,
    MANUAL_SPO2: 46,
    TEMPERATURE: 48,
    DETAIL_SLEEP_AND_ACTIVITY: 81,
};

const SLEEP_STAGE_AWAKE = 0;
const DEFAULT_SLEEP_LOOKBACK_MINUTES = 24 * 60;

const MENTAL_LEVELS = {
    LOW: 'low',
    MODERATE: 'moderate',
    HIGH: 'high',
};

let _sleepContextState = {
    latestSleepPayload: null,
    sleepWindows: [],
};

let _mentalState = {
    heartRate: null,
    hrv: null,
    spo2: null,
    lastStressScore: null,
    lastAnxietyScore: null,
};

function toDate(value) {
    if (!value) return null;
    if (value instanceof Date && !Number.isNaN(value.getTime())) return value;
    if (typeof value === 'number') {
        const d = new Date(value);
        return Number.isNaN(d.getTime()) ? null : d;
    }
    if (typeof value !== 'string') return null;

    // 1) ISO-8601 / RFC-compatible strings
    const iso = new Date(value);
    if (!Number.isNaN(iso.getTime())) return iso;

    // 2) Common SDK style: "yy-MM-dd HH:mm", "yyyy.MM.dd HH:mm:ss", etc.
    const normalized = value.replace(/[/.]/g, '-').trim();
    const sdkMatch = normalized.match(/^(\d{2}|\d{4})-(\d{1,2})-(\d{1,2})(?:\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?$/);
    if (sdkMatch) {
        const yearRaw = Number(sdkMatch[1]);
        const year = yearRaw < 100 ? (2000 + yearRaw) : yearRaw;
        const month = Number(sdkMatch[2]) - 1;
        const day = Number(sdkMatch[3]);
        const hour = Number(sdkMatch[4] || 0);
        const minute = Number(sdkMatch[5] || 0);
        const second = Number(sdkMatch[6] || 0);
        const d = new Date(year, month, day, hour, minute, second);
        return Number.isNaN(d.getTime()) ? null : d;
    }

    return null;
}

function getArray(payload, candidateKeys) {
    if (!payload || typeof payload !== 'object') return [];
    const data = payload.data && typeof payload.data === 'object' ? payload.data : payload;
    for (const key of candidateKeys) {
        if (Array.isArray(data[key])) return data[key];
    }
    return [];
}

function getSleepRecords(payload) {
    return getArray(payload, [
        'arrayDetailSleepAndActivityData',
        'arrayDetailSleepData',
        'arraySleep',
    ]);
}

function getRecordDate(record) {
    return toDate(record?.date || record?.startDate || record?.startTime || null);
}

function isSleepingStage(stage) {
    return Number(stage) !== SLEEP_STAGE_AWAKE;
}

function buildSleepWindowsFromRecord(record) {
    const start = getRecordDate(record);
    if (!start) return [];

    const stages = Array.isArray(record.arraySleepQuality)
        ? record.arraySleepQuality
        : [];
    if (stages.length === 0) return [];

    let unitMinutes = Number(record.sleepUnitLength || 1);
    if (!Number.isFinite(unitMinutes) || unitMinutes <= 0) unitMinutes = 1;

    const windows = [];
    let i = 0;

    while (i < stages.length) {
        if (!isSleepingStage(stages[i])) {
            i += 1;
            continue;
        }

        let j = i + 1;
        while (j < stages.length && isSleepingStage(stages[j])) {
            j += 1;
        }

        const startMs = start.getTime() + (i * unitMinutes * 60 * 1000);
        const endMs = start.getTime() + (j * unitMinutes * 60 * 1000);

        windows.push({
            start: new Date(startMs),
            end: new Date(endMs),
            durationMinutes: (j - i) * unitMinutes,
            sourceDate: record.date || null,
            sourceStagesStartIndex: i,
            sourceStagesEndIndexExclusive: j,
        });

        i = j;
    }

    return windows;
}

export function buildSleepWindows(sleepPayload) {
    const records = getSleepRecords(sleepPayload);
    const windows = [];

    for (const record of records) {
        windows.push(...buildSleepWindowsFromRecord(record));
    }

    windows.sort((a, b) => a.start.getTime() - b.start.getTime());
    return windows;
}

export function isSleepingAt(dateLike, sleepWindows) {
    const at = toDate(dateLike);
    if (!at || !Array.isArray(sleepWindows)) return null;

    const ts = at.getTime();
    return sleepWindows.some((w) => ts >= w.start.getTime() && ts < w.end.getTime());
}

export function isSleepingFromBlePayload(sleepPayload, options = {}) {
    const sleepWindows = buildSleepWindows(sleepPayload);
    const now = options.now ? toDate(options.now) : new Date();
    const lookbackMinutes = Number(options.lookbackMinutes || DEFAULT_SLEEP_LOOKBACK_MINUTES);

    if (sleepWindows.length === 0 || !now) {
        return {
            isSleepingNow: null,
            lastSleepWindow: null,
            sleepWindows,
        };
    }

    const minTs = now.getTime() - (lookbackMinutes * 60 * 1000);
    const recentWindows = sleepWindows.filter((w) => w.end.getTime() >= minTs);
    const isSleepingNow = isSleepingAt(now, recentWindows);

    return {
        isSleepingNow,
        lastSleepWindow: recentWindows.length ? recentWindows[recentWindows.length - 1] : null,
        sleepWindows: recentWindows,
    };
}

function annotateArray(records, dateKey, sleepWindows) {
    return records.map((r) => {
        const date = toDate(r?.[dateKey]);
        return {
            ...r,
            isSleeping: date ? isSleepingAt(date, sleepWindows) : null,
        };
    });
}

function toFiniteNumber(value) {
    const parsed = typeof value === 'number' ? value : Number(value);
    return Number.isFinite(parsed) ? parsed : null;
}

function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
}

function scoreToLevel(score) {
    if (score >= 70) return MENTAL_LEVELS.HIGH;
    if (score >= 40) return MENTAL_LEVELS.MODERATE;
    return MENTAL_LEVELS.LOW;
}

function readLatestFromArray(array, key) {
    if (!Array.isArray(array) || array.length === 0) return null;
    const latest = array[array.length - 1];
    return toFiniteNumber(latest?.[key]);
}

function readLatestContinuousHr(array) {
    if (!Array.isArray(array) || array.length === 0) return null;
    const latest = array[array.length - 1];
    if (!Array.isArray(latest?.arrayHR) || latest.arrayHR.length === 0) return null;
    return toFiniteNumber(latest.arrayHR[latest.arrayHR.length - 1]);
}

function extractPrimaryMetrics(payload) {
    const data = payload?.data && typeof payload.data === 'object' ? payload.data : {};

    const realtimeHeartRate = toFiniteNumber(data.heartRate ?? data.hr);
    const realtimeSteps = toFiniteNumber(data.steps ?? data.step ?? data.stepCount ?? data.totalSteps);

    const latestSingleHr = readLatestFromArray(data.arraySingleHR, 'singleHR');
    const latestContinuousHr = readLatestContinuousHr(data.arrayContinuousHR);
    const latestSpo2Auto = readLatestFromArray(data.arrayAutomaticSpo2Data, 'automaticSpo2Data');
    const latestSpo2Manual = readLatestFromArray(data.arrayManualSpo2Data, 'manualSpo2Data');
    const latestTemp = readLatestFromArray(data.arrayTemperatureData || data.arrayemperatureData, 'temperature');
    const latestHrv = readLatestFromArray(data.arrayHRVData, 'hrv');

    return {
        steps: realtimeSteps,
        heartRate: realtimeHeartRate ?? latestSingleHr ?? latestContinuousHr,
        spo2: latestSpo2Manual ?? latestSpo2Auto,
        temperature: latestTemp,
        hrv: latestHrv,
    };
}

function computeStressScore(metrics, isSleepingNow) {
    let score = 30;

    if (metrics.heartRate !== null) {
        if (metrics.heartRate >= 110) score += 34;
        else if (metrics.heartRate >= 95) score += 24;
        else if (metrics.heartRate >= 85) score += 14;
        else if (metrics.heartRate <= 55) score += 6;
    }

    if (metrics.hrv !== null) {
        if (metrics.hrv < 20) score += 34;
        else if (metrics.hrv < 30) score += 25;
        else if (metrics.hrv < 45) score += 14;
        else if (metrics.hrv >= 80) score -= 8;
    }

    if (metrics.spo2 !== null) {
        if (metrics.spo2 < 92) score += 16;
        else if (metrics.spo2 < 95) score += 8;
    }

    if (isSleepingNow === true) {
        score -= 20;
    }

    if (_mentalState.heartRate !== null && metrics.heartRate !== null) {
        const deltaHr = metrics.heartRate - _mentalState.heartRate;
        if (deltaHr >= 15) score += 8;
    }

    if (_mentalState.lastStressScore !== null) {
        score = (score * 0.65) + (_mentalState.lastStressScore * 0.35);
    }

    return Math.round(clamp(score, 0, 100));
}

function computeAnxietyScore(metrics, stressScore, isSleepingNow) {
    let score = stressScore * 0.6;

    if (metrics.heartRate !== null) {
        if (metrics.heartRate >= 105) score += 22;
        else if (metrics.heartRate >= 90) score += 14;
    }

    if (metrics.hrv !== null) {
        if (metrics.hrv < 25) score += 24;
        else if (metrics.hrv < 35) score += 14;
    }

    if (isSleepingNow === false) {
        score += 6;
    }

    if (_mentalState.lastAnxietyScore !== null) {
        score = (score * 0.7) + (_mentalState.lastAnxietyScore * 0.3);
    }

    return Math.round(clamp(score, 0, 100));
}

export function estimateMentalWellnessFromPayload(payload, options = {}) {
    const sleepContext = options.sleepContext || payload?.sleepContext || null;
    const isSleepingNow = sleepContext?.isSleepingNow ?? null;

    const incoming = extractPrimaryMetrics(payload);
    const metrics = {
        steps: incoming.steps,
        heartRate: incoming.heartRate ?? _mentalState.heartRate,
        spo2: incoming.spo2 ?? _mentalState.spo2,
        temperature: incoming.temperature,
        hrv: incoming.hrv ?? _mentalState.hrv,
    };

    const stressScore = computeStressScore(metrics, isSleepingNow);
    const anxietyScore = computeAnxietyScore(metrics, stressScore, isSleepingNow);

    _mentalState = {
        ..._mentalState,
        heartRate: metrics.heartRate,
        hrv: metrics.hrv,
        spo2: metrics.spo2,
        lastStressScore: stressScore,
        lastAnxietyScore: anxietyScore,
    };

    return {
        stressScore,
        stressLevel: scoreToLevel(stressScore),
        anxietyScore,
        anxietyLevel: scoreToLevel(anxietyScore),
        inputs: {
            heartRate: metrics.heartRate,
            hrv: metrics.hrv,
            spo2: metrics.spo2,
            isSleepingNow,
        },
        updatedAt: new Date().toISOString(),
    };
}

export function getMentalWellnessState() {
    return {
        ..._mentalState,
        stressLevel: _mentalState.lastStressScore === null
            ? null
            : scoreToLevel(_mentalState.lastStressScore),
        anxietyLevel: _mentalState.lastAnxietyScore === null
            ? null
            : scoreToLevel(_mentalState.lastAnxietyScore),
    };
}

export function buildHealthContext(params) {
    const {
        sleepPayload,
        heartRatePayload,
        spo2Payload,
        temperaturePayload,
        now,
    } = params || {};

    const sleepSummary = isSleepingFromBlePayload(sleepPayload, { now });
    const sleepWindows = sleepSummary.sleepWindows;

    const hrContinuous = annotateArray(
        getArray(heartRatePayload, ['arrayContinuousHR']),
        'date',
        sleepWindows
    );
    const hrSingle = annotateArray(
        getArray(heartRatePayload, ['arraySingleHR']),
        'date',
        sleepWindows
    );
    const spo2Auto = annotateArray(
        getArray(spo2Payload, ['arrayAutomaticSpo2Data', 'arraySpo2']),
        'date',
        sleepWindows
    );
    const spo2Manual = annotateArray(
        getArray(spo2Payload, ['arrayManualSpo2Data']),
        'date',
        sleepWindows
    );
    const temperature = annotateArray(
        getArray(temperaturePayload, ['arrayTemperatureData', 'arrayemperatureData', 'arrayTemperature']),
        'date',
        sleepWindows
    );

    return {
        now: (now ? toDate(now) : new Date())?.toISOString() || null,
        isSleepingNow: sleepSummary.isSleepingNow,
        lastSleepWindow: sleepSummary.lastSleepWindow,
        sleepWindows,
        heartRate: {
            continuous: hrContinuous,
            single: hrSingle,
        },
        spo2: {
            automatic: spo2Auto,
            manual: spo2Manual,
        },
        temperature,
    };
}

export function classifyBlePayload(payload, sleepWindows, options = {}) {
    if (!payload || typeof payload !== 'object') return payload;
    const dataType = Number(payload.dataType);

    if (dataType === DATA_TYPE.DETAIL_SLEEP || dataType === DATA_TYPE.DETAIL_SLEEP_AND_ACTIVITY) {
        return {
            ...payload,
            sleepSummary: isSleepingFromBlePayload(payload, options),
        };
    }

    const data = payload.data && typeof payload.data === 'object' ? payload.data : {};

    if (dataType === DATA_TYPE.DYNAMIC_HR) {
        return {
            ...payload,
            data: {
                ...data,
                arrayContinuousHR: annotateArray(data.arrayContinuousHR || [], 'date', sleepWindows),
            },
        };
    }

    if (dataType === DATA_TYPE.STATIC_HR) {
        return {
            ...payload,
            data: {
                ...data,
                arraySingleHR: annotateArray(data.arraySingleHR || [], 'date', sleepWindows),
            },
        };
    }

    if (dataType === DATA_TYPE.AUTO_SPO2) {
        return {
            ...payload,
            data: {
                ...data,
                arrayAutomaticSpo2Data: annotateArray(data.arrayAutomaticSpo2Data || [], 'date', sleepWindows),
            },
        };
    }

    if (dataType === DATA_TYPE.MANUAL_SPO2) {
        return {
            ...payload,
            data: {
                ...data,
                arrayManualSpo2Data: annotateArray(data.arrayManualSpo2Data || [], 'date', sleepWindows),
            },
        };
    }

    if (dataType === DATA_TYPE.TEMPERATURE) {
        const tempArray = data.arrayTemperatureData || data.arrayemperatureData || [];
        return {
            ...payload,
            data: {
                ...data,
                arrayTemperatureData: annotateArray(tempArray, 'date', sleepWindows),
            },
        };
    }

    return payload;
}

export function isSleepPayload(payload) {
    const dataType = Number(payload?.dataType);
    return dataType === DATA_TYPE.DETAIL_SLEEP || dataType === DATA_TYPE.DETAIL_SLEEP_AND_ACTIVITY;
}

export function resetSleepContextState() {
    _sleepContextState = {
        latestSleepPayload: null,
        sleepWindows: [],
    };

    _mentalState = {
        heartRate: null,
        hrv: null,
        spo2: null,
        lastStressScore: null,
        lastAnxietyScore: null,
    };
}

export function getSleepContextState(now) {
    const at = now ? toDate(now) : new Date();
    const sleepWindows = _sleepContextState.sleepWindows || [];
    return {
        latestSleepPayload: _sleepContextState.latestSleepPayload,
        sleepWindows,
        isSleepingNow: isSleepingAt(at, sleepWindows),
        lastSleepWindow: sleepWindows.length ? sleepWindows[sleepWindows.length - 1] : null,
    };
}

export function updateSleepContextWithPayload(payload, options = {}) {
    if (!isSleepPayload(payload)) {
        return getSleepContextState(options.now);
    }

    const summary = isSleepingFromBlePayload(payload, options);
    _sleepContextState.latestSleepPayload = payload;
    _sleepContextState.sleepWindows = summary.sleepWindows;
    return {
        latestSleepPayload: payload,
        ...summary,
    };
}

export function enrichBlePayloadWithSleepContext(payload, options = {}) {
    if (!payload || typeof payload !== 'object') return payload;

    if (isSleepPayload(payload)) {
        const context = updateSleepContextWithPayload(payload, options);
        const classified = classifyBlePayload(payload, context.sleepWindows, options);

        const mentalWellness = estimateMentalWellnessFromPayload(classified, {
            ...options,
            sleepContext: context,
        });

        return {
            ...classified,
            sleepContext: context,
            mentalWellness,
            data: classified?.data && typeof classified.data === 'object'
                ? {
                    ...classified.data,
                    stressScore: mentalWellness.stressScore,
                    stressLevel: mentalWellness.stressLevel,
                    anxietyScore: mentalWellness.anxietyScore,
                    anxietyLevel: mentalWellness.anxietyLevel,
                }
                : classified?.data,
        };
    }

    const state = getSleepContextState(options.now);
    const classified = classifyBlePayload(payload, state.sleepWindows, options);
    const mentalWellness = estimateMentalWellnessFromPayload(classified, {
        ...options,
        sleepContext: state,
    });

    return {
        ...classified,
        sleepContext: {
            isSleepingNow: state.isSleepingNow,
            lastSleepWindow: state.lastSleepWindow,
            sleepWindows: state.sleepWindows,
        },
        mentalWellness,
        data: classified?.data && typeof classified.data === 'object'
            ? {
                ...classified.data,
                stressScore: mentalWellness.stressScore,
                stressLevel: mentalWellness.stressLevel,
                anxietyScore: mentalWellness.anxietyScore,
                anxietyLevel: mentalWellness.anxietyLevel,
            }
            : classified?.data,
    };
}

/**
 * One-call helper for app event handlers:
 * - updates sleep cache when payload is sleep type
 * - returns a boolean-or-null sleep status for "now"
 */
export function resolveSleepStatusFromBleData(payload, options = {}) {
    const enriched = enrichBlePayloadWithSleepContext(payload, options);
    return {
        isSleepingNow: enriched?.sleepContext?.isSleepingNow ?? null,
        sleepContext: enriched?.sleepContext || null,
        enrichedPayload: enriched,
    };
}

/**
 * Returns latest cached sleep status without needing a new payload.
 */
export function getCurrentSleepStatus(now) {
    const state = getSleepContextState(now);
    return {
        isSleepingNow: state.isSleepingNow,
        lastSleepWindow: state.lastSleepWindow,
        sleepWindows: state.sleepWindows,
    };
}
