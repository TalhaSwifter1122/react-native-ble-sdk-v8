//
//  infoView.m
//  Ble SDK Demo
//
//  Created by yang sai on 2023/12/12.
//

#import "infoView.h"

@interface infoView ()

@property (weak, nonatomic) IBOutlet UITextView *myTextView;
@end

@implementation infoView
@synthesize infoType;
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    
    if(infoType==0)
    {
        _myTextView.text = LocalForkey(@"设置设备时间   SetDeviceTime:\n\n参数 : MyDeviceTime_X3 的结构体\n\n调用方法\n\nNSMutableData * data = [[BleSDK_X3 sharedManager] SetDeviceTime:deviceTime];\n\n[[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];\n\n返回结果\n_dataEnd (是否是最后一条返回数据) true\n_dataType (返回的数据类型) SetDeviceTime_X3\n_dicData (返回数据的内容) nil \n\n\n\n\n\n获取设备时间   GetDeviceTime\n\n调用方法\n\nNSMutableData * data = [[BleSDK_X3 sharedManager] GetDeviceTime];\n\n[[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];\n\n返回结果\n_dataEnd (是否是最后一条返回数据) true\n_dataType (返回的数据类型) GetDeviceTime_X3\n_dicData (返回数据的内容):\n@\"deviceTime\":@\"2023-12-12 09:36:44\"");
    }
    else if (infoType==1)
    {
        _myTextView.text = LocalForkey(@"设置自动测量   SetAutomaticHRMonitoring\n\n参数   MyAutomaticMonitoring_X3的结构体\nmode : 自动测量模式 0表示关闭  2表示在设定的时间内，间隔式测量\nstartTime_Hour : 自动测量的开始小时\nstartTime_Minutes : 自动测量的开始分钟\nendTime_Hour : 自动测量的结束小时\nendTime_Minutes : 自动测量的结束分钟\nweeks : 自动测量的星期\nintervalTime: 自动测量的时间间隔\ndataType : 自动测量的类型 1 means heartRate  2 means spo2  3 means temperature  4 means HRV，其他值无效\n\n调用方法\n\nNSMutableData * data = [[BleSDK_X3 sharedManager] SetAutomaticHRMonitoring:automaticMonitoring];\n\n[[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];\n\n返回结果\n_dataEnd (是否是最后一条返回数据) true\n_dataType (返回的数据类型) SetAutomaticMonitoring_X3\n_dicData (返回数据的内容) nil\n\n\n\n\n\n\n获取自动测量的设置   GetAutomaticMonitoringWithDataType\n\n参数   dataType 1 means heartRate  2 means spo2  3 means temperature  4 means HRV，其他值无效\n\n调用方法\n\nNSMutableData * data = [[BleSDK_X3 sharedManager] GetAutomaticMonitoringWithDataType:(int)_segDataType.selectedSegmentIndex+1];\n\n[[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];\n\n返回结果\n_dataEnd (是否是最后一条返回数据) true\n_dataType (返回的数据类型) GetAutomaticMonitoring_X3\n_dicData (返回数据的内容)\nstartTime : 14:04(测量的开始时间)\nendTime : 17:04(测量的结束时间)\ndataType : 1(数据类型 1 means heartRate  2 means spo2  3 means temperature  4 means HRV)\nintervalTime : 5(测量的时间间隔)\nweeks : 15(测量的星期 把这个数值转换成2个字节的2进制 0000 1111，从左往右依次代表周日->周六，最右边的那个值是无效值。1代表开启 0代表关闭)\nworkMode : 0(0表示关闭  2表示在设定的时间内，间隔式测量)");
    }
    else if (infoType==2)
    {
        _myTextView.text = LocalForkey(@"开启实时计步   RealTimeDataWithType\n\n参数   dataType \ndataType : 0表示关闭 ，1表示开启，其他值无效\n\n调用方法\n\nNSMutableData * data= [[BleSDK_X3 sharedManager] RealTimeDataWithType:1];\n\n[[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];\n\n返回结果\n_dataEnd (是否是最后一条返回数据,当有新的数据产生时，会继续返回) true\n_dataType (返回的数据类型) RealTimeStep_X3\n_dicData (返回数据的内容)\ndistance : 0.54(运动距离，单位是km)\ntime : 346(运动时间，单位是秒)\nstep : 806(运动步数)\ncalories : 23.84(运动消耗的卡路里，单位是kcal)\nStrengthTrainingTime : 2(强度运动时间，单位是秒)\nheartRate : 84(实时心率，只有在开启手动心率测量时，这个值才有效)\nspo2 : 95(实时血氧，只有在开启手动血氧测量时，这个值才有效)\ntemperature : 36.4(实时温度，如果设备是戒指，这个值可以忽略)\n\n\n\n\n开启或者关闭手动测量 manualMeasurementWithDataType:::\n参数\nMeasurementDataType_X3 : heartRateData_X3表示是心率测量，spo2Data_X3表示是血氧测量\nmeasurementTime : 测量的时间，单位是秒，默认是30秒\nisOpen : YES表示开启，NO表示关闭\n\n调用方法\n\nNSMutableData * data = [[BleSDK_X3 sharedManager] manualMeasurementWithDataType:heartRateData_X3 measurementTime:30 open:YES];\n\n[[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];\n\n返回结果\n_dataEnd (是否是最后一条返回数据) true\n_dataType (返回的数据类型) DeviceMeasurement_X3\n_dicData (返回数据的内容) nil\n注意 : 只有在实时计步处于开启状态下，手动测量才会有数据返回\n\n\n\n\n\n");
    }
    else if(infoType==3)
    {
        _myTextView.text = LocalForkey(@"获取总的运动数据   GetTotalActivityDataWithMode::\n\n参数\nmode\n0 : 当开始同步该数据的时候，mode必须填0\n2 : 当返回了50次该数据，但没有获取的结束标志时，需要将mode的值设为2，表示获取剩下的数据，以此类推，直到获取到结束标志为止。\n0x99 : 表示删除所有的该类型的存储数据\nstartDate : 表示获取这个时间之后的历史数据。注意 : 这个时间必须是历史数据存在的时间，如果历史数据不存在该时间，这个值将无效。第一次同步时，该值可以填nil\n\n调用方法 \n\nNSMutableData * data = [[BleSDK_X3 sharedManager] GetTotalActivityDataWithMode:0 withStartDate:[[MyDate sharedManager] dateFromString:@\"2022.04.10\" WithStringFormat:@\"YYYY.MM.dd\"]];\n\n [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];\n\n返回结果\n_dataEnd (是否是最后一条返回数据,YES表示不会会有新的数据返回,NO表示还会有新的数据产生) NO\n_dataType (返回的数据类型) TotalActivityData_X3\n_dicData key:arrayTotalActivityData(返回数据的内容,数据类型是字典的数组)\ndate : 2023.12.02\nstep : 123(当天的总步数)\ndistance : 1.23(单位是km，当天的运动距离)\ncalories : 34.2(单位是kcal，当天消耗的卡路里)\nexerciseMinutes : 12(当天的运动时间，单位是分钟)\nactiveMinutes : 当天的强度运动时间，单位是分钟\ngoal : 当天的步数目标达成率\n\n\n\n\n\n获取详细的运动数据   GetDetailActivityDataWithMode::\n\n参数\nmode\n0 : 当开始同步该数据的时候，mode必须填0\n2 : 当返回了50次该数据，但没有获取的结束标志时，需要将mode的值设为2，表示获取剩下的数据，以此类推，直到获取到结束标志为止。\n0x99 : 表示删除所有的该类型的存储数据\nstartDate : 表示获取这个时间之后的历史数据。注意 : 这个时间必须是历史数据存在的时间，如果历史数据不存在该时间，这个值将无效。第一次同步时，该值可以填nil\n\n调用方法 \n\nNSMutableData * data = [[BleSDK_X3 sharedManager] GetDetailActivityDataWithMode:0 withStartDate:[[MyDate sharedManager] dateFromString:@\"2022.04.10 12:23:59\" WithStringFormat:@\"YYYY.MM.dd HH:mm:ss\"]];\n\n [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];\n\n返回结果\n_dataEnd (是否是最后一条返回数据,YES表示不会会有新的数据返回,NO表示还会有新的数据产生) NO\n_dataType (返回的数据类型) DetailActivityData_X3\n_dicData  key:arrayDetailActivityData(返回数据的内容,数据类型是字典的数组)\narraySteps = (15,0, 0,0,0, 0,0,0,0,0)(10分钟内，每分钟的步数)\ncalories = 0.48(10分钟的卡路里消耗)\ndate = 2023.12.12 15:16:40\ndistance = 0.01(10分钟的距离)\nstep = 15(10分钟的总步数)\n\n\n\n\n获取运动模式的历史数据   GetActivityModeDataWithMode::\n\n参数\nmode\n0 : 当开始同步该数据的时候，mode必须填0\n2 : 当返回了50次该数据，但没有获取的结束标志时，需要将mode的值设为2，表示获取剩下的数据，以此类推，直到获取到结束标志为止。\n0x99 : 表示删除所有的该类型的存储数据\nstartDate : 表示获取这个时间之后的历史数据。注意 : 这个时间必须是历史数据存在的时间，如果历史数据不存在该时间，这个值将无效。第一次同步时，该值可以填nil\n\n调用方法 \n\nNSMutableData * data = [[BleSDK_X3 sharedManager] GetActivityModeDataWithMode:0 withStartDate:[[MyDate sharedManager] dateFromString:@\"2022.04.10 12:23:59\" WithStringFormat:@\"YYYY.MM.dd HH:mm:ss\"]];\n\n [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];\n\n返回结果\n_dataEnd (是否是最后一条返回数据,YES表示不会会有新的数据返回,NO表示还会有新的数据产生) YES\n_dataType (返回的数据类型) ActivityModeData_X3\n_dicData  key:arrayActivityModeData(返回数据的内容,数据类型是字典的数组)\nactiveMinutes = 138(运动时间，单位是秒)\nactivityMode = 8(运动类型)\ncalories = 11(运动的卡路里消耗)\ndate = \"2023.12.13 10:53:34\"(运动的开始时间)\ndistance = 0(运动距离，单位是km)\nheartRate = 101(运动的平均心率)\npaceMinutes = 0(运动的配速分钟)\npaceSeconds = 0(运动的配速秒)\nstep = 0(运动的总步数)");
    }
    else if (infoType==4)
    {
        _myTextView.text = LocalForkey(@"获取详细的睡眠数据   GetDetailSleepDataWithMode::\n\n参数\nmode\n0 : 当开始同步该数据的时候，mode必须填0\n2 : 当返回了50次该数据，但没有获取的结束标志时，需要将mode的值设为2，表示获取剩下的数据，以此类推，直到获取到结束标志为止。\n0x99 : 表示删除所有的该类型的存储数据\nstartDate : 表示获取这个时间之后的历史数据。注意 : 这个时间必须是历史数据存在的时间，如果历史数据不存在该时间，这个值将无效。第一次同步时，该值可以填nil\n\n调用方法 \n\nNSMutableData * data = [[BleSDK_X3 sharedManager] GetDetailSleepDataWithMode:0 withStartDate:[[MyDate sharedManager] dateFromString:@\"2022.04.10\" WithStringFormat:@\"YYYY.MM.dd\"]];\n\n [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];\n\n返回结果\n_dataEnd (是否是最后一条返回数据,YES表示不会会有新的数据返回,NO表示还会有新的数据产生) NO\n_dataType (返回的数据类型) DetailSleepData_X3\n_dicData key:arrayDetailSleepData(返回数据的内容,数据类型是字典的数组)\narraySleepQuality = (5,5,5,5,5,5,5,5,5,5,5,5,5,5,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2)(每分钟的睡眠质量，1代表深睡 2代表浅睡 3代表REM 其他代表清醒)\nsleepUnitLength = 1(一分钟监测一次睡眠质量)\n\"startTime_SleepData\" = \"2023.11.06 12:45:01\"(这段睡眠的开始时间)\ntotalSleepTime = 50(这段睡眠的持续时长)");
    }
    else if (infoType==5)
    {
        _myTextView.text = LocalForkey(@"获取连续的心率数据   GetContinuousHRDataWithMode::\n\n参数\nmode\n0 : 当开始同步该数据的时候，mode必须填0\n2 : 当返回了50次该数据，但没有获取的结束标志时，需要将mode的值设为2，表示获取剩下的数据，以此类推，直到获取到结束标志为止。\n0x99 : 表示删除所有的该类型的存储数据\nstartDate : 表示获取这个时间之后的历史数据。注意 : 这个时间必须是历史数据存在的时间，如果历史数据不存在该时间，这个值将无效。第一次同步时，该值可以填nil\n\n调用方法 \n\nNSMutableData * data = [[BleSDK_X3 sharedManager] GetContinuousHRDataWithMode:0 withStartDate:[[MyDate sharedManager] dateFromString:@\"2022.04.10 12:23:58\" WithStringFormat:@\"YYYY.MM.dd\"]];\n\n [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];\n\n返回结果\n_dataEnd (是否是最后一条返回数据,YES表示不会会有新的数据返回,NO表示还会有新的数据产生) NO\n_dataType (返回的数据类型) DynamicHR_X3\n_dicData key:arrayContinuousHR(返回数据的内容,数据类型是字典的数组)\narrayHR = (83,89,86,86,86,81,88,86,84,85,86,84,87,86,86)(15分钟的心率，每个值代表一分钟的平均心率)\ndate = \"2023.12.11 17:25:59\"(这段心率的开始时间)\n\n\n\n\n\n获取单次的心率数据   GetSingleHRDataWithMode::\n\n参数\nmode\n0 : 当开始同步该数据的时候，mode必须填0\n2 : 当返回了50次该数据，但没有获取的结束标志时，需要将mode的值设为2，表示获取剩下的数据，以此类推，直到获取到结束标志为止。\n0x99 : 表示删除所有的该类型的存储数据\nstartDate : 表示获取这个时间之后的历史数据。注意 : 这个时间必须是历史数据存在的时间，如果历史数据不存在该时间，这个值将无效。第一次同步时，该值可以填nil\n\n调用方法 \n\nNSMutableData * data = [[BleSDK_X3 sharedManager] GetSingleHRDataWithMode:0 withStartDate:[[MyDate sharedManager] dateFromString:@\"2022.04.10\" WithStringFormat:@\"YYYY.MM.dd\"]];\n\n [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];\n\n返回结果\n_dataEnd (是否是最后一条返回数据,YES表示不会会有新的数据返回,NO表示还会有新的数据产生) NO\n_dataType (返回的数据类型) StaticHR_X3\n_dicData key:arraySingleHR(返回数据的内容,数据类型是字典的数组)\ndate = \"2023.12.12 13:45:30\"(心率存储的时间点)\nsingleHR = 83(具体的心率值)");
    }
    else if (infoType==6)
    {
        _myTextView.text = LocalForkey(@"获取戒指的温度数据   GetTemperatureDataWithMode::\n\n参数\nmode\n0 : 当开始同步该数据的时候，mode必须填0\n2 : 当返回了50次该数据，但没有获取的结束标志时，需要将mode的值设为2，表示获取剩下的数据，以此类推，直到获取到结束标志为止。\n0x99 : 表示删除所有的该类型的存储数据\nstartDate : 表示获取这个时间之后的历史数据。注意 : 这个时间必须是历史数据存在的时间，如果历史数据不存在该时间，这个值将无效。第一次同步时，该值可以填nil\n\n调用方法 \n\nNSMutableData * data = [[BleSDK_X3 sharedManager] GetTemperatureDataWithMode:0 withStartDate:[[MyDate sharedManager] dateFromString:@\"2022.04.10 08:23:59\" WithStringFormat:@\"YYYY.MM.dd HH:mm:ss\"]];\n\n [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];\n\n返回结果\n_dataEnd (是否是最后一条返回数据,YES表示不会会有新的数据返回,NO表示还会有新的数据产生) NO\n_dataType (返回的数据类型) TemperatureData_X3\n_dicData key:arrayemperatureData(返回数据的内容,数据类型是字典的数组)\ndate = \"2023.12.12 13:45:30\"(温度存储的时间点)\ntemperature = 29.1(戒指的温度，单位是℃)");
    }
    else if (infoType==7)
    {
        _myTextView.text = LocalForkey(@"获取戒指自动测量的Spo2历史数据   GetAutomaticSpo2DataWithMode::\n\n参数\nmode\n0 : 当开始同步该数据的时候，mode必须填0\n2 : 当返回了50次该数据，但没有获取的结束标志时，需要将mode的值设为2，表示获取剩下的数据，以此类推，直到获取到结束标志为止。\n0x99 : 表示删除所有的该类型的存储数据\nstartDate : 表示获取这个时间之后的历史数据。注意 : 这个时间必须是历史数据存在的时间，如果历史数据不存在该时间，这个值将无效。第一次同步时，该值可以填nil\n\n调用方法 \n\nNSMutableData * data = [[BleSDK_X3 sharedManager] GetAutomaticSpo2DataWithMode:0 withStartDate:[[MyDate sharedManager] dateFromString:@\"2022.04.10 08:23:59\" WithStringFormat:@\"YYYY.MM.dd HH:mm:ss\"]];\n\n [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];\n\n返回结果\n_dataEnd (是否是最后一条返回数据,YES表示不会会有新的数据返回,NO表示还会有新的数据产生) NO\n_dataType (返回的数据类型) AutomaticSpo2Data_X3\n_dicData key:arrayAutomaticSpo2Data(返回数据的内容,数据类型是字典的数组)\ndate = \"2023.12.12 13:45:30\"(温度存储的时间点)\nautomaticSpo2Data = 98(血氧浓度)");
    }
    else if (infoType==8)
    {
        _myTextView.text = LocalForkey(@"获取戒指自动测量的HRV历史数据   GetHRVDataWithMode::\n\n参数\nmode\n0 : 当开始同步该数据的时候，mode必须填0\n2 : 当返回了50次该数据，但没有获取的结束标志时，需要将mode的值设为2，表示获取剩下的数据，以此类推，直到获取到结束标志为止。\n0x99 : 表示删除所有的该类型的存储数据\nstartDate : 表示获取这个时间之后的历史数据。注意 : 这个时间必须是历史数据存在的时间，如果历史数据不存在该时间，这个值将无效。第一次同步时，该值可以填nil\n\n调用方法 \n\nNSMutableData * data = [[BleSDK_X3 sharedManager] GetHRVDataWithMode:0 withStartDate:[[MyDate sharedManager] dateFromString:@\"2022.04.10 08:23:59\" WithStringFormat:@\"YYYY.MM.dd HH:mm:ss\"]];\n\n [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];\n\n返回结果\n_dataEnd (是否是最后一条返回数据,YES表示不会会有新的数据返回,NO表示还会有新的数据产生) NO\n_dataType (返回的数据类型) HRVData_X3\n_dicData key:arrayAutomaticSpo2Data(返回数据的内容,数据类型是字典的数组)\ndate = \"2023.12.12 13:45:30\"(HRV存储的时间点)\ndiastolicBP = 60(舒张压，没有做血压校准，可以忽略)\nheartRate = 85(心率值)\nhrv = 109(HRV)\nstress = 30(压力值)\nsystolicBP = 115(收缩压，没有做血压校准，可以忽略)\nvascularAging = 0(血管老化度，可以忽略)");
    }
    else if (infoType==9)
    {
        _myTextView.text = LocalForkey(@"开启运动模式   startActivityMode::\n\n参数\nactivityMode : 运动模式\nworkMode : 1表示开启运动模式，2表示暂停运动模式，3表示继续运动模式，4表示停止运动模式\nactivityTime : 运动时间，单位是分钟\nbreathParameter : 呼吸参数，只有运动模式是呼吸时，这个参数才会起作用 \n\n调用方法 \n\nNSMutableData * data = [[BleSDK_X3 sharedManager] startActivityMode:activityType WorkMode:continueActivity ActivityTime:continueActivity BreathParameter:breathParameter];\n\n[[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];");
    }
}


- (IBAction)back:(UIButton *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}


@end
