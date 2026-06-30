//
//  WearableRNModule.swift
//
//  React Native Native Module — bridges WearableManager to JavaScript.
//
//  SETUP IN XCODE:
//  1. Add this file + WearableRNModule.m to your Xcode project.
//  2. Make sure "Ble-SDK-Demo-Bridging-Header.h" already imports <React/RCTBridgeModule.h>
//     and <React/RCTEventEmitter.h>. If not, add those two imports.
//  3. In your RN app: import WearableModule from './WearableModule';
//

import Foundation
import CoreBluetooth

@objc(WearableModule)
final class WearableRNModule: RCTEventEmitter {

    // ----------------------------------------------------------------
    // MARK: RCTEventEmitter boilerplate
    // ----------------------------------------------------------------
    override static func requiresMainQueueSetup() -> Bool { true }

    /// Every event name you emit must be listed here.
    override func supportedEvents() -> [String]! {
        return [
            "onConnectionStateChanged",   // "idle"|"scanning"|"connecting"|"connected"|"disconnected"
            "onBluetoothStateChanged",     // "unknown"|"resetting"|"unsupported"|"unauthorized"|"poweredOff"|"poweredOn"
            "onDeviceFound",              // { id, name, rssi }

            // Universal BLE scanner (any peripheral)
            "onUniversalDeviceFound",     // { id, name, rssi, localName?, manufacturerDataHex?, serviceUUIDs[] }
            "onUniversalConnectionState", // "idle"|"scanning"|"connecting"|"connected"|"disconnected"
            "onUniversalServicesDiscovered", // [{ uuid, characteristics: [{ uuid, properties }] }]
            "onUniversalError",           // { message }

            "onHeartRateData",            // [{ date, heartbeatPerMinute[] }]
            "onSingleHeartRateData",      // [{ date, singleHR }]
            "onSpo2Data",                 // [{ date, spo2 }]
            "onSleepData",                // [{ date, sleepStages }]
            "onActivityData",             // [{ date, steps, calories, distance }]
            "onTemperatureData",          // [{ date, temperature }]
            "onHRVData",                  // [{ date, hrv }]
            "onRealtimeStepData",         // { steps, calories, distance }
            "onDeviceInfo",               // { macAddress, version, batteryLevel }
            "onError",                    // { message }
        ]
    }

    // ----------------------------------------------------------------
    // MARK: Module setup — wire WearableManager callbacks once
    // ----------------------------------------------------------------
    @objc override func startObserving() {
        let mgr = WearableManager.shared

        mgr.onConnectionStateChanged = { [weak self] state in
            self?.sendEvent(withName: "onConnectionStateChanged",
                            body: state.rawStringValue)
        }

        mgr.onBluetoothStateChanged = { [weak self] state in
            self?.sendEvent(withName: "onBluetoothStateChanged", body: state)
        }

        mgr.onPeripheralFound = { [weak self] peripheral, rssi in
            self?.sendEvent(withName: "onDeviceFound", body: [
                "id":   peripheral.identifier.uuidString,
                "name": peripheral.name ?? "Unknown",
                "rssi": rssi.intValue
            ])
        }

        mgr.onHeartRateReceived = { [weak self] records in
            self?.sendEvent(withName: "onHeartRateData",
                            body: records.map { $0.toDict() })
        }

        mgr.onSingleHeartRateReceived = { [weak self] records in
            self?.sendEvent(withName: "onSingleHeartRateData",
                            body: records.map { $0.toDict() })
        }

        mgr.onSpo2Received = { [weak self] records in
            self?.sendEvent(withName: "onSpo2Data",
                            body: records.map { $0.toDict() })
        }

        mgr.onSleepReceived = { [weak self] records in
            self?.sendEvent(withName: "onSleepData",
                            body: records.map { ["date": $0.date, "sleepStages": $0.sleepStages] })
        }

        mgr.onActivityReceived = { [weak self] records in
            self?.sendEvent(withName: "onActivityData",
                            body: records.map { $0.toDict() })
        }

        mgr.onTemperatureReceived = { [weak self] records in
            self?.sendEvent(withName: "onTemperatureData",
                            body: records.map { $0.toDict() })
        }

        mgr.onHRVReceived = { [weak self] records in
            self?.sendEvent(withName: "onHRVData",
                            body: records.map { $0.toDict() })
        }

        mgr.onRealtimeStepReceived = { [weak self] data in
            self?.sendEvent(withName: "onRealtimeStepData", body: data.toDict())
        }

        mgr.onDeviceInfoReceived = { [weak self] info in
            self?.sendEvent(withName: "onDeviceInfo", body: [
                "macAddress":   info.macAddress ?? "",
                "version":      info.version ?? "",
                "batteryLevel": info.batteryLevel ?? -1
            ])
        }

        // ---- Universal BLE scanner callbacks --------------------
        let universal = UniversalBLEManager.shared

        universal.onStateChanged = { [weak self] state in
            self?.sendEvent(withName: "onUniversalConnectionState", body: state)
        }

        universal.onDeviceFound = { [weak self] device in
            var body: [String: Any] = [
                "id":          device.id,
                "name":        device.name,
                "rssi":        device.rssi,
                "serviceUUIDs": device.serviceUUIDs,
                "time" : device.time
            ]
            if let ln = device.localName          { body["localName"] = ln }
            if let mfr = device.manufacturerDataHex { body["manufacturerDataHex"] = mfr }
            self?.sendEvent(withName: "onUniversalDeviceFound", body: body)
        }

        universal.onServicesDiscovered = { [weak self] services in
            let payload = services.map { svc -> [String: Any] in
                let chars = svc.characteristics.map { ch -> [String: Any] in
                    ["uuid": ch.uuid, "properties": ch.properties]
                }
                return ["uuid": svc.uuid, "characteristics": chars]
            }
            self?.sendEvent(withName: "onUniversalServicesDiscovered", body: payload)
        }

        universal.onError = { [weak self] message in
            self?.sendEvent(withName: "onUniversalError", body: ["message": message])
        }

        mgr.prepareForAutoReconnect()
    }

