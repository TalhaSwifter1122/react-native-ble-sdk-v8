//
//  WearableAPIService.swift
//  Ble SDK Demo
//
//  Sends wearable data to YOUR server.
//  Change `baseURL` (or call `configure(baseURL:token:)` at app start)
//  to point at any endpoint without touching anything else.
//
//  QUICK START
//  -----------
//  // AppDelegate / @main
//  WearableAPIService.shared.configure(
//      baseURL: "https://api.yourcompany.com/v1",
//      bearerToken: "YOUR_AUTH_TOKEN"          // optional
//  )
//
//  // Wire up WearableManager callbacks once:
//  WearableAPIService.shared.wireUp()
//

import Foundation

final class WearableAPIService {

    // --------------------------------------------------------
    // MARK: Singleton
    // --------------------------------------------------------
    static let shared = WearableAPIService()
    private init() {}

    // --------------------------------------------------------
    // MARK: Configuration  ← CHANGE YOUR ENDPOINT HERE
    // --------------------------------------------------------
    private var baseURL: String = "https://api.yourcompany.com/v1"
    private var bearerToken: String? = nil

    /// Call once at app launch (e.g. in AppDelegate or @main).
    func configure(baseURL: String, bearerToken: String? = nil) {
        self.baseURL = baseURL
        self.bearerToken = bearerToken
    }

    // --------------------------------------------------------
    // MARK: Wire-up convenience
    //
    // Call this once after configure() to automatically push
    // every data type to the server as it arrives from the device.
    // --------------------------------------------------------
    func wireUp() {
        let mgr = WearableManager.shared

        mgr.onHeartRateReceived = { [weak self] records in
            self?.uploadHeartRate(records)
        }
        mgr.onSingleHeartRateReceived = { [weak self] records in
            self?.uploadSingleHeartRate(records)
        }
        mgr.onSpo2Received = { [weak self] records in
            self?.uploadSpo2(records)
        }
        mgr.onSleepReceived = { [weak self] records in
            self?.uploadSleep(records)
        }
        mgr.onActivityReceived = { [weak self] records in
            self?.uploadActivity(records)
        }
        mgr.onTemperatureReceived = { [weak self] records in
            self?.uploadTemperature(records)
        }
        mgr.onHRVReceived = { [weak self] records in
            self?.uploadHRV(records)
        }
        mgr.onRealtimeStepReceived = { [weak self] data in
            self?.uploadRealtimeStep(data)
        }
    }

    // --------------------------------------------------------
    // MARK: Public upload methods
    //
    // Each method can also be called manually from anywhere in
    // your app, independently of wireUp().
    // --------------------------------------------------------

    func uploadHeartRate(_ records: [HeartRateRecord]) {
        let payload = WearableUploadPayload(
            deviceId: WearableManager.shared.deviceId,
            dataType: "continuousHeartRate",
            timestamp: isoNow(),
            records: records
        )
        post(path: "/health/heart-rate", payload: payload)
    }

    func uploadSingleHeartRate(_ records: [SingleHeartRateRecord]) {
        let payload = WearableUploadPayload(
            deviceId: WearableManager.shared.deviceId,
            dataType: "singleHeartRate",
            timestamp: isoNow(),
            records: records
        )
        post(path: "/health/heart-rate/single", payload: payload)
    }

    func uploadSpo2(_ records: [SpO2Record]) {
        let payload = WearableUploadPayload(
            deviceId: WearableManager.shared.deviceId,
            dataType: "spo2",
            timestamp: isoNow(),
            records: records
        )
        post(path: "/health/spo2", payload: payload)
    }

    func uploadSleep(_ records: [SleepRecord]) {
        let payload = WearableUploadPayload(
            deviceId: WearableManager.shared.deviceId,
            dataType: "sleep",
            timestamp: isoNow(),
            records: records
        )
        post(path: "/health/sleep", payload: payload)
    }

    func uploadActivity(_ records: [ActivityRecord]) {
        let payload = WearableUploadPayload(
            deviceId: WearableManager.shared.deviceId,
            dataType: "activity",
            timestamp: isoNow(),
            records: records
        )
        post(path: "/health/activity", payload: payload)
    }

    func uploadTemperature(_ records: [TemperatureRecord]) {
        let payload = WearableUploadPayload(
            deviceId: WearableManager.shared.deviceId,
            dataType: "temperature",
            timestamp: isoNow(),
            records: records
        )
        post(path: "/health/temperature", payload: payload)
    }

    func uploadHRV(_ records: [HRVRecord]) {
        let payload = WearableUploadPayload(
            deviceId: WearableManager.shared.deviceId,
            dataType: "hrv",
            timestamp: isoNow(),
            records: records
        )
        post(path: "/health/hrv", payload: payload)
    }

    func uploadRealtimeStep(_ data: RealtimeStepData) {
        let payload = WearableUploadPayload(
            deviceId: WearableManager.shared.deviceId,
            dataType: "realtimeStep",
            timestamp: isoNow(),
            records: [data]
        )
        post(path: "/health/realtime-step", payload: payload)
    }

    // --------------------------------------------------------
    // MARK: Private networking core
    // --------------------------------------------------------

    private func post<T: Encodable>(path: String, payload: T) {
        guard let url = URL(string: baseURL + path) else {
            print("[WearableAPIService] Invalid URL: \(baseURL + path)")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            print("[WearableAPIService] Encoding error: \(error)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[WearableAPIService] Network error for \(path): \(error.localizedDescription)")
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                print("[WearableAPIService] HTTP \(http.statusCode) for \(path): \(body)")
            }
        }.resume()
    }

    private func isoNow() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
