/**
 * sleepLogic.js
 *
 * Custom sleep logic layer that runs ON TOP of what the SDK returns.
 *
 * WHY THIS IS NEEDED
 * ──────────────────
 * The SDK binary detects sleep on the device and returns raw stage data:
 *   arraySleepQuality: [2, 2, 1, 0, 1, 2, 3, ...]
 *     0 = awake
 *     1 = light sleep
 *     2 = deep sleep
 *     3 = REM
 *   sleepUnitLength: minutes per element (typically 1 or 2 minutes)
 *
 * We cannot change HOW the device classifies sleep, but we CAN
 * re-interpret those numbers here before sending to your server.
 *
 * WHAT YOU CAN CHANGE
 * ───────────────────
 * 1. Sleep stage remapping     — reclassify SDK stage values to your own
 * 2. Awake threshold           — short awake bursts (e.g. < 3 min) are
 *                                re-labelled as light sleep (common in medical scoring)
 * 3. Sleep window filter       — ignore sleep segments shorter than N minutes
 * 4. Stage label names         — use your own names for each stage
 * 5. Derived metrics           — re-calculate all summary fields from the
 *                                processed stage array
 *
 * USAGE
 * ─────
 * import { configureSleepLogic, processSleepPayload } from 'react-native-ble-sdk-v8';
 *
 * configureSleepLogic({
 *   awakeWindowToIgnoreMinutes: 3,      // brief awakenings < 3 min → light sleep
 *   minimumSleepSessionMinutes: 20,     // sessions < 20 min are discarded
 *   stageRemap: { 1: 'light', 2: 'deep', 3: 'rem', 0: 'awake' },
 * });
 *
 * // In your BleEvents.DATA listener:
 * addBleListener(BleEvents.DATA, (payload) => {
 *   const processed = processSleepPayload(payload);  // apply custom logic
 *   uploadData(processed);                           // send to server
 * });
 */

import { resolveSleepStatusFromBleData } from './healthInsights';

// ─────────────────────────────────────────────────────────────────────────────
// SDK stage constants (do not change — these come from the device)
// ─────────────────────────────────────────────────────────────────────────────
const SDK_STAGE = {
    AWAKE: 0,
    LIGHT: 1,
    DEEP: 2,
    REM: 3,
};

// ─────────────────────────────────────────────────────────────────────────────
// Configuration state
// ─────────────────────────────────────────────────────────────────────────────
let _config = {
    /**
     * Consecutive awake units whose total duration is ≤ this value (minutes)
     * are re-labelled as light sleep. Set to 0 to disable.
     * Medical sleep scoring typically uses 3–5 min.
     */
    awakeWindowToIgnoreMinutes: 0,

    /**
     * Sleep sessions (records) shorter than this total duration are
     * dropped from the output array. Set to 0 to keep all.
     */
    minimumSleepSessionMinutes: 0,

    /**
     * Map SDK stage integer → your custom label string.
     * These labels appear in the 'stages' array of each unit in the output.
     */
    stageRemap: {
        0: 'awake',
        1: 'light',
        2: 'deep',
        3: 'rem',
    },

    /**
     * Override how the SDK's totalSleepTime is calculated.
     * 'sdkValue'  — use what the SDK reported (default)
     * 'computed'  — recalculate from the stage array (excludes awake time)
     */
    totalSleepTimeSource: 'sdkValue',
};

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Configure the sleep processing rules.
 * @param {Object} config  Partial config object — only provided keys are updated.
 */
export function configureSleepLogic(config) {
    _config = { ..._config, ...config };
    if (config.stageRemap) {
        _config.stageRemap = { ..._config.stageRemap, ...config.stageRemap };
    }
}

/**
 * Process a BleEvents.DATA payload that contains sleep data.
 * Returns a NEW payload object with the custom sleep logic applied.
 * Non-sleep payloads are returned unchanged.
 *
 * @param {Object} payload  Raw BleEvents.DATA payload
 * @returns {Object}        Processed payload
 */
export function processSleepPayload(payload) {
    const SLEEP_TYPES = [27, 81]; // DetailSleepData_V8=27, DetailSleepAndActivityData_V8=81

    if (!SLEEP_TYPES.includes(payload.dataType)) {
        const resolved = resolveSleepStatusFromBleData(payload);
        return {
            ...resolved.enrichedPayload,
            isSleeping: resolved.isSleepingNow,
            lastSleepWindow: resolved.sleepContext?.lastSleepWindow ?? null,
        };
    }

    const arrayKey = payload.dataType === 81
        ? 'arrayDetailSleepAndActivityData'
        : 'arrayDetailSleepData';

    const records = payload.data[arrayKey];
    if (!Array.isArray(records)) return payload;

    const processed = records
        .map(record => _processSleepRecord(record))
        .filter(record => record !== null); // null = filtered out by minimumSleepSession

    const processedPayload = {
        ...payload,
        data: {
            ...payload.data,
            [arrayKey]: processed,
        },
    };

    const resolved = resolveSleepStatusFromBleData(processedPayload);
    return {
        ...resolved.enrichedPayload,
        isSleeping: resolved.isSleepingNow,
        lastSleepWindow: resolved.sleepContext?.lastSleepWindow ?? null,
    };
}

