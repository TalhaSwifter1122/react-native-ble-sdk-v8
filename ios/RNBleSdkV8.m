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
static NSString *const kDefaultUploadBaseUrl = @"http://167.172.132.179:5000";
static NSString *const kDefaultUploadEndpoint = @"/JC_band_data_dump";
static NSString *const kDefaultUploadAuthToken = @"Bearer YOUR_TOKEN";
static NSString *const kDefaultUploadDeviceId = @"test-device-001";
static const NSTimeInterval kDefaultUploadTimeoutMs = 30000.0;
static const NSInteger kDefaultUploadRetryCount = 0;

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

    // Track currently connected device so JS can distinguish payload source.
    NSString *_activeDeviceUUID;

    // Server-upload config (native-side, no RN fetch needed).
    BOOL _autoUploadEnabled;
    NSString *_uploadBaseUrl;
    NSString *_uploadAuthToken;
    NSString *_uploadDeviceId;
    NSString *_uploadEndpoint;
    NSTimeInterval _uploadTimeoutMs;
    NSInteger _uploadRetryCount;
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
        @"BleUploadStatus",
    ];
}

+ (BOOL)requiresMainQueueSetup { return YES; }

// Initialize CBCentralManager at module-load time, exactly like the vendor
// demo app does in AppDelegate. This gives the manager enough time to reach
// the poweredOn state before the user ever calls startScan from JS.
- (instancetype)init {
    if (self = [super init]) {
        _autoUploadEnabled = NO;
        _uploadBaseUrl = kDefaultUploadBaseUrl;
        _uploadAuthToken = kDefaultUploadAuthToken;
        _uploadDeviceId = kDefaultUploadDeviceId;
        _uploadEndpoint = kDefaultUploadEndpoint;
        _uploadTimeoutMs = kDefaultUploadTimeoutMs;
        _uploadRetryCount = kDefaultUploadRetryCount;

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
        [self emitAlreadyConnectedPeripherals];
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

RCT_EXPORT_METHOD(getActivityModeHistory:(int)mode startDateISO:(nullable NSString *)iso) {
    [self sendData:[[BleSDK_V8 sharedManager]
                    GetActivityModeDataWithMode:mode
                    withStartDate:[self dateFromISOString:iso]
                    needMETS:YES]];
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

RCT_EXPORT_METHOD(configureServerUpload:(NSDictionary *)config) {
    NSString *baseUrl = [self stringOrNil:config[@"baseUrl"]];
    NSString *authToken = [self stringOrNil:config[@"authToken"]];
    NSString *deviceId = [self stringOrNil:config[@"deviceId"]];
    NSString *endpoint = [self stringOrNil:config[@"endpoint"]];
    NSNumber *timeoutMs = [self numberOrNil:config[@"timeoutMs"]];
    NSNumber *retryCount = [self numberOrNil:config[@"retryCount"]];

    if (baseUrl.length > 0) {
        _uploadBaseUrl = [self normalizedBaseURL:baseUrl];
    }
    if (authToken) {
        _uploadAuthToken = authToken;
    }
    if (deviceId) {
        _uploadDeviceId = deviceId;
    }
    if (endpoint.length > 0) {
        _uploadEndpoint = [self normalizedEndpoint:endpoint];
    }
    if (timeoutMs) {
        _uploadTimeoutMs = MAX(1000.0, [timeoutMs doubleValue]);
    }
    if (retryCount) {
        _uploadRetryCount = MAX(0, [retryCount integerValue]);
    }
}

RCT_EXPORT_METHOD(startNativeAutoUpload:(NSDictionary *)options) {
    (void)options;
    _autoUploadEnabled = YES;
}

RCT_EXPORT_METHOD(stopNativeAutoUpload) {
    _autoUploadEnabled = NO;
}

RCT_EXPORT_METHOD(uploadDataNative:(NSDictionary *)blePayload) {
    if (![blePayload isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *body = [self buildServerBodyFromBlePayload:blePayload];
    [self postBody:body endpoint:nil];
}

RCT_EXPORT_METHOD(uploadToEndpointNative:(NSString *)endpoint data:(NSDictionary *)data) {
    if (![endpoint isKindOfClass:[NSString class]] || endpoint.length == 0) return;

    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"deviceId"] = _uploadDeviceId ?: @"";
    body[@"timestamp"] = [self isoTimestampNow];

    if ([data isKindOfClass:[NSDictionary class]]) {
        NSDictionary *safeData = [self jsonSafeDictionary:data];
        [body addEntriesFromDictionary:safeData];
    }

    [self postBody:body endpoint:[self normalizedEndpoint:endpoint]];
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - NewBle delegate

- (void)ConnectSuccessfully {
    // Intentionally empty – wait for EnableCommunicate before notifying JS
}

- (void)CentralManagerPoweredOn {
    [self sendEventWithName:@"BlePowerStateChanged" body:@{ @"state": @"poweredOn" }];
    [self emitAlreadyConnectedPeripherals];
}

- (void)EnableCommunicate {
    NSString *uuid = [NewBle sharedManager].activityPeripheral.identifier.UUIDString ?: @"";
    NSString *name = [NewBle sharedManager].activityPeripheral.name ?: @"";
    _activeDeviceUUID = uuid;
    [self sendEventWithName:@"BleConnected"
                       body:@{ @"connected": @YES,
                                @"uuid":      uuid,
                                @"name":      name }];
}

- (void)Disconnect:(NSError *_Nullable)error {
    _activeDeviceUUID = nil;
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

    [self emitDiscoveredPeripheral:peripheral advertisementData:advertisementData RSSI:RSSI source:@"scan"];
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - Discovery helpers

- (void)emitAlreadyConnectedPeripherals {
    CBCentralManager *central = [NewBle sharedManager].CentralManage;
    if (!central || central.state != CBManagerStatePoweredOn) {
        return;
    }

    NSArray<CBUUID *> *serviceUUIDs = @[[CBUUID UUIDWithString:kServiceUUID]];
    NSArray<CBPeripheral *> *connected = [central retrieveConnectedPeripheralsWithServices:serviceUUIDs];

    for (CBPeripheral *peripheral in connected) {
        [self emitDiscoveredPeripheral:peripheral
                     advertisementData:@{}
                                  RSSI:@0
                                source:@"connected"];
    }
}

- (void)emitDiscoveredPeripheral:(CBPeripheral *)peripheral
               advertisementData:(NSDictionary<NSString *, id> *)advertisementData
                            RSSI:(NSNumber *)RSSI
                          source:(NSString *)source {

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
        @"source": source ?: @"scan",
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

    NSString *packetTimestamp = [self isoTimestampNow];

    // Start with a mutable copy of the parsed dictionary
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"dataType"] = @(deviceData.dataType);
    payload[@"dataEnd"]  = @(deviceData.dataEnd);
    payload[@"uuid"]     = peripheral.identifier.UUIDString ?: (_activeDeviceUUID ?: @"");
    payload[@"timestamp"] = packetTimestamp;
    payload[@"packetTimestamp"] = packetTimestamp;
    payload[@"receivedAt"] = packetTimestamp;
    payload[@"sensorTimestamp"] = packetTimestamp;

    // Deep-mutable copy so we can safely replace values
    NSDictionary *dicData = deviceData.dicData;
    NSMutableDictionary *mutableDic = dicData
        ? [NSMutableDictionary dictionaryWithDictionary:dicData]
        : [NSMutableDictionary dictionary];
    mutableDic[@"packetTimestamp"] = packetTimestamp;
    mutableDic[@"receivedAt"] = packetTimestamp;

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
            NSNumber *rawSteps = mutableDic[@"steps"]
                ?: mutableDic[@"step"]
                ?: mutableDic[@"stepCount"]
                ?: mutableDic[@"totalSteps"];
            if (rawSteps) {
                NSInteger v = [rawSteps integerValue] + _stepsOffset;
                NSNumber *normalizedSteps = @(MAX(0, v));
                // Emit common aliases so JS integrations can read any expected key.
                mutableDic[@"steps"] = normalizedSteps;
                mutableDic[@"step"] = normalizedSteps;
                mutableDic[@"stepCount"] = normalizedSteps;
                mutableDic[@"totalSteps"] = normalizedSteps;
            }

            NSNumber *rawHeartRate = mutableDic[@"heartRate"] ?: mutableDic[@"hr"];
            if (rawHeartRate) {
                NSInteger v = [rawHeartRate integerValue] + _heartRateOffset;
                NSNumber *normalizedHeartRate = @(MAX(0, v));
                mutableDic[@"heartRate"] = normalizedHeartRate;
                mutableDic[@"hr"] = normalizedHeartRate;
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

        // RR / PPI interval data
        case realtimeRRIntervalData_V8:
        case realtimePPIData_V8:
        case ppiData_V8: {
            [self normalizeRRIntervalFields:mutableDic];
            break;
        }

        // Real-time PPG packets do not include a persisted device-side time, so
        // mark when the sample packet reached the phone.
        case realtimePPGData_V8: {
            mutableDic[@"ppgTimestamp"] = packetTimestamp;
            mutableDic[@"measurementTime"] = packetTimestamp;
            break;
        }

        default:
            break;
    }

    payload[@"data"] = mutableDic;
    [self sendEventWithName:@"BleData" body:payload];

    if (_autoUploadEnabled) {
        NSDictionary *body = [self buildServerBodyFromBlePayload:payload];
        [self postBody:body endpoint:nil];
    }
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

- (void)normalizeRRIntervalFields:(NSMutableDictionary *)data {
    NSNumber *interval = [self firstNumberInDictionary:data
                                                  keys:@[@"RRIntervalData",
                                                         @"rrIntervalData",
                                                         @"rrInterval",
                                                         @"rr",
                                                         @"RR",
                                                         @"ppi",
                                                         @"PPI",
                                                         @"ppiData",
                                                         @"PPIData"]];
    if (!interval) return;

    data[@"rrInterval"] = interval;
    data[@"RRIntervalData"] = interval;
    data[@"ppi"] = interval;
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

#pragma mark - Native upload helpers

- (NSString *)isoTimestampNow {
    NSISO8601DateFormatter *fmt = [[NSISO8601DateFormatter alloc] init];
    return [fmt stringFromDate:[NSDate date]];
}

- (nullable NSString *)stringOrNil:(id)value {
    return [value isKindOfClass:[NSString class]] ? (NSString *)value : nil;
}

- (nullable NSNumber *)numberOrNil:(id)value {
    return [value isKindOfClass:[NSNumber class]] ? (NSNumber *)value : nil;
}

- (NSString *)normalizedBaseURL:(NSString *)baseUrl {
    NSString *trimmed = [baseUrl stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    while ([trimmed hasSuffix:@"/"]) {
        trimmed = [trimmed substringToIndex:trimmed.length - 1];
    }
    return trimmed;
}

- (NSString *)normalizedEndpoint:(NSString *)endpoint {
    NSString *trimmed = [endpoint stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) return @"/";
    return [trimmed hasPrefix:@"/"] ? trimmed : [@"/" stringByAppendingString:trimmed];
}

- (NSString *)resolvedURLStringWithEndpoint:(nullable NSString *)overrideEndpoint {
    NSString *baseUrl = _uploadBaseUrl.length > 0 ? _uploadBaseUrl : kDefaultUploadBaseUrl;
    NSString *endpoint = overrideEndpoint.length > 0
        ? overrideEndpoint
        : (_uploadEndpoint.length > 0 ? _uploadEndpoint : kDefaultUploadEndpoint);
    return [NSString stringWithFormat:@"%@%@", [self normalizedBaseURL:baseUrl], [self normalizedEndpoint:endpoint]];
}

- (NSDictionary *)buildServerBodyFromBlePayload:(NSDictionary *)blePayload {
    NSNumber *dataType = [blePayload[@"dataType"] isKindOfClass:[NSNumber class]]
        ? blePayload[@"dataType"]
        : @(-1);
    NSString *uploadedAt = [self isoTimestampNow];
    NSString *packetTimestamp =
        [self stringOrNil:blePayload[@"packetTimestamp"]]
        ?: [self stringOrNil:blePayload[@"sensorTimestamp"]]
        ?: [self stringOrNil:blePayload[@"receivedAt"]]
        ?: [self stringOrNil:blePayload[@"timestamp"]]
        ?: uploadedAt;
    NSString *dataTypeName = [self dataTypeNameFromNumber:dataType];
    NSDictionary *safePayload = [self jsonSafeDictionary:blePayload];
    NSDictionary *safeData = [blePayload[@"data"] isKindOfClass:[NSDictionary class]]
        ? [self jsonSafeDictionary:blePayload[@"data"]]
        : @{};
    NSDictionary *healthStatus = [self buildHealthStatusFromData:safeData dataType:dataType];
    NSDictionary *metrics = [self buildMetricsFromData:safeData];

    return @{
        @"schemaVersion": @"2.0-native",
        @"deviceId": _uploadDeviceId ?: @"",
        @"bleDeviceUuid": [self stringOrNil:blePayload[@"uuid"]] ?: @"",
        @"timestamp": packetTimestamp,
        @"packetTimestamp": packetTimestamp,
        @"receivedAt": packetTimestamp,
        @"sensorTimestamp": packetTimestamp,
        @"uploadedAt": uploadedAt,
        @"dataType": dataType,
        @"dataTypeName": dataTypeName,
        @"dataEnd": @([blePayload[@"dataEnd"] boolValue]),
        @"healthStatus": healthStatus,
        @"metrics": metrics,
        @"data": safeData,
        @"payload": safePayload,
    };
}

- (id)valueOrNull:(id)value {
    return value ?: [NSNull null];
}

- (nullable NSNumber *)numberFromValue:(id)value {
    if ([value isKindOfClass:[NSNumber class]]) return value;
    if ([value isKindOfClass:[NSString class]]) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        return [formatter numberFromString:value];
    }
    return nil;
}

- (nullable NSNumber *)firstNumberInDictionary:(NSDictionary *)dict keys:(NSArray<NSString *> *)keys {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    for (NSString *key in keys) {
        NSNumber *number = [self numberFromValue:dict[key]];
        if (number) return number;
    }
    return nil;
}

- (nullable NSDictionary *)lastDictionaryForKeys:(NSArray<NSString *> *)keys inData:(NSDictionary *)data {
    if (![data isKindOfClass:[NSDictionary class]]) return nil;
    for (NSString *key in keys) {
        NSArray *array = [data[key] isKindOfClass:[NSArray class]] ? data[key] : nil;
        if (array.count == 0) continue;
        id last = array.lastObject;
        if ([last isKindOfClass:[NSDictionary class]]) return last;
    }
    return nil;
}

- (nullable NSNumber *)lastNumberInArray:(NSArray *)array {
    if (![array isKindOfClass:[NSArray class]] || array.count == 0) return nil;
    for (NSInteger i = array.count - 1; i >= 0; i--) {
        NSNumber *number = [self numberFromValue:array[i]];
        if (number) return number;
    }
    return nil;
}

- (NSInteger)arrayCountForKeys:(NSArray<NSString *> *)keys inData:(NSDictionary *)data {
    NSInteger count = 0;
    if (![data isKindOfClass:[NSDictionary class]]) return count;
    for (NSString *key in keys) {
        NSArray *array = [data[key] isKindOfClass:[NSArray class]] ? data[key] : nil;
        count += array.count;
    }
    return count;
}

- (NSDictionary *)buildHealthStatusFromData:(NSDictionary *)data dataType:(NSNumber *)dataType {
    NSNumber *steps = [self firstNumberInDictionary:data keys:@[@"steps", @"step", @"stepCount", @"totalSteps"]];
    NSNumber *calories = [self firstNumberInDictionary:data keys:@[@"calories", @"calorie"]];
    NSNumber *distance = [self firstNumberInDictionary:data keys:@[@"distance"]];
    NSNumber *heartRate = [self firstNumberInDictionary:data keys:@[@"heartRate", @"hr"]];
    NSNumber *spo2 = [self firstNumberInDictionary:data keys:@[@"spo2"]];
    NSNumber *temperature = [self firstNumberInDictionary:data keys:@[@"temperature"]];
    NSNumber *hrv = [self firstNumberInDictionary:data keys:@[@"hrv"]];
    NSNumber *rrInterval = [self firstNumberInDictionary:data
                                                    keys:@[@"RRIntervalData",
                                                           @"rrIntervalData",
                                                           @"rrInterval",
                                                           @"rr",
                                                           @"RR",
                                                           @"ppi",
                                                           @"PPI",
                                                           @"ppiData",
                                                           @"PPIData"]];
    NSNumber *stress = [self firstNumberInDictionary:data keys:@[@"stress"]];

    NSDictionary *activity = [self lastDictionaryForKeys:@[@"arrayTotalActivityData", @"arrayDetailActivityData", @"arrayActivity"] inData:data];
    if (!steps) steps = [self firstNumberInDictionary:activity keys:@[@"steps", @"step"]];
    if (!calories) calories = [self firstNumberInDictionary:activity keys:@[@"calories", @"calorie"]];
    if (!distance) distance = [self firstNumberInDictionary:activity keys:@[@"distance"]];

    NSDictionary *activityMode = [self lastDictionaryForKeys:@[@"arrayActivityModeData", @"arrayActivityMode"] inData:data];
    if (!steps) steps = [self firstNumberInDictionary:activityMode keys:@[@"steps", @"step"]];
    if (!calories) calories = [self firstNumberInDictionary:activityMode keys:@[@"calories", @"calorie"]];
    if (!distance) distance = [self firstNumberInDictionary:activityMode keys:@[@"distance"]];
    if (!heartRate) heartRate = [self firstNumberInDictionary:activityMode keys:@[@"heartRate", @"hr"]];

    NSDictionary *singleHR = [self lastDictionaryForKeys:@[@"arraySingleHR"] inData:data];
    if (!heartRate) heartRate = [self firstNumberInDictionary:singleHR keys:@[@"singleHR", @"heartRate", @"hr"]];

    NSDictionary *continuousHR = [self lastDictionaryForKeys:@[@"arrayContinuousHR"] inData:data];
    if (!heartRate && [continuousHR[@"arrayHR"] isKindOfClass:[NSArray class]]) {
        heartRate = [self lastNumberInArray:continuousHR[@"arrayHR"]];
    }

    NSDictionary *manualSpo2 = [self lastDictionaryForKeys:@[@"arrayManualSpo2Data"] inData:data];
    NSDictionary *autoSpo2 = [self lastDictionaryForKeys:@[@"arrayAutomaticSpo2Data", @"arraySpo2"] inData:data];
    if (!spo2) spo2 = [self firstNumberInDictionary:manualSpo2 keys:@[@"manualSpo2Data", @"spo2"]];
    if (!spo2) spo2 = [self firstNumberInDictionary:autoSpo2 keys:@[@"automaticSpo2Data", @"spo2"]];

    NSDictionary *temp = [self lastDictionaryForKeys:@[@"arrayTemperatureData", @"arrayemperatureData", @"arrayTemperature"] inData:data];
    if (!temperature) temperature = [self firstNumberInDictionary:temp keys:@[@"temperature", @"bodyTemperature", @"axillaryTemperature"]];

    NSDictionary *hrvRecord = [self lastDictionaryForKeys:@[@"arrayHRVData"] inData:data];
    if (!hrv) hrv = [self firstNumberInDictionary:hrvRecord keys:@[@"hrv"]];
    if (!stress) stress = [self firstNumberInDictionary:hrvRecord keys:@[@"stress"]];
    if (!heartRate) heartRate = [self firstNumberInDictionary:hrvRecord keys:@[@"heartRate", @"hr"]];

    NSDictionary *rrRecord = [self lastDictionaryForKeys:@[@"arrayPPIData",
                                                           @"arrayPpiData",
                                                           @"arrayPPI",
                                                           @"arrayPpi",
                                                           @"arrayRRIntervalData",
                                                           @"arrayRRIntervals",
                                                           @"arrayRRInterval",
                                                           @"ppiData",
                                                           @"ppi",
                                                           @"rrData",
                                                           @"RRIntervalData"] inData:data];
    if (!rrInterval) {
        rrInterval = [self firstNumberInDictionary:rrRecord
                                              keys:@[@"rrInterval",
                                                     @"RRIntervalData",
                                                     @"rrIntervalData",
                                                     @"rr",
                                                     @"RR",
                                                     @"ppi",
                                                     @"PPI",
                                                     @"ppiData",
                                                     @"PPIData",
                                                     @"value"]];
    }

    NSDictionary *sleep = [self lastDictionaryForKeys:@[@"arrayDetailSleepAndActivityData", @"arrayDetailSleepData"] inData:data];
    NSNumber *sleepMinutes = [self firstNumberInDictionary:sleep keys:@[@"totalSleepTime", @"sleepTotalTime", @"totalMinutes"]];
    NSNumber *awakeMinutes = [self firstNumberInDictionary:sleep keys:@[@"awakeDurationMinutes"]];
    NSString *sleepStart = [self stringOrNil:sleep[@"startTime_SleepData"]]
        ?: [self stringOrNil:sleep[@"startTime"]]
        ?: [self stringOrNil:sleep[@"startDate"]]
        ?: [self stringOrNil:sleep[@"date"]];

    return @{
        @"isSleeping": [NSNull null],
        @"steps": [self valueOrNull:steps],
        @"calories": [self valueOrNull:calories],
        @"distance": [self valueOrNull:distance],
        @"heartRate": [self valueOrNull:heartRate],
        @"spo2": [self valueOrNull:spo2],
        @"temperature": [self valueOrNull:temperature],
        @"hrv": [self valueOrNull:hrv],
        @"rrInterval": [self valueOrNull:rrInterval],
        @"stress": [self valueOrNull:stress],
        @"sleepMinutes": [self valueOrNull:sleepMinutes],
        @"awakeMinutes": [self valueOrNull:awakeMinutes],
        @"lastSleepStart": [self valueOrNull:sleepStart],
        @"sourceDataType": dataType ?: @(-1),
    };
}

- (NSDictionary *)buildMetricsFromData:(NSDictionary *)data {
    return @{
        @"records": @{
            @"sleep": @([self arrayCountForKeys:@[@"arrayDetailSleepData", @"arrayDetailSleepAndActivityData"] inData:data]),
            @"activity": @([self arrayCountForKeys:@[@"arrayTotalActivityData", @"arrayDetailActivityData", @"arrayActivity"] inData:data]),
            @"activityMode": @([self arrayCountForKeys:@[@"arrayActivityModeData", @"arrayActivityMode"] inData:data]),
            @"heartRateContinuous": @([self arrayCountForKeys:@[@"arrayContinuousHR"] inData:data]),
            @"heartRateSingle": @([self arrayCountForKeys:@[@"arraySingleHR"] inData:data]),
            @"spo2Automatic": @([self arrayCountForKeys:@[@"arrayAutomaticSpo2Data", @"arraySpo2"] inData:data]),
            @"spo2Manual": @([self arrayCountForKeys:@[@"arrayManualSpo2Data"] inData:data]),
            @"temperature": @([self arrayCountForKeys:@[@"arrayTemperatureData", @"arrayemperatureData", @"arrayTemperature"] inData:data]),
            @"hrv": @([self arrayCountForKeys:@[@"arrayHRVData"] inData:data]),
            @"rr": @([self arrayCountForKeys:@[@"arrayPPIData",
                                               @"arrayPpiData",
                                               @"arrayPPI",
                                               @"arrayPpi",
                                               @"arrayRRIntervalData",
                                               @"arrayRRIntervals",
                                               @"arrayRRInterval",
                                               @"ppiData",
                                               @"ppi",
                                               @"rrData",
                                               @"RRIntervalData"] inData:data]),
        },
    };
}

- (NSString *)dataTypeNameFromNumber:(NSNumber *)dataType {
    switch ([dataType integerValue]) {
        case 24: return @"RealTimeStep";
        case 25: return @"TotalActivityData";
        case 26: return @"DetailActivityData";
        case 27: return @"DetailSleepData";
        case 28: return @"DynamicHR";
        case 29: return @"StaticHR";
        case 30: return @"ActivityModeData";
        case 41: return @"HRVData";
        case 45: return @"AutomaticSpo2Data";
        case 46: return @"ManualSpo2Data";
        case 48: return @"TemperatureData";
        case 81: return @"DetailSleepAndActivityData";
        case 66: return @"OpenRRInterval";
        case 67: return @"CloseRRInterval";
        case 68: return @"RealtimeRRIntervalData";
        case 69: return @"RealtimePPIData";
        case 70: return @"RealtimePPGData";
        case 71: return @"PPGStartSucceeded";
        case 72: return @"PPGStartFailed";
        case 73: return @"PPGResult";
        case 74: return @"PPGStop";
        case 75: return @"PPGQuit";
        case 76: return @"PPGMeasurementProgress";
        case 82: return @"PPIData";
        default: return @"Unknown";
    }
}

- (id)jsonSafeObject:(id)obj {
    if (!obj || obj == [NSNull null]) return [NSNull null];

    if ([obj isKindOfClass:[NSString class]] ||
        [obj isKindOfClass:[NSNumber class]] ||
        [obj isKindOfClass:[NSNull class]]) {
        return obj;
    }

    if ([obj isKindOfClass:[NSDate class]]) {
        NSISO8601DateFormatter *fmt = [[NSISO8601DateFormatter alloc] init];
        return [fmt stringFromDate:(NSDate *)obj];
    }

    if ([obj isKindOfClass:[NSArray class]]) {
        NSArray *arr = (NSArray *)obj;
        NSMutableArray *safe = [NSMutableArray arrayWithCapacity:arr.count];
        for (id item in arr) {
            [safe addObject:[self jsonSafeObject:item] ?: [NSNull null]];
        }
        return safe;
    }

    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)obj;
        NSMutableDictionary *safe = [NSMutableDictionary dictionaryWithCapacity:dict.count];
        for (id key in dict) {
            NSString *safeKey = [key isKindOfClass:[NSString class]] ? key : [key description];
            safe[safeKey] = [self jsonSafeObject:dict[key]] ?: [NSNull null];
        }
        return safe;
    }

    return [obj description] ?: @"";
}

- (NSDictionary *)jsonSafeDictionary:(NSDictionary *)dict {
    id safe = [self jsonSafeObject:dict];
    return [safe isKindOfClass:[NSDictionary class]] ? safe : @{};
}

- (id)parsedResponseBodyFromData:(NSData *)data response:(NSHTTPURLResponse *)response {
    if (!data || data.length == 0) return [NSNull null];

    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (json) return [self jsonSafeObject:json];

    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return text ?: [NSNull null];
}

- (void)sendUploadStatusEvent:(NSDictionary *)body {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self sendEventWithName:@"BleUploadStatus" body:body ?: @{}];
    });
}

- (void)postBody:(NSDictionary *)body endpoint:(nullable NSString *)overrideEndpoint {
    NSString *urlString = [self resolvedURLStringWithEndpoint:overrideEndpoint];
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;

    NSInteger totalRetries = MAX(0, _uploadRetryCount);
    [self postURL:url
             body:[self jsonSafeDictionary:body ?: @{}]
      totalRetries:totalRetries
       retriesLeft:totalRetries];
}

- (void)postURL:(NSURL *)url
           body:(NSDictionary *)body
    totalRetries:(NSInteger)totalRetries
     retriesLeft:(NSInteger)retriesLeft {

    NSInteger attempt = MAX(1, totalRetries - retriesLeft + 1);

    NSMutableDictionary *headers = [@{ @"Content-Type": @"application/json" } mutableCopy];
    if (_uploadAuthToken.length > 0) {
        headers[@"Authorization"] = _uploadAuthToken;
    }

    [self sendUploadStatusEvent:@{
        @"stage": @"request",
        @"attempt": @(attempt),
        @"retriesLeft": @(retriesLeft),
        @"url": url.absoluteString ?: @"",
        @"request": @{ @"method": @"POST", @"headers": headers, @"body": body },
    }];

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
    if (!jsonData) {
        [self sendUploadStatusEvent:@{
            @"stage": @"error",
            @"attempt": @(attempt),
            @"retriesLeft": @(retriesLeft),
            @"url": url.absoluteString ?: @"",
            @"message": jsonError.localizedDescription ?: @"Failed to serialize upload body",
            @"request": @{ @"method": @"POST", @"headers": headers, @"body": body },
            @"response": [NSNull null],
        }];
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = MAX(1.0, _uploadTimeoutMs / 1000.0);
    request.HTTPBody = jsonData;
    [headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [request setValue:value forHTTPHeaderField:key];
    }];

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = request.timeoutInterval;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData * _Nullable data,
                                                                NSURLResponse * _Nullable response,
                                                                NSError * _Nullable error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;

        NSHTTPURLResponse *httpResponse = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? (NSHTTPURLResponse *)response
            : nil;

        NSInteger statusCode = httpResponse.statusCode;
        BOOL ok = (statusCode >= 200 && statusCode < 300) && (error == nil);

        id responseBody = [strongSelf parsedResponseBodyFromData:data response:httpResponse];
        NSDictionary *responseMeta = httpResponse
            ? @{ @"ok": @(ok),
                 @"status": @(statusCode),
                 @"statusText": [NSHTTPURLResponse localizedStringForStatusCode:statusCode] ?: @"",
                 @"headers": [strongSelf jsonSafeObject:httpResponse.allHeaderFields ?: @{}],
                 @"body": responseBody ?: [NSNull null] }
            : (NSDictionary *)[NSNull null];

        if (ok) {
            [strongSelf sendUploadStatusEvent:@{
                @"stage": @"success",
                @"attempt": @(attempt),
                @"retriesLeft": @(retriesLeft),
                @"url": url.absoluteString ?: @"",
                @"request": @{ @"method": @"POST", @"headers": headers, @"body": body },
                @"response": responseMeta,
            }];
            [session finishTasksAndInvalidate];
            return;
        }

        if (retriesLeft > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                           dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [strongSelf postURL:url body:body totalRetries:totalRetries retriesLeft:retriesLeft - 1];
            });
            [session finishTasksAndInvalidate];
            return;
        }

        NSString *message = error.localizedDescription;
        if (message.length == 0) {
            message = [NSString stringWithFormat:@"Server responded %ld", (long)statusCode];
        }

        [strongSelf sendUploadStatusEvent:@{
            @"stage": @"error",
            @"attempt": @(attempt),
            @"retriesLeft": @(retriesLeft),
            @"url": url.absoluteString ?: @"",
            @"message": message,
            @"request": @{ @"method": @"POST", @"headers": headers, @"body": body },
            @"response": responseMeta ?: [NSNull null],
        }];

        [session finishTasksAndInvalidate];
    }];

    [task resume];
}

@end
