//
//  BleSDK.h
//  BleSDK
//
//  Created by yang sai on 2022/4/27.
//

#import <Foundation/Foundation.h>
#import "BleSDK_Header_V8.h"
#import "DeviceData_V8.h"
@interface BleSDK_V8 : NSObject
/*!
 *  @method sharedManager:
 *
 *  @discussion Singleton pattern 单例模式
 *
 */
+(BleSDK_V8 *)sharedManager;

/*!
 *  @method GetDeviceTime:
 *
 *  @discussion Get the time of the watch  获取手表的时间
 *
 */
-(NSMutableData*)GetDeviceTime;
/*!
 *  @method SetDeviceTime:
 *  @param deviceTime   time parameter  时间参数.
 *  @discussion Set the time of the watch 设置手表的时间
 *
 */
-(NSMutableData*)SetDeviceTime:(MyDeviceTime_V8)deviceTime;

/*!
 *  @method GetPersonalInfo:
 *
 *  @discussion Get the personal information of the watch  获取手表的个人信息
 *
 */
-(NSMutableData*)GetPersonalInfo;
/*!
 *  @method SetPersonalInfo:
 *  @param personalInfo   Personal basic information parameters   个人基本信息参数
 *  @discussion Set up your watch's personal information  设置手表的个人信息
 *
 */
-(NSMutableData*)SetPersonalInfo:(MyPersonalInfo_V8)personalInfo;








/*!
 *  @method GetStepGoal
 *
 *  @discussion Get your watch's step goal 获取手表的步数目标
 *
 */
-(NSMutableData*)GetStepGoal;
/*!
 *  @method SetStepGoal:
 *  @param stepGoal    target value of steps 步数的目标值.
 *  @discussion Set a step goal  设置步数目标
 *
 */
-(NSMutableData*)SetStepGoal:(int)stepGoal;










/*!
 *  @method GetDeviceBatteryLevel
 *
 *  @discussion Get the battery of the watch  获取手表的电量
 *
 */
-(NSMutableData*)GetDeviceBatteryLevel;


/*!
 *  @method GetDeviceMacAddress
 *
 *  @discussion Get the Mac address of the watch  获取手表的Mac地址
 *
 */
-(NSMutableData*)GetDeviceMacAddress;



/*!
 *  @method GetDeviceVersion
 *
 *  @discussion  Get the version information of the watch 获取手表的版本信息
 *
 */
-(NSMutableData*)GetDeviceVersion;



/*!
 *  @method Reset
 *
 *  @discussion  Factory reset (factory reset will delete all data on the device) 恢复出厂设置(恢复出厂设置会让设备的数据全部删除)
 *
 */
-(NSMutableData*)Reset;

/*!
 *  @method MCUReset
 *
 *  @discussion MCU reset, restarting the device, will not delete the data stored in the watch    MCU复位，重启设备，不会删除手表存储的数据
 *
 */
-(NSMutableData*)MCUReset;





/*!
 *  @method GetAutomaticMonitoringWithDataType:
 *  @param dataType   1 means heartRate  2 means spo2  3 means temperature  4 means HRV 1 表示心率 2 表示血氧饱和度 3 表示体温 4 表示 HRV
 *  @discussion get  the automatic monitoring information set by the watch
 *
 */
-(NSMutableData*)GetAutomaticMonitoringWithDataType:(int)dataType;

/*!
 *  @method SetAutomaticMonitoring:
 *  @param automaticMonitoring   Automatic measurement setting information of the watch  手表的自动测量设置信息
 *  @discussion Set the automatic measurement setting information of the watch 设置手表的自动测量设置信息
 *
 */
-(NSMutableData*)SetAutomaticHRMonitoring:(MyAutomaticMonitoring_V8)automaticMonitoring;




/*!
 *  @method GetAlarmClock:
 *
 *  @discussion get alarm获取闹钟
 *
 */
-(NSMutableData*)GetAlarmClock;



/*!
 *  @method  DeleteAllAlarmClock
 *
 *  @discussion   delete all alarms 删除所有闹钟
 *
 */
-(NSMutableData*)DeleteAllAlarmClock;


/*!
 *  @method SetAlarmClockWithAllClock:
 *  @param arrayClockAlarm   Set all alarm clocks (the maximum number of alarm clocks is 10) The format of each alarm clock is an NSDictionary 设置所有闹钟(闹钟最大的个数是10) 每个闹钟的格式是一个NSDictionary
 *  @discussion Set watch alarm 设置手表闹钟
 *
 */
-(nullable NSMutableArray<NSMutableData *> *)SetAlarmClockWithAllClock:(nullable NSArray<NSDictionary *> *)arrayClockAlarm;








