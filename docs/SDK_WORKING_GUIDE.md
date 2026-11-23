# React Native BLE SDK V8 Working Guide

This document explains how this SDK works end to end: how a React Native app calls it, how iOS connects to the wearable, how commands are sent, how data comes back, and where server upload and health helpers fit in.

## 1. What This SDK Is

`react-native-ble-sdk-v8` is an iOS-only React Native wrapper around the vendor V8 wearable BLE SDK.

The important pieces are:

| Layer | File | Responsibility |
|---|---|---|
| React Native public API | `index.js` | Exposes functions such as `startScan`, `connect`, `getSleepHistory`, `setRealtimeData`, and event helpers. |
| React Native helper logic | `src/serverUpload.js`, `src/healthInsights.js`, `src/sleepLogic.js` | Adds server upload controls, sleep context, health enrichment, and mental wellness estimates. |
| Native React bridge | `ios/RNBleSdkV8.m` | Receives JS calls, calls the vendor SDK, transforms parsed data, emits JS events, and performs native upload. |
| BLE transport | `ios/NewBle.m` | Uses CoreBluetooth to scan, connect, discover services, enable notifications, write commands, and receive packets. |
| Vendor SDK | `ios/BleSDK/libBleSDK.a`, `ios/BleSDK/*.h` | Closed-source static library that builds command bytes and parses raw BLE bytes into `DeviceData_V8`. |

The vendor parser implementation is inside `libBleSDK.a`, so its internal parsing code is not visible. The public headers and wrapper code show how this project uses it.

## 2. High-Level Flow

```text
React Native app
  |
  | import BleSdk from 'react-native-ble-sdk-v8'
  v
index.js
  |
  | calls NativeModules.RNBleSdkV8
  v
ios/RNBleSdkV8.m
  |
  | asks BleSDK_V8 to create command bytes
  v
ios/BleSDK/libBleSDK.a
  |
  | command bytes
  v
ios/NewBle.m
  |
  | CoreBluetooth write to service FFF0 / characteristic FFF6
  v
Wearable device
  |
  | response notification on characteristic FFF7
  v
ios/NewBle.m
  |
  | raw NSData packet
  v
ios/RNBleSdkV8.m
  |
  | BleSDK_V8 parses raw bytes into DeviceData_V8
  | wrapper adds timestamps, offsets, normalized fields
  v
React Native BleEvents.DATA event
  |
  | optional JS enrichment or native server upload
  v
App UI / backend
```

## 3. Installation In A Host React Native App

Install the package:

```bash
npm install /path/to/react-native-ble-sdk-v8
```

Install iOS pods:

```bash
cd ios
pod install
```

Add Bluetooth permission to the host app `Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to communicate with your wearable device.</string>
```

If you upload to an HTTP URL, also add an App Transport Security exception, or use HTTPS in production.

## 4. Public JavaScript API

Import from `index.js`:

```js
import BleSdk, {
  BleEvents,
  addBleListener,
  startAutoUpload,
  configureServer,
} from 'react-native-ble-sdk-v8';
```

Main connection functions:

| Function | Purpose |
|---|---|
| `startScan(nameFilter = '')` | Scans for nearby BLE devices. No service UUID filter is used because the V8/JCVital band may not advertise its service UUID. |
| `stopScan()` | Stops scanning. |
| `connect(peripheralUUID)` | Connects to a discovered peripheral UUID. |
| `disconnect()` | Disconnects current device. |
| `addBleListener(eventName, callback)` | Subscribes to native BLE events. Call `.remove()` on cleanup. |

Device info commands:

| Function | Purpose |
|---|---|
| `getDeviceTime()` | Reads watch time. |
| `getPersonalInfo()` | Reads personal profile stored on watch. |
| `getBatteryLevel()` | Reads battery level. |
| `getDeviceVersion()` | Reads firmware/device version. |
| `getStepGoal()` | Reads step goal. |
| `getMacAddress()` | Reads MAC address. |

History and measurement commands:

