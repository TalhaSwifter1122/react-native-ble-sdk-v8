//
//  UniversalBLEManager.swift
//  Ble SDK Demo
//
//  A standalone CoreBluetooth scanner that finds and connects to ANY BLE peripheral —
//  not just X3 devices. Used by the React Native bridge to expose universal BLE access.
//
//  This deliberately does NOT go through the NewBle Obj-C SDK so it is not filtered.
//

import Foundation
import CoreBluetooth

// MARK: - Value types surfaced to the RN bridge

struct UniversalBLEDeviceInfo {
    let id: String              // peripheral.identifier.uuidString — pass to connectUniversal()
    let name: String
    let rssi: Int
    let localName: String?
    let manufacturerDataHex: String?
    let serviceUUIDs: [String]
}

struct UniversalBLEServiceInfo {
    let uuid: String
    let characteristics: [UniversalBLECharInfo]
}

struct UniversalBLECharInfo {
    let uuid: String
    let properties: String      // human-readable e.g. "Read, Notify"
}

// MARK: - UniversalBLEManager

final class UniversalBLEManager: NSObject {

    // --------------------------------------------------------
    // MARK: Singleton
    // --------------------------------------------------------
    static let shared = UniversalBLEManager()
    private override init() { super.init() }

    // --------------------------------------------------------
    // MARK: Callbacks (set in WearableRNModule.startObserving)
    // --------------------------------------------------------
    var onStateChanged:          ((String) -> Void)?   // "idle"|"scanning"|"connecting"|"connected"|"disconnected"
    var onDeviceFound:           ((UniversalBLEDeviceInfo) -> Void)?
    var onServicesDiscovered:    (([UniversalBLEServiceInfo]) -> Void)?
    var onError:                 ((String) -> Void)?

    // --------------------------------------------------------
    // MARK: Private state
    // --------------------------------------------------------
    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private var pendingScan = false

    // --------------------------------------------------------
    // MARK: Public API
    // --------------------------------------------------------

    /// Initialises CBCentralManager on first call, then scans for every BLE advertisement.
    func startScan() {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: .main)
        }
        disconnectCurrentIfNeeded()
        discoveredPeripherals.removeAll()

        if centralManager?.state == .poweredOn {
            performScan()
        } else {
            // Defer scan until centralManagerDidUpdateState fires with .poweredOn
            pendingScan = true
            onStateChanged?("scanning")
        }
    }

    func stopScan() {
        pendingScan = false
        centralManager?.stopScan()
        if connectedPeripheral == nil {
            onStateChanged?("idle")
        }
    }

    /// Connect to a peripheral discovered during scan.
    /// - Parameter uuid: The UUID string received in `onUniversalDeviceFound`.
    func connect(toDeviceId uuid: String) {
        guard let peripheral = discoveredPeripherals.first(where: {
            $0.key.uuidString.caseInsensitiveCompare(uuid) == .orderedSame
        })?.value else {
            onError?("Device \(uuid) not found. Make sure you scanned first.")
            return
        }

        centralManager?.stopScan()
        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        onStateChanged?("connecting")
        centralManager?.connect(peripheral, options: nil)
    }

    func disconnect() {
        disconnectCurrentIfNeeded()
        onStateChanged?("disconnected")
    }

    // --------------------------------------------------------
    // MARK: Private helpers
    // --------------------------------------------------------

    private func performScan() {
        pendingScan = false
        onStateChanged?("scanning")
        // nil = all services (no filter). allowDuplicates = true so RSSI updates keep arriving.
        centralManager?.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    private func disconnectCurrentIfNeeded() {
        if let p = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(p)
        }
        connectedPeripheral = nil
    }

    private func propertiesText(_ props: CBCharacteristicProperties) -> String {
        var values: [String] = []
        if props.contains(.read)                      { values.append("Read") }
        if props.contains(.write)                     { values.append("Write") }
        if props.contains(.writeWithoutResponse)      { values.append("WriteNoResponse") }
        if props.contains(.notify)                    { values.append("Notify") }
        if props.contains(.indicate)                  { values.append("Indicate") }
        if props.contains(.broadcast)                 { values.append("Broadcast") }
        if props.contains(.authenticatedSignedWrites) { values.append("SignedWrite") }
        if props.contains(.extendedProperties)        { values.append("Extended") }
        if props.contains(.notifyEncryptionRequired)  { values.append("NotifyEncRequired") }
        if props.contains(.indicateEncryptionRequired){ values.append("IndicateEncRequired") }
        return values.isEmpty ? "Unknown" : values.joined(separator: ", ")
    }
}

// MARK: - CBCentralManagerDelegate

extension UniversalBLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn && pendingScan {
            performScan()
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        discoveredPeripherals[peripheral.identifier] = peripheral

        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? [])
            .map { $0.uuidString }
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let manufacturerHex = manufacturerData?.map { String(format: "%02X", $0) }.joined(separator: " ")

        let info = UniversalBLEDeviceInfo(
            id: peripheral.identifier.uuidString,
            name: peripheral.name ?? localName ?? "Unknown",
            rssi: RSSI.intValue,
            localName: localName,
            manufacturerDataHex: manufacturerHex,
            serviceUUIDs: serviceUUIDs
        )
        onDeviceFound?(info)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        onStateChanged?("connected")
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        connectedPeripheral = nil
        onStateChanged?("disconnected")
        onError?(error?.localizedDescription ?? "Failed to connect to \(peripheral.name ?? peripheral.identifier.uuidString)")
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        connectedPeripheral = nil
        onStateChanged?("disconnected")
        if let error = error {
            onError?(error.localizedDescription)
        }
    }
}

// MARK: - CBPeripheralDelegate

extension UniversalBLEManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            onError?("Service discovery failed: \(error.localizedDescription)")
            return
        }
        guard let services = peripheral.services, !services.isEmpty else {
            onServicesDiscovered?([])
            return
        }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error = error {
            onError?("Characteristic discovery error for \(service.uuid.uuidString): \(error.localizedDescription)")
            return
        }

        // Wait until every service has had its characteristics resolved before firing the callback.
        guard let allServices = peripheral.services else { return }
        let allDone = allServices.allSatisfy { $0.characteristics != nil }
        guard allDone else { return }

        let result: [UniversalBLEServiceInfo] = allServices.map { svc in
            let chars = svc.characteristics?.map { ch in
                UniversalBLECharInfo(uuid: ch.uuid.uuidString,
                                     properties: propertiesText(ch.properties))
            } ?? []
            return UniversalBLEServiceInfo(uuid: svc.uuid.uuidString, characteristics: chars)
        }
        onServicesDiscovered?(result)
    }
}
