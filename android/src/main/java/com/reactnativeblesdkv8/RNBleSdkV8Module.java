package com.reactnativeblesdkv8;

import android.Manifest;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.BluetoothStatusCodes;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.LifecycleEventListener;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.ReadableMapKeySetIterator;
import com.facebook.react.bridge.ReadableType;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.jstyle.blesdkv8.Util.BleSDK;
import com.jstyle.blesdkv8.callback.DataListener2301;
import com.jstyle.blesdkv8.model.AutoMode;
import com.jstyle.blesdkv8.model.AutoTestMode;
import com.jstyle.blesdkv8.model.Clock;
import com.jstyle.blesdkv8.model.MyAutomaticHRMonitoring;
import com.jstyle.blesdkv8.model.MyDeviceTime;
import com.jstyle.blesdkv8.model.MyPersonalInfo;
import com.jstyle.blesdkv8.model.MySedentaryReminder;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Queue;
import java.util.UUID;

/**
 * RNBleSdkV8 — unified JCVital / V8 band bridge (Android).
 *
 * Payloads emitted on "RNBleSdkV8.data" keep the RAW Android SDK values so
 * apps keep full control of the data, and additionally expose iOS-parity
 * fields so one consumer works on both platforms:
 *
 *   {
 *     dataType:      <raw Android dataType number, e.g. 27>   // backward compatible
 *     iosDataType:   <iOS-parity dataType number, e.g. 28>
 *     dataTypeName:  <iOS-style name, e.g. "DynamicHR">
 *     dataEnd:       <boolean>
 *     data:          { ...raw parsed map, including "dataType", "End", "Data" ... }
 *     Data:          <raw "Data" content (array or map)>      // backward compatible
 *     dicData:       <same as Data>                            // backward compatible
 *     uuid/address:  <band MAC address>
 *     name:          <band name>
 *     timestamp/packetTimestamp/receivedAt/sensorTimestamp/collectedAt(±Ms),
 *     collectedAtLocal, rawHex, platform: "android"
 *   }
 *
 * Nothing is sent from the native side: no tokens, no endpoints, no uploader.
 * Data leaves the app only through the JS layer, exactly when the app decides.
 *
 * Connectivity is persistent: the band is reconnected automatically after
 * unexpected drops, Bluetooth restarts and app resume, until the app calls
 * disconnect().
 */
