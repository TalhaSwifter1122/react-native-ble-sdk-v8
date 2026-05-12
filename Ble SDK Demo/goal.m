//
//  goal.m
//  Ble SDK Demo
//
//  Created by yang sai on 2022/4/21.
//

#import "goal.h"

@interface goal ()<MyBleDelegate,UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UILabel *labTitle;
@property (weak, nonatomic) IBOutlet UITextField *textFieldGoal;
@property (weak, nonatomic) IBOutlet UIButton *btnSetGoal;
@property (weak, nonatomic) IBOutlet UIButton *btnGetGoal;
@end

@implementation goal

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [NewBle sharedManager].delegate = self;
    [self myMasonry];
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
    DeviceData_X3 *  deviceData = [[DeviceData_X3 alloc] init];
    deviceData  = [[BleSDK_X3 sharedManager] DataParsingWithData:data];
    if(deviceData.dataType == SetDeviceGoal_X3)
    {
        [PishumToast showToastWithMessage:LocalForkey(@"设置目标成功") Length:TOAST_SHORT ParentView:self.view];
    }
    else if (deviceData.dataType == GetDeviceGoal_X3)
    {
        NSDictionary * dicData = deviceData.dicData;
        NSNumber * goal = dicData[@"stepGoal"];
        _textFieldGoal.text = [NSString stringWithFormat:@"%@",goal];
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






-(void)myMasonry
{
    _labTitle.text = LocalForkey(@"目标");
    _textFieldGoal.placeholder = LocalForkey(@"目标");
    [_btnSetGoal setTitle:LocalForkey(@"设置目标") forState:UIControlStateNormal];
    [_btnGetGoal setTitle:LocalForkey(@"获取目标") forState:UIControlStateNormal];
    _btnGetGoal.layer.cornerRadius = 10 * Proportion;
    _btnSetGoal.layer.cornerRadius = 10 * Proportion;
    
    
    [_textFieldGoal mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.top.mas_equalTo(self.view.mas_top).offset(160*Proportion);
        make.width.mas_equalTo(200*Proportion);
        make.height.mas_equalTo(40*Proportion);
    }];
    
    [_btnSetGoal mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(self.view.mas_left).offset(20*Proportion);
        make.bottom.mas_equalTo(self.view.mas_bottom).offset(-80*Proportion);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    
    [_btnGetGoal mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.right.mas_equalTo(self.view.mas_right).offset(-20*Proportion);
        make.centerY.mas_equalTo(_btnSetGoal.mas_centerY);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    
}


#pragma mark UITextFieldDelegate

- (BOOL)textField:(UITextField*)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString*)string
{
    //
    NSString *blank = [[string componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsJoinedByString:@""];
    if(![string isEqualToString:blank]) {
        return NO;
    }
    //密码长度限制

        if (range.length == 1 && string.length == 0) {
            return YES;
        }  else if (textField.text.length >= 12) {
            
            textField.text = [textField.text substringToIndex:12];
            return NO;
        }
   
    //只能是数字和英文
    NSCharacterSet * cs = [[NSCharacterSet characterSetWithCharactersInString:DEVICE_ID] invertedSet];
    NSString *filtered = [[string componentsSeparatedByCharactersInSet:cs] componentsJoinedByString:@""];
    return [string isEqualToString:filtered];
    
    
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return  YES;
}

- (IBAction)setGoal:(UIButton *)sender {
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        int stepGoal = _textFieldGoal.text.intValue;
        if(stepGoal>0){
            NSMutableData * data = [[BleSDK_X3 sharedManager] SetStepGoal:stepGoal];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
        }
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
    
}

- (IBAction)getGoal:(UIButton *)sender {
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        NSMutableData * data = [[BleSDK_X3 sharedManager] GetStepGoal];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
}
- (IBAction)back:(UIButton *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}
@end
