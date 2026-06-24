# react-native-ble-sdk-v8

React Native iOS wrapper for the V8 BLE wearable SDK.  
Wraps the pre-compiled `libBleSDK.a` so the React Native team can install it
exactly like any other npm library.

---

## Installation

```bash
npm install /path/to/react-native-ble-sdk-v8
# or from a git repo / npm registry once published:
# npm install react-native-ble-sdk-v8
```

Then link the native iOS pod:

```bash
cd ios && pod install
```

Add the following permission to `ios/YourApp/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to communicate with your wearable device.</string>
```

---

## Usage

```js
import BleSdk, {
  BleEvents,
  addBleListener,
  startAutoUpload,
} from 'react-native-ble-sdk-v8';

// 1. (Optional) Customise values BEFORE any scanning starts
BleSdk.setTransformConfig({
  spo2Offset:           2,   // add 2% to every SpO2 reading
  heartRateOffset:      0,
  temperatureOffset:    0.0,
  awakeDurationOffset:  0,   // minutes to add to awake time in sleep records
  totalSleepTimeOffset: 0,
  hrvOffset:            0,
  stepsOffset:          0,
});

// 2. Listen for events
const onFound = addBleListener(BleEvents.DEVICE_FOUND, device => {
  console.log('Found:', device.uuid, device.name, 'RSSI:', device.rssi);
  BleSdk.stopScan();
  BleSdk.connect(device.uuid);
});

const onConnected = addBleListener(BleEvents.CONNECTED, () => {
  console.log('Connected!');
  startAutoUpload();                 // native SDK posts every received packet
  BleSdk.getSleepHistory(0);          // fetch latest 50 sleep records
  BleSdk.getAutomaticSpo2History(0);  // fetch latest 50 SpO2 records
  BleSdk.setRealtimeData(true);       // start real-time step + HR stream
});

const onData = addBleListener(BleEvents.DATA, payload => {
  // payload.dataType  — numeric type ID (matches DATATYPE_V8 enum)
  // payload.dataEnd   — true when the last page of data has arrived
  // payload.data      — the parsed + transformed data object
  console.log('Data type:', payload.dataType, payload.data);
});

const onDisconnected = addBleListener(BleEvents.DISCONNECTED, () => {
  console.log('Disconnected');
});

// 3. Start scanning
BleSdk.startScan();

// 4. Clean up on unmount
// onFound.remove();
// onConnected.remove();
// onData.remove();
// onDisconnected.remove();
```

## Native Server Upload

`configureServer()` and `startAutoUpload()` are thin JavaScript controls for a
native upload pipeline. The React Native app does not need to listen for
`BleEvents.DATA` and call `fetch`; once auto-upload is enabled, `RNBleSdkV8.m`
posts each parsed packet directly from the SDK layer.

The SDK ships with these native defaults:

```js
{
  baseUrl: 'http://167.172.132.179:5000',
  endpoint: '/JC_band_data_dump',
  authToken: 'Bearer YOUR_TOKEN',
  deviceId: 'test-device-001',
  timeoutMs: 30000,
  retryCount: 0,
}
```

The host app can still call `configureServer()` to override them for another
customer, environment, or user/device id.

Each upload body includes:

| Key | Description |
|---|---|
| `schemaVersion` | Native upload schema, currently `2.0-native` |
| `deviceId` | Your configured app/user/device identifier |
| `bleDeviceUuid` | Connected BLE peripheral UUID |
| `timestamp`, `packetTimestamp`, `receivedAt`, `sensorTimestamp`, `collectedAt` | Time the BLE packet reached the phone, generated in full ISO-8601 format |
| `timestampMs`, `packetTimestampMs`, `sensorTimestampMs`, `collectedAtMs` | Same packet collection time as Unix epoch milliseconds |
| `collectedAtLocal` | Same packet collection time as a readable local string with clock time and timezone |
| `uploadedAt`, `uploadedAtMs` | Time the SDK built the server upload request |
| `dataType`, `dataTypeName`, `dataEnd` | Vendor SDK packet metadata |
| `healthStatus` | SDK-derived latest steps, HR, SpO2, temperature, HRV, sleep summary |
| `metrics.records` | Counts for records in this packet |
| `data` | Parsed vendor SDK payload |
| `payload` | Full emitted BLE payload |