public class RNBleSdkV8Module extends ReactContextBaseJavaModule
        implements LifecycleEventListener {

    private static final String TAG = "RNBleSdkV8";
    private static final UUID SERVICE_UUID = UUID.fromString("0000fff0-0000-1000-8000-00805f9b34fb");
    private static final UUID WRITE_UUID = UUID.fromString("0000fff6-0000-1000-8000-00805f9b34fb");
    private static final UUID NOTIFY_UUID = UUID.fromString("0000fff7-0000-1000-8000-00805f9b34fb");
    private static final UUID CCCD_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");

    private static final String EVENT_LOG = "RNBleSdkV8.log";
    private static final String PREFS_NAME = "rnblesdkv8_prefs";
    private static final String PREF_LAST_ADDRESS = "lastAddress";
    private static final String PREF_LAST_NAME = "lastName";

    /**
     * Android SDK raw dataType (stringified numbers from the vendor's
     * BleConst) → iOS DATATYPE_V8 number. Empirically validated against the
     * MFC-App consumer which maps: 23→24, 24→25, 25→26, 26→27, 27→28, 28→29,
     * 29→30, 42→41, 55→46, 68→45, 59→48, 62→48, 121→81, 127→82.
     */
    private static final Map<String, Integer> RAW_TO_IOS_DT = new HashMap<>();
    static {
        RAW_TO_IOS_DT.put("0", 0);    // GetDeviceTime
        RAW_TO_IOS_DT.put("1", 1);    // SetDeviceTime
        RAW_TO_IOS_DT.put("2", 2);    // GetPersonalInfo
        RAW_TO_IOS_DT.put("3", 3);    // SetPersonalInfo
        RAW_TO_IOS_DT.put("4", 4);    // GetDeviceInfo
        RAW_TO_IOS_DT.put("5", 5);    // SetDeviceInfo
        RAW_TO_IOS_DT.put("7", 7);    // GetStepGoal
        RAW_TO_IOS_DT.put("8", 8);    // SetStepGoal
        RAW_TO_IOS_DT.put("9", 9);    // GetDeviceBatteryLevel
        RAW_TO_IOS_DT.put("10", 10);  // GetDeviceMacAddress
        RAW_TO_IOS_DT.put("11", 11);  // GetDeviceVersion
        RAW_TO_IOS_DT.put("15", 15);  // GetDeviceName
        RAW_TO_IOS_DT.put("23", 24);  // RealTimeStep
        RAW_TO_IOS_DT.put("24", 25);  // GetTotalActivityData
        RAW_TO_IOS_DT.put("25", 26);  // GetDetailActivityData
        RAW_TO_IOS_DT.put("26", 27);  // GetDetailSleepData
        RAW_TO_IOS_DT.put("27", 28);  // GetDynamicHR
        RAW_TO_IOS_DT.put("28", 29);  // GetStaticHR
        RAW_TO_IOS_DT.put("29", 30);  // GetActivityModeData
        RAW_TO_IOS_DT.put("30", 31);  // EnterActivityMode
        RAW_TO_IOS_DT.put("42", 41);  // GetHRVData
        RAW_TO_IOS_DT.put("55", 46);  // Blood_oxygen (manual spo2 per band)
        RAW_TO_IOS_DT.put("59", 48);  // Temperature_history
        RAW_TO_IOS_DT.put("62", 48);  // GetAxillaryTemperatureDataWithMode
        RAW_TO_IOS_DT.put("68", 45);  // GetAutomaticSpo2Monitoring (automatic spo2)
        RAW_TO_IOS_DT.put("72", 41);  // DeleteHrv
        RAW_TO_IOS_DT.put("83", 46);  // Delete_Obtain_The_data_of_manual_blood_oxygen_test
        RAW_TO_IOS_DT.put("84", 45);  // Delete_Blood_oxygen
        RAW_TO_IOS_DT.put("85", 25);  // Delete_GetTotalActivityData
        RAW_TO_IOS_DT.put("88", 30);  // Delete_ActivityModeData
        RAW_TO_IOS_DT.put("89", 29);  // Delete_GetStaticHR
        RAW_TO_IOS_DT.put("90", 28);  // Delete_GetDynamicHR
        RAW_TO_IOS_DT.put("93", 26);  // deleteGetDetailActivityDataWithMode
        RAW_TO_IOS_DT.put("94", 27);  // Delete_GetDetailSleepData
        RAW_TO_IOS_DT.put("96", 66);  // openRRInterval
        RAW_TO_IOS_DT.put("97", 67);  // closeRRInterval
        RAW_TO_IOS_DT.put("98", 68);  // realtimeRRIntervalData
        RAW_TO_IOS_DT.put("99", 70);  // realtimePPGData
        RAW_TO_IOS_DT.put("100", 69); // realtimePPIData
        RAW_TO_IOS_DT.put("102", 71); // ppgStartSucessed
        RAW_TO_IOS_DT.put("104", 74);  // ppgStop
        RAW_TO_IOS_DT.put("105", 75);  // ppgQuit
        RAW_TO_IOS_DT.put("106", 76);  // ppgMeasurementProgress
        RAW_TO_IOS_DT.put("107", 73);  // ppgResult
        RAW_TO_IOS_DT.put("103", 72); // ppgStartFailed
        RAW_TO_IOS_DT.put("121", 81); // Obtain_detailed_sleep_data (sleep + activity)
        RAW_TO_IOS_DT.put("122", 81); // DeleteSleep
        RAW_TO_IOS_DT.put("127", 82); // GetPPIData
        RAW_TO_IOS_DT.put("128", 82); // DeletePPIData
    }

    // ── Device state ─────────────────────────────────────────────────────────
    private final ReactApplicationContext reactContext;
    private final NativeBandUploader uploader;
    private volatile Map<String, Object> transformConfig = java.util.Collections.emptyMap();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final java.util.concurrent.ThreadPoolExecutor packetWorker = new java.util.concurrent.ThreadPoolExecutor(
            1, 1, 0, java.util.concurrent.TimeUnit.MILLISECONDS,
            new java.util.concurrent.ArrayBlockingQueue<>(512),
            runnable -> new Thread(runnable, "V8-band-packets"));
    private final Queue<byte[]> commandQueue = new ArrayDeque<>();
    private final Map<String, Long> seenScanDevices = new HashMap<>();

    private BluetoothAdapter bluetoothAdapter;
    private BluetoothLeScanner bluetoothLeScanner;
    private volatile BluetoothGatt bluetoothGatt;
    private BluetoothGattCharacteristic writeCharacteristic;
    private BluetoothGattCharacteristic notifyCharacteristic;
    private BluetoothGattDescriptor notifyDescriptor;
    private ScanCallback activeScan;
    private boolean waitingForBluetooth;
    private String pendingScanFilter;
    private boolean connected = false;
    private boolean notificationsReady = false;
    private boolean writing = false;
    private String connectedAddress = null;
    private String connectedName = null;

    // ── Persistent connectivity ──────────────────────────────────────────────
    private boolean userRequestedDisconnect = false;
    private boolean hostDestroyed;
    private boolean receiverRegistered;
    private boolean invalidated;
    private static final long CONNECTION_TIMEOUT_MS = 15000;
    private static final long WRITE_TIMEOUT_MS = 6000;
    private static final long SCAN_TIMEOUT_MS = 20000;
    private volatile boolean disconnecting;
    private Runnable pendingConnect;
    private final Runnable disconnectTimeout = this::finishUserDisconnect;
    private final Runnable reconnectTask = this::attemptReconnect;
    private final Runnable connectionTimeout = () -> failLink("Band connection timed out", true);
    private final Runnable writeTimeout = () -> failLink("Band write timed out", true);
    private final Runnable scanTimeout = () -> stopScanInternal(true);
    private int reconnectAttempts = 0;
    private static final long RECONNECT_BASE_DELAY_MS = 2000;

    // ── Scan filtering (JC V8 bands advertise no service UUID) ──────────────
    private List<String> deviceFilterPatterns = null;

    private final BroadcastReceiver bluetoothStateReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (!BluetoothAdapter.ACTION_STATE_CHANGED.equals(intent.getAction())) {
                return;
            }
            int state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR);
            if (state == BluetoothAdapter.STATE_ON) {
                emitState("poweredOn");
                if (waitingForBluetooth) startScanInternal(pendingScanFilter);
                else scheduleAutoReconnect();
            } else if (state == BluetoothAdapter.STATE_OFF) {
                logNative("bluetooth", "Bluetooth turned OFF");
                mainHandler.removeCallbacks(reconnectTask);
                if (disconnecting) finishUserDisconnect();
                else closeGatt(true, false);
                emitState("poweredOff");
            }
        }
    };

    public RNBleSdkV8Module(ReactApplicationContext reactContext) {
        super(reactContext);
        this.reactContext = reactContext;
        uploader = new NativeBandUploader(event -> {
            if (reactContext.hasActiveReactInstance()) emitEvent("BleUploadStatus", mapToWritableMap(event));
        });
        this.reactContext.addLifecycleEventListener(this);
        initAdapter();
        try {
            IntentFilter filter = new IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED);
            ContextCompat.registerReceiver(reactContext, bluetoothStateReceiver, filter, ContextCompat.RECEIVER_EXPORTED);
            receiverRegistered = true;
        } catch (Exception ignored) {
            // Receiver registration is best-effort.
        }
    }

    @NonNull
    @Override
    public String getName() {
        return "RNBleSdkV8";
    }

    @ReactMethod
    public void addListener(String eventName) {
        // Required by NativeEventEmitter. No-op.
    }

    @ReactMethod
    public void removeListeners(Integer count) {
        // Required by NativeEventEmitter. No-op.
    }

    // ── Scanning ─────────────────────────────────────────────────────────────

    /**
     * setDeviceFilter — restrict scan results to JC V8 devices by advertised
     * name. Pass an array of substrings; a device matches when its name
     * contains any pattern (case-insensitive). Empty array / null clears it.
     */
    @ReactMethod
    public void setDeviceFilter(ReadableArray patterns) {
        if (patterns == null || patterns.size() == 0) {
            deviceFilterPatterns = null;
            logNative("setDeviceFilter", "Filter cleared — accepting all devices");
            return;
        }
        List<String> cleaned = new ArrayList<>();
        for (int i = 0; i < patterns.size(); i++) {
            String p = patterns.getString(i);
            if (p != null && !p.isEmpty()) {
                cleaned.add(p.toLowerCase(Locale.ROOT));
            }
        }
        deviceFilterPatterns = cleaned.isEmpty() ? null : cleaned;
        logNative("setDeviceFilter", "Patterns=" + deviceFilterPatterns);
    }

    @ReactMethod
    public void startScan(@Nullable String nameFilter) {
        mainHandler.post(() -> startScanInternal(nameFilter));
    }

    private void startScanInternal(@Nullable String nameFilter) {
        if (invalidated || hostDestroyed) return;
        deviceFilterPatterns = nameFilter == null || nameFilter.isEmpty()
                ? null : java.util.Collections.singletonList(nameFilter.toLowerCase(Locale.ROOT));

        if (!ensureAdapter()) {
            emitError("Bluetooth adapter is not available");
            return;
        }
        if (!canScan() || !canConnect()) {
            emitError("Missing Bluetooth scan permissions");
            return;
        }
        stopScanInternal(false);
        if (!isBluetoothEnabled()) {
            waitingForBluetooth = true;
            pendingScanFilter = nameFilter;
            emitState("poweredOff");
            return;
        }
        bluetoothLeScanner = bluetoothAdapter.getBluetoothLeScanner();
        if (bluetoothLeScanner == null) {
            emitError("Bluetooth scanner is not available");
            return;
        }

        seenScanDevices.clear();
        activeScan = newScanCallback();
        logNative("startScan", "Starting BLE scan");

        ScanSettings settings = new ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build();

        try {
            bluetoothLeScanner.startScan((List<ScanFilter>) null, settings, activeScan);
            mainHandler.postDelayed(scanTimeout, SCAN_TIMEOUT_MS);
            emitState("scanning");
            logNative("startScan", "Scan started");
        } catch (SecurityException securityException) {
            activeScan = null;
            emitError("Scan permission denied");
        }
    }

    @ReactMethod
    public void stopScan() {
        mainHandler.post(() -> stopScanInternal(true));
    }

    // ── Connection ───────────────────────────────────────────────────────────

    @ReactMethod
    public void connect(String address, @Nullable String deviceName) {
        mainHandler.post(() -> connectInternal(address, deviceName));
    }

    private void connectInternal(String address, @Nullable String deviceName) {
        if (invalidated || hostDestroyed) return;
        String target = address == null ? "" : address.trim().toUpperCase(Locale.ROOT);
        if (!BluetoothAdapter.checkBluetoothAddress(target)) {
            emitError("Invalid device address");
            return;
        }
        if (!ensureAdapter() || !canConnect() || !isBluetoothEnabled()) {
            emitError("Bluetooth is unavailable or connect permission is missing");
            return;
        }
        stopScanInternal(false);
        if (disconnecting) {
            pendingConnect = () -> connectInternal(target, deviceName);
            return;
        }
        if (bluetoothGatt != null && target.equals(connectedAddress)) {
            if (connected) emitConnectedDevice();
            return;
        }

        mainHandler.removeCallbacks(reconnectTask);
        closeGatt(connected, false);
        userRequestedDisconnect = false;
        reconnectAttempts = 0;
        connectedAddress = target;
        connectedName = deviceName;
        attemptReconnect();
    }

    @ReactMethod
    public void disconnect() {
        mainHandler.post(() -> {
            if (invalidated) return;
            userRequestedDisconnect = true;
            mainHandler.removeCallbacks(reconnectTask);
            reconnectAttempts = 0;
            clearLastDevice();
            pendingConnect = null;
            stopScanInternal(false);
            if (disconnecting) return;
            BluetoothGatt current = bluetoothGatt;
            if (current == null) {
                closeGatt(true, true);
                return;
            }
            disconnecting = true;
            mainHandler.removeCallbacks(connectionTimeout);
            mainHandler.removeCallbacks(writeTimeout);
            notificationsReady = false;
            packetWorker.getQueue().clear();
            try {
                current.disconnect();
                mainHandler.postDelayed(disconnectTimeout, 3000);
            } catch (SecurityException error) {
                finishUserDisconnect();
            }
        });
    }

    private void finishUserDisconnect() {
        if (!disconnecting) return;
        Runnable next = pendingConnect;
        closeGatt(true, true);
        if (next != null) next.run();
    }

    @ReactMethod
    public void reconnect() {
        mainHandler.post(() -> {
            if (invalidated || bluetoothGatt != null) return;
            userRequestedDisconnect = false;
            reconnectAttempts = 0;
            restoreLastDevice();
            mainHandler.removeCallbacks(reconnectTask);
            attemptReconnect();
        });
    }

    private void restoreLastDevice() {
        if (connectedAddress == null) {
            connectedAddress = loadLastAddress();
            connectedName = loadLastName();
        }
    }

    // ── Device info commands ─────────────────────────────────────────────────

    @ReactMethod
    public void getDeviceTime() {
        queueCommand(BleSDK.GetDeviceTime());
    }

    @ReactMethod
    public void getPersonalInfo() {
        queueCommand(BleSDK.GetPersonalInfo());
    }

    @ReactMethod
    public void getBatteryLevel() {
        queueCommand(BleSDK.GetDeviceBatteryLevel());
    }

    @ReactMethod
    public void getDeviceVersion() {
        queueCommand(BleSDK.GetDeviceVersion());
    }

    @ReactMethod
    public void getMacAddress() {
        queueCommand(BleSDK.GetDeviceMacAddress());
    }

    @ReactMethod
    public void getDeviceName() {
        queueCommand(BleSDK.GetDeviceName());
    }

    @ReactMethod
    public void setDeviceName(String name) {
        if (name == null || name.isEmpty()) {
            emitError("setDeviceName: name is required");
            return;
        }
        queueCommand(BleSDK.SetDeviceName(name));
    }

    @ReactMethod
    public void setDeviceId(String deviceId) {
        if (deviceId == null || deviceId.isEmpty()) {
            emitError("setDeviceId: deviceId is required");
            return;
        }
        queueCommand(BleSDK.SetDeviceID(deviceId));
    }

    @ReactMethod
    public void setDeviceTime(ReadableMap config) {
        if (config == null) {
            emitError("setDeviceTime: config is required");
            return;
        }
        MyDeviceTime time = new MyDeviceTime();
        time.setYear(config.hasKey("year") ? config.getInt("year") : 0);
        time.setMonth(config.hasKey("month") ? config.getInt("month") : 0);
        time.setDay(config.hasKey("day") ? config.getInt("day") : 0);
        time.setHour(config.hasKey("hour") ? config.getInt("hour") : 0);
        time.setMinute(config.hasKey("minute") ? config.getInt("minute") : 0);
        time.setSecond(config.hasKey("second") ? config.getInt("second") : 0);
        queueCommand(BleSDK.SetDeviceTime(time));
    }

    @ReactMethod
    public void setPersonalInfo(ReadableMap config) {
        if (config == null) {
            emitError("setPersonalInfo: config is required");
            return;
        }
        MyPersonalInfo info = new MyPersonalInfo();
        info.setSex(config.hasKey("sex") ? config.getInt("sex") : 0);
        info.setAge(config.hasKey("age") ? config.getInt("age") : 0);
        info.setHeight(config.hasKey("height") ? config.getInt("height") : 0);
        info.setWeight(config.hasKey("weight") ? config.getInt("weight") : 0);
        info.setStepLength(config.hasKey("stepLength") ? config.getInt("stepLength") : 0);
        queueCommand(BleSDK.SetPersonalInfo(info));
    }

    @ReactMethod
    public void getBasicParameters() {
        queueCommand(BleSDK.GetBasic_parameters_of_equipment());
    }

    @ReactMethod
    public void setBasicParameters(boolean heartRateEnabled, boolean temperatureEnabled) {
        queueCommand(BleSDK.SetBasic_parameters_of_equipment(heartRateEnabled, temperatureEnabled));
    }

    /**
     * Not supported by the Android vendor SDK (no GetStepGoal command exists).
     * The JS layer emits the "not supported" error event (single source).
     */
    @ReactMethod
    public void getStepGoal() {
        // no-op — JS emits RNBleSdkV8.error
    }

    // ── History commands (mode: 0 = start, 2 = continue, 0x99 = delete) ─────

    @ReactMethod
    public void getSleepHistory(int mode, String dateOfLastData) {
        queueCommand(BleSDK.GetDetailSleepDataWithMode((byte) mode, safeDate(dateOfLastData)));
    }

    /**
     * Sleep + activity combined — vendor Android command getObtainDetailedSleepData
     * (raw dataType 121 → iOS 81, records carry Sleep_level + ActivityData).
     */
    @ReactMethod
    public void getSleepAndActivityHistory(int mode, String dateOfLastData) {
        queueCommand(BleSDK.getObtainDetailedSleepData((byte) mode, safeDate(dateOfLastData)));
    }

    /** Explicit alias of getSleepAndActivityHistory (Obtain_detailed_sleep_data). */
    @ReactMethod
    public void getObtainDetailedSleepData(int mode, String dateOfLastData) {
        queueCommand(BleSDK.getObtainDetailedSleepData((byte) mode, safeDate(dateOfLastData)));
    }

    @ReactMethod
    public void getTotalActivityData(int mode, String dateOfLastData) {
        queueCommand(BleSDK.GetTotalActivityDataWithMode((byte) mode, safeDate(dateOfLastData)));
    }

    @ReactMethod
    public void getDetailActivityData(int mode, String dateOfLastData) {
        queueCommand(BleSDK.GetDetailActivityDataWithMode((byte) mode, safeDate(dateOfLastData)));
    }

    @ReactMethod
    public void getContinuousHRHistory(int mode, String dateOfLastData) {
        queueCommand(BleSDK.GetDynamicHRWithMode((byte) mode, safeDate(dateOfLastData)));
    }

    @ReactMethod
    public void getSingleHRHistory(int mode, String dateOfLastData) {
        queueCommand(BleSDK.GetStaticHRWithMode((byte) mode, safeDate(dateOfLastData)));
    }

    @ReactMethod
    public void getAutomaticSpo2History(int mode, String dateOfLastData) {
        queueCommand(BleSDK.Oxygen_data((byte) mode, safeDate(dateOfLastData)));
    }

    /** Manual SpO2 history shares the vendor Oxygen_data stream. */
    @ReactMethod
    public void getManualSpo2History(int mode, String dateOfLastData) {
        queueCommand(BleSDK.Oxygen_data((byte) mode, safeDate(dateOfLastData)));
    }

    @ReactMethod
    public void getTemperatureHistory(int mode, String dateOfLastData) {
        queueCommand(BleSDK.GetTemperature_historyData((byte) mode, safeDate(dateOfLastData)));
    }

    @ReactMethod
    public void getHRVHistory(int mode, String dateOfLastData) {
        queueCommand(BleSDK.GetHRVDataWithMode((byte) mode, safeDate(dateOfLastData)));
    }

    @ReactMethod
    public void getPPIHistory(int mode, String dateOfLastData) {
        queueCommand(BleSDK.GetPPI((byte) mode, safeDate(dateOfLastData)));
    }

    @ReactMethod
    public void getActivityModeHistory(int mode, String dateOfLastData) {
        queueCommand(BleSDK.GetActivityModeDataWithMode((byte) mode));
    }

    // ── Realtime / measurement commands ──────────────────────────────────────

    @ReactMethod
    public void setRealtimeData(int enable) {
        queueCommand(BleSDK.RealTimeStep(enable != 0, false));
    }

    /** Mirrors iOS ppgControl:(int)ppgMode ppgStatus:(int)ppgStatus. */
    @ReactMethod
    public void ppgControl(int ppgMode, int ppgStatus) {
        queueCommand(BleSDK.ppgWithMode(ppgMode, ppgStatus));
    }

    @ReactMethod
    public void realTimeTemperature() {
        queueCommand(BleSDK.RealTimeTemperature());
    }

    /**
     * Start a one-shot measurement on the band.
     * mode: "AutoHeartRate" | "AutoSpo2" | "AutoHRV" | "ECG"
     * intervalSeconds: measurement duration / interval
     * open: true to stream realtime values to the app
     */
    @ReactMethod
    public void setDeviceMeasurementWithType(String mode, double intervalSeconds, boolean open) {
        AutoTestMode testMode = autoTestModeFromString(mode);
        if (testMode == null) {
            emitError("setDeviceMeasurementWithType: unknown mode '" + mode + "'");
            return;
        }
        queueCommand(BleSDK.SetDeviceMeasurementWithType(
                testMode, (long) intervalSeconds, open));
    }

    /** Automatic HR monitoring configuration. */
    @ReactMethod
    public void setAutomaticMonitoring(ReadableMap config) {
        if (config == null) {
            emitError("setAutomaticMonitoring: config is required");
            return;
        }
        AutoMode mode = autoModeFromString(config.hasKey("mode")
                ? config.getString("mode") : null);
        if (mode == null) {
            emitError("setAutomaticMonitoring: unknown mode");
            return;
        }
        MyAutomaticHRMonitoring monitoring = new MyAutomaticHRMonitoring();
        monitoring.setTime(config.hasKey("time") ? config.getInt("time") : 0);
        monitoring.setOpen(config.hasKey("open") ? config.getInt("open") : 0);
        monitoring.setStartHour(config.hasKey("startHour") ? config.getInt("startHour") : 0);
        monitoring.setStartMinute(config.hasKey("startMinute") ? config.getInt("startMinute") : 0);
        monitoring.setEndHour(config.hasKey("endHour") ? config.getInt("endHour") : 0);
        monitoring.setEndMinute(config.hasKey("endMinute") ? config.getInt("endMinute") : 0);
        queueCommand(BleSDK.SetAutomaticHRMonitoring(monitoring, mode));
    }

    @ReactMethod
    public void getAutomaticMonitoring(String mode) {
        AutoMode autoMode = autoModeFromString(mode);
        if (autoMode == null) {
            emitError("getAutomaticMonitoring: unknown mode '" + mode + "'");
            return;
        }
        queueCommand(BleSDK.GetAutomatic(autoMode));
    }

    @ReactMethod
    public void setSedentaryReminder(ReadableMap config) {
        if (config == null) {
            emitError("setSedentaryReminder: config is required");
            return;
        }
        MySedentaryReminder reminder = new MySedentaryReminder();
        reminder.setEnable(config.hasKey("enable") && config.getBoolean("enable"));
        reminder.setStartHour(config.hasKey("startHour") ? config.getInt("startHour") : 0);
        reminder.setStartMinute(config.hasKey("startMinute") ? config.getInt("startMinute") : 0);
        reminder.setEndHour(config.hasKey("endHour") ? config.getInt("endHour") : 0);
        reminder.setEndMinute(config.hasKey("endMinute") ? config.getInt("endMinute") : 0);
        reminder.setWeek(config.hasKey("week") ? config.getInt("week") : 0);
        queueCommand(BleSDK.SetSedentaryReminder(reminder));
    }

    @ReactMethod
    public void getSedentaryReminder() {
        queueCommand(BleSDK.GetSedentaryReminder());
    }

    @ReactMethod
    public void getAlarmClock() {
        queueCommand(BleSDK.GetAlarmClock());
    }

    @ReactMethod
    public void setClockData(ReadableArray clocks) {
        if (clocks == null || clocks.size() == 0) {
            emitError("setClockData: clocks array is required");
            return;
        }
        List<Clock> clockList = new ArrayList<>();
        for (int i = 0; i < clocks.size(); i++) {
            ReadableMap item = clocks.getMap(i);
            Clock clock = new Clock();
            clock.setEnable(item.hasKey("enable") && item.getBoolean("enable"));
            clock.setNumber(item.hasKey("number") ? item.getInt("number") : i);
            clock.setType(item.hasKey("type") ? item.getInt("type") : 0);
            clock.setHour(item.hasKey("hour") ? item.getInt("hour") : 0);
            clock.setMinute(item.hasKey("minute") ? item.getInt("minute") : 0);
            if (item.hasKey("content")) {
                clock.setContent(item.getString("content"));
            }
            clockList.add(clock);
        }
        queueCommand(BleSDK.setClockData(clockList));
    }

    @ReactMethod
    public void deleteAllClock() {
        queueCommand(BleSDK.deleteAllClock());
    }

    @ReactMethod
    public void enterActivityMode(int mode, int duration, int interval) {
        queueCommand(BleSDK.EnterActivityMode(mode, duration, interval));
    }

    @ReactMethod
    public void findActivityMode() {
        queueCommand(BleSDK.FindActivityMode());
    }

    @ReactMethod
    public void setExerciseModeByBreath(int breath, int duration, int interval) {
        queueCommand(BleSDK.setExerciseModeByBreath(breath, duration, interval));
    }

    @ReactMethod
    public void sendHeartPackage(double heartRate, int weight, int age) {
        queueCommand(BleSDK.sendHeartPackage((float) heartRate, weight, age));
    }

    @ReactMethod
    public void setECGRealtimeDuringHRVEnabled(boolean enabled) {
        queueCommand(BleSDK.setECGRealtimeDuringHRVEnabled(enabled));
    }

    @ReactMethod
    public void reset() {
        queueCommand(BleSDK.Reset());
    }

    @ReactMethod
    public void mcuReset() {
        queueCommand(BleSDK.MCUReset());
    }

    @ReactMethod
    public void enterOta() {
        queueCommand(BleSDK.enterOTA());
    }

    /**
     * Not supported by the Android vendor SDK (no ClearAllHistoryData command
     * exists). Emits an error event instead of sending bytes.
     */
    @ReactMethod
    public void clearAllHistoryData() {
        emitUnsupported("clearAllHistoryData");
    }

    @ReactMethod
    public void setTransformConfig(ReadableMap config) {
        transformConfig = config == null ? java.util.Collections.emptyMap() : config.toHashMap();
    }

    @ReactMethod
    public void configureServerUpload(ReadableMap config) {
        if (config != null) uploader.configure(config.toHashMap());
    }

    @ReactMethod
    public void startNativeAutoUpload(ReadableMap options) {
        uploader.start();
    }

    @ReactMethod
    public void stopNativeAutoUpload() {
        uploader.stop();
    }

    @ReactMethod
    public void uploadDataNative(ReadableMap packet) {
        if (packet != null) uploader.upload(packet.toHashMap());
    }

    @ReactMethod
    public void uploadToEndpointNative(String endpoint, ReadableMap data) {
        uploader.uploadToEndpoint(endpoint, data == null ? java.util.Collections.emptyMap() : data.toHashMap());
    }

    @Override
    public void invalidate() {
        uploader.close();
        packetWorker.shutdownNow();
        reactContext.removeLifecycleEventListener(this);
        mainHandler.post(() -> {
            invalidated = true;
            mainHandler.removeCallbacks(reconnectTask);
            closeGatt(false, true);
            if (receiverRegistered) {
                reactContext.unregisterReceiver(bluetoothStateReceiver);
                receiverRegistered = false;
            }
        });
        super.invalidate();
    }

    @Override
    public void onHostResume() {
        mainHandler.post(() -> {
            if (invalidated) return;
            hostDestroyed = false;
            if (!userRequestedDisconnect) {
                restoreLastDevice();
                scheduleAutoReconnect();
            }
        });
    }

    @Override
    public void onHostPause() {
        // Keep the active connection while the host is in the background.
    }

    @Override
    public void onHostDestroy() {
        mainHandler.post(() -> {
            hostDestroyed = true;
            mainHandler.removeCallbacks(reconnectTask);
            closeGatt(true, disconnecting);
        });
    }

    // ── DataListener2301 ─────────────────────────────────────────────────────

    private void deliverPacket(BluetoothGatt gatt, Map<String, Object> maps, String address, String name, long receivedAt) {
        if (maps == null || gatt != bluetoothGatt || disconnecting) return;
        Number vendorType = BandPacket.number(maps.get("dataType"));
        int rawType = vendorType == null ? -1 : vendorType.intValue();
        int type = RAW_TO_IOS_DT.getOrDefault(Integer.toString(rawType), rawType);
        Map<String, Object> packet = BandPacket.normalize(maps, rawType, type, BandPacket.uploadTypeName(type),
                address, name, receivedAt, transformConfig);
        if (gatt != bluetoothGatt || disconnecting) return;
        uploader.autoUpload(packet);
        emitEvent("RNBleSdkV8.data", mapToWritableMap(packet));
    }

    // ── Native helpers ───────────────────────────────────────────────────────

    private void initAdapter() {
        BluetoothManager bluetoothManager =
                (BluetoothManager) reactContext.getSystemService(Context.BLUETOOTH_SERVICE);
        if (bluetoothManager != null) {
            bluetoothAdapter = bluetoothManager.getAdapter();
        }
    }

    private boolean ensureAdapter() {
        if (bluetoothAdapter == null) {
            initAdapter();
        }
        return bluetoothAdapter != null;
    }

    private boolean canScan() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return hasPermission(Manifest.permission.BLUETOOTH_SCAN);
        }
        return hasPermission(Manifest.permission.ACCESS_FINE_LOCATION);
    }

    private boolean canConnect() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return hasPermission(Manifest.permission.BLUETOOTH_CONNECT);
        }
        return true;
    }

    private boolean isBluetoothEnabled() {
        return bluetoothAdapter != null && bluetoothAdapter.isEnabled();
    }

    private boolean hasPermission(String permission) {
        return ContextCompat.checkSelfPermission(reactContext, permission)
                == PackageManager.PERMISSION_GRANTED;
    }

    private boolean canReconnect() {
        return !invalidated && !hostDestroyed && !userRequestedDisconnect && bluetoothGatt == null
                && connectedAddress != null && ensureAdapter() && canConnect() && isBluetoothEnabled();
    }

    private void attemptReconnect() {
        if (!canReconnect()) return;
        try {
            BluetoothDevice device = bluetoothAdapter.getRemoteDevice(connectedAddress);
            if (connectedName == null) connectedName = device.getName();
            emitState("connecting");
            bluetoothGatt = device.connectGatt(reactContext, false, gattCallback,
                    BluetoothDevice.TRANSPORT_LE, BluetoothDevice.PHY_LE_1M_MASK, mainHandler);
            if (bluetoothGatt == null) {
                failLink("Unable to open a BLE connection", true);
                return;
            }
            mainHandler.postDelayed(connectionTimeout, CONNECTION_TIMEOUT_MS);
        } catch (IllegalArgumentException | SecurityException error) {
            failLink("Unable to connect to band: " + error.getMessage(), false);
        }
    }

    private void scheduleAutoReconnect() {
        if (!canReconnect()) return;
        mainHandler.removeCallbacks(reconnectTask);
        long delay = Math.min(RECONNECT_BASE_DELAY_MS * (1L << Math.min(reconnectAttempts, 3)), 12000);
        reconnectAttempts++;
        mainHandler.postDelayed(reconnectTask, delay);
    }

    private void failLink(String message, boolean retry) {
        emitError(message);
        closeGatt(true, false);
        if (retry) scheduleAutoReconnect();
    }

    private void stopScanInternal(boolean emitState) {
        mainHandler.removeCallbacks(scanTimeout);
        ScanCallback previousScan = activeScan;
        boolean wasScanning = previousScan != null || waitingForBluetooth;
        activeScan = null;
        waitingForBluetooth = false;
        pendingScanFilter = null;
        if (bluetoothLeScanner != null && previousScan != null) {
            try {
                bluetoothLeScanner.stopScan(previousScan);
                logNative("stopScan", "Scan stopped");
            } catch (SecurityException ignored) {
                // Ignore.
            }
        }
        if (emitState && wasScanning) {
            emitState("scan_stopped");
        }
    }

    private void queueCommand(byte[] command) {
        if (command == null || command.length == 0) {
            return;
        }
        synchronized (commandQueue) {
            commandQueue.offer(command);
        }
        flushCommandQueue();
    }

    private void flushCommandQueue() {
        mainHandler.post(() -> {
            if (bluetoothGatt == null || writeCharacteristic == null
                    || !notificationsReady || writing) {
                return;
            }

            byte[] next;
            synchronized (commandQueue) {
                next = commandQueue.poll();
            }
            if (next == null) {
                return;
            }

            int properties = writeCharacteristic.getProperties();
            int writeType = (properties & BluetoothGattCharacteristic.PROPERTY_WRITE) != 0
                    ? BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                    : BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE;
            try {
                if (Build.VERSION.SDK_INT >= 33) {
                    writing = bluetoothGatt.writeCharacteristic(writeCharacteristic, next, writeType)
                            == BluetoothStatusCodes.SUCCESS;
                } else {
                    writeCharacteristic.setWriteType(writeType);
                    writeCharacteristic.setValue(next);
                    writing = bluetoothGatt.writeCharacteristic(writeCharacteristic);
                }
                if (writing) mainHandler.postDelayed(writeTimeout, WRITE_TIMEOUT_MS);
                else failLink("Unable to write BLE command", true);
            } catch (SecurityException exception) {
                failLink("Missing Bluetooth connect permission", false);
            }
        });
    }

    private void closeGatt(boolean emitDisconnected, boolean clearSession) {
        boolean hadSession = bluetoothGatt != null || connected || (clearSession && connectedAddress != null);
        mainHandler.removeCallbacks(connectionTimeout);
        mainHandler.removeCallbacks(writeTimeout);
        mainHandler.removeCallbacks(disconnectTimeout);
        boolean disconnectAlreadyRequested = disconnecting;
        disconnecting = false;
        pendingConnect = null;
        stopScanInternal(false);
        notificationsReady = false;
        writing = false;

        BluetoothGatt previousGatt = bluetoothGatt;
        bluetoothGatt = null;
        packetWorker.getQueue().clear();
        if (previousGatt != null) {
            try {
                if (!disconnectAlreadyRequested) previousGatt.disconnect();
            } catch (SecurityException ignored) {
                // Ignore.
            }
            try {
                previousGatt.close();
            } catch (Exception ignored) {
                // Ignore.
            }
        }

        writeCharacteristic = null;
        notifyCharacteristic = null;
        notifyDescriptor = null;

        synchronized (commandQueue) {
            commandQueue.clear();
        }

        if (hadSession) {
            WritableMap payload = Arguments.createMap();
            if (connectedAddress != null) {
                payload.putString("uuid", connectedAddress);
                payload.putString("address", connectedAddress);
            }
            if (connectedName != null) {
                payload.putString("name", connectedName);
            }
            if (emitDisconnected) {
                payload.putBoolean("userInitiated", userRequestedDisconnect);
                emitEvent("RNBleSdkV8.disconnected", payload);
            }
            emitState("disconnected");
        }

        connected = false;
        if (clearSession) {
            connectedAddress = null;
            connectedName = null;
        }
    }

    private void prepareNotification(BluetoothGatt gatt) {
        BluetoothGattService service = gatt.getService(SERVICE_UUID);
        if (service == null) {
            failLink("V8 BLE service not found", false);
            return;
        }
        writeCharacteristic = service.getCharacteristic(WRITE_UUID);
        notifyCharacteristic = service.getCharacteristic(NOTIFY_UUID);
        if (writeCharacteristic == null || notifyCharacteristic == null) {
            failLink("V8 BLE characteristics not found", false);
            return;
        }

        notifyDescriptor = notifyCharacteristic.getDescriptor(CCCD_UUID);
        if (notifyDescriptor == null) {
            failLink("Notification descriptor not found", false);
            return;
        }
        byte[] value = (notifyCharacteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0
                ? BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE : BluetoothGattDescriptor.ENABLE_INDICATION_VALUE;
        try {
            if (!gatt.setCharacteristicNotification(notifyCharacteristic, true)) {
                failLink("Unable to enable notifications", true);
                return;
            }
            boolean started;
            if (Build.VERSION.SDK_INT >= 33) {
                started = gatt.writeDescriptor(notifyDescriptor, value) == BluetoothStatusCodes.SUCCESS;
            } else {
                notifyDescriptor.setValue(value);
                started = gatt.writeDescriptor(notifyDescriptor);
            }
            if (!started) failLink("Unable to write notification descriptor", true);
        } catch (SecurityException exception) {
            failLink("Missing Bluetooth connect permission", false);
        }
    }

    private void emitConnected() {
        mainHandler.removeCallbacks(connectionTimeout);
        mainHandler.removeCallbacks(reconnectTask);
        connected = true;
        saveLastDevice(connectedAddress, connectedName);
        reconnectAttempts = 0;
        emitConnectedDevice();
        emitState("connected");
        if (uploader.isEnabled()) setRealtimeData(1);
        flushCommandQueue();
    }

    private void emitConnectedDevice() {
        WritableMap payload = Arguments.createMap();
        payload.putString("uuid", connectedAddress);
        payload.putString("address", connectedAddress);
        if (connectedName != null) {
            payload.putString("name", connectedName);
        }
        emitEvent("RNBleSdkV8.connected", payload);
    }

    private void emitState(String state) {
        WritableMap payload = Arguments.createMap();
        payload.putString("state", state);
        if (connectedAddress != null) {
            payload.putString("uuid", connectedAddress);
            payload.putString("address", connectedAddress);
        }
        if (connectedName != null) {
            payload.putString("name", connectedName);
        }
        emitEvent("RNBleSdkV8.state", payload);
    }

    private void emitError(String message) {
        WritableMap payload = Arguments.createMap();
        payload.putString("message", message);
        emitEvent("RNBleSdkV8.error", payload);
        Log.w(TAG, message);
    }

    private void emitUnsupported(String method) {
        String message = method + " is not supported on Android (vendor SDK has no such command)";
        emitError(message);
    }

    private void logNative(String stage, String message) {
        String text = stage + ": " + message;
        Log.d(TAG, text);
        WritableMap payload = Arguments.createMap();
        payload.putString("stage", stage);
        payload.putString("message", message);
        emitEvent(EVENT_LOG, payload);
    }

    private void emitEvent(String eventName, WritableMap payload) {
        if (!reactContext.hasActiveReactInstance()) return;
        reactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, payload);
    }

    private WritableMap mapToWritableMap(Map<String, Object> map) {
        WritableMap writableMap = Arguments.createMap();
        if (map == null) {
            return writableMap;
        }
        for (Map.Entry<String, Object> entry : map.entrySet()) {
            putValue(writableMap, entry.getKey(), entry.getValue());
        }
        return writableMap;
    }

    private void putValue(WritableMap map, String key, Object value) {
        if (value == null) {
            map.putNull(key);
            return;
        }
        if (value instanceof Boolean) {
            map.putBoolean(key, (Boolean) value);
            return;
        }
        if (value instanceof Integer) {
            map.putInt(key, (Integer) value);
            return;
        }
        if (value instanceof Long) {
            long longValue = (Long) value;
            if (longValue >= Integer.MIN_VALUE && longValue <= Integer.MAX_VALUE) {
                map.putInt(key, (int) longValue);
            } else {
                map.putDouble(key, (double) longValue);
            }
            return;
        }
        if (value instanceof Float) {
            map.putDouble(key, ((Float) value).doubleValue());
            return;
        }
        if (value instanceof Double) {
            map.putDouble(key, (Double) value);
            return;
        }
        if (value instanceof Number) {
            map.putDouble(key, ((Number) value).doubleValue());
            return;
        }
        if (value instanceof String) {
            map.putString(key, (String) value);
            return;
        }
        if (value instanceof Map) {
            map.putMap(key, mapToWritableMap((Map<String, Object>) value));
            return;
        }
        if (value instanceof List) {
            map.putArray(key, listToWritableArray((List<Object>) value));
            return;
        }
        map.putString(key, String.valueOf(value));
    }

    private WritableArray listToWritableArray(List<Object> list) {
        WritableArray array = Arguments.createArray();
        if (list == null) {
            return array;
        }
        for (Object value : list) {
            if (value == null) {
                array.pushNull();
            } else if (value instanceof Boolean) {
                array.pushBoolean((Boolean) value);
            } else if (value instanceof Integer) {
                array.pushInt((Integer) value);
            } else if (value instanceof Long) {
                long longValue = (Long) value;
                if (longValue >= Integer.MIN_VALUE && longValue <= Integer.MAX_VALUE) {
                    array.pushInt((int) longValue);
                } else {
                    array.pushDouble((double) longValue);
                }
            } else if (value instanceof Float) {
                array.pushDouble(((Float) value).doubleValue());
            } else if (value instanceof Double) {
                array.pushDouble((Double) value);
            } else if (value instanceof Number) {
                array.pushDouble(((Number) value).doubleValue());
            } else if (value instanceof String) {
                array.pushString((String) value);
            } else if (value instanceof Map) {
                array.pushMap(mapToWritableMap((Map<String, Object>) value));
            } else if (value instanceof List) {
                array.pushArray(listToWritableArray((List<Object>) value));
            } else {
                array.pushString(String.valueOf(value));
            }
        }
        return array;
    }

    // ── Model helpers ────────────────────────────────────────────────────────

    private AutoMode autoModeFromString(@Nullable String mode) {
        if (mode == null) {
            return null;
        }
        if ("AutoHeartRate".equalsIgnoreCase(mode)) return AutoMode.AutoHeartRate;
        if ("AutoSpo2".equalsIgnoreCase(mode)) return AutoMode.AutoSpo2;
        if ("AutoTemp".equalsIgnoreCase(mode)) return AutoMode.AutoTemp;
        if ("AutoHrv".equalsIgnoreCase(mode)) return AutoMode.AutoHrv;
        return null;
    }

    private AutoTestMode autoTestModeFromString(@Nullable String mode) {
        if (mode == null) {
            return null;
        }
        if ("AutoHeartRate".equalsIgnoreCase(mode)) return AutoTestMode.AutoHeartRate;
        if ("AutoSpo2".equalsIgnoreCase(mode)) return AutoTestMode.AutoSpo2;
        if ("AutoHRV".equalsIgnoreCase(mode)) return AutoTestMode.AutoHRV;
        if ("ECG".equalsIgnoreCase(mode)) return AutoTestMode.ECG;
        return null;
    }

    // ── Persistence + timestamps ─────────────────────────────────────────────

    private SharedPreferences prefs() {
        return reactContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }

    private void saveLastDevice(String address, String name) {
        prefs().edit()
                .putString(PREF_LAST_ADDRESS, address)
                .putString(PREF_LAST_NAME, name != null ? name : "")
                .apply();
    }

    private String loadLastAddress() {
        String address = prefs().getString(PREF_LAST_ADDRESS, null);
        return (address == null || address.isEmpty()) ? null : address;
    }

    private String loadLastName() {
        String name = prefs().getString(PREF_LAST_NAME, "");
        return name.isEmpty() ? null : name;
    }

    private void clearLastDevice() {
        prefs().edit()
                .remove(PREF_LAST_ADDRESS)
                .remove(PREF_LAST_NAME)
                .apply();
    }

    private String safeDate(String dateOfLastData) {
        return dateOfLastData == null ? "" : dateOfLastData;
    }

    // ── Scan + GATT callbacks ────────────────────────────────────────────────

    private ScanCallback newScanCallback() {
        return new ScanCallback() {
            @Override
            public void onScanResult(int callbackType, ScanResult result) {
                if (this != activeScan) return;
                BluetoothDevice device = result.getDevice();
                if (device == null) {
                    return;
                }

                String address = device.getAddress();
                if (address == null || seenScanDevices.containsKey(address)) {
                    return;
                }

                String name = null;
                try {
                    name = device.getName();
                } catch (SecurityException ignored) {
                    // Ignore and fall back to scan record.
                }
                if ((name == null || name.isEmpty()) && result.getScanRecord() != null) {
                    ScanRecord record = result.getScanRecord();
                    name = record.getDeviceName();
                }
                if (name == null || name.isEmpty()) {
                    name = "Unknown";
                }

                if (deviceFilterPatterns != null) {
                    String lowerName = name.toLowerCase(Locale.ROOT);
                    boolean matched = false;
                    for (String pattern : deviceFilterPatterns) {
                        if (lowerName.contains(pattern)) {
                            matched = true;
                            break;
                        }
                    }
                    if (!matched) {
                        return;
                    }
                }

                seenScanDevices.put(address, System.currentTimeMillis());
                logNative("scanResult",
                        "Found device address=" + address + ", name=" + name
                                + ", rssi=" + result.getRssi());

                WritableMap payload = Arguments.createMap();
                payload.putString("address", address);
                payload.putString("uuid", address);
                payload.putString("name", name);
                payload.putInt("rssi", result.getRssi());
                payload.putString("platform", "android");
                emitEvent("RNBleSdkV8.scanResult", payload);
            }

            @Override
            public void onScanFailed(int errorCode) {
                if (this != activeScan) return;
                logNative("scanFailed", "Scan failed with code=" + errorCode);
                emitError("Scan failed: " + errorCode);
                stopScanInternal(true);
            }
        };
    }

    private final BluetoothGattCallback gattCallback = new BluetoothGattCallback() {
        @Override
        public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {
            if (gatt != bluetoothGatt) return;
            if (disconnecting) {
                if (newState == BluetoothProfile.STATE_DISCONNECTED) finishUserDisconnect();
                return;
            }
            if (status != BluetoothGatt.GATT_SUCCESS) {
                failLink("Bluetooth connection failed: " + status, true);
            } else if (newState == BluetoothProfile.STATE_CONNECTED) {
                try {
                    if (!gatt.discoverServices()) failLink("Unable to start service discovery", true);
                } catch (SecurityException exception) {
                    failLink("Missing Bluetooth connect permission", false);
                }
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                closeGatt(true, false);
                scheduleAutoReconnect();
            }
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status) {
            if (gatt != bluetoothGatt || disconnecting) return;
            if (status == BluetoothGatt.GATT_SUCCESS) prepareNotification(gatt);
            else failLink("Service discovery failed: " + status, true);
        }

        @Override
        public void onDescriptorWrite(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status) {
            if (gatt != bluetoothGatt || disconnecting || notifyDescriptor == null || !CCCD_UUID.equals(descriptor.getUuid())
                    || !NOTIFY_UUID.equals(descriptor.getCharacteristic().getUuid()) || notificationsReady) return;
            if (status == BluetoothGatt.GATT_SUCCESS) {
                notificationsReady = true;
                emitConnected();
            } else {
                failLink("Notification setup failed: " + status, true);
            }
        }

        @Override
        public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {
            handleNotification(gatt, characteristic, characteristic.getValue());
        }

        @Override
        public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, byte[] value) {
            handleNotification(gatt, characteristic, value);
        }

        @Override
        public void onCharacteristicWrite(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status) {
            if (gatt != bluetoothGatt || disconnecting || !WRITE_UUID.equals(characteristic.getUuid()) || !writing) return;
            mainHandler.removeCallbacks(writeTimeout);
            writing = false;
            if (status == BluetoothGatt.GATT_SUCCESS) flushCommandQueue();
            else failLink("Band write failed: " + status, true);
        }
    };

    private void handleNotification(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, byte[] value) {
        if (gatt != bluetoothGatt || disconnecting || !NOTIFY_UUID.equals(characteristic.getUuid()) || value == null) return;
        String address = connectedAddress;
        String name = connectedName;
        long receivedAt = System.currentTimeMillis();
        byte[] packet = value.clone();
        try {
            packetWorker.execute(() -> {
                if (gatt != bluetoothGatt) return;
                try {
                    BleSDK.DataParsingWithData(packet, new DataListener2301() {
                        @Override
                        public void dataCallback(Map<String, Object> data) {
                            deliverPacket(gatt, data, address, name, receivedAt);
                        }

                        @Override
                        public void dataCallback(byte[] ignored) {}
                    });
                } catch (RuntimeException error) {
                    logNative("parser", "Unable to parse band packet: " + error.getClass().getSimpleName());
                }
            });
        } catch (java.util.concurrent.RejectedExecutionException error) {
            if (!packetWorker.isShutdown()) Log.w(TAG, "Band packet queue is full");
        }
    }
}