| Function | Purpose |
|---|---|
| `getSleepHistory(mode, startDate)` | Reads detailed sleep records. |
| `getSleepAndActivityHistory(mode, startDate)` | Reads combined sleep and activity records. |
| `getContinuousHRHistory(mode, startDate)` | Reads continuous heart-rate history. |
| `getSingleHRHistory(mode, startDate)` | Reads manual/single heart-rate records. |
| `getAutomaticSpo2History(mode, startDate)` | Reads automatic SpO2 history. |
| `getManualSpo2History(mode, startDate)` | Reads manual SpO2 records. |
| `getTemperatureHistory(mode, startDate)` | Reads temperature history. |
| `getHRVHistory(mode, startDate)` | Reads HRV history. |
| `getPPIHistory(mode, startDate)` | Reads PPI/RR interval history. |
| `getTotalActivityData(mode, startDate)` | Reads total activity records. |
| `getDetailActivityData(mode, startDate)` | Reads detailed activity records. |
| `getActivityModeHistory(mode, startDate)` | Reads activity mode records. |
| `setRealtimeData(enabled)` | Enables/disables real-time step and heart-rate stream. |
| `ppgControl(ppgMode, ppgStatus)` | Controls PPG measurement. |

History `mode` values follow the vendor SDK:

| Mode | Meaning |
|---|---|
| `0` | Start from latest position, up to 50 records. |
| `2` | Read next page when more than 50 records exist. |
| `0x99` | Delete that history type from device, where supported. |

## 5. Events

Events are defined in `BleEvents`:

| Event | Native name | Payload |
|---|---|---|
| `DEVICE_FOUND` | `BleDeviceFound` | `{ uuid, name, rssi, source, advertisementData }` |
| `CONNECTED` | `BleConnected` | `{ connected: true, uuid, name }` |
| `DISCONNECTED` | `BleDisconnected` | `{ connected: false, error? }` — emitted after CoreBluetooth confirms a disconnect, or immediately when disconnect is requested with no active/connecting peripheral. |
| `CONNECT_FAILED` | `BleConnectFailed` | `{ error }` |
| `DATA` | `BleData` | Parsed wearable payload. |
| `BLE_STATE_CHANGED` | `BlePowerStateChanged` | `{ state: 'poweredOn' }` |

Native upload also emits `BleUploadStatus`, used internally by `src/serverUpload.js`.

## 6. Typical App Flow

```js
import BleSdk, { BleEvents, addBleListener } from 'react-native-ble-sdk-v8';

const foundSub = addBleListener(BleEvents.DEVICE_FOUND, device => {
  console.log('Found device:', device.name, device.uuid);
  BleSdk.stopScan();
  BleSdk.connect(device.uuid);
});

const connectedSub = addBleListener(BleEvents.CONNECTED, () => {
  BleSdk.getBatteryLevel();
  BleSdk.getSleepHistory(0);
  BleSdk.getAutomaticSpo2History(0);
  BleSdk.setRealtimeData(true);
});

const dataSub = addBleListener(BleEvents.DATA, payload => {
  console.log(payload.dataType, payload.dataEnd, payload.data);
});

BleSdk.startScan('JCVital');

// On screen unmount:
// foundSub.remove();
// connectedSub.remove();
// dataSub.remove();
```

## 7. Native BLE Details

The wearable protocol uses these UUIDs in `ios/RNBleSdkV8.m` and `ios/NewBle.m`:

| UUID | Meaning |
|---|---|
| `FFF0` | BLE service. |
| `FFF6` | Write/send characteristic. |
| `FFF7` | Receive/notify characteristic. |

Connection lifecycle:

1. `RNBleSdkV8.init` creates and stores a `NewBle` singleton delegate.
2. `NewBle.SetUpCentralManager` creates a `CBCentralManager`.
3. `startScan` calls `scanForPeripheralsWithServices:nil`.
4. Each discovered peripheral is emitted to JS as `BleDeviceFound`.
5. `connect(uuid)` connects to a known peripheral or starts a pending auto-connect scan.
6. On connection, `NewBle` discovers all services and characteristics.
7. When characteristics are discovered, `NewBle.enable` enables notifications on `FFF7`.
8. `RNBleSdkV8.EnableCommunicate` emits `BleConnected`.
9. Commands write to `FFF6`.
10. Device responses arrive on `FFF7`.

