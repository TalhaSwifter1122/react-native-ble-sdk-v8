//
//  Ble-SDK-Demo-Bridging-Header.h
//  Ble SDK Demo
//
//  Exposes Objective-C SDK headers to Swift.
//
//  SETUP: In Xcode → Target → Build Settings → search "Objective-C Bridging Header"
//  Set the value to:  Ble SDK Demo/Ble-SDK-Demo-Bridging-Header.h
//

#import <CoreBluetooth/CoreBluetooth.h>

// BLE SDK core
#import "NewBle.h"
#import "BleSDK_X3.h"
#import "BleSDK_Header_X3.h"
#import "DeviceData_X3.h"

// Utilities already used by demo app
#import "MyDate.h"

// BLE service / characteristic UUIDs and device constants
#define SERVICE   @"FFF0"
#define SEND_CHAR @"FFF6"
#define REC_CHAR  @"FFF7"