Realtime PPG packets (`dataType: 70`) also include `data.ppgTimestamp` and
`data.measurementTime`, plus millisecond fields, all set to the same packet
receive time. Realtime PPI/RR packets are normalized into `data.arrayPPIData`
with `ppi`, `rrInterval`, `measurementTime`, `collectedAt`, and
`collectedAtMs` on each record.

For HTTP endpoints on iOS, add an App Transport Security exception in the host
app's `Info.plist`, or use HTTPS in production.

## Sleep Status + Vital Context

Use these helpers when you need to decide if the user was sleeping at a given
time and annotate HR/SpO2/temperature with that context.

```js
import {
  buildSleepWindows,
  isSleepingFromBlePayload,
  buildHealthContext,
} from 'react-native-ble-sdk-v8';

let latestSleepPayload = null;

addBleListener(BleEvents.DATA, (payload) => {
  // Save latest sleep packet (dataType 27 or 81)
  if (payload.dataType === 27 || payload.dataType === 81) {
    latestSleepPayload = payload;

    const sleepNow = isSleepingFromBlePayload(payload);
    console.log('isSleepingNow:', sleepNow.isSleepingNow);
  }

  // Example: when HR packet arrives, annotate with sleep context
  if (payload.dataType === 28 && latestSleepPayload) {
    const context = buildHealthContext({
      sleepPayload: latestSleepPayload,
      heartRatePayload: payload,
    });
    console.log('HR with sleep tags:', context.heartRate.continuous);
  }
});
```

Notes:
- Sleep stage encoding used by SDK: `0=awake`, `1=light`, `2=deep`, `3=REM`.
- `isSleepingNow` is based on whether current time falls into any non-awake
  sleep window reconstructed from `arraySleepQuality` and `sleepUnitLength`.
- This is inference from historical packets, not a dedicated real-time sleep
  flag from firmware.

### RN functions you can call directly

```js
import {
  updateSleepContextWithPayload,
  enrichBlePayloadWithSleepContext,
  getSleepContextState,
  resetSleepContextState,
  setAutoUploadSleepContextEnabled,
} from 'react-native-ble-sdk-v8';

// 1) On every BleEvents.DATA packet
addBleListener(BleEvents.DATA, (payload) => {
  // Keeps latest sleep windows in memory when payload is sleep type
  updateSleepContextWithPayload(payload);

  // Any payload (HR/SpO2/temp/...) gets sleepContext + per-record isSleeping tags
  const enriched = enrichBlePayloadWithSleepContext(payload);
  console.log(enriched.sleepContext?.isSleepingNow);
});

// 2) Read current state any time
const sleepState = getSleepContextState();
console.log('isSleepingNow:', sleepState.isSleepingNow);

// 3) Reset cached windows (e.g. on logout/device switch)
resetSleepContextState();

// 4) Auto-upload already enriches by default; disable if needed
setAutoUploadSleepContextEnabled(false);
```

Auto-upload note:
- `startAutoUpload()` sends data directly from the iOS SDK bridge.
- JS sleep helpers are still available for UI-side context, but native
  auto-upload does not require a JS event listener or RN `fetch`.

Mental wellness note:
- Enriched payloads now include `mentalWellness` with `stressScore`, `stressLevel`, `anxietyScore`, and `anxietyLevel`.
- Mental wellness fields are produced by the JS helper layer. Native auto-upload
  sends raw vitals and SDK-derived `healthStatus`.

---

## Event reference