`NewBle` also handles:

| Behavior | Detail |
|---|---|
| Deferred scan | If Bluetooth is not powered on yet, scan intent is stored and started when the central manager becomes powered on. |
| Already connected peripherals | `RNBleSdkV8` checks `retrieveConnectedPeripheralsWithServices:@[FFF0]`. |
| Reconnect | Unexpected disconnects can reconnect if `_allowAutoReconnect` is true. |
| Device switching | If a different device is active, the old device is disconnected before connecting the new target. |

## 8. Command And Response Flow

Example: `getSleepHistory(0)`.

```text
JS: getSleepHistory(0)
  -> index.js calls RNBleSdkV8.getSleepHistory(0, null)
  -> RNBleSdkV8 calls [[BleSDK_V8 sharedManager] GetDetailSleepDataWithMode:0 withStartDate:nil]
  -> BleSDK_V8 returns NSMutableData command bytes
  -> RNBleSdkV8.sendData writes bytes through NewBle
  -> NewBle writes to FFF6
  -> device sends response notification on FFF7
  -> NewBle calls BleCommunicateWithPeripheral:data:
  -> RNBleSdkV8 calls [[BleSDK_V8 sharedManager] DataParsingWithData:data]
  -> BleSDK_V8 returns DeviceData_V8
  -> RNBleSdkV8 emits BleData to JS
```

Important: most command functions do not directly return the final data. They send a command, and the response arrives later through the `BleEvents.DATA` event.

## 9. Data Payload Shape

Each `BleData` payload is built in `ios/RNBleSdkV8.m`:

```js
{
  dataType: 27,
  dataEnd: true,
  uuid: 'peripheral-uuid',
  timestamp: '2026-09-08T...',
  packetTimestamp: '2026-09-08T...',
  receivedAt: '2026-09-08T...',
  sensorTimestamp: '2026-09-08T...',
  timestampMs: 178...,
  packetTimestampMs: 178...,
  sensorTimestampMs: 178...,
  collectedAt: '2026-09-08T...',
  collectedAtLocal: '2026-09-08 12:34:56.789 +05:00',
  collectedAtMs: 178...,
  data: {
    // Parsed vendor SDK fields for this dataType
  }
}
```

`dataEnd` tells whether the final page/packet for that request has arrived.

## 10. Common Data Types

Data types come from `ios/BleSDK/BleSDK_Header_V8.h`.

| Value | Name | Meaning |
|---:|---|---|
| `0` | `GetDeviceTime_V8` | Device time response. |
| `2` | `GetPersonalInfo_V8` | Personal info response. |
| `9` | `GetDeviceBattery_V8` | Battery response. |
| `10` | `GetDeviceMacAddress_V8` | MAC address response. |
| `11` | `GetDeviceVersion_V8` | Device version response. |
| `24` | `RealTimeStep_V8` | Real-time step/heart-rate packet. |
| `25` | `TotalActivityData_V8` | Total activity history. |
| `26` | `DetailActivityData_V8` | Detailed activity history. |
| `27` | `DetailSleepData_V8` | Sleep history. |
| `28` | `DynamicHR_V8` | Continuous heart-rate history. |
| `29` | `StaticHR_V8` | Single/manual heart-rate history. |
| `30` | `ActivityModeData_V8` | Activity mode history. |
| `41` | `HRVData_V8` | HRV history. |
| `45` | `AutomaticSpo2Data_V8` | Automatic SpO2 history. |
| `46` | `ManualSpo2Data_V8` | Manual SpO2 history. |
| `48` | `TemperatureData_V8` | Temperature history. |
| `68` | `realtimeRRIntervalData_V8` | Real-time RR interval data. |
| `69` | `realtimePPIData_V8` | Real-time PPI data. |
| `70` | `realtimePPGData_V8` | Real-time PPG data. |
| `81` | `DetailSleepAndActivityData_V8` | Combined sleep and activity data. |
| `82` | `ppiData_V8` | PPI history data. |
| `255` | `DataError_V8` | Parser/protocol error. |

