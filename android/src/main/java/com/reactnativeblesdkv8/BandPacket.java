package com.reactnativeblesdkv8;

import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

final class BandPacket {
    private static final DateTimeFormatter ISO = DateTimeFormatter
            .ofPattern("uuuu-MM-dd'T'HH:mm:ss.SSS'Z'").withZone(ZoneId.of("UTC"));
    private static final DateTimeFormatter LOCAL = DateTimeFormatter
            .ofPattern("uuuu-MM-dd HH:mm:ss.SSS xxxxx");

    /** iOS numeric dataType → iOS-style name (mirrors RNBleSdkV8.m dataTypeNameFromNumber). */
    private static final Map<Integer, String> IOS_DT_NAME = new LinkedHashMap<>();
    static {
        IOS_DT_NAME.put(24, "RealTimeStep");
        IOS_DT_NAME.put(25, "TotalActivityData");
        IOS_DT_NAME.put(26, "DetailActivityData");
        IOS_DT_NAME.put(27, "DetailSleepData");
        IOS_DT_NAME.put(28, "DynamicHR");
        IOS_DT_NAME.put(29, "StaticHR");
        IOS_DT_NAME.put(30, "ActivityModeData");
        IOS_DT_NAME.put(41, "HRVData");
        IOS_DT_NAME.put(45, "AutomaticSpo2Data");
        IOS_DT_NAME.put(46, "ManualSpo2Data");
        IOS_DT_NAME.put(48, "TemperatureData");
        IOS_DT_NAME.put(66, "OpenRRInterval");
        IOS_DT_NAME.put(67, "CloseRRInterval");
        IOS_DT_NAME.put(68, "RealtimeRRIntervalData");
        IOS_DT_NAME.put(69, "RealtimePPIData");
        IOS_DT_NAME.put(70, "RealtimePPGData");
        IOS_DT_NAME.put(71, "PPGStartSucceeded");
        IOS_DT_NAME.put(72, "PPGStartFailed");
        IOS_DT_NAME.put(73, "PPGResult");
        IOS_DT_NAME.put(74, "PPGStop");
        IOS_DT_NAME.put(75, "PPGQuit");
        IOS_DT_NAME.put(76, "PPGMeasurementProgress");
        IOS_DT_NAME.put(81, "DetailSleepAndActivityData");
        IOS_DT_NAME.put(82, "PPIData");
    }

    static String uploadTypeName(int type) {
        return IOS_DT_NAME.getOrDefault(type, "Unknown");
    }

    private BandPacket() {}

    static String timestamp(long millis) {
        return ISO.format(Instant.ofEpochMilli(millis));
    }

    static String localTimestamp(long millis) {
        return LOCAL.withZone(ZoneId.systemDefault()).format(Instant.ofEpochMilli(millis));
    }

    static Map<String, Object> fields(Object... pairs) {
        Map<String, Object> result = new LinkedHashMap<>();
        for (int i = 0; i < pairs.length; i += 2) {
            result.put((String) pairs[i], pairs[i + 1]);
        }
        return result;
    }

    @SuppressWarnings("unchecked")
    static Map<String, Object> map(Object value) {
        return value instanceof Map ? (Map<String, Object>) value : Collections.emptyMap();
    }

    static Object first(Map<String, Object> data, String... keys) {
        for (String key : keys) {
            Object value = data.get(key);
            if (value != null) return value;
        }
        return null;
    }

    static Number number(Object value) {
        if (value instanceof Number && Double.isFinite(((Number) value).doubleValue())) return (Number) value;
        if (value instanceof String) {
            try {
                double parsed = Double.parseDouble(((String) value).trim());
                return Double.isFinite(parsed) ? parsed : null;
            } catch (NumberFormatException ignored) {}
        }
        return null;
    }

    static Number number(Map<String, Object> data, String... keys) {
        for (String key : keys) {
            Number value = number(data.get(key));
            if (value != null) return value;
        }
        return null;
    }

    static Number or(Number... values) {
        for (Number value : values) if (value != null) return value;
        return null;
    }

    private static double offset(Map<String, Object> config, String key) {
        Number value = number(config.get(key));
        return value == null ? 0 : value.doubleValue();
    }

    private static void adjust(Map<String, Object> data, String key, double delta) {
        Number value = number(data.get(key));
        if (value != null && delta != 0) data.put(key, Math.max(0, value.doubleValue() + delta));
    }

    private static List<Number> numbers(Object value, boolean hex) {
        List<?> input;
        if (value instanceof List) input = (List<?>) value;
        else if (value instanceof String) {
            String source = ((String) value).replaceAll("[\\[\\]']", "").trim();
            input = java.util.Arrays.asList(source.split("[,\\s]+"));
        } else input = Collections.singletonList(value);
        List<Number> result = new ArrayList<>(input.size());
        for (Object item : input) {
            Number parsed = hex && item instanceof String && ((String) item).matches("[a-fA-F]")
                    ? Integer.parseInt((String) item, 16) : number(item);
            if (parsed != null) result.add(parsed);
        }
        return result;
    }