| Event constant | Payload keys | Description |
|---|---|---|
| `BleEvents.DEVICE_FOUND` | `uuid`, `name`, `rssi` | A peripheral found during scan |
| `BleEvents.CONNECTED` | `connected: true` | Device connected and ready |
| `BleEvents.DISCONNECTED` | `connected: false`, `error?` | Device disconnected |
| `BleEvents.CONNECT_FAILED` | `error` | Connection attempt failed |
| `BleEvents.DATA` | `dataType`, `dataEnd`, `data` | Parsed device data |
| `BleEvents.BLE_STATE_CHANGED` | `state` | Bluetooth power state |

---

## `setTransformConfig` — value customisation

Because we cannot modify the vendor SDK binary, all value adjustments are
applied in the native bridge layer **before** the data reaches JavaScript.

| Key | Type | Default | Effect |
|---|---|---|---|
| `spo2Offset` | integer | 0 | Added to every SpO2 % reading |
| `heartRateOffset` | integer | 0 | Added to every heart-rate bpm |
| `temperatureOffset` | float | 0.0 | Added to every temperature value |
| `awakeDurationOffset` | integer | 0 | Minutes added to computed awake time |
| `totalSleepTimeOffset` | integer | 0 | Minutes added to total sleep time |
| `hrvOffset` | integer | 0 | Added to every HRV value |
| `stepsOffset` | integer | 0 | Added to step counts |

> Values are clamped to `0` so they never go negative.

---

## Available commands

| Method | Description |
|---|---|
| `startScan()` | Scan for V8 peripherals |
| `stopScan()` | Stop scanning |
| `connect(uuid)` | Connect to a peripheral UUID |
| `disconnect()` | Disconnect current device |
| `getDeviceTime()` | Read device clock |
| `getPersonalInfo()` | Read personal info (age, height, weight…) |
| `getBatteryLevel()` | Read battery % |
| `getDeviceVersion()` | Read firmware version |
| `getStepGoal()` | Read daily step goal |
| `getSleepHistory(mode, date?)` | Fetch sleep records |
| `getSleepAndActivityHistory(mode, date?)` | Fetch combined sleep+activity |
| `getContinuousHRHistory(mode, date?)` | Fetch continuous heart rate log |
| `getSingleHRHistory(mode, date?)` | Fetch spot heart-rate log |
| `getAutomaticSpo2History(mode, date?)` | Fetch auto SpO2 log |
| `getManualSpo2History(mode, date?)` | Fetch manual SpO2 log |
| `getTemperatureHistory(mode, date?)` | Fetch temperature log |
| `getHRVHistory(mode, date?)` | Fetch HRV log |
| `getPPIHistory(mode, date?)` | Fetch PPI log |
| `getTotalActivityData(mode, date?)` | Fetch total activity summary |
| `getDetailActivityData(mode, date?)` | Fetch detailed activity records |
| `setRealtimeData(enabled)` | Toggle real-time step/HR streaming |
| `ppgControl(mode, status?)` | Start / stop PPG measurement |
| `clearAllHistoryData()` | Erase all stored records on device |
| `configureServer(config)` | Configure SDK-owned native upload |
| `startAutoUpload()` | Start native auto-upload of every received BLE packet |
| `stopAutoUpload()` | Stop native auto-upload |
| `uploadData(payload)` | Manually upload a payload through the native SDK bridge |

`mode` values: `0` = latest 50, `2` = next page, `0x99` = delete all.

---

## Data type IDs (payload.dataType)

The `dataType` number in each `BleEvents.DATA` event maps to the
`DATATYPE_V8` enum defined in `BleSDK_Header_V8.h`.  Key values:

| Value | Meaning |
|---|---|
| 27 | `DetailSleepData_V8` — sleep history |
| 28 | `DynamicHR_V8` — continuous HR |
| 29 | `StaticHR_V8` — single HR |
| 41 | `HRVData_V8` |
| 45 | `AutomaticSpo2Data_V8` |
| 46 | `ManualSpo2Data_V8` |
| 48 | `TemperatureData_V8` |
| 81 | `DetailSleepAndActivityData_V8` |
| 24 | `RealTimeStep_V8` — live step/HR |
