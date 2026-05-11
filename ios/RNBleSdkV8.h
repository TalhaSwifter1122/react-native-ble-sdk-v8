//
//  RNBleSdkV8.h
//  react-native-ble-sdk-v8
//
//  React Native Native Module that wraps BleSDK_V8 + NewBle.
//  All SDK data is intercepted here; configurable numeric offsets
//  are applied before values are emitted to JavaScript.
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "NewBle.h"
#import "BleSDK_V8.h"
#import "BleSDK_Header_V8.h"
#import "DeviceData_V8.h"

NS_ASSUME_NONNULL_BEGIN

@interface RNBleSdkV8 : RCTEventEmitter <RCTBridgeModule, MyBleDelegate>

@end

NS_ASSUME_NONNULL_END
