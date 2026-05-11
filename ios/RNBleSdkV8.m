//
//  RNBleSdkV8.m
//  react-native-ble-sdk-v8
//
//  Bridges BleSDK_V8 to React Native.
//
//  ARCHITECTURE
//  ────────────
//  1. NewBle       — manages CoreBluetooth scanning / connecting / raw data I/O
//  2. BleSDK_V8    — parses raw BLE bytes into DeviceData_V8 (type + dicData)
//  3. THIS FILE    — intercepts every DeviceData_V8 result, applies configurable
//                    numeric transforms, then emits a JS event with the final values.
//
//  TRANSFORM CONFIG (set from JS via setTransformConfig)
//  ─────────────────────────────────────────────────────
//  spo2Offset           – added to every SpO2 percentage value
//  heartRateOffset      – added to every heart-rate bpm value
//  temperatureOffset    – added to every temperature reading
//  awakeDurationOffset  – added to awake-time minutes in sleep records
//  totalSleepTimeOffset – added to totalSleepTime minutes in sleep records
//  hrvOffset            – added to every HRV value
//  stepsOffset          – added to step counts
//

#import "RNBleSdkV8.h"

// BLE UUIDs for the V8/JCVital device
static NSString *const kServiceUUID   = @"FFF0";
static NSString *const kSendCharUUID  = @"FFF6";

// Optional name filter set from JS — nil means accept all devices
static NSString *_nameFilter = nil;
// UUID of the device the JS layer wants to auto-connect to after scan
static NSString *_pendingConnectUUID = nil;

// ─────────────────────────────────────────────────────────────────────────────
@implementation RNBleSdkV8
{
    // ── Transform offsets ────────────────────────────────────────────────────
    NSInteger _spo2Offset;
    NSInteger _heartRateOffset;
    double    _temperatureOffset;
    NSInteger _awakeDurationOffset;
    NSInteger _totalSleepTimeOffset;
    NSInteger _hrvOffset;
    NSInteger _stepsOffset;
}

RCT_EXPORT_MODULE(RNBleSdkV8);

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - RCTEventEmitter

- (NSArray<NSString *> *)supportedEvents {
    return @[
        @"BleDeviceFound",
        @"BleConnected",
        @"BleDisconnected",
        @"BleConnectFailed",
        @"BleData",
        @"BlePowerStateChanged",
    ];
}

+ (BOOL)requiresMainQueueSetup { return YES; }

// Initialize CBCentralManager at module-load time, exactly like the vendor
// demo app does in AppDelegate. This gives the manager enough time to reach
// the poweredOn state before the user ever calls startScan from JS.
- (instancetype)init {
    if (self = [super init]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [NewBle sharedManager].delegate = self;
            [[NewBle sharedManager] SetUpCentralManager];
        });
    }
    return self;
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - Transform config

/**
 * Called from JavaScript to set value offsets applied before emitting data.
 * Example JS call:
 *   BleSdkV8.setTransformConfig({ spo2Offset: 2, awakeDurationOffset: -5 });
 */
RCT_EXPORT_METHOD(setTransformConfig:(NSDictionary *)config) {
    _spo2Offset           = [config[@"spo2Offset"]           integerValue];
    _heartRateOffset      = [config[@"heartRateOffset"]      integerValue];
    _temperatureOffset    = [config[@"temperatureOffset"]    doubleValue];
    _awakeDurationOffset  = [config[@"awakeDurationOffset"]  integerValue];
    _totalSleepTimeOffset = [config[@"totalSleepTimeOffset"] integerValue];
    _hrvOffset            = [config[@"hrvOffset"]            integerValue];
    _stepsOffset          = [config[@"stepsOffset"]          integerValue];
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - Scanning

/**
 * startScan — discovers ALL nearby BLE devices (no service-UUID filter).
 * The JCVital / V8 band does not broadcast its service UUID in advertisement
 * packets, so filtering by UUID hides it. We scan with nil and let JS filter
 * by device name if needed.
 *
 * Optional JS parameter: nameFilter (e.g. "JCVital" or "V8")
 * Only devices whose name CONTAINS the filter string are emitted to JS.
 */
RCT_EXPORT_METHOD(startScan:(nullable NSString *)nameFilter) {
    _nameFilter = (nameFilter && nameFilter.length > 0) ? nameFilter : nil;
    _pendingConnectUUID = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        // SetUpCentralManager is guarded — safe to call; creates manager only once
        [NewBle sharedManager].delegate = self;
        [[NewBle sharedManager] SetUpCentralManager];
        // startScanningWithServices defers automatically if not yet poweredOn
        [[NewBle sharedManager] startScanningWithServices:nil];
    });
}

