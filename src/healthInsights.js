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

let _sleepContextState = {
    latestSleepPayload: null,
    sleepWindows: [],
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
        return {
            ...classified,
            sleepContext: context,
        };
    }

    const state = getSleepContextState(options.now);
    const classified = classifyBlePayload(payload, state.sleepWindows, options);
    return {
        ...classified,
        sleepContext: {
            isSleepingNow: state.isSleepingNow,
            lastSleepWindow: state.lastSleepWindow,
            sleepWindows: state.sleepWindows,
        },
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