    @objc override func stopObserving() {
        // Optionally clear callbacks when no JS listeners remain
    }

    // ----------------------------------------------------------------
    // MARK: Exported methods — callable from React Native JS
    // ----------------------------------------------------------------

    /// Start BLE scanning for X3 devices.
    @objc func startScan() {
        WearableManager.shared.startScan()
    }

    /// Stop BLE scanning.
    @objc func stopScan() {
        WearableManager.shared.stopScan()
    }

    // ---- Universal BLE (any peripheral) ---------------------------

    /// Start scanning for ALL nearby BLE peripherals (not limited to X3 devices).
    /// Listen to `onUniversalDeviceFound` for results.
    @objc func startUniversalScan() {
        UniversalBLEManager.shared.startScan()
    }

    /// Stop the universal BLE scan.
    @objc func stopUniversalScan() {
        UniversalBLEManager.shared.stopScan()
    }

    /// Connect to any BLE peripheral discovered during a universal scan.
    /// - Parameter deviceId: The UUID string received in `onUniversalDeviceFound`.
    /// On success `onUniversalConnectionState` fires "connected" and
    /// `onUniversalServicesDiscovered` fires with the full GATT profile.
    @objc func connectUniversal(_ deviceId: String) {
        UniversalBLEManager.shared.connect(toDeviceId: deviceId)
    }

    /// Disconnect from the currently connected universal BLE peripheral.
    @objc func disconnectUniversal() {
        UniversalBLEManager.shared.disconnect()
    }

    /// Connect to a device found during scan.
    /// - Parameter deviceId: The UUID string received in onDeviceFound event.
    @objc func connectDevice(_ deviceId: String) {
        guard let peripheral = WearableManager.shared.discoveredPeripheral(withId: deviceId) else {
            sendEvent(withName: "onError",
                      body: ["message": "Device \(deviceId) not found in scan results"])
            return
        }
        WearableManager.shared.connect(to: peripheral)
    }

    /// Disconnect from the current device.
    @objc func disconnect() {
        WearableManager.shared.disconnect()
    }

    // ---- Data sync methods ----------------------------------------

    @objc func fetchHeartRateHistory(_ startDateISO: String?) {
        WearableManager.shared.fetchHeartRateHistory(startDate: date(from: startDateISO))
    }

    @objc func fetchSpo2History(_ startDateISO: String?) {
        WearableManager.shared.fetchSpo2History(startDate: date(from: startDateISO))
    }

    @objc func fetchSleepHistory(_ startDateISO: String?) {
        WearableManager.shared.fetchSleepHistory(startDate: date(from: startDateISO))
    }

    @objc func fetchActivityHistory(_ startDateISO: String?) {
        WearableManager.shared.fetchActivityHistory(startDate: date(from: startDateISO))
    }

