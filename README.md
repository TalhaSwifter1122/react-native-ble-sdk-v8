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
import BleSdk, { BleEvents, addBleListener } from 'react-native-ble-sdk-v8';

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
