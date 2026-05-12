//
//  otherDeviceInfo.m
//  Ble SDK Demo
//
//  Created by yang sai on 2022/4/21.
//

#import "otherDeviceInfo.h"

@interface otherDeviceInfo ()<MyBleDelegate>

@property (weak, nonatomic) IBOutlet UILabel *labContent;
@property (weak, nonatomic) IBOutlet UIButton *btnGetDevicebattery;
@property (weak, nonatomic) IBOutlet UIButton *btnGetDeviceMacAddress;
@property (weak, nonatomic) IBOutlet UIButton *btnGetVersion;
@property (weak, nonatomic) IBOutlet UIButton *btnReset;
@property (weak, nonatomic) IBOutlet UIButton *btnMCUReset;
@end

@implementation otherDeviceInfo

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [NewBle sharedManager].delegate = self;
    [self myMasonry];
}

-(void)myMasonry
{
    
    [_btnGetDevicebattery setTitle:LocalForkey(@"获取设备电量") forState:UIControlStateNormal];
    [_btnGetDeviceMacAddress setTitle:LocalForkey(@"获取设备MAC地址") forState:UIControlStateNormal];
    [_btnGetVersion setTitle:LocalForkey(@"获取设备版本") forState:UIControlStateNormal];
    [_btnReset setTitle:LocalForkey(@"恢复出厂设置") forState:UIControlStateNormal];
    [_btnMCUReset setTitle:LocalForkey(@"重启设备") forState:UIControlStateNormal];
    _btnReset.layer.cornerRadius  = 10 * Proportion;
    _btnMCUReset.layer.cornerRadius = 10 * Proportion;
    _btnGetVersion.layer.cornerRadius = 10 * Proportion;
    _btnGetDevicebattery.layer.cornerRadius = 10 * Proportion;
    _btnGetDeviceMacAddress.layer.cornerRadius = 10 * Proportion;
    
    [_labContent mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.top.mas_equalTo(self.view.mas_top).offset(110*Proportion);
        make.width.mas_equalTo(320*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    [_btnGetDevicebattery mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(self.view.mas_left).offset(20*Proportion);
        make.top.mas_equalTo(_labContent.mas_bottom).offset(10*Proportion);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    [_btnGetDeviceMacAddress mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.right.mas_equalTo(self.view.mas_right).offset(-20*Proportion);
        make.centerY.mas_equalTo(_btnGetDevicebattery.mas_centerY);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    [_btnGetVersion mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_btnGetDevicebattery.mas_centerX);
        make.top.mas_equalTo(_btnGetDevicebattery.mas_bottom).offset(10*Proportion);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    [_btnReset mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_btnGetDeviceMacAddress.mas_centerX);
        make.centerY.mas_equalTo(_btnGetVersion.mas_centerY);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    [_btnMCUReset mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_btnGetDevicebattery.mas_centerX);
        make.top.mas_equalTo(_btnGetVersion.mas_bottom).offset(10*Proportion);
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
    NSDictionary * dicData = deviceData.dicData;
    if(deviceData.dataType == GetDeviceBattery_X3)
    {
        _labContent.text = [NSString stringWithFormat:@"Device Battery\n%@%%",dicData[@"batteryLevel"]];
    }
    else if (deviceData.dataType == GetDeviceMacAddress_X3)
    {
        _labContent.text = [NSString stringWithFormat:@"macAddress\n%@",dicData[@"macAddress"]];
    }
    else if (deviceData.dataType == GetDeviceVersion_X3)
    {
        _labContent.text = [NSString stringWithFormat:@"Device Version\n%@",dicData[@"deviceVersion"]];
    }
    else if (deviceData.dataType == FactoryReset_X3)
    {
        [PishumToast showToastWithMessage:LocalForkey(@"恢复出厂设置成功!") Length:TOAST_SHORT ParentView:self.view];
    }
    else if (deviceData.dataType == MCUReset_X3)
    {
        [PishumToast showToastWithMessage:LocalForkey(@"重启设备成功!") Length:TOAST_SHORT ParentView:self.view];
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


- (IBAction)getDeviceBattery:(UIButton *)sender {
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        NSMutableData * data = [[BleSDK_X3 sharedManager] GetDeviceBatteryLevel];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
}

- (IBAction)getDeviceMacAddress:(UIButton *)sender {
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        NSMutableData * data = [[BleSDK_X3 sharedManager] GetDeviceMacAddress];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
}

- (IBAction)getDeviceVersion:(UIButton *)sender {
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        NSMutableData * data = [[BleSDK_X3 sharedManager] GetDeviceVersion];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
}
- (IBAction)factoryReset:(UIButton *)sender {
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        NSMutableData * data = [[BleSDK_X3 sharedManager] Reset];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
}

- (IBAction)MCUReset:(UIButton *)sender {
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        NSMutableData * data = [[BleSDK_X3 sharedManager] MCUReset];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
}
- (IBAction)back:(UIButton *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}


@end
