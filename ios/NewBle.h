//
//  NewBle.h
//  NewBle
//
//  Created by  on 2018/6/29.
//  Copyright © 2018年 杨赛. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreBluetooth/CBService.h>

@protocol MyBleDelegate <NSObject>
@optional
-(void)ConnectSuccessfully;
-(void)Disconnect:(NSError *_Nullable)error;
-(void)scanWithPeripheral:(CBPeripheral*_Nonnull)peripheral advertisementData:(NSDictionary<NSString *, id> *_Nonnull)advertisementData RSSI:(NSNumber *_Nonnull)RSSI;
-(void)ConnectFailedWithError:(nullable NSError *)error;
-(void)EnableCommunicate;
-(void)BleCommunicateWithPeripheral:(CBPeripheral*)Peripheral data:(NSData *)data;
@end

@interface NewBle : NSObject
{
    
}

@property (retain, nonatomic) CBCentralManager * _Nullable   CentralManage;
@property (retain, nonatomic) CBPeripheralManager * _Nullable PeripheralManager;
@property (retain, nonatomic) CBPeripheral * _Nullable activityPeripheral;
@property (nonatomic,retain) id<MyBleDelegate> _Nullable delegate;
NS_ASSUME_NONNULL_BEGIN
+(NewBle *_Nullable)sharedManager;
//设置为主设备
- (void)SetUpCentralManager;
//设置为从设备
- (void)SetUpPeripheralManager;

/**
 Description 设备是否处于连接或者正在连接
 */
-(BOOL)isConnectOrConnecting;

/**
 Description 设备是否处于连接状态
 */
-(BOOL)isActivityPeripheral;


- (void)startScanningWithServices:(nullable NSArray<CBUUID *> *)serviceUUIDs;

- (void)connectDevice:(CBPeripheral*)peripheral;
#pragma mark 获取已经被系统蓝牙连接的设备
- (NSArray *)retrieveConnectedPeripheralsWithServices:(NSArray<CBUUID *> *)serviceUUIDs;

/**
 Description
 获取已经连接的设备
 @param serviceUUIDs 设备的UUID
 @param block 连接后的反馈
 */
- (void)retrieveConnectedPeripheralsWithServices:(NSArray<CBUUID *> *_Nullable)serviceUUIDs Block:(void (^_Nullable)(NSArray* _Nonnull arrayConnectPeripheral,BOOL isSuccess))block;
/**
 Description
 停止扫描
 */
-(void)Stopscan;
/**
 Description
 断开连接
 */
-(void)Disconnect;
NS_ASSUME_NONNULL_END

/**
 Description
 发送数据到手环

 */
-(void)writeValue:(NSString*)serviceUUID characteristicUUID:(NSString*)characteristicUUID p:(CBPeripheral *)p data:(NSData *)data;


- (void)SetWeatherWithWeather:(int )weatherType CurrentTemp:(int )CurrentTemp  LowTemp:(int )LowTemp HighTemp:(int )HighTemp CityName:(NSString *)CityName  Block:(void (^_Nullable)(Byte* _Nullable buf,int length))block;
@end
