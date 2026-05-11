//
//  DeviceData.h
//  BleSDK
//
//  Created by yang sai on 2022/4/27.
//

#import <Foundation/Foundation.h>
#import "BleSDK_Header_V8.h"
NS_ASSUME_NONNULL_BEGIN

@interface DeviceData_V8 : NSObject
@property  DATATYPE_V8 dataType;
@property(nullable,nonatomic) NSDictionary * dicData;
@property BOOL dataEnd;
@end

NS_ASSUME_NONNULL_END
