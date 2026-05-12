//
//  WearableManager.swift
//  Ble SDK Demo
//
//  A Swift singleton that wraps the Objective-C BLE SDK (NewBle + BleSDK_X3).
//  It scans, connects, parses device data and publishes results via callbacks
//  so the rest of your Swift app never needs to touch Obj-C directly.
//
//  USAGE EXAMPLE
//  -------------
//  WearableManager.shared.onHeartRateReceived = { records in
//      WearableAPIService.shared.uploadHeartRate(records)
//  }
//  WearableManager.shared.startScan()
//

import Foundation
import CoreBluetooth

// MARK: - Connection State

enum WearableConnectionState {
    case idle
    case scanning
    case connecting
    case connected
    case disconnected
}

// MARK: - WearableManager

final class WearableManager: NSObject {

    // --------------------------------------------------------
    // MARK: Singleton
    // --------------------------------------------------------
    static let shared = WearableManager()
    private override init() { super.init() }

    // --------------------------------------------------------
    // MARK: Public state
    // --------------------------------------------------------
    private(set) var connectionState: WearableConnectionState = .idle {
        didSet { onConnectionStateChanged?(connectionState) }
    }

    /// Device MAC address (populated after connection + info fetch)
    private(set) var deviceId: String = "unknown"

    // --------------------------------------------------------
    // MARK: Public callbacks  (set these from your ViewControllers / Services)
    // --------------------------------------------------------
    var onConnectionStateChanged:   ((WearableConnectionState) -> Void)?
    var onPeripheralFound:          ((CBPeripheral, NSNumber) -> Void)?

    // Health data callbacks – each fires when a full batch is ready
    var onHeartRateReceived:        (([HeartRateRecord]) -> Void)?
    var onSingleHeartRateReceived:  (([SingleHeartRateRecord]) -> Void)?
    var onSpo2Received:             (([SpO2Record]) -> Void)?
    var onSleepReceived:            (([SleepRecord]) -> Void)?
    var onActivityReceived:         (([ActivityRecord]) -> Void)?
    var onTemperatureReceived:      (([TemperatureRecord]) -> Void)?
    var onHRVReceived:              (([HRVRecord]) -> Void)?
    var onRealtimeStepReceived:     ((RealtimeStepData) -> Void)?
    var onDeviceInfoReceived:       ((DeviceInfo) -> Void)?

    // --------------------------------------------------------
    // MARK: Private accumulation buffers
    // --------------------------------------------------------
    private var hrBuffer:     [HeartRateRecord]       = []
    private var singleHRBuffer: [SingleHeartRateRecord] = []
    private var spo2Buffer:   [SpO2Record]             = []
    private var sleepBuffer:  [SleepRecord]            = []
    private var activityBuffer: [ActivityRecord]       = []
    private var tempBuffer:   [TemperatureRecord]      = []
    private var hrvBuffer:    [HRVRecord]              = []

    // --------------------------------------------------------
    // MARK: BLE helpers
    // --------------------------------------------------------
    private let service  = "FFF0"
    private let sendChar = "FFF6"

    private func write(_ data: NSData) {
        guard let peripheral = NewBle.sharedManager()?.activityPeripheral else { return }
        NewBle.sharedManager()?.writeValue(
            service,
            characteristicUUID: sendChar,
            p: peripheral,
            data: data as Data
        )
    }

    // --------------------------------------------------------
    // MARK: Public API – BLE scanning / connection
    // --------------------------------------------------------

    func startScan() {
        NewBle.sharedManager()?.delegate = self
        NewBle.sharedManager()?.setUpCentralManager()
        NewBle.sharedManager()?.startScanning(withServices: nil)
        connectionState = .scanning
    }

    func stopScan() {
        NewBle.sharedManager()?.stopscan()
        if connectionState == .scanning {
            connectionState = .idle
        }
    }

    func connect(to peripheral: CBPeripheral) {
        connectionState = .connecting
        NewBle.sharedManager()?.connectDevice(peripheral)
    }

    func disconnect() {
        NewBle.sharedManager()?.disconnect()
    }

    // --------------------------------------------------------
    // MARK: Public API – Data requests (call after connected)
    // --------------------------------------------------------

    func fetchHeartRateHistory(startDate: Date? = nil) {
        hrBuffer = []
        singleHRBuffer = []
        if let data = BleSDK_X3.sharedManager()?.getContinuousHRData(withMode: 0, withStartDate: startDate) {
            write(data)
        }
    }

    func fetchSpo2History(startDate: Date? = nil) {
        spo2Buffer = []
        if let data = BleSDK_X3.sharedManager()?.getAutomaticSpo2Data(withMode: 0, withStartDate: startDate) {
            write(data)
        }
    }

    func fetchSleepHistory(startDate: Date? = nil) {
        sleepBuffer = []
        if let data = BleSDK_X3.sharedManager()?.getDetailSleepData(withMode: 0, withStartDate: startDate) {
            write(data)
        }
    }