## 11. Native Data Transformations

Before data is emitted to JS, `RNBleSdkV8.m` can apply offsets set by:

```js
BleSdk.setTransformConfig({
  spo2Offset: 2,
  heartRateOffset: 0,
  temperatureOffset: 0,
  awakeDurationOffset: 0,
  totalSleepTimeOffset: 0,
  hrvOffset: 0,
  stepsOffset: 0,
});
```

Transform behavior:

| Data | Fields changed |
|---|---|
| Automatic SpO2 | Adds `spo2Offset` to `arrayAutomaticSpo2Data[].automaticSpo2Data`. |
| Manual SpO2 | Adds `spo2Offset` to `arrayManualSpo2Data[].manualSpo2Data`. |
| Continuous HR | Adds `heartRateOffset` to values inside `arrayContinuousHR[].arrayHR`. |
| Single HR | Adds `heartRateOffset` to `arraySingleHR[].singleHR`. |
| Sleep | Adds `totalSleepTimeOffset`; computes `awakeDurationMinutes` from sleep stages and applies `awakeDurationOffset`. |
| Temperature | Adds `temperatureOffset` to `arrayTemperatureData[].temperature`. |
| Real-time step | Normalizes step aliases: `steps`, `step`, `stepCount`, `totalSteps`; applies `stepsOffset`. |
| Real-time HR | Normalizes `heartRate` and `hr`; applies `heartRateOffset`. |
| HRV | Adds `hrvOffset` to `arrayHRVData[].hrv`. |
| PPI/RR | Normalizes interval aliases into `arrayPPIData`, `ppi`, `rrInterval`, and timestamp fields. |
| Real-time PPG | Adds `ppgTimestamp`, `measurementTime`, and millisecond fields. |

Offsets are clamped to `0` for non-temperature values.

## 12. Sleep And Health Helpers

`src/healthInsights.js` provides JS-side helpers.

Sleep stage encoding:

| Value | Stage |
|---:|---|
| `0` | Awake |
| `1` | Light sleep |
| `2` | Deep sleep |
| `3` | REM |

Important helpers:

| Helper | Purpose |
|---|---|
| `buildSleepWindows(sleepPayload)` | Converts sleep stage arrays into time windows. |
| `isSleepingAt(date, sleepWindows)` | Checks whether a time falls inside a sleep window. |
| `isSleepingFromBlePayload(payload)` | Returns current sleep status based on latest sleep payload. |
| `updateSleepContextWithPayload(payload)` | Stores latest sleep payload in module state. |
| `enrichBlePayloadWithSleepContext(payload)` | Adds sleep context and per-record `isSleeping` tags where possible. |
| `buildHealthContext(...)` | Combines sleep, HR, SpO2, temperature, and HRV context. |
| `estimateMentalWellnessFromPayload(payload)` | Estimates stress/anxiety level from vitals. |

The sleep status is inferred from historical sleep stage records. It is not a dedicated real-time sleep flag from firmware.

## 13. Server Upload

There are two upload paths:

1. Native auto-upload: native code posts each parsed packet automatically after `startAutoUpload()`.
2. Manual upload: JS calls `uploadData(payload)` or `uploadToEndpoint(endpoint, data)`, but those still delegate posting to native iOS.

Default upload config:

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

Configure it:

```js
configureServer({
  baseUrl: 'https://api.example.com',
  endpoint: '/wearable/packets',
  authToken: 'Bearer real-token',
  deviceId: 'user-or-device-id',
  onRequest: event => console.log('upload request', event),
  onSuccess: (body, event) => console.log('upload ok', body.dataType),
  onError: (error, body, event) => console.log('upload failed', error.message),
});
```

Start auto-upload after connection:

```js
startAutoUpload();
```

Native upload body includes:

