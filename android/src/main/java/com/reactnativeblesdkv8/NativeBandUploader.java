package com.reactnativeblesdkv8;

import static com.reactnativeblesdkv8.BandPacket.*;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.json.JSONTokener;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import okhttp3.Call;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import okhttp3.ResponseBody;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.ScheduledThreadPoolExecutor;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import java.util.function.Consumer;
import java.util.function.Supplier;

final class NativeBandUploader {
    private static final int MAX_PENDING = 1024;
    private static final int MAX_RESPONSE_BYTES = 64 * 1024;
    private static final String DEFAULT_ENDPOINT = "/JC_band_data_dump";
    private static final String[] RR_FIELDS = {
            "RRIntervalData", "rrIntervalData", "rrInterval", "rr", "RR", "ppi", "PPI", "ppiData", "PPIData"
    };
    private static final String[][] RECORD_TYPES = {
            {"sleep", "arrayDetailSleepData", "arrayDetailSleepAndActivityData"},
            {"activity", "arrayTotalActivityData", "arrayDetailActivityData", "arrayActivity"},
            {"activityMode", "arrayActivityModeData", "arrayActivityMode"},
            {"heartRateContinuous", "arrayContinuousHR"},
            {"heartRateSingle", "arraySingleHR"},
            {"spo2Automatic", "arrayAutomaticSpo2Data", "arraySpo2"},
            {"spo2Manual", "arrayManualSpo2Data"},
            {"temperature", "arrayTemperatureData", "arrayemperatureData", "arrayTemperature"},
            {"hrv", "arrayHRVData"},
            {"rr", "arrayPPIData", "arrayPpiData", "arrayPPI", "arrayPpi", "arrayRRIntervalData",
                    "arrayRRIntervals", "arrayRRInterval", "ppiData", "ppi", "rrData", "RRIntervalData"}
    };

    private final ScheduledThreadPoolExecutor workers = new ScheduledThreadPoolExecutor(4, runnable -> {
        Thread thread = new Thread(runnable, "V8-band-upload");
        thread.setDaemon(true);
        return thread;
    });
    private final OkHttpClient client = new OkHttpClient.Builder()
            .connectTimeout(0, TimeUnit.MILLISECONDS)
            .writeTimeout(0, TimeUnit.MILLISECONDS)
            .readTimeout(0, TimeUnit.MILLISECONDS)
            .retryOnConnectionFailure(false)
            .build();
    private final Semaphore pending = new Semaphore(MAX_PENDING);
    private final Consumer<Map<String, Object>> statusListener;
    private volatile Config config = new Config(Collections.emptyMap());
    private volatile boolean enabled;
    private volatile boolean closed;

    NativeBandUploader(Consumer<Map<String, Object>> statusListener) {
        this.statusListener = statusListener;
        workers.setExecuteExistingDelayedTasksAfterShutdownPolicy(false);
    }

    void configure(Map<String, Object> options) {
        config = new Config(options);
    }

    void start() {
        enabled = true;
    }

    void stop() {
        enabled = false;
    }

    boolean isEnabled() {
        return enabled;
    }

    void close() {
        closed = true;
        stop();
        workers.shutdownNow();
        client.dispatcher().cancelAll();
        client.connectionPool().evictAll();
    }

    void autoUpload(Map<String, Object> packet) {
        if (enabled) upload(packet);
    }

    void upload(Map<String, Object> packet) {
        Config snapshot = config;
        submit(snapshot, snapshot.endpoint, () -> body(packet, snapshot.deviceId, System.currentTimeMillis()));
    }

    void uploadToEndpoint(String endpoint, Map<String, Object> data) {
        if (endpoint == null || endpoint.isEmpty()) return;
        Config snapshot = config;
        submit(snapshot, endpoint, () -> {
            Map<String, Object> body = fields("deviceId", snapshot.deviceId, "timestamp", timestamp(System.currentTimeMillis()));
            body.putAll(data);
            return body;
        });
    }

    private void submit(Config snapshot, String endpoint, Supplier<Map<String, Object>> bodyFactory) {
        if (closed) return;
        String url = snapshot.baseUrl + "/" + endpoint.trim().replaceFirst("^/+", "");
        if (!pending.tryAcquire()) {
            // Post through the bridge without serializing the packet or waiting on I/O.
            emitStatus(fields("stage", "error", "attempt", 0, "retriesLeft", 0,
                    "url", url, "message", "Native upload queue is full"));
            return;
        }
        try {
            workers.execute(() -> {
                Map<String, Object> body;
                byte[] json;
                try {
                    body = bodyFactory.get();
                    json = toJson(body).toString().getBytes(StandardCharsets.UTF_8);
                } catch (JSONException | RuntimeException error) {
                    pending.release();
                    emitStatus(fields("stage", "error", "attempt", 0, "retriesLeft", 0,
                            "url", url, "message", "Unable to serialize upload body"));
                    return;
                }
                attempt(snapshot, url, body, json, 1);
            });
        } catch (RejectedExecutionException ignored) {
            pending.release(); // The React Native instance is shutting down.
        }
    }

