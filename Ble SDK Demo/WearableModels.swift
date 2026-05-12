//
//  WearableModels.swift
//  Ble SDK Demo
//
//  Clean Swift models that mirror the NSDictionary payloads
//  returned by BleSDK_X3's DataParsingWithData().
//

import Foundation

// MARK: - Heart Rate

struct HeartRateRecord: Codable {
    let date: String
    let heartbeatPerMinute: [Int]   // continuous HR per minute array
}

struct SingleHeartRateRecord: Codable {
    let date: String
    let singleHR: Int
}

// MARK: - SpO2

struct SpO2Record: Codable {
    let date: String
    let spo2: Int
}

// MARK: - Sleep

struct SleepRecord: Codable {
    let date: String
    let sleepStages: [[String: Any]]   // raw stage array from SDK

    enum CodingKeys: String, CodingKey {
        case date
        case sleepStages
    }
    // Custom encode so sleepStages (non-Codable [[String:Any]]) round-trips as JSON
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(date, forKey: .date)
        let jsonData = try JSONSerialization.data(withJSONObject: sleepStages)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
        try c.encode(jsonString, forKey: .sleepStages)
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(String.self, forKey: .date)
        let jsonString = try c.decode(String.self, forKey: .sleepStages)
        let data = jsonString.data(using: .utf8) ?? Data()
        sleepStages = (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }
    init(date: String, sleepStages: [[String: Any]]) {
        self.date = date
        self.sleepStages = sleepStages
    }
}

// MARK: - Activity (Steps / Calories / Distance)

struct ActivityRecord: Codable {
    let date: String
    let steps: Int
    let calories: Int
    let distance: Int       // unit: metres
}

// MARK: - Temperature

struct TemperatureRecord: Codable {
    let date: String
    let temperature: Double // °C
}

// MARK: - HRV

struct HRVRecord: Codable {
    let date: String
    let hrv: Int
}

// MARK: - Real-time Step

struct RealtimeStepData: Codable {
    let steps: Int
    let calories: Int
    let distance: Int
}

// MARK: - Device Info

struct DeviceInfo: Codable {
    let macAddress: String?
    let version: String?
    let batteryLevel: Int?
}

// MARK: - Server Upload Envelope
//
// All data types share this envelope so your backend
// can route them with a single endpoint if needed.

struct WearableUploadPayload<T: Codable>: Codable {
    let deviceId: String        // MAC address or custom ID
    let dataType: String        // e.g. "heartRate", "spo2", "sleep" …
    let timestamp: String       // ISO-8601 upload time
    let records: [T]
}