    func fetchActivityHistory(startDate: Date? = nil) {
        activityBuffer = []
        if let data = BleSDK_X3.sharedManager()?.getTotalActivityData(withMode: 0, withStartDate: startDate) {
            write(data)
        }
    }

    func fetchTemperatureHistory(startDate: Date? = nil) {
        tempBuffer = []
        if let data = BleSDK_X3.sharedManager()?.getTemperatureData(withMode: 0, withStartDate: startDate) {
            write(data)
        }
    }

    func fetchHRVHistory(startDate: Date? = nil) {
        hrvBuffer = []
        if let data = BleSDK_X3.sharedManager()?.getHRVData(withMode: 0, withStartDate: startDate) {
            write(data)
        }
    }

    func enableRealtimeSteps() {
        if let data = BleSDK_X3.sharedManager()?.realTimeData(withType: 1) {
            write(data)
        }
    }

    func disableRealtimeSteps() {
        if let data = BleSDK_X3.sharedManager()?.realTimeData(withType: 0) {
            write(data)
        }
    }

    func fetchDeviceInfo() {
        if let data = BleSDK_X3.sharedManager()?.getDeviceMacAddress() { write(data) }
        if let data = BleSDK_X3.sharedManager()?.getDeviceVersion()    { write(data) }
        if let data = BleSDK_X3.sharedManager()?.getDeviceBatteryLevel(){ write(data) }
    }

    // --------------------------------------------------------
    // MARK: Public write — used by WearableRNModule for direct commands
    // --------------------------------------------------------
    func writePublic(_ data: NSMutableData) {
        write(data)
    }

    // --------------------------------------------------------
    // MARK: Device lookup — used by WearableRNModule.connectDevice
    // --------------------------------------------------------
    private var scannedPeripherals: [String: CBPeripheral] = [:]

    func discoveredPeripheral(withId uuid: String) -> CBPeripheral? {
        scannedPeripherals[uuid]
    }

    // --------------------------------------------------------
    // MARK: Private – data parsing (called from delegate)
    // --------------------------------------------------------