    private void attempt(Config config, String url, Map<String, Object> body, byte[] json, int attempt) {
        if (closed) {
            pending.release();
            return;
        }
        int retriesLeft = config.retries - (attempt - 1);
        Map<String, Object> metadata = fields("attempt", attempt, "retriesLeft", retriesLeft, "url", url,
                "request", fields("method", "POST", "headers", fields("Content-Type", "application/json"), "body", body));
        publish(metadata, "request", null, null);
        Map<String, Object> response = null;
        String failure;
        try {
            Request.Builder request = new Request.Builder().url(url)
                    .post(RequestBody.create(json, MediaType.get("application/json")));
            if (!config.authToken.isEmpty()) request.header("Authorization", config.authToken);
            Call call = client.newCall(request.build());
            call.timeout().timeout(config.timeoutMs, TimeUnit.MILLISECONDS);
            try (Response result = call.execute()) {
                int code = result.code();
                boolean ok = result.isSuccessful();
                Map<String, Object> headers = fields();
                result.headers().toMultimap().forEach((name, values) -> headers.put(name, String.join(", ", values)));
                ResponseBody resultBody = result.body();
                Object responseBody = readResponse(resultBody == null ? null : resultBody.byteStream());
                response = fields("ok", ok, "status", code, "statusText", result.message(),
                        "headers", headers, "body", responseBody);
                failure = ok ? null : "Server responded " + code;
            }
        } catch (IOException | RuntimeException error) {
            failure = error.getMessage() == null ? "Upload failed" : error.getMessage();
        }
        if (failure == null) {
            pending.release();
            publish(metadata, "success", response, null);
            return;
        }
        if (retriesLeft > 0) {
            try {
                workers.schedule(() -> attempt(config, url, body, json, attempt + 1), 500, TimeUnit.MILLISECONDS);
                return;
            } catch (RejectedExecutionException ignored) {
                // The React Native instance is shutting down.
            }
        }
        pending.release();
        publish(metadata, "error", response, failure);
    }

    private void publish(Map<String, Object> metadata, String stage, Map<String, Object> response, String message) {
        Map<String, Object> event = new java.util.LinkedHashMap<>(metadata);
        event.put("stage", stage);
        if (!"request".equals(stage)) event.put("response", response);
        if (message != null) event.put("message", message);
        emitStatus(event);
    }

    private void emitStatus(Map<String, Object> event) {
        if (closed) return;
        try {
            statusListener.accept(event);
        } catch (RuntimeException ignored) {
            // An unavailable React instance must not interrupt the native uploader.
        }
    }

    private static Object toJson(Object value) throws JSONException {
        if (value == null) return JSONObject.NULL;
        if (value instanceof Map) {
            JSONObject object = new JSONObject();
            for (Map.Entry<String, Object> entry : map(value).entrySet()) {
                object.put(entry.getKey(), toJson(entry.getValue()));
            }
            return object;
        }
        if (value instanceof List) {
            JSONArray array = new JSONArray();
            for (Object item : (List<?>) value) array.put(toJson(item));
            return array;
        }
        if (value instanceof Number) return number(value) == null ? JSONObject.NULL : value;
        if (value instanceof String || value instanceof Boolean) return value;
        return String.valueOf(value);
    }

    private static Object readResponse(InputStream input) throws IOException {
        if (input == null) return null;
        try (InputStream stream = input; ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[4096];
            int remaining = MAX_RESPONSE_BYTES;
            while (remaining > 0) {
                int count = stream.read(buffer, 0, Math.min(buffer.length, remaining));
                if (count == -1) break;
                output.write(buffer, 0, count);
                remaining -= count;
            }
            String text = new String(output.toByteArray(), StandardCharsets.UTF_8);
            if (text.isEmpty()) return null;
            try {
                return jsonValue(new JSONTokener(text).nextValue());
            } catch (JSONException ignored) {
                return text;
            }
        }
    }

    private static Object jsonValue(Object value) throws JSONException {
        if (value == JSONObject.NULL) return null;
        if (value instanceof JSONObject) {
            JSONObject object = (JSONObject) value;
            Map<String, Object> result = fields();
            java.util.Iterator<String> keys = object.keys();
            while (keys.hasNext()) {
                String key = keys.next();
                result.put(key, jsonValue(object.get(key)));
            }
            return result;
        }
        if (value instanceof JSONArray) {
            JSONArray array = (JSONArray) value;
            List<Object> result = new ArrayList<>(array.length());
            for (int i = 0; i < array.length(); i++) result.add(jsonValue(array.get(i)));
            return result;
        }
        return value;
    }

