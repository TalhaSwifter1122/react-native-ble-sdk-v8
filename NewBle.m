//
//  NewBle.m
//  NewBle
//
//  Created by  on 2018/6/29.
//  Copyright © 2018年 杨赛. All rights reserved.
//

#import "NewBle.h"
@interface NewBle()<CBCentralManagerDelegate,CBPeripheralDelegate>
{
    
}
@end
@implementation NewBle
@synthesize CentralManage,PeripheralManager,activityPeripheral;
+(NewBle *)sharedManager
{
    static NewBle *sharedAccountManagerInstance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        sharedAccountManagerInstance = [[self alloc] init];
    });
    return sharedAccountManagerInstance;
}
//设置为主设备
- (void)SetUpCentralManager
{
    CentralManage = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}
//设置为从设备
- (void)SetUpPeripheralManager
{
    
}

-(BOOL)isConnectOrConnecting
{
   if(activityPeripheral.state==CBPeripheralStateConnected||activityPeripheral.state==CBPeripheralStateConnecting)
        return YES;
    else
        return NO;
}

-(BOOL)isActivityPeripheral
{
   if(activityPeripheral.state==CBPeripheralStateConnected)
        return YES;
    else
        return NO;
}



- (void)startScanningWithServices:(nullable NSArray<CBUUID *> *)serviceUUIDs
{
    CentralManage.delegate = self;
    [CentralManage scanForPeripheralsWithServices:serviceUUIDs options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@YES}];
}


- (void)connectDevice:(CBPeripheral*)peripheral
{
    if (CentralManage.isScanning==YES)
        [self Stopscan];
      activityPeripheral = peripheral;
      activityPeripheral.delegate = self;
      peripheral.delegate = self;
     [CentralManage connectPeripheral:peripheral options:nil];
}


#pragma mark 获取已经连接的设备
- (NSArray *)retrieveConnectedPeripheralsWithServices:(NSArray<CBUUID *> *)serviceUUIDs
{
    NSArray * arrayConnectPeripheral = [CentralManage retrieveConnectedPeripheralsWithServices:serviceUUIDs];
      return arrayConnectPeripheral;
}


#pragma mark 浮点转换
/*
 将浮点数f转化为4个字节数据存放在byte[4]中
 */
-(void)Float_to_Byte:(float)f byte:(Byte*)byte location:(int)location
{
    
    memcpy(byte+location, &f, 4);
    
}

#pragma mark 数据收发!!!
static void (^BLE_Block_Receive)(Byte* _Nullable buf,int length);

- (void)SendData:(char*)b length:(int)length
{
  
    int sam = 0;
    for (int j = 0; j < length; j++)
    {
        sam += b[j];
    }
    b[15] = sam;
    NSMutableData *data = [[NSMutableData alloc] initWithBytes:b length:length];
    
    [self writeValue:SERVICE characteristicUUID:SEND_CHAR p:activityPeripheral data:data];
    
}


-(void)writeValueUI:(NSString*)serviceUUID characteristicUUID:(NSString*)characteristicUUID p:(CBPeripheral *)p data:(NSData *)data
{
    NSString * strData = @"";
    Byte * byte = (Byte*) data.bytes;
    for (int i = 0 ; i< data.length; i++) {
        strData = [strData stringByAppendingString:[NSString stringWithFormat:@"%02x ",byte[i]]];
    }
    strData = [@"Send:" stringByAppendingString:[NSString stringWithFormat:@"(lenght:%d)-%@",(int)data.length,strData]];
    writeLogs(strData, @"Ble SDK Demo Log.txt");
  
    CBService * service  = [self FindServiceFromUUID:serviceUUID Peripheral:p];
    if(!service)
    {
        NSLog(@"Could not find service with UUID %@ on peripheral",serviceUUID);
        return;
    }
    CBCharacteristic * characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];
    if(!characteristic)
    {
        NSLog(@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral",serviceUUID,characteristicUUID);
        return;
    }
    [p writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];  //ISSC
}
-(void)writeValue:(NSString*)serviceUUID characteristicUUID:(NSString*)characteristicUUID p:(CBPeripheral *)p data:(NSData *)data
{
     NSString * strData = @"";
    Byte * byte = (Byte*) data.bytes;
    for (int i = 0 ; i< data.length; i++) {
//        NSLog(@"buf[0] = %02x",byte[0]);
        strData = [strData stringByAppendingString:[NSString stringWithFormat:@"%02x ",byte[i]]];
    }
  
     strData = [@"Send:" stringByAppendingString:[NSString stringWithFormat:@"(lenght:%d)-%@",(int)data.length,strData]];
     writeLogs(strData, @"Ble SDK Demo.txt");
    
    CBService * service  = [self FindServiceFromUUID:serviceUUID Peripheral:p];
    if(!service)
    {
        NSLog(@"Could not find service with UUID %@ on peripheral",serviceUUID);
        return;
    }
    CBCharacteristic * characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];
    if(!characteristic)
    {
        NSLog(@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral",serviceUUID,characteristicUUID);
        return;
    }
    [p writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];  //ISSC
}