/*!
 *  @method ppgWithMode::
 *  @param ppgMode  1 表示开启ppg测量   2表示给设备发送测量结果  3表示停止ppg测量  4表示给设备发送ppg测量的进度  5表示退出ppg测量
 *  @param ppgStatus 当 ppgMode=2或者 ppgMode=4的时候才有效。当ppgMode=2时，0表示测量失败  1 表示测量结果偏低  2表示测量结果正常 3表示测量结果偏高 。 当ppgMode=4时，ppgStatus表示测量的进度值，范围是0-100
 *  @discussion Turn on ECG measurement 开启ECG测量
 *
 */
-(NSMutableData*)ppgWithMode:(int)ppgMode  ppgStatus:(int)ppgStatus;



/*!
 *  @method RealTimeDataWithType:
 *  @param dataType   0: means off 1: when the number of steps changes, the watch will upload data (the data does not include the temperature value)  0:表示关闭  1:当步数发生变化时，手表会上传数据（数据不包含温度值） 
 *
 *  @discussion Watch real-time data upload  实时数据上传
 *
 */
-(NSMutableData*)RealTimeDataWithType:(int8_t)dataType;




/*!
 *  @method manualMeasurementWithDataType::
 *  @param dataType heartRateData menas heart rate  spo2Data menas spo2
 *  @param measurementTime  The length of time to measure, the minimum value is 30 seconds
 *  @param isOpen  When isOpen=YES, it means open measurement. When isOpen=NO, it means close the measurement.
 *  @discussion Watch real-time data upload  实时数据上传
 *
 */
-(NSMutableData*)manualMeasurementWithDataType:(MeasurementDataType_V8)dataType measurementTime:(int)measurementTime open:(BOOL)isOpen;




/*!
 *  @method setECGRealtimeDuringHRVEnabled:
 *  @param enabled  When enabled=YES, Real-time ECG transmission will be turned on, otherwise it will be turned off.
 *  @discussion Enable / Disable ECG Real-Time Data Transmission  开启 / 关闭 ECG 实时数据发送
 *
 */
- (NSMutableData*)setECGRealtimeDuringHRVEnabled:(BOOL)enabled;


/*!
 *  @method GetTotalActivityDataWithMode::
 *  @param mode   0: It means to start reading from the latest position (up to 50 sets of data) 2: It means to read next (when the total number of data is greater than 50) 0x99: It means to delete all the total exercise data   0:表示是从最新的位置开始读取(最多50组数据)  2:表示接着读取(当数据总数大于50的时候) 0x99:表示删除所有运动总数据
 *  @param  startDate  Read data from this date (note: this date must be exactly the same as the date of a piece of data stored in the watch, otherwise this parameter will be invalid)    从这个日期开始读取数据(注意：这个日期一定是要与手环存储的某条数据的日期完全相同，否则这个参数将无效)
 *  @discussion Get total exercise data    获取运动总数据
 *
 */
-(NSMutableData*)GetTotalActivityDataWithMode:(int)mode withStartDate:(NSDate*)startDate;


/*!
 *  @method GetDetailActivityDataWithMode::
 *  @param mode    0: It means to start reading from the latest position (up to 50 sets of data) 2: It means to read next (when the total number of data is greater than 50)     0x99: Indicates to delete all detailed exercise data          0:表示是从最新的位置开始读取(最多50组数据)  2:表示接着读取(当数据总数大于50的时候) 0x99:表示删除所有详细运动数据
 *   @param  startDate  Read data from this date (note: this date must be exactly the same as the date of a piece of data stored in the watch, otherwise this parameter will be invalid)    从这个日期开始读取数据(注意：这个日期一定是要与手环存储的某条数据的日期完全相同，否则这个参数将无效)
 *  @discussion  Get detailed exercise data   获取详细运动数据
 *
 */
-(NSMutableData*)GetDetailActivityDataWithMode:(int)mode  withStartDate:(NSDate*)startDate;


/*!
 *  @method GetDetailSleepDataWithMode::
 *  @param mode    0: It means to start reading from the latest position (up to 50 sets of data) 2: It means to read next (when the total number of data is greater than 50)     0x99: Indicates to delete all sleep  data    0:表示是从最新的位置开始读取(最多50组数据)  2:表示接着读取(当数据总数大于50的时候) 0x99:表示删除所有睡眠数据
 *  @param  startDate  Read data from this date (note: this date must be exactly the same as the date of a piece of data stored in the watch, otherwise this parameter will be invalid)    从这个日期开始读取数据(注意：这个日期一定是要与手环存储的某条数据的日期完全相同，否则这个参数将无效)
 *  @discussion Get sleep data  获取睡眠数据
 *
 */
-(NSMutableData*)GetDetailSleepDataWithMode:(int)mode  withStartDate:(NSDate*)startDate;



