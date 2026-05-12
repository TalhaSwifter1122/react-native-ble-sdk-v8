//
//  deviceTime.m
//  Ble SDK Demo
//
//  Created by yang sai on 2022/4/19.
//

#import "deviceTime.h"
#import "infoView.h"
@interface deviceTime ()<MyBleDelegate>
@property (weak, nonatomic) IBOutlet UIDatePicker *myDatePicker;

@property (weak, nonatomic) IBOutlet UIButton *btnSetDeviceTime;
@property (weak, nonatomic) IBOutlet UIButton *btnGetDeviceTime;

@property (weak, nonatomic) IBOutlet UILabel *labTitle;
@end

@implementation deviceTime

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [NewBle sharedManager].delegate = self;
    
    
    
    
    _btnSetDeviceTime.layer.cornerRadius  = 10 * Proportion;
    _btnGetDeviceTime.layer.cornerRadius  = 10 * Proportion;
    [_btnSetDeviceTime setTitle:LocalForkey(@"设置设备时间") forState:UIControlStateNormal];
    [_btnGetDeviceTime setTitle:LocalForkey(@"获取设备时间") forState:UIControlStateNormal];
    [_labTitle mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.top.mas_equalTo(self.view.mas_top).offset(120*Proportion);
        make.width.mas_equalTo(200*Proportion);
        make.height.mas_equalTo(40*Proportion);
    }];
    
    [_myDatePicker mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.top.mas_equalTo(self.view.mas_top).offset(220*Proportion);
        make.width.mas_equalTo(Width);
        make.height.mas_equalTo(160*Proportion);
    }];
    
    [_btnSetDeviceTime mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(self.view.mas_left).offset(20*Proportion);
        make.top.mas_equalTo(_myDatePicker.mas_bottom).offset(20*Proportion);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    
    [_btnGetDeviceTime mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.right.mas_equalTo(self.view.mas_right).offset(-20*Proportion);
        make.centerY.mas_equalTo(_btnSetDeviceTime.mas_centerY);
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
    if(deviceData.dataType == SetDeviceTime_X3)
    {
        [PishumToast showToastWithMessage:LocalForkey(@"设置设备时间成功") Length:TOAST_SHORT ParentView:self.view];
    }
    else if (deviceData.dataType == GetDeviceTime_X3)
    {
        NSString * strDeviceTime = deviceData.dicData[@"deviceTime"];
        NSDate * deviceDate = [[MyDate sharedManager] dateFromString:strDeviceTime WithStringFormat:@"YYYY-MM-dd HH:mm:ss"];
        _myDatePicker.date = deviceDate;
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






- (IBAction)setDeviceTime:(UIButton *)sender {
    
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        NSDate * sendDate =  _myDatePicker.date;
        NSCalendar * cal = [NSCalendar currentCalendar];
        NSUInteger unitFlags = NSCalendarUnitDay|NSCalendarUnitMonth|NSCalendarUnitYear|NSCalendarUnitWeekday|NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond;
        NSDateComponents * conponent = [cal components:unitFlags fromDate:sendDate];
        MyDeviceTime_X3 deviceTime;
        deviceTime.year  = (int)[conponent year];
        deviceTime.month = (int)[conponent month];
        deviceTime.day = (int)[conponent day];
        deviceTime.hour = (int)[conponent hour];
        deviceTime.minute = (int)[conponent minute];
        deviceTime.second = (int)[conponent second];
        NSMutableData * data = [[BleSDK_X3 sharedManager] SetDeviceTime:deviceTime];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
    
    
    
}

- (IBAction)getDeviceTime:(UIButton *)sender {
    
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        NSMutableData * data = [[BleSDK_X3 sharedManager] GetDeviceTime];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
}


- (IBAction)showInfo:(UIButton *)sender {
    
    infoView * myInfoView = [[infoView alloc] init];
    myInfoView.infoType = 0;
    [self.navigationController pushViewController:myInfoView animated:YES];
}


- (IBAction)back:(UIButton *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}
@end
