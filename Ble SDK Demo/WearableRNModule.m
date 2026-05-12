//
//  WearableRNModule.m
//
//  Objective-C macro bridge — tells React Native about the Swift module.
//  This file must be in your Xcode project alongside WearableRNModule.swift.
//
//  No changes needed here unless you add new @objc methods to the Swift file.
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(WearableModule, RCTEventEmitter)

// ---- X3-specific BLE control -------------------------------------
RCT_EXTERN_METHOD(startScan)
RCT_EXTERN_METHOD(stopScan)
RCT_EXTERN_METHOD(connectDevice:(NSString *)deviceId)
RCT_EXTERN_METHOD(disconnect)

// ---- Universal BLE (any peripheral) ------------------------------
RCT_EXTERN_METHOD(startUniversalScan)
RCT_EXTERN_METHOD(stopUniversalScan)
RCT_EXTERN_METHOD(connectUniversal:(NSString *)deviceId)
RCT_EXTERN_METHOD(disconnectUniversal)

// ---- Data sync ----------------------------------------------------
RCT_EXTERN_METHOD(fetchHeartRateHistory:(NSString *)startDateISO)
RCT_EXTERN_METHOD(fetchSpo2History:(NSString *)startDateISO)
RCT_EXTERN_METHOD(fetchSleepHistory:(NSString *)startDateISO)
RCT_EXTERN_METHOD(fetchActivityHistory:(NSString *)startDateISO)
RCT_EXTERN_METHOD(fetchTemperatureHistory:(NSString *)startDateISO)
RCT_EXTERN_METHOD(fetchHRVHistory:(NSString *)startDateISO)
RCT_EXTERN_METHOD(enableRealtimeSteps)
RCT_EXTERN_METHOD(disableRealtimeSteps)
RCT_EXTERN_METHOD(fetchDeviceInfo)
RCT_EXTERN_METHOD(syncAll:(NSString *)startDateISO)

// ---- Device settings ----------------------------------------------
RCT_EXTERN_METHOD(setPersonalInfo:(NSDictionary *)options)
RCT_EXTERN_METHOD(vibrate)

// ---- Server configuration -----------------------------------------
RCT_EXTERN_METHOD(configure:(NSString *)baseURL token:(NSString *)token)

@end