| Field | Meaning |
|---|---|
| `schemaVersion` | Current native schema, `2.0-native`. |
| `deviceId` | Configured app/user/device identifier. |
| `bleDeviceUuid` | Connected BLE peripheral UUID. |
| `timestamp`, `packetTimestamp`, `receivedAt`, `sensorTimestamp`, `collectedAt` | Packet collection timestamp. |
| `timestampMs`, `packetTimestampMs`, `sensorTimestampMs`, `collectedAtMs` | Epoch millisecond versions. |
| `uploadedAt`, `uploadedAtMs` | Time upload body was created. |
| `dataType`, `dataTypeName`, `dataEnd` | Vendor SDK metadata. |
| `healthStatus` | Native-derived latest steps, HR, SpO2, temperature, HRV, and sleep summary. |
| `metrics` | Record counts for arrays in the packet. |
| `data` | Parsed vendor data. |
| `payload` | Full emitted BLE payload. |

## 14. How To Add A New SDK Command

Use this pattern:

1. Check `ios/BleSDK/BleSDK_V8.h` for the vendor method that creates command bytes.
2. Add an `RCT_EXPORT_METHOD` in `ios/RNBleSdkV8.m`.
3. Inside that method, call the vendor SDK method and pass the returned `NSData` to `sendData:`.
4. Add a JS wrapper function in `index.js`.
5. Listen for `BleEvents.DATA` and check the `dataType` from `BleSDK_Header_V8.h`.
6. If needed, add transform/normalization handling in `BleCommunicateWithPeripheral:data:`.

Example native pattern:

```objc
RCT_EXPORT_METHOD(getBatteryLevel) {
    [self sendData:[[BleSDK_V8 sharedManager] GetDeviceBatteryLevel]];
}
```

Example JS pattern:

```js
export function getBatteryLevel() {
  RNBleSdkV8.getBatteryLevel();
}
```

## 15. Debugging Checklist

If no devices are found:

| Check | Why |
|---|---|
| Bluetooth is enabled | `NewBle` waits for `CBManagerStatePoweredOn`. |
| iOS permission is present | Missing `NSBluetoothAlwaysUsageDescription` can block Bluetooth access. |
| Use empty scan filter | The SDK scans all devices, but `nameFilter` can hide devices. |
| Device is advertising | Some wearables stop advertising while already connected elsewhere. |

If connect succeeds but no data arrives:

| Check | Why |
|---|---|
| `BleConnected` fired | It fires only after notifications are enabled. |
| Service `FFF0` exists | Commands require this service. |
| Characteristic `FFF6` exists | Commands are written here. |
| Characteristic `FFF7` exists | Responses arrive here. |
| Command sent after connection | Writes before discovery/notification setup can fail. |

If server upload fails:

| Check | Why |
|---|---|
| Use HTTPS or ATS exception | iOS blocks many HTTP requests by default. |
| Set real `authToken` | Default token is placeholder. |
| Verify `baseUrl` and `endpoint` | Native code joins them after trimming slashes. |
| Listen to upload status | `configureServer({ onError })` exposes failure messages. |

## 16. Best Integration Order

For a new app, implement in this order:

1. Install package and run `pod install`.
2. Add Bluetooth permission.
3. Add scan screen using `DEVICE_FOUND`.
4. Add connect flow using `CONNECTED`, `DISCONNECTED`, and `CONNECT_FAILED`.
5. After connection, call simple commands first: `getBatteryLevel`, `getDeviceVersion`.
6. Add history commands and inspect `BleEvents.DATA`.
7. Add `setRealtimeData(true)` if real-time stream is needed.
8. Configure server upload only after local BLE data is confirmed.
9. Add sleep/health enrichment if the UI or backend needs sleep context.

## 17. Source Files To Read Next

Read these files in this order:

1. `README.md` - quick install and usage.
2. `index.js` - public React Native API.
3. `ios/RNBleSdkV8.m` - native bridge, command exports, events, transforms, upload.
4. `ios/NewBle.m` - CoreBluetooth scanning, connecting, writing, receiving.
5. `ios/BleSDK/BleSDK_V8.h` - vendor SDK command methods.
6. `ios/BleSDK/BleSDK_Header_V8.h` - data type enum and structs.
7. `src/serverUpload.js` - upload controls from JS.
8. `src/healthInsights.js` - sleep, health, and mental wellness helper logic.

