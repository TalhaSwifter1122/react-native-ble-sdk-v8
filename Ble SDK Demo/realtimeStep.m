//
//  realtimeStep.m
//  Ble SDK Demo
//
//  Created by yang sai on 2022/4/21.
//

#import "realtimeStep.h"
#import "infoView.h"
@interface realtimeStep ()<MyBleDelegate>
{
    int distanceUnit;
    int temperatureUnit;
    
    BOOL isStep;
    BOOL isStartSpo2;
    BOOL isStartHeartRate;
    
}
@property (weak, nonatomic) IBOutlet UILabel *labTitle;
@property (weak, nonatomic) IBOutlet UILabel *labStepName;
@property (weak, nonatomic) IBOutlet UILabel *labStepValue;
@property (weak, nonatomic) IBOutlet UILabel *labStepUnit;
@property (weak, nonatomic) IBOutlet UILabel *labCaloriesName;
@property (weak, nonatomic) IBOutlet UILabel *labCaloriesValue;
@property (weak, nonatomic) IBOutlet UILabel *labCaloriesUnit;
@property (weak, nonatomic) IBOutlet UILabel *labDistanceName;
@property (weak, nonatomic) IBOutlet UILabel *labDistanceValue;
@property (weak, nonatomic) IBOutlet UILabel *labDistanceUnit;
@property (weak, nonatomic) IBOutlet UILabel *labExerciseMinutesName;
@property (weak, nonatomic) IBOutlet UILabel *labExerciseMinutesValue;
@property (weak, nonatomic) IBOutlet UILabel *labExerciseMinutesUnit;
@property (weak, nonatomic) IBOutlet UILabel *labActiveMinutesName;
@property (weak, nonatomic) IBOutlet UILabel *labActiveMinutesValue;
@property (weak, nonatomic) IBOutlet UILabel *labActiveMinutesUnit;
@property (weak, nonatomic) IBOutlet UILabel *labHRName;
@property (weak, nonatomic) IBOutlet UILabel *labHRValue;
@property (weak, nonatomic) IBOutlet UILabel *labHRUnit;
@property (weak, nonatomic) IBOutlet UILabel *labSpo2Name;
@property (weak, nonatomic) IBOutlet UILabel *labSpo2Value;
@property (weak, nonatomic) IBOutlet UILabel *labSpo2Unit;
@property (weak, nonatomic) IBOutlet UIButton *btnStartRealtimeStep;
@property (weak, nonatomic) IBOutlet UIButton *btnStartSpo2;
@property (weak, nonatomic) IBOutlet UIButton *btnStartHeartRate;

@end

@implementation realtimeStep

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [NewBle sharedManager].delegate = self;
    [self myMasonry];
}