/**
 * Process a single sleep record dictionary.
 * Returns null if the record should be discarded.
 *
 * @param {Object} record  One element from arrayDetailSleepData
 * @returns {Object|null}
 */
export function processSleepRecord(record) {
    return _processSleepRecord(record);
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal processing
// ─────────────────────────────────────────────────────────────────────────────

function _processSleepRecord(record) {
    const stageArray = record.arraySleepQuality || [];
    const unitMinutes = record.sleepUnitLength || 1;

    // Step 1: Optionally collapse brief awake windows into light sleep
    const smoothed = _collapseAwakeWindows(stageArray, unitMinutes);

    // Step 2: Derive metrics from the (possibly smoothed) stage array
    const summary = _calculateSummary(smoothed, unitMinutes);

    // Step 3: Filter out sessions shorter than the minimum
    if (_config.minimumSleepSessionMinutes > 0 &&
        summary.totalSleepMinutes < _config.minimumSleepSessionMinutes) {
        return null;
    }

    // Step 4: Map stage integers → label strings for the output
    const labelledStages = smoothed.map(s => _config.stageRemap[s] ?? String(s));

    return {
        // Preserve all original SDK fields
        ...record,

        // Override totalSleepTime if configured
        totalSleepTime: _config.totalSleepTimeSource === 'computed'
            ? summary.totalSleepMinutes
            : (record.totalSleepTime ?? summary.totalSleepMinutes),

        // Computed fields added by this layer
        awakeDurationMinutes: summary.awakeMinutes,
        lightSleepMinutes: summary.lightMinutes,
        deepSleepMinutes: summary.deepMinutes,
        remSleepMinutes: summary.remMinutes,
        sleepEfficiency: summary.sleepEfficiency,  // 0–100 %

        // Human-readable stage labels (same length as arraySleepQuality)
        sleepStageLabels: labelledStages,

        // Keep the smoothed raw stage array for further processing if needed
        arraySleepQualitySmoothed: smoothed,
    };
}

/**
 * Collapse short awake windows into light sleep.
 * e.g. [2, 2, 0, 2, 2] with awakeWindowToIgnore=2min, unitMinutes=1
 * → [2, 2, 1, 2, 2]  (the single awake unit = 1min < 2min threshold → light)
 */
function _collapseAwakeWindows(stages, unitMinutes) {
    const threshold = _config.awakeWindowToIgnoreMinutes;
    if (threshold === 0) return stages.slice();

    const result = stages.slice();
    let i = 0;

    while (i < result.length) {
        if (result[i] === SDK_STAGE.AWAKE) {
            // Find the end of this awake run
            let j = i;
            while (j < result.length && result[j] === SDK_STAGE.AWAKE) j++;
            const runMinutes = (j - i) * unitMinutes;
            if (runMinutes <= threshold) {
                // Replace with light sleep
                for (let k = i; k < j; k++) result[k] = SDK_STAGE.LIGHT;
            }
            i = j;
        } else {
            i++;
        }
    }

    return result;
}

/**
 * Calculate duration summaries from a stage array.
 */
function _calculateSummary(stages, unitMinutes) {
    let awakeMinutes = 0;
    let lightMinutes = 0;
    let deepMinutes = 0;
    let remMinutes = 0;

    for (const s of stages) {
        switch (s) {
            case SDK_STAGE.AWAKE: awakeMinutes += unitMinutes; break;
            case SDK_STAGE.LIGHT: lightMinutes += unitMinutes; break;
            case SDK_STAGE.DEEP: deepMinutes += unitMinutes; break;
            case SDK_STAGE.REM: remMinutes += unitMinutes; break;
        }
    }

    const totalMinutes = stages.length * unitMinutes;
    const totalSleepMinutes = lightMinutes + deepMinutes + remMinutes;
    const sleepEfficiency = totalMinutes > 0
        ? Math.round((totalSleepMinutes / totalMinutes) * 100)
        : 0;

    return {
        awakeMinutes,
        lightMinutes,
        deepMinutes,
        remMinutes,
        totalSleepMinutes,
        sleepEfficiency,
    };
}