/*!
 *  @method getSleepDetailsAndActivityWithMode::
 *  @param mode    0: It means to start reading from the latest position (up to 50 sets of data) 2: It means to read next (when the total number of data is greater than 50)     0x99: Indicates deleting all sleep details and activity data. 0:表示是从最新的位置开始读取(最多50组数据)  2:表示接着读取(当数据总数大于50的时候) 0x99:表示删除所有睡眠详细数据+活动量
 *  @param  startDate  Read data from this date (note: this date must be exactly the same as the date of a piece of data stored in the watch, otherwise this parameter will be invalid)    从这个日期开始读取数据(注意：这个日期一定是要与手环存储的某条数据的日期完全相同，否则这个参数将无效)
 *  @discussion Get sleep data and activity data  获得睡眠详细数据+活动量
 *
 */

-(NSMutableData*)getSleepDetailsAndActivityWithMode:(int)mode withStartDate:(NSDate*)startDate;

/*!
 *  @method GetContinuousHRDataWithMode::
 *  @param mode   0: It means to start reading from the latest position (up to 50 sets of data) 2: It means to read next (when the total number of data is greater than 50)     0x99: means to delete all continuous HR  data  0:表示是从最新的位置开始读取(最多50组数据)  2:表示接着读取(当数据总数大于50的时候) 0x99:表示删除所有连续心率数据
 *  @param  startDate  Read data from this date (note: this date must be exactly the same as the date of a piece of data stored in the watch, otherwise this parameter will be invalid)    从这个日期开始读取数据(注意：这个日期一定是要与手环存储的某条数据的日期完全相同，否则这个参数将无效)
 *  @discussion Get continuous heart rate data  获取连续心率
 *
 */
-(NSMutableData*)GetContinuousHRDataWithMode:(int)mode  withStartDate:(NSDate*)startDate;

/*!
 *  @method GetSingleHRDataWithMode::
 *  @param mode    0: It means to start reading from the latest position (up to 50 sets of data) 2: It means to read next (when the total number of data is greater than 50)     0x99: means to delete all single HR  data  0:表示是从最新的位置开始读取(最多50组数据)  2:表示接着读取(当数据总数大于50的时候) 0x99:表示删除所有单次心率数据
 *  @param  startDate  Read data from this date (note: this date must be exactly the same as the date of a piece of data stored in the watch, otherwise this parameter will be invalid)    从这个日期开始读取数据(注意：这个日期一定是要与手环存储的某条数据的日期完全相同，否则这个参数将无效)
 *  @discussion Get single heart rate data 获取单次心率数据
 *
 */
-(NSMutableData*)GetSingleHRDataWithMode:(int)mode  withStartDate:(NSDate*)startDate;



/*!
 *  @method GetHRVDataWithMode::
 *  @param mode  0: It means to start reading from the latest position (up to 50 sets of data) 2: It means to read next (when the total number of data is greater than 50)     0x99: means to delete all HRV data  0:表示是从最新的位置开始读取(最多50组数据)  2:表示接着读取(当数据总数大于50的时候) 0x99:表示删除所有HRV数据
    @param  startDate  Read data from this date (note: this date must be exactly the same as the date of a piece of data stored in the watch, otherwise this   parameter will be invalid)    从这个日期开始读取数据(注意：这个日期一定是要与手环存储的某条数据的日期完全相同，否则这个参数将无效)
 *  @discussion Get HRV monitoring data   获取HRV历史数据
 *
 */
-(NSMutableData*)GetHRVDataWithMode:(int)mode  withStartDate:(NSDate*)startDate;




/*!
 *  @method GetAutomaticSpo2DataWithMode::
 *  @param mode  0: It means to start reading from the latest position (up to 50 sets of data) 2: It means to read next (when the total number of data is greater than 50)     0x99: means to delete all  automatic Spo2 data   0:表示是从最新的位置开始读取(最多50组数据)  2:表示接着读取(当数据总数大于50的时候) 0x99:表示删除所有自动血氧历史数据
    @param  startDate  Read data from this date (note: this date must be exactly the same as the date of a piece of data stored in the watch, otherwise this   parameter will be invalid)    从这个日期开始读取数据(注意：这个日期一定是要与手环存储的某条数据的日期完全相同，否则这个参数将无效)
 *  @discussion Get automatic Spo2 historical data  获取自动Spo2历史数据
 *
 */
-(NSMutableData*)GetAutomaticSpo2DataWithMode:(int)mode  withStartDate:(NSDate*)startDate;