    static Map<String, Object> body(Map<String, Object> packet, String deviceId, long now) {
        Map<String, Object> data = map(packet.get("data"));
        Number type = or(number(packet.get("dataType")), -1);
        Object time = first(packet, "packetTimestamp", "collectedAt", "sensorTimestamp", "receivedAt", "timestamp");
        if (!(time instanceof String)) time = timestamp(now);
        Number millis = or(number(packet, "packetTimestampMs", "collectedAtMs", "sensorTimestampMs", "timestampMs"), now);
        Map<String, Object> counts = fields();
        Map<String, Object> lastRecords = fields();
        for (String[] keys : RECORD_TYPES) {
            List<?> records = Collections.emptyList();
            for (int index = 1; index < keys.length; index++) {
                Object candidate = data.get(keys[index]);
                if (candidate instanceof List && !((List<?>) candidate).isEmpty()) {
                    records = (List<?>) candidate;
                    break;
                }
            }
            counts.put(keys[0], records.size());
            lastRecords.put(keys[0], lastRecord(records));
        }
        Map<String, Object> activity = map(lastRecords.get("activity"));
        Map<String, Object> mode = map(lastRecords.get("activityMode"));
        Map<String, Object> hrv = map(lastRecords.get("hrv"));
        Map<String, Object> sleep = lastRecord(data.get("arrayDetailSleepAndActivityData"));
        if (sleep.isEmpty()) sleep = map(lastRecords.get("sleep"));
        Map<String, Object> rr = map(lastRecords.get("rr"));
        Map<String, Object> health = fields(
                "isSleeping", null,
                "steps", or(number(data, "steps", "step", "stepCount", "totalSteps"), number(activity, "steps", "step"), number(mode, "steps", "step")),
                "calories", or(number(data, "calories", "calorie"), number(activity, "calories", "calorie"), number(mode, "calories", "calorie")),
                "distance", or(number(data, "distance"), number(activity, "distance"), number(mode, "distance")),
                "heartRate", or(number(data, "heartRate", "hr"), number(mode, "heartRate", "hr"),
                        number(map(lastRecords.get("heartRateSingle")), "singleHR", "heartRate", "hr"),
                        lastNumber(map(lastRecords.get("heartRateContinuous")).get("arrayHR")), number(hrv, "heartRate", "hr")),
                "spo2", or(number(data, "spo2"), number(map(lastRecords.get("spo2Manual")), "manualSpo2Data", "spo2"),
                        number(map(lastRecords.get("spo2Automatic")), "automaticSpo2Data", "spo2")),
                "temperature", or(number(data, "temperature"), number(map(lastRecords.get("temperature")), "temperature", "bodyTemperature", "axillaryTemperature")),
                "hrv", or(number(data, "hrv"), number(hrv, "hrv")),
                "rrInterval", or(number(data, RR_FIELDS), number(rr, RR_FIELDS), number(rr.get("value"))),
                "stress", or(number(data, "stress"), number(hrv, "stress")),
                "sleepMinutes", number(sleep, "totalSleepTime", "sleepTotalTime", "totalMinutes"),
                "awakeMinutes", number(sleep, "awakeDurationMinutes"),
                "lastSleepStart", first(sleep, "startTime_SleepData", "startTime", "startDate", "date"), "sourceDataType", type);
        return fields("schemaVersion", "2.0-native", "deviceId", deviceId, "bleDeviceUuid", packet.getOrDefault("uuid", ""),
                "timestamp", time, "packetTimestamp", time, "receivedAt", time, "sensorTimestamp", time, "collectedAt", time,
                "timestampMs", millis, "packetTimestampMs", millis, "sensorTimestampMs", millis, "collectedAtMs", millis,
                "collectedAtLocal", packet.getOrDefault("collectedAtLocal", localTimestamp(now)),
                "uploadedAt", timestamp(now), "uploadedAtMs", now, "dataType", type,
                "dataTypeName", uploadTypeName(type.intValue()), "dataEnd", Boolean.TRUE.equals(packet.get("dataEnd")),
                "healthStatus", health, "metrics", fields("records", counts), "data", data, "payload", packet);
    }

    private static Map<String, Object> lastRecord(Object value) {
        if (value instanceof List) {
            List<?> records = (List<?>) value;
            for (int index = records.size() - 1; index >= 0; index--) {
                if (records.get(index) instanceof Map) return map(records.get(index));
            }
        }
        return Collections.emptyMap();
    }

    private static Number lastNumber(Object value) {
        if (value instanceof List) {
            List<?> values = (List<?>) value;
            for (int index = values.size() - 1; index >= 0; index--) {
                Number number = number(values.get(index));
                if (number != null) return number;
            }
        }
        return null;
    }

    private static final class Config {
        final String baseUrl;
        final String endpoint;
        final String authToken;
        final String deviceId;
        final int retries;
        final int timeoutMs;

        Config(Map<String, Object> options) {
            baseUrl = string(options, "baseUrl", "").trim().replaceFirst("/+$", "");
            endpoint = string(options, "endpoint", DEFAULT_ENDPOINT);
            authToken = string(options, "authToken", "");
            deviceId = string(options, "deviceId", "");
            retries = Math.max(0, or(number(options, "retryCount"), 0).intValue());
            timeoutMs = Math.max(1000, or(number(options, "timeoutMs"), 30000).intValue());
        }

        private static String string(Map<String, Object> options, String key, String fallback) {
            Object value = options.get(key);
            return value instanceof String ? (String) value : fallback;
        }
    }
}