    static Map<String, Object> normalize(Map<String, Object> vendor, int rawType, int type, String typeName,
                                        String uuid, String name, long millis, Map<String, Object> offsets) {
        String time = timestamp(millis);
        String local = localTimestamp(millis);
        Map<String, Object> packet = fields("dataType", type, "iosDataType", type,
                "rawDataType", rawType, "dataTypeName", typeName, "dataEnd", !Boolean.FALSE.equals(vendor.get("End")),
                "uuid", uuid == null ? "" : uuid, "platform", "android", "rawVendorPayload", vendor);
        if (uuid != null) packet.put("address", uuid);
        if (name != null) packet.put("name", name);
        Map<String, Object> clock = fields("packetTimestamp", time, "receivedAt", time, "collectedAt", time,
                "timestampMs", millis, "packetTimestampMs", millis, "collectedAtMs", millis, "collectedAtLocal", local);
        packet.putAll(clock);
        packet.putAll(fields("timestamp", time, "sensorTimestamp", time, "sensorTimestampMs", millis));

        Object content = first(vendor, "Data", "dicData");
        Map<String, Object> data = new LinkedHashMap<>(map(content));
        if (content != null) packet.putAll(fields("Data", content, "dicData", content));
        if (content instanceof List) {
            String key = historyKey(rawType);
            if (key != null) {
                List<Map<String, Object>> records = new ArrayList<>();
                for (Object item : (List<?>) content) {
                    if (item instanceof Map) records.add(historyRecord(map(item), rawType, offsets));
                }
                data.put(key, records);
            } else {
                data.put("records", content);
            }
        } else {
            normalizeReading(data, rawType, type, offsets, time, millis);
        }
        data.putAll(clock);
        packet.put("data", data);
        return packet;
    }

    private static String historyKey(int type) {
        switch (type) {
            case 24: return "arrayTotalActivityData";
            case 25: return "arrayDetailActivityData";
            case 26: return "arrayDetailSleepData";
            case 27: return "arrayContinuousHR";
            case 28: return "arraySingleHR";
            case 29: return "arrayActivityModeData";
            case 42: return "arrayHRVData";
            case 55: return "arrayManualSpo2Data";
            case 68: return "arrayAutomaticSpo2Data";
            case 59: case 62: return "arrayTemperatureData";
            case 121: return "arrayDetailSleepAndActivityData";
            case 127: return "arrayPPIData";
            default: return null;
        }
    }

    private static Map<String, Object> historyRecord(Map<String, Object> raw, int type, Map<String, Object> config) {
        Map<String, Object> record = new LinkedHashMap<>(raw);
        Object date = first(raw, "Date", "date", "StartTime", "startTime");
        record.put("date", date);
        record.put("startTime", date);
        switch (type) {
            case 24: case 25: case 29:
                record.putAll(fields("steps", number(raw, "Step", "KDetailMinterStep", "steps", "step"),
                        "distance", number(raw, "Distance", "distance"), "calories", number(raw, "Calories", "calories")));
                if (type != 29) adjust(record, "steps", offset(config, "stepsOffset"));
                if (type == 24) record.putAll(fields("step", record.get("steps"),
                        "exerciseMinutes", number(raw, "ExerciseMinutes", "exerciseMinutes"), "goal", number(raw, "Goal", "goal")));
                if (type == 25) record.put("arraySteps", numbers(first(raw, "ArraySteps", "arraySteps"), false));
                if (type == 29) record.putAll(fields("activeMinutes", number(raw, "ActiveMinutes", "activeMinutes"),
                        "heartRate", number(raw, "HeartRate", "heartRate"), "pace", number(raw, "Pace", "pace"),
                        "activityMode", first(raw, "ActivityMode", "activityMode")));
                break;
            case 26: case 121:
                normalizeSleep(record, type == 121, config);
                break;
            case 27:
                List<Number> values = numbers(first(raw, "ArrayDynamicHR", "arrayDynamicHR", "arrayHR"), false);
                double hrOffset = offset(config, "heartRateOffset");
                if (hrOffset != 0) values.replaceAll(value -> Math.max(0, value.doubleValue() + hrOffset));
                record.put("arrayHR", values);
                break;
            case 28:
                record.put("singleHR", number(raw, "StaticHR", "singleHR"));
                adjust(record, "singleHR", offset(config, "heartRateOffset"));
                break;
            case 42:
                record.putAll(fields("hrv", number(raw, "hrvValue", "HRV", "hrv"),
                        "stress", number(raw, "Stress", "stress"), "heartRate", number(raw, "HeartRate", "heartRate")));
                adjust(record, "hrv", offset(config, "hrvOffset"));
                break;
            case 55: case 68:
                String key = type == 55 ? "manualSpo2Data" : "automaticSpo2Data";
                record.put(key, number(raw, "Blood_oxygen", key, "Manual"));
                if (type == 68) record.put("heartRate", number(raw, "HeartRate", "heartRate"));
                adjust(record, key, offset(config, "spo2Offset"));
                break;
            case 59: case 62:
                record.put("temperature", number(raw, "temperature", "Temperature", "axillaryTemperature", "TempData"));
                adjust(record, "temperature", offset(config, "temperatureOffset"));
                break;
            case 127:
                record.put("ppi", number(raw, "PPI", "ppi", "PPIData", "RRIntervalData", "rrInterval"));
                break;
            default:
                break;
        }
        return record;
    }