/*!
 *  @method GetManualSpo2DataWithMode:
 *  @param mode  0: It means to start reading from the latest position (up to 50 sets of data) 2: It means to read next (when the total number of data is greater than 50)     0x99: means to delete all  manual Spo2 data   0:表示是从最新的位置开始读取(最多50组数据)  2:表示接着读取(当数据总数大于50的时候) 0x99:表示删除所有手动血氧历史数据
    @param  startDate  Read data from this date (note: this date must be exactly the same as the date of a piece of data stored in the watch, otherwise this   parameter will be invalid)    从这个日期开始读取数据(注意：这个日期一定是要与手环存储的某条数据的日期完全相同，否则这个参数将无效)
 *  @discussion Get manual Spo2 historical data  获取手动Spo2历史数据
 *
 */
-(NSMutableData*)GetManualSpo2DataWithMode:(int)mode  withStartDate:(NSDate*)startDate;


/*!
 *  @method GetTemperatureDataWithMode::
 *  @param mode    0: It means to start reading from the latest position (up to 50 sets of data) 2: It means to read next (when the total number of data is greater than 50)     0x99: means to delete all  temperature data   0:表示是从最新的位置开始读取(最多50组数据)  2:表示接着读取(当数据总数大于50的时候) 0x99:表示删除所有体温历史数据
    @param  startDate  Read data from this date (note: this date must be exactly the same as the date of a piece of data stored in the watch, otherwise this   parameter will be invalid)    从这个日期开始读取数据(注意：这个日期一定是要与手环存储的某条数据的日期完全相同，否则这个参数将无效)
 *  @discussion Get temperature history data  获取体温的历史数据
 *
 */
-(NSMutableData*)GetTemperatureDataWithMode:(int)mode  withStartDate:(NSDate*)startDate;


/*!
 *  @method GetPPIDataWithMode::
 *  @param mode    0: It means to start reading from the latest position (up to 50 sets of data) 2: It means to read next (when the total number of data is greater than 50)     0x99: means to delete all  PPI data   0:表示是从最新的位置开始读取(最多50组数据)  2:表示接着读取(当数据总数大于50的时候) 0x99:表示删除所有PPI历史数据
    @param  startDate  Read data from this date (note: this date must be exactly the same as the date of a piece of data stored in the watch, otherwise this   parameter will be invalid)    从这个日期开始读取数据(注意：这个日期一定是要与手环存储的某条数据的日期完全相同，否则这个参数将无效)
 *  @discussion Get PPI history data  获取PPI的历史数据
 *
 */
-(NSMutableData*)GetPPIDataWithMode:(int)mode  withStartDate:(NSDate*)startDate;



/*!
 *  @method GetActivityModeDataWithMode::
 *  @param mode  0: It means to start reading from the latest position (up to 50 sets of data) 2: It means to read next (when the total number of data is greater than 50)     0x99: means to delete all activity mode data  0:表示是从最新的位置开始读取(最多50组数据)  2:表示接着读取(当数据总数大于50的时候) 0x99:表示删除所有运动类型历史数据
    @param  startDate  Read data from this date (note: this date must be exactly the same as the date of a piece of data stored in the watch, otherwise this   parameter will be invalid)    从这个日期开始读取数据(注意：这个日期一定是要与手环存储的某条数据的日期完全相同，否则这个参数将无效)
 *   @param  needMETS   If METS is required, set needMETS to YES; if not, set it to NO.   是否需要METS，如果需要则将needMETS设置为YES，不需要就设置为NO
 *  @discussion Get sports type historical data  获取运动类型历史数据
 *
 */
-(NSMutableData*)GetActivityModeDataWithMode:(int)mode  withStartDate:(NSDate*)startDate needMETS:(BOOL)needMETS;


/*!
 *  @method startActivityMode:::
 *  @param activityMode   sport mode
 *  @param workMode  Working mode
 *  @param activityTime  Set how long to exercise unit is minutes
 *  @param breathParameter When workMode is 6, you need to set the parameters of breathing exercise  当workMode是6的时候需要设置呼吸锻炼的参数

 *  @discussion Enter or exit multisport mode  进入或退出多运动模式
 *
 */
-(NSMutableData*)startActivityMode:(ACTIVITYMODE_V8)activityMode WorkMode:(WORKMODE_V8)workMode  ActivityTime:(int)activityTime BreathParameter:(MyBreathParameter_V8)breathParameter ;



/*!
 *  @method getActivityMode
 *  @discussion Get current exercise mode  获取当前戒指的运动模式
 *
 */
-(NSMutableData*)getActivityMode;






/*!
 *  @method ClearAllHistoryData
 *  @discussion  Clear all historical data  清除所有历史数据
 *
 */
-(NSMutableData*)ClearAllHistoryData;


/*!
 *  @method DataParsingWithData:
 *  @param bleData Data returned by the watch  手环返回的数据
 *  @discussion  data analysis 数据解析
 *
 */
-(DeviceData_V8*)DataParsingWithData:(NSData*_Nullable)bleData;
@end
