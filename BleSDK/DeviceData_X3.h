//
//  DeviceData.h
//  BleSDK
//
//  Created by yang sai on 2022/4/27.
//

#import <Foundation/Foundation.h>
#import "BleSDK_Header_X3.h"
NS_ASSUME_NONNULL_BEGIN

@interface DeviceData_X3 : NSObject
@property  DATATYPE_X3 dataType;
@property(nullable,nonatomic) NSDictionary * dicData;
@property BOOL dataEnd;
@end

NS_ASSUME_NONNULL_END