    private static void normalizeSleep(Map<String, Object> record, boolean combined, Map<String, Object> config) {
        List<Number> stages = numbers(first(record, "Sleep_level", "ArraySleep", "arraySleepQuality"), combined);
        int unit = combined ? 1 : Math.max(1, or(number(record, "sleepUnitLength"), 1).intValue());
        int sleeping = 0;
        for (int i = 0; i < stages.size(); i++) {
            double value = stages.get(i).doubleValue();
            int stage = unit == 1 ? (value == 1 ? 2 : value == 2 ? 1 : value == 3 ? 3 : 0)
                    : (value < 0 || value > 100 ? 0 : value <= 10 ? 2 : value <= 40 ? 1 : 3);
            stages.set(i, stage);
            if (stage != 0) sleeping++;
        }
        Number sleepLength = combined ? null : number(record, "KSleepLength");
        double total = sleepLength == null ? sleeping * unit : sleepLength.doubleValue() * 6;
        double totalOffset = offset(config, "totalSleepTimeOffset");
        double awakeOffset = offset(config, "awakeDurationOffset");
        record.putAll(fields("startTime_SleepData", record.get("date"),
                "endTime", first(record, "EndTime", "endTime"), "arraySleepQuality", stages,
                "sleepUnitLength", unit, "sleepLength", stages.size(), "totalSleepTime", Math.max(0, total + totalOffset)));
        if (combined) record.put("activityData", numbers(first(record, "ActivityData", "activityData"), true));
        if (awakeOffset != 0 || totalOffset != 0) {
            record.put("awakeDurationMinutes", Math.max(0, (stages.size() - sleeping) * unit + awakeOffset));
        }
    }

    private static void normalizeReading(Map<String, Object> data, int rawType, int type, Map<String, Object> config,
                                         String time, long millis) {
        switch (rawType) {
            case 23:
                data.putAll(fields("steps", number(data, "Step", "step", "steps"),
                        "heartRate", number(data, "HeartRate", "heartRate"),
                        "calories", number(data, "Calories", "calories"), "distance", number(data, "Distance", "distance"),
                        "exerciseMinutes", number(data, "ExerciseMinutes", "exerciseMinutes"),
                        "activeMinutes", number(data, "ActiveMinutes", "activeMinutes"),
                        "temperature", number(data, "TempData", "temperature"), "spo2", number(data, "Blood_oxygen", "bloodOxygen", "spo2")));
                adjust(data, "steps", offset(config, "stepsOffset"));
                adjust(data, "heartRate", offset(config, "heartRateOffset"));
                data.putAll(fields("step", data.get("steps"), "stepCount", data.get("steps"), "hr", data.get("heartRate")));
                break;
            case 9:
                data.putAll(fields("battery", number(data, "BatteryLevel", "batteryLevel", "battery"),
                        "charging", first(data, "Chargingstate", "charging"), "voltage", number(data, "Voltage_value", "voltage")));
                break;
            case 11: data.put("deviceVersion", first(data, "DeviceVersion", "deviceVersion")); break;
            case 15: data.put("deviceName", first(data, "DeviceName", "deviceName")); break;
            case 10: data.put("macAddress", first(data, "MacAddress", "macAddress")); break;
            case 0: data.put("deviceTime", first(data, "DeviceTime", "deviceTime")); break;
            case 2:
                data.putAll(fields("sex", first(data, "Gender", "sex"), "age", number(data, "Age", "age"),
                        "height", number(data, "Height", "height"), "weight", number(data, "Weight", "weight"),
                        "stride", number(data, "Stride", "stepLength")));
                break;
            default: break;
        }
        if (type == 68 || type == 69) {
            Number interval = number(data, "RRIntervalData", "rrInterval", "rrIntervalData", "PPI", "ppi", "PPIData");
            if (interval != null) data.putAll(fields("rrInterval", interval, "ppi", interval));
            data.putAll(fields("measurementTime", time, "measurementTimeMs", millis));
        } else if (type == 70) {
            data.putAll(fields("ppgTimestamp", time, "measurementTime", time, "ppgTimestampMs", millis, "measurementTimeMs", millis));
        }
    }
}