-(void)myMasonry
{
    
    _labTitle.text  = LocalForkey(@"实时计步");
    _labStepName.text = LocalForkey(@"步数");
    _labCaloriesName.text = LocalForkey(@"卡路里");
    _labDistanceName.text = LocalForkey(@"距离");
    _labExerciseMinutesName.text = LocalForkey(@"运动时间");
    _labActiveMinutesName.text = LocalForkey(@"强度运动时间");
    _labHRName.text = LocalForkey(@"心率");
    _labSpo2Name.text = LocalForkey(@"血氧");
    _labCaloriesUnit.text = LocalForkey(@"千卡");
    _labDistanceUnit.text = LocalForkey(@"千米");
    _labExerciseMinutesUnit.text = LocalForkey(@"分钟");
    _labActiveMinutesUnit.text = LocalForkey(@"分钟");
    _labStepUnit.text = LocalForkey(@"步");
    [_btnStartRealtimeStep setTitle:LocalForkey(@"开启实时计步") forState:UIControlStateNormal];
    [_btnStartSpo2 setTitle:LocalForkey(@"开启实时血氧") forState:UIControlStateNormal];
    [_btnStartHeartRate setTitle:LocalForkey(@"开启心率测量") forState:UIControlStateNormal];
    [_btnStartSpo2 setTitle:LocalForkey(@"开启血氧测量") forState:UIControlStateNormal];
    _btnStartSpo2.layer.cornerRadius  = 10 * Proportion;
    _btnStartHeartRate.layer.cornerRadius  = 10 * Proportion;
    _btnStartRealtimeStep.layer.cornerRadius  = 10 * Proportion;
    [_labStepName mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(self.view.mas_left).offset(40*Proportion);
        make.top.mas_equalTo(self.view.mas_top).offset(100*Proportion);
        make.width.mas_equalTo(150*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];
    [_labStepValue mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(_labStepName.mas_right).offset(16*Proportion);
        make.centerY.mas_equalTo(_labStepName.mas_centerY);
        make.width.mas_equalTo(77*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];
    [_labStepUnit mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(_labStepValue.mas_right).offset(8*Proportion);
        make.centerY.mas_equalTo(_labStepName.mas_centerY);
        make.width.mas_equalTo(77*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];
    
    [_labCaloriesName mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStepName.mas_centerX);
        make.top.mas_equalTo(_labStepName.mas_bottom).offset(10*Proportion);
        make.width.mas_equalTo(150*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];
    [_labCaloriesValue mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStepValue.mas_centerX);
        make.centerY.mas_equalTo(_labCaloriesName.mas_centerY);
        make.width.mas_equalTo(77*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];
    [_labCaloriesUnit mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStepUnit.mas_centerX);
        make.centerY.mas_equalTo(_labCaloriesName.mas_centerY);
        make.width.mas_equalTo(77*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];
    
    
    [_labDistanceName mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStepName.mas_centerX);
        make.top.mas_equalTo(_labCaloriesName.mas_bottom).offset(10*Proportion);
        make.width.mas_equalTo(150*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];
    [_labDistanceValue mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStepValue.mas_centerX);
        make.centerY.mas_equalTo(_labDistanceName.mas_centerY);
        make.width.mas_equalTo(77*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];
    [_labDistanceUnit mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStepUnit.mas_centerX);
        make.centerY.mas_equalTo(_labDistanceName.mas_centerY);
        make.width.mas_equalTo(77*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];

    [_labExerciseMinutesName mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStepName.mas_centerX);
        make.top.mas_equalTo(_labDistanceName.mas_bottom).offset(10*Proportion);
        make.width.mas_equalTo(150*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];
    [_labExerciseMinutesValue mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStepValue.mas_centerX);
        make.centerY.mas_equalTo(_labExerciseMinutesName.mas_centerY);
        make.width.mas_equalTo(77*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];
    [_labExerciseMinutesUnit mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStepUnit.mas_centerX);
        make.centerY.mas_equalTo(_labExerciseMinutesName.mas_centerY);
        make.width.mas_equalTo(77*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];

    [_labActiveMinutesName mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStepName.mas_centerX);
        make.top.mas_equalTo(_labExerciseMinutesName.mas_bottom).offset(10*Proportion);
        make.width.mas_equalTo(150*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];
    [_labActiveMinutesValue mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStepValue.mas_centerX);
        make.centerY.mas_equalTo(_labActiveMinutesName.mas_centerY);
        make.width.mas_equalTo(77*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];
    [_labActiveMinutesUnit mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStepUnit.mas_centerX);
        make.centerY.mas_equalTo(_labActiveMinutesName.mas_centerY);
        make.width.mas_equalTo(77*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];

    [_labHRName mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStepName.mas_centerX);
        make.top.mas_equalTo(_labActiveMinutesName.mas_bottom).offset(10*Proportion);
        make.width.mas_equalTo(150*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];
    [_labHRValue mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStepValue.mas_centerX);
        make.centerY.mas_equalTo(_labHRName.mas_centerY);
        make.width.mas_equalTo(77*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];
    [_labHRUnit mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStepUnit.mas_centerX);
        make.centerY.mas_equalTo(_labHRName.mas_centerY);
        make.width.mas_equalTo(77*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];

    [_labSpo2Name mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStepName.mas_centerX);
        make.top.mas_equalTo(_labHRName.mas_bottom).offset(10*Proportion);
        make.width.mas_equalTo(150*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];
    [_labSpo2Value mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStepValue.mas_centerX);
        make.centerY.mas_equalTo(_labSpo2Name.mas_centerY);
        make.width.mas_equalTo(77*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];
    [_labSpo2Unit mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStepUnit.mas_centerX);
        make.centerY.mas_equalTo(_labSpo2Name.mas_centerY);
        make.width.mas_equalTo(77*Proportion);
        make.height.mas_equalTo(30*Proportion);
    }];
    
    
    [_btnStartRealtimeStep mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(self.view.mas_left).offset(20*Proportion);
        make.top.mas_equalTo(self.view.mas_top).offset(430*Proportion);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    [_btnStartSpo2 mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.right.mas_equalTo(self.view.mas_right).offset(-20*Proportion);
        make.top.mas_equalTo(self.view.mas_top).offset(430*Proportion);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    [_btnStartHeartRate mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_btnStartRealtimeStep.mas_centerX);
        make.top.mas_equalTo(_btnStartRealtimeStep.mas_bottom).offset(10*Proportion);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
}


#pragma mark MyBleDelegate
-(void)ConnectSuccessfully
{
    
}
-(void)Disconnect:(NSError *_Nullable)error
{
    [PishumToast showToastWithMessage:LocalForkey(@"设备断开连接") Length:TOAST_SHORT ParentView:self.view];
}
-(void)scanWithPeripheral:(CBPeripheral*_Nonnull)peripheral advertisementData:(NSDictionary<NSString *, id> *_Nonnull)advertisementData RSSI:(NSNumber *_Nonnull)RSSI
{
    
}
-(void)ConnectFailedWithError:(nullable NSError *)error
{
    
}
-(void)EnableCommunicate
{
    
}

-(void)BleCommunicateWithPeripheral:(CBPeripheral*)Peripheral data:(NSData *)data
{
    DeviceData_X3 * deviceData = [[DeviceData_X3 alloc] init];
    deviceData  = [[BleSDK_X3 sharedManager] DataParsingWithData:data];
    if(deviceData.dataType == RealTimeStep_X3)
    {
        NSDictionary * dicData = deviceData.dicData;
        /*  NSDictionary * dicData = @{@"step":@(step),@"calories":@(calories*0.01),@"distance":@(distance*0.01),@"time":@(time),@"StrengthTrainingTime":@(StrengthTrainingTime),@"heartRate":@(heartRate),@"temperature":@(temperature*0.1),@"spo2":@(spo2)};*/
        _labStepValue.text = [NSString stringWithFormat:@"%@",dicData[@"step"]];
        _labCaloriesValue.text = [NSString stringWithFormat:@"%@",dicData[@"calories"]];
        NSNumber * numberDistance = dicData[@"distance"];
        _labDistanceValue.text = [NSString stringWithFormat:@"%@",numberDistance];
        _labExerciseMinutesValue.text = [NSString stringWithFormat:@"%@",dicData[@"time"]];
        _labActiveMinutesValue.text = [NSString stringWithFormat:@"%@",dicData[@"StrengthTrainingTime"]];
        _labHRValue.text = [NSString stringWithFormat:@"%@",dicData[@"heartRate"]];
        NSNumber * numberSpo2 = dicData[@"spo2"];
        _labSpo2Value.text = [NSString stringWithFormat:@"%@",numberSpo2];
        
        
    }
    else if (deviceData.dataType == FindMobilePhone_X3)
    {
        [PishumToast showToastWithMessage:LocalForkey(@"正在查找手机") Length:TOAST_SHORT ParentView:self.view];
    }
    else if (deviceData.dataType == SOS_X3)
    {
        [PishumToast showToastWithMessage:LocalForkey(@"正在发送SOS") Length:TOAST_SHORT ParentView:self.view];
    }

    
   
    
}


- (IBAction)startRealtimeStep:(UIButton *)sender {
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        NSMutableData * data;
        if(isStep==NO)
        {
            isStep = YES;
            [sender setTitle:LocalForkey(@"关闭实时计步") forState:UIControlStateNormal];
            data= [[BleSDK_X3 sharedManager] RealTimeDataWithType:1];
        }
        else
        {
            isStep = NO;
            [sender setTitle:LocalForkey(@"开启实时计步") forState:UIControlStateNormal];
            data= [[BleSDK_X3 sharedManager] RealTimeDataWithType:0];
        }
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
}

- (IBAction)startSpo2:(UIButton *)sender {
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        NSMutableData * data;
        if(isStartSpo2==NO)
        {
            isStartSpo2 = YES;
            [sender setTitle:LocalForkey(@"关闭血氧测量") forState:UIControlStateNormal];
            data= [[BleSDK_X3 sharedManager] manualMeasurementWithDataType:spo2Data_X3 measurementTime:30 open:YES];
        }
        else
        {
            isStartSpo2 = NO;
            [sender setTitle:LocalForkey(@"开启血氧测量") forState:UIControlStateNormal];
            data= [[BleSDK_X3 sharedManager] manualMeasurementWithDataType:spo2Data_X3 measurementTime:30 open:NO];
        }
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
}


- (IBAction)startHeartRate:(UIButton *)sender {
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        NSMutableData * data;
        if(isStartHeartRate==NO)
        {
            isStartHeartRate = YES;
            [sender setTitle:LocalForkey(@"关闭心率测量") forState:UIControlStateNormal];
            data= [[BleSDK_X3 sharedManager] manualMeasurementWithDataType:heartRateData_X3 measurementTime:30 open:YES];
        }
        else
        {
            isStartHeartRate = NO;
            [sender setTitle:LocalForkey(@"开启心率测量") forState:UIControlStateNormal];
            data= [[BleSDK_X3 sharedManager] manualMeasurementWithDataType:heartRateData_X3 measurementTime:30 open:NO];
        }
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
}


- (IBAction)showInfo:(UIButton *)sender {
    
    infoView * myInfoView = [[infoView alloc] init];
    myInfoView.infoType = 2;
    [self.navigationController pushViewController:myInfoView animated:YES];
}


- (IBAction)back:(UIButton *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}
@end