    private func parse(rawData: Data) {
        guard let deviceData = BleSDK_X3.sharedManager()?.dataParsing(with: rawData) else { return }
        let dic  = deviceData.dicData as? [String: Any] ?? [:]
        let done = deviceData.dataEnd

        switch deviceData.dataType {

        // ---- Continuous Heart Rate -----------------------------------
        case DynamicHR_X3:
            if let array = dic["arrayContinuousHR"] as? [[String: Any]] {
                for entry in array {
                    let date = entry["date"] as? String ?? ""
                    let bpm  = entry["arrayHR"] as? [Int] ?? []
                    hrBuffer.append(HeartRateRecord(date: date, heartbeatPerMinute: bpm))
                }
            }
            if done {
                onHeartRateReceived?(hrBuffer)
                hrBuffer = []
            } else {
                // fetch next page
                if let next = BleSDK_X3.sharedManager()?.getContinuousHRData(withMode: 2, withStartDate: nil) {
                    write(next)
                }
            }

        // ---- Single Heart Rate --------------------------------------
        case StaticHR_X3:
            if let array = dic["arraySingleHR"] as? [[String: Any]] {
                for entry in array {
                    let date = entry["date"] as? String ?? ""
                    let hr   = entry["singleHR"] as? Int ?? 0
                    singleHRBuffer.append(SingleHeartRateRecord(date: date, singleHR: hr))
                }
            }
            if done {
                onSingleHeartRateReceived?(singleHRBuffer)
                singleHRBuffer = []
            } else {
                if let next = BleSDK_X3.sharedManager()?.getSingleHRData(withMode: 2, withStartDate: nil) {
                    write(next)
                }
            }

        // ---- SpO2 ---------------------------------------------------
        case AutomaticSpo2Data_X3:
            if let array = dic["arraySpo2"] as? [[String: Any]] {
                for entry in array {
                    let date = entry["date"] as? String ?? ""
                    let spo2 = entry["spo2"] as? Int ?? 0
                    spo2Buffer.append(SpO2Record(date: date, spo2: spo2))
                }
            }
            if done {
                onSpo2Received?(spo2Buffer)
                spo2Buffer = []
            } else {
                if let next = BleSDK_X3.sharedManager()?.getAutomaticSpo2Data(withMode: 2, withStartDate: nil) {
                    write(next)
                }
            }

        // ---- Sleep --------------------------------------------------
        case DetailSleepData_X3:
            if let array = dic["arraySleep"] as? [[String: Any]] {
                for entry in array {
                    let date   = entry["date"] as? String ?? ""
                    let stages = entry["sleepStages"] as? [[String: Any]] ?? []
                    sleepBuffer.append(SleepRecord(date: date, sleepStages: stages))
                }
            }
            if done {
                onSleepReceived?(sleepBuffer)
                sleepBuffer = []
            } else {
                if let next = BleSDK_X3.sharedManager()?.getDetailSleepData(withMode: 2, withStartDate: nil) {
                    write(next)
                }
            }

        // ---- Total Activity (Steps) ---------------------------------
        case TotalActivityData_X3:
            if let array = dic["arrayActivity"] as? [[String: Any]] {
                for entry in array {
                    let date     = entry["date"] as? String ?? ""
                    let steps    = entry["steps"] as? Int ?? 0
                    let calories = entry["calories"] as? Int ?? 0
                    let distance = entry["distance"] as? Int ?? 0
                    activityBuffer.append(ActivityRecord(date: date, steps: steps,
                                                         calories: calories, distance: distance))
                }
            }
            if done {
                onActivityReceived?(activityBuffer)
                activityBuffer = []
            } else {
                if let next = BleSDK_X3.sharedManager()?.getTotalActivityData(withMode: 2, withStartDate: nil) {
                    write(next)
                }
            }

        // ---- Temperature --------------------------------------------
        case TemperatureData_X3:
            if let array = dic["arrayTemperature"] as? [[String: Any]] {
                for entry in array {
                    let date = entry["date"] as? String ?? ""
                    let temp = entry["temperature"] as? Double ?? 0.0
                    tempBuffer.append(TemperatureRecord(date: date, temperature: temp))
                }
            }
            if done {
                onTemperatureReceived?(tempBuffer)
                tempBuffer = []
            } else {
                if let next = BleSDK_X3.sharedManager()?.getTemperatureData(withMode: 2, withStartDate: nil) {
                    write(next)
                }
            }

        // ---- HRV ----------------------------------------------------
        case HRVData_X3:
            if let array = dic["arrayHRV"] as? [[String: Any]] {
                for entry in array {
                    let date = entry["date"] as? String ?? ""
                    let hrv  = entry["hrv"] as? Int ?? 0
                    hrvBuffer.append(HRVRecord(date: date, hrv: hrv))
                }
            }
            if done {
                onHRVReceived?(hrvBuffer)
                hrvBuffer = []
            } else {
                if let next = BleSDK_X3.sharedManager()?.getHRVData(withMode: 2, withStartDate: nil) {
                    write(next)
                }
            }

        // ---- Real-time steps ----------------------------------------
        case RealTimeStep_X3:
            let steps    = dic["steps"] as? Int ?? 0
            let calories = dic["calories"] as? Int ?? 0
            let distance = dic["distance"] as? Int ?? 0
            onRealtimeStepReceived?(RealtimeStepData(steps: steps,
                                                     calories: calories,
                                                     distance: distance))

        // ---- Device info (MAC / version / battery) ------------------
        case GetDeviceMacAddress_X3:
            deviceId = dic["macAddress"] as? String ?? deviceId
        case GetDeviceVersion_X3:
            let version = dic["version"] as? String
            onDeviceInfoReceived?(DeviceInfo(macAddress: deviceId,
                                             version: version,
                                             batteryLevel: nil))
        case GetDeviceBattery_X3:
            let battery = dic["batteryLevel"] as? Int
            onDeviceInfoReceived?(DeviceInfo(macAddress: deviceId,
                                             version: nil,
                                             batteryLevel: battery))

        default:
            break
        }
    }
}

// MARK: - MyBleDelegate (Obj-C protocol → Swift)

extension WearableManager: MyBleDelegate {

    func connectSuccessfully() {
        connectionState = .connected
        // Sync device clock automatically on connect
        var t = MyDeviceTime_X3()
        let cal = Calendar.current
        let now = Date()
        t.year   = Int32(cal.component(.year,   from: now))
        t.month  = Int32(cal.component(.month,  from: now))
        t.day    = Int32(cal.component(.day,    from: now))
        t.hour   = Int32(cal.component(.hour,   from: now))
        t.minute = Int32(cal.component(.minute, from: now))
        t.second = Int32(cal.component(.second, from: now))
        if let data = BleSDK_X3.sharedManager()?.setDeviceTime(t) { write(data) }
    }

    func disconnect(_ error: Error?) {
        connectionState = .disconnected
    }

    func scan(with peripheral: CBPeripheral,
              advertisementData: [String: Any],
              rssi RSSI: NSNumber) {
        scannedPeripherals[peripheral.identifier.uuidString] = peripheral
        onPeripheralFound?(peripheral, RSSI)
    }

    func connectFailed(withError error: Error?) {
        connectionState = .disconnected
    }

    func enableCommunicate() {
        // Communication channel is ready – fetch device info
        fetchDeviceInfo()
    }

    func bleCommunicate(with peripheral: CBPeripheral, data: Data) {
        parse(rawData: data)
    }
}