- (void)retrieveConnectedPeripheralsWithServices:(NSArray<CBUUID *> *)serviceUUIDs Block:(void (^)(NSArray* arrayConnectPeripheral,BOOL isSuccess))block
{
    NSArray * arrayConnectPeripheral = [CentralManage retrieveConnectedPeripheralsWithServices:serviceUUIDs];
    if(arrayConnectPeripheral.count>0)
        block(arrayConnectPeripheral,YES);
    else
        block(nil,NO);
}

-(void)Stopscan
{
    [CentralManage stopScan];
}
-(void)Disconnect
{
    if(activityPeripheral)
    [CentralManage cancelPeripheralConnection:activityPeripheral];
}

-(void)enable
{
    [self notification:SERVICE characteristicUUID:REC_CHAR p:activityPeripheral on:YES];
}

-(void)notification:(NSString*)serviceUUID characteristicUUID:(NSString*)characteristicUUID p:(CBPeripheral *)p on:(BOOL)on
{
   CBService * service  = [self FindServiceFromUUID:serviceUUID Peripheral:p];
    if(!service)
    {
        NSLog(@"Could not find service with UUID %@ on peripheral",serviceUUID);
        return;
    }
    CBCharacteristic * characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];
    if(!characteristic)
    {
        NSLog(@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral",serviceUUID,characteristicUUID);
        return;
    }
   [p setNotifyValue:on forCharacteristic:characteristic];
   [self.delegate EnableCommunicate];
}


-(CBService*)FindServiceFromUUID:(NSString*)serviceUUID Peripheral:(CBPeripheral *)peripheral
{
    
    for (int i = 0; i<peripheral.services.count; i++) {
        CBService * service = [peripheral.services objectAtIndex:i];
        if([service.UUID.UUIDString.lowercaseString isEqualToString:serviceUUID.lowercaseString])
            return service;
    }
    return nil;
}

//查找服务的指定特征
-(CBCharacteristic *) findCharacteristicFromUUID:(NSString *)UUID service:(CBService*)service {
    for(int i=0; i < service.characteristics.count; i++) {
        CBCharacteristic *c = [service.characteristics objectAtIndex:i];
        if([UUID.lowercaseString isEqualToString:c.UUID.UUIDString.lowercaseString])
            return c;
    }
    return nil; //Characteristic not found on this service
}


#pragma mark 蓝牙状态发生改变
-(NSString*)centralManagerStateToString:(NSInteger)state
{
    switch(state) {
        case CBManagerStateUnknown:
            return @"CBManagerStateUnknown";
        case CBManagerStateResetting:
            return @"CBManagerStateResetting";
        case CBManagerStateUnsupported:
            return @"CBManagerStateUnsupported";
        case CBManagerStateUnauthorized:
            return @"CBManagerStateUnauthorized";
        case CBManagerStatePoweredOff:
        {
            [UserDefaults setBool:NO forKey:@"blestatus"];
            [UserDefaults synchronize];
            [self.delegate Disconnect:nil];
            return @"CBCentralManagerStatePoweredOff";
        }
        case CBManagerStatePoweredOn:
        {
            [UserDefaults setBool:YES forKey:@"blestatus"];
            [UserDefaults synchronize];
            return @"CBCentralManagerStatePoweredOn";
        }
        default:
            return @"State unknown";
    }
    return @"Unknown state";
}
#pragma mark CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(nonnull CBCentralManager *)central {
    NSLog(@"Status of CoreBluetooth central manager changed %@",[self centralManagerStateToString:central.state]);
}

- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *, id> *)dict
{
    
}
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    [self.delegate scanWithPeripheral:peripheral advertisementData:advertisementData RSSI:RSSI];
}
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    [peripheral discoverServices:nil];
    [self.delegate ConnectSuccessfully];
}
    
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
    [self.delegate ConnectFailedWithError:error];
}
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
    
    NSString * strError = [NSString stringWithFormat:@"设备%@蓝牙断开连接:%@",peripheral.name,error.description];
    writeLogs(strError, @"Ble SDK Demo.txt");
    if(error)
    {
        [central connectPeripheral:peripheral options:nil];
    }
     [self.delegate Disconnect:error];
}
#pragma mark CBPeripheralDelegate
- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral
{
    
}
- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray<CBService *> *)invalidatedServices NS_AVAILABLE(10_9, 7_0)
{
    
}
- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(nullable NSError *)error NS_AVAILABLE(10_13, 8_0)
{
    
}
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error
{
    for (int i=0; i < peripheral.services.count; i++) {
        CBService *s = [peripheral.services objectAtIndex:i];
        [peripheral discoverCharacteristics:nil forService:s];
    }
}
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverIncludedServicesForService:(CBService *)service error:(nullable NSError *)error
{
    
}
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error
{
    if([service isEqual:peripheral.services.lastObject])
        [self enable];
    
}
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
//    NSLog(@"characteristic.value --- : %@",characteristic.value);
    NSString * strUUID = characteristic.UUID.UUIDString;
    if([strUUID isEqualToString:REC_CHAR])
    {
        Byte *byte = (Byte *)[characteristic.value bytes];
        NSString * strData = @"";
        for (int i = 0 ; i< characteristic.value.length; i++) {
            strData = [strData stringByAppendingString:[NSString stringWithFormat:@"%02x ",byte[i]]];
        }
        strData = [@"Receive:" stringByAppendingString:[NSString stringWithFormat:@"(lenght:%d) %@",(int)characteristic.value.length,strData]];
         writeLogs(strData, @"Ble SDK Demo.txt");
        [self.delegate BleCommunicateWithPeripheral:peripheral data:characteristic.value];
        
    }
   
}
 - (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    
}
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    
}
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    
}
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(nullable NSError *)error
{
    
}
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor error:(nullable NSError *)error
{
    
}
- (void)peripheralIsReadyToSendWriteWithoutResponse:(CBPeripheral *)peripheral
{
    
}
- (void)peripheral:(CBPeripheral *)peripheral didOpenL2CAPChannel:(nullable CBL2CAPChannel *)channel error:(nullable NSError *)error
API_AVAILABLE(ios(11.0)){
    
}



-(NSString *) utf8ToUnicode:(NSString *)string{
    NSUInteger length = [string length];
    NSMutableString *str = [NSMutableString stringWithCapacity:0];
    for (int i = 0;i < length; i++){
        NSMutableString *s = [NSMutableString stringWithCapacity:0];
        unichar _char = [string characterAtIndex:i];
        // 判断是否为英文和数字
        if (_char <= '9' && _char >='0'){
            [s appendFormat:@"%@",[string substringWithRange:NSMakeRange(i,1)]];
        }else if(_char >='a' && _char <= 'z'){
            [s appendFormat:@"%@",[string substringWithRange:NSMakeRange(i,1)]];
        }else if(_char >='A' && _char <= 'Z')
        {
            [s appendFormat:@"%@",[string substringWithRange:NSMakeRange(i,1)]];
        }else{
            // 中文和字符
            [s appendFormat:@"\\u%x",[string characterAtIndex:i]];
            // 不足位数补0 否则解码不成功
            if(s.length == 4) {
                [s insertString:@"00" atIndex:2];
            } else if (s.length == 5) {
                [s insertString:@"0" atIndex:2];
            }
        }
        [str appendFormat:@"%@", s];
    }
    return str;
}

-(NSString *) getNSUTF8String: (NSString *) content{
    return [content stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
}
@end