    @objc func fetchTemperatureHistory(_ startDateISO: String?) {
        WearableManager.shared.fetchTemperatureHistory(startDate: date(from: startDateISO))
    }

    @objc func fetchHRVHistory(_ startDateISO: String?) {
        WearableManager.shared.fetchHRVHistory(startDate: date(from: startDateISO))
    }

    @objc func enableRealtimeSteps() {
        WearableManager.shared.enableRealtimeSteps()
    }

    @objc func disableRealtimeSteps() {
        WearableManager.shared.disableRealtimeSteps()
    }

    @objc func fetchDeviceInfo() {
        WearableManager.shared.fetchDeviceInfo()
    }

    /// Sync all available data types in one call.
    @objc func syncAll(_ startDateISO: String?) {
        let date = date(from: startDateISO)
        WearableManager.shared.fetchHeartRateHistory(startDate: date)
        WearableManager.shared.fetchSpo2History(startDate: date)
        WearableManager.shared.fetchSleepHistory(startDate: date)
        WearableManager.shared.fetchActivityHistory(startDate: date)
        WearableManager.shared.fetchTemperatureHistory(startDate: date)
        WearableManager.shared.fetchHRVHistory(startDate: date)
        WearableManager.shared.fetchDeviceInfo()
    }

    // ---- Device settings ------------------------------------------

    /// Set personal info on the device (needed for accurate metrics).
    @objc func setPersonalInfo(_ options: NSDictionary) {
        var info = MyPersonalInfo_X3()
        info.gender = Int32(options["gender"] as? Int ?? 0)  // 0=male, 1=female
        info.age    = Int32(options["age"]    as? Int ?? 25)
        info.height = Int32(options["height"] as? Int ?? 170) // cm
        info.weight = Int32(options["weight"] as? Int ?? 70)  // kg
        info.stride = Int32(options["stride"] as? Int ?? 70)  // cm
        if let data = BleSDK_X3.sharedManager()?.setPersonalInfo(info) {
            WearableManager.shared.writePublic(data)
        }
    }

    /// Trigger motor vibration on the device.
    @objc func vibrate() {
        if let data = BleSDK_X3.sharedManager()?.motorVibration() {
            WearableManager.shared.writePublic(data)
        }
    }

    /// Configure the server endpoint from React Native JS.
    /// Call this once at app start before any sync.
    /// - Parameters:
    ///   - baseURL: Full base URL e.g. "https://api.yourcompany.com/v1"
    ///   - token:   Bearer token string, or nil/empty to skip auth header.
    @objc func configure(_ baseURL: String, token: String?) {
        let t = (token?.isEmpty == false) ? token : nil
        WearableAPIService.shared.configure(baseURL: baseURL, bearerToken: t)
        WearableAPIService.shared.wireUp()
    }

    // ----------------------------------------------------------------
    // MARK: Private helpers
    // ----------------------------------------------------------------
    private func date(from iso: String?) -> Date? {
        guard let iso = iso else { return nil }
        return ISO8601DateFormatter().date(from: iso)
    }
}

// ----------------------------------------------------------------
// MARK: WearableConnectionState → String
// ----------------------------------------------------------------
extension WearableConnectionState {
    var rawStringValue: String {
        switch self {
        case .idle:         return "idle"
        case .scanning:     return "scanning"
        case .connecting:   return "connecting"
        case .connected:    return "connected"
        case .disconnected: return "disconnected"
        }
    }
}

// ----------------------------------------------------------------
// MARK: Model → Dictionary helpers (for RN bridge serialization)
// ----------------------------------------------------------------
extension HeartRateRecord {
    func toDict() -> [String: Any] {
        ["date": date, "heartbeatPerMinute": heartbeatPerMinute]
    }
}
extension SingleHeartRateRecord {
    func toDict() -> [String: Any] { ["date": date, "singleHR": singleHR] }
}
extension SpO2Record {
    func toDict() -> [String: Any] { ["date": date, "spo2": spo2] }
}
extension ActivityRecord {
    func toDict() -> [String: Any] {
        ["date": date, "steps": steps, "calories": calories, "distance": distance]
    }
}
extension TemperatureRecord {
    func toDict() -> [String: Any] { ["date": date, "temperature": temperature] }
}
extension HRVRecord {
    func toDict() -> [String: Any] { ["date": date, "hrv": hrv] }
}
extension RealtimeStepData {
    func toDict() -> [String: Any] {
        ["steps": steps, "calories": calories, "distance": distance]
    }
}