RCT_EXPORT_METHOD(stopScan) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NewBle sharedManager] Stopscan];
    });
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - Connection

RCT_EXPORT_METHOD(connect:(NSString *)peripheralUUID) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NewBle sharedManager].delegate = self;

        // 1. Check if the peripheral is already known to CoreBluetooth
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:peripheralUUID];
        if (uuid) {
            NSArray *known = [[NewBle sharedManager].CentralManage
                retrievePeripheralsWithIdentifiers:@[uuid]];
            if (known.count > 0) {
                [[NewBle sharedManager] connectDevice:known.firstObject];
                return;
            }
        }

        // 2. Not yet known — start a nil-filter scan and auto-connect when found
        _pendingConnectUUID = peripheralUUID;
        [[NewBle sharedManager] startScanningWithServices:nil];
    });
}

RCT_EXPORT_METHOD(disconnect) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NewBle sharedManager] Disconnect];
    });
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - SDK command helpers

/** Sends pre-built command bytes to the connected device. */
- (void)sendData:(NSData *)data {
    if (!data) return;
    [[NewBle sharedManager] writeValue:kServiceUUID
                    characteristicUUID:kSendCharUUID
                                     p:[NewBle sharedManager].activityPeripheral
                                  data:data];
}

/** Convert an ISO8601 string (from JS) to NSDate, or nil. */
- (nullable NSDate *)dateFromISOString:(nullable NSString *)iso {
    if (!iso || [iso isEqual:[NSNull null]]) return nil;
    NSISO8601DateFormatter *fmt = [[NSISO8601DateFormatter alloc] init];
    return [fmt dateFromString:iso];
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - Exported commands

RCT_EXPORT_METHOD(getDeviceTime) {
    [self sendData:[[BleSDK_V8 sharedManager] GetDeviceTime]];
}

RCT_EXPORT_METHOD(getPersonalInfo) {
    [self sendData:[[BleSDK_V8 sharedManager] GetPersonalInfo]];
}

RCT_EXPORT_METHOD(getBatteryLevel) {
    [self sendData:[[BleSDK_V8 sharedManager] GetDeviceBatteryLevel]];
}

RCT_EXPORT_METHOD(getDeviceVersion) {
    [self sendData:[[BleSDK_V8 sharedManager] GetDeviceVersion]];
}

RCT_EXPORT_METHOD(getStepGoal) {
    [self sendData:[[BleSDK_V8 sharedManager] GetStepGoal]];
}

RCT_EXPORT_METHOD(getMacAddress) {
    [self sendData:[[BleSDK_V8 sharedManager] GetDeviceMacAddress]];
}

RCT_EXPORT_METHOD(getSleepHistory:(int)mode startDateISO:(nullable NSString *)iso) {
    [self sendData:[[BleSDK_V8 sharedManager]
                    GetDetailSleepDataWithMode:mode
                    withStartDate:[self dateFromISOString:iso]]];
}

RCT_EXPORT_METHOD(getSleepAndActivityHistory:(int)mode startDateISO:(nullable NSString *)iso) {
    [self sendData:[[BleSDK_V8 sharedManager]
                    getSleepDetailsAndActivityWithMode:mode
                    withStartDate:[self dateFromISOString:iso]]];
}

RCT_EXPORT_METHOD(getContinuousHRHistory:(int)mode startDateISO:(nullable NSString *)iso) {
    [self sendData:[[BleSDK_V8 sharedManager]
                    GetContinuousHRDataWithMode:mode
                    withStartDate:[self dateFromISOString:iso]]];
}

RCT_EXPORT_METHOD(getSingleHRHistory:(int)mode startDateISO:(nullable NSString *)iso) {
    [self sendData:[[BleSDK_V8 sharedManager]
                    GetSingleHRDataWithMode:mode
                    withStartDate:[self dateFromISOString:iso]]];
}

RCT_EXPORT_METHOD(getAutomaticSpo2History:(int)mode startDateISO:(nullable NSString *)iso) {
    [self sendData:[[BleSDK_V8 sharedManager]
                    GetAutomaticSpo2DataWithMode:mode
                    withStartDate:[self dateFromISOString:iso]]];
}

RCT_EXPORT_METHOD(getManualSpo2History:(int)mode startDateISO:(nullable NSString *)iso) {
    [self sendData:[[BleSDK_V8 sharedManager]
                    GetManualSpo2DataWithMode:mode
                    withStartDate:[self dateFromISOString:iso]]];
}

RCT_EXPORT_METHOD(getTemperatureHistory:(int)mode startDateISO:(nullable NSString *)iso) {
    [self sendData:[[BleSDK_V8 sharedManager]
                    GetTemperatureDataWithMode:mode
                    withStartDate:[self dateFromISOString:iso]]];
}

RCT_EXPORT_METHOD(getHRVHistory:(int)mode startDateISO:(nullable NSString *)iso) {
    [self sendData:[[BleSDK_V8 sharedManager]
                    GetHRVDataWithMode:mode
                    withStartDate:[self dateFromISOString:iso]]];
}

RCT_EXPORT_METHOD(getPPIHistory:(int)mode startDateISO:(nullable NSString *)iso) {
    [self sendData:[[BleSDK_V8 sharedManager]
                    GetPPIDataWithMode:mode
                    withStartDate:[self dateFromISOString:iso]]];
}

RCT_EXPORT_METHOD(getTotalActivityData:(int)mode startDateISO:(nullable NSString *)iso) {
    [self sendData:[[BleSDK_V8 sharedManager]
                    GetTotalActivityDataWithMode:mode
                    withStartDate:[self dateFromISOString:iso]]];
}

RCT_EXPORT_METHOD(getDetailActivityData:(int)mode startDateISO:(nullable NSString *)iso) {
    [self sendData:[[BleSDK_V8 sharedManager]
                    GetDetailActivityDataWithMode:mode
                    withStartDate:[self dateFromISOString:iso]]];
}

RCT_EXPORT_METHOD(setRealtimeData:(int)dataType) {
    [self sendData:[[BleSDK_V8 sharedManager] RealTimeDataWithType:dataType]];
}

RCT_EXPORT_METHOD(ppgControl:(int)ppgMode ppgStatus:(int)ppgStatus) {
    [self sendData:[[BleSDK_V8 sharedManager] ppgWithMode:ppgMode ppgStatus:ppgStatus]];
}

RCT_EXPORT_METHOD(clearAllHistoryData) {
    [self sendData:[[BleSDK_V8 sharedManager] ClearAllHistoryData]];
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - NewBle delegate

- (void)ConnectSuccessfully {
    // Intentionally empty – wait for EnableCommunicate before notifying JS
}

- (void)CentralManagerPoweredOn {
    [self sendEventWithName:@"BlePowerStateChanged" body:@{ @"state": @"poweredOn" }];
}

- (void)EnableCommunicate {
    [self sendEventWithName:@"BleConnected"
                       body:@{ @"connected": @YES }];
}

- (void)Disconnect:(NSError *_Nullable)error {
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"connected"] = @NO;
    if (error) {
        body[@"error"] = error.localizedDescription ?: @"Unknown error";
    }
    [self sendEventWithName:@"BleDisconnected" body:body];
}

- (void)ConnectFailedWithError:(nullable NSError *)error {
    [self sendEventWithName:@"BleConnectFailed"
                       body:@{ @"error": error.localizedDescription ?: @"Connection failed" }];
}

- (void)scanWithPeripheral:(CBPeripheral *)peripheral
         advertisementData:(NSDictionary<NSString *, id> *)advertisementData
                      RSSI:(NSNumber *)RSSI {

    NSString *name = peripheral.name
        ?: advertisementData[CBAdvertisementDataLocalNameKey]
        ?: @"";

    // Apply name filter if set from JS
    if (_nameFilter) {
        NSRange r = [name rangeOfString:_nameFilter
                                options:NSCaseInsensitiveSearch];
        if (r.location == NSNotFound) return; // skip non-matching device
    }

    // Auto-connect if JS called connect() before the device was found
    if (_pendingConnectUUID &&
        [peripheral.identifier.UUIDString isEqualToString:_pendingConnectUUID]) {
        _pendingConnectUUID = nil;
        [[NewBle sharedManager] connectDevice:peripheral];
        return;
    }

    [self sendEventWithName:@"BleDeviceFound" body:@{
        @"uuid":  peripheral.identifier.UUIDString,
        @"name":  name,
        @"rssi":  RSSI,
        @"advertisementData": @{
            @"isConnectable": advertisementData[CBAdvertisementDataIsConnectable] ?: @NO,
            @"txPowerLevel":  advertisementData[CBAdvertisementDataTxPowerLevelKey] ?: @0,
        },
    }];
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - Data reception + transformation

/**
 * Every raw BLE packet arrives here.
 * 1. Parse with BleSDK_V8
 * 2. Deep-copy the result dict so we can mutate it safely
 * 3. Apply numeric offsets to the relevant fields
 * 4. Emit the transformed payload to JS as a BleData event
 */
- (void)BleCommunicateWithPeripheral:(CBPeripheral *)peripheral data:(NSData *)data {
    DeviceData_V8 *deviceData = [[BleSDK_V8 sharedManager] DataParsingWithData:data];
    if (!deviceData) return;

    // Start with a mutable copy of the parsed dictionary
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"dataType"] = @(deviceData.dataType);
    payload[@"dataEnd"]  = @(deviceData.dataEnd);

    // Deep-mutable copy so we can safely replace values
    NSDictionary *dicData = deviceData.dicData;
    NSMutableDictionary *mutableDic = dicData
        ? [NSMutableDictionary dictionaryWithDictionary:dicData]
        : [NSMutableDictionary dictionary];

    // ── Apply transforms based on dataType ───────────────────────────────────
    switch (deviceData.dataType) {

        // SpO2 – automatic monitoring
        case AutomaticSpo2Data_V8: {
            NSArray *arr = mutableDic[@"arrayAutomaticSpo2Data"];
            if (arr) mutableDic[@"arrayAutomaticSpo2Data"] =
                [self applyOffset:_spo2Offset toKey:@"automaticSpo2Data" inArray:arr];
            break;
        }

        // SpO2 – manual single measurement
        case ManualSpo2Data_V8: {
            NSArray *arr = mutableDic[@"arrayManualSpo2Data"];
            if (arr) mutableDic[@"arrayManualSpo2Data"] =
                [self applyOffset:_spo2Offset toKey:@"manualSpo2Data" inArray:arr];
            break;
        }

        // Continuous heart rate
        case DynamicHR_V8: {
            NSArray *arr = mutableDic[@"arrayContinuousHR"];
            if (arr) mutableDic[@"arrayContinuousHR"] =
                [self applyArrayOffset:_heartRateOffset toNestedArrayKey:@"arrayHR" inArray:arr];
            break;
        }

        // Single / spot heart rate
        case StaticHR_V8: {
            NSArray *arr = mutableDic[@"arraySingleHR"];
            if (arr) mutableDic[@"arraySingleHR"] =
                [self applyOffset:_heartRateOffset toKey:@"singleHR" inArray:arr];
            break;
        }

        // Sleep detail
        case DetailSleepData_V8: {
            NSArray *arr = mutableDic[@"arrayDetailSleepData"];
            if (arr) mutableDic[@"arrayDetailSleepData"] =
                [self transformSleepArray:arr];
            break;
        }

        // Sleep + activity combined
        case DetailSleepAndActivityData_V8: {
            NSArray *arr = mutableDic[@"arrayDetailSleepAndActivityData"];
            if (arr) mutableDic[@"arrayDetailSleepAndActivityData"] =
                [self transformSleepArray:arr];
            break;
        }

        // Temperature
        case TemperatureData_V8: {
            NSArray *arr = mutableDic[@"arrayTemperatureData"];
            if (arr) mutableDic[@"arrayTemperatureData"] =
                [self applyDoubleOffset:_temperatureOffset toKey:@"temperature" inArray:arr];
            break;
        }

        // Real-time step data
        case RealTimeStep_V8: {
            if (mutableDic[@"steps"]) {
                NSInteger v = [mutableDic[@"steps"] integerValue] + _stepsOffset;
                mutableDic[@"steps"] = @(MAX(0, v));
            }
            if (mutableDic[@"heartRate"]) {
                NSInteger v = [mutableDic[@"heartRate"] integerValue] + _heartRateOffset;
                mutableDic[@"heartRate"] = @(MAX(0, v));
            }
            break;
        }

        // HRV
        case HRVData_V8: {
            NSArray *arr = mutableDic[@"arrayHRVData"];
            if (arr) mutableDic[@"arrayHRVData"] =
                [self applyOffset:_hrvOffset toKey:@"hrv" inArray:arr];
            break;
        }

        default:
            break;
    }

    payload[@"data"] = mutableDic;
    [self sendEventWithName:@"BleData" body:payload];
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - Transform helpers

/**
 * Returns a new array where each dict's `key` NSNumber value
 * has `offset` added to it (clamped to 0).
 */
- (NSArray *)applyOffset:(NSInteger)offset
                   toKey:(NSString *)key
                 inArray:(NSArray *)array {
    if (offset == 0) return array;
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:array.count];
    for (NSDictionary *item in array) {
        NSMutableDictionary *m = [item mutableCopy];
        if (m[key]) {
            NSInteger v = [m[key] integerValue] + offset;
            m[key] = @(MAX(0, v));
        }
        [result addObject:m];
    }
    return result;
}

/** Same but for double (float) values like temperature. */
- (NSArray *)applyDoubleOffset:(double)offset
                         toKey:(NSString *)key
                       inArray:(NSArray *)array {
    if (offset == 0.0) return array;
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:array.count];
    for (NSDictionary *item in array) {
        NSMutableDictionary *m = [item mutableCopy];
        if (m[key]) {
            double v = [m[key] doubleValue] + offset;
            m[key] = @(v);
        }
        [result addObject:m];
    }
    return result;
}

/**
 * For continuous HR each record has a nested `arrayHR` array of numbers.
 * Adds `offset` to every element of that inner array.
 */
- (NSArray *)applyArrayOffset:(NSInteger)offset
           toNestedArrayKey:(NSString *)key
                    inArray:(NSArray *)array {
    if (offset == 0) return array;
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:array.count];
    for (NSDictionary *item in array) {
        NSMutableDictionary *m = [item mutableCopy];
        NSArray *inner = m[key];
        if (inner) {
            NSMutableArray *shiftedInner = [NSMutableArray arrayWithCapacity:inner.count];
            for (NSNumber *n in inner) {
                NSInteger v = [n integerValue] + offset;
                [shiftedInner addObject:@(MAX(0, v))];
            }
            m[key] = shiftedInner;
        }
        [result addObject:m];
    }
    return result;
}

/**
 * Applies sleep-specific transforms:
 *   totalSleepTime  += totalSleepTimeOffset
 *   awakeDuration   += awakeDurationOffset  (computed from arraySleepQuality
 *                                            where state == 0 means awake)
 */
- (NSArray *)transformSleepArray:(NSArray *)array {
    if (_totalSleepTimeOffset == 0 && _awakeDurationOffset == 0) return array;
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:array.count];
    for (NSDictionary *item in array) {
        NSMutableDictionary *m = [item mutableCopy];

        // totalSleepTime (minutes)
        if (m[@"totalSleepTime"] && _totalSleepTimeOffset != 0) {
            NSInteger v = [m[@"totalSleepTime"] integerValue] + _totalSleepTimeOffset;
            m[@"totalSleepTime"] = @(MAX(0, v));
        }

        // awakeDuration — derived field we add for convenience
        // arraySleepQuality values: 0=awake, 1=light, 2=deep, 3=REM (common encoding)
        NSArray *sleepQuality = m[@"arraySleepQuality"];
        NSInteger sleepUnitLength = [m[@"sleepUnitLength"] integerValue];
        if (sleepUnitLength <= 0) sleepUnitLength = 1;
        if (sleepQuality) {
            NSInteger awakeUnits = 0;
            for (NSNumber *state in sleepQuality) {
                if ([state integerValue] == 0) awakeUnits++;
            }
            NSInteger awakeMins = (awakeUnits * sleepUnitLength) + _awakeDurationOffset;
            m[@"awakeDurationMinutes"] = @(MAX(0, awakeMins));
        }

        [result addObject:m];
    }
    return result;
}

@end
