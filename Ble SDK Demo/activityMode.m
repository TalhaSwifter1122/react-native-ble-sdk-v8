//
//  activityMode.m
//  Ble SDK Demo
//
//  Created by yang sai on 2022/4/22.
//

#import "activityMode.h"
#import "infoView.h"
@interface activityMode ()<MyBleDelegate>
{
    NSArray * arrayActivityType;
    int activityType;
}
@property (weak, nonatomic) IBOutlet UILabel *labTitle;
@property (weak, nonatomic) IBOutlet UILabel *labActivityType;
@property (weak, nonatomic) IBOutlet UIPickerView *pickerActivityType;
@property (weak, nonatomic) IBOutlet UILabel *labStepName;
@property (weak, nonatomic) IBOutlet UILabel *labStepValue;
@property (weak, nonatomic) IBOutlet UILabel *labStepUnit;
@property (weak, nonatomic) IBOutlet UILabel *labCaloriesName;
@property (weak, nonatomic) IBOutlet UILabel *labCaloriesValue;
@property (weak, nonatomic) IBOutlet UILabel *labCaloriesUnit;
@property (weak, nonatomic) IBOutlet UILabel *labHRName;
@property (weak, nonatomic) IBOutlet UILabel *labHRValue;
@property (weak, nonatomic) IBOutlet UILabel *labHRUnit;
@property (weak, nonatomic) IBOutlet UILabel *labExerciseMinutesName;
@property (weak, nonatomic) IBOutlet UILabel *labExerciseMinutesValue;
@property (weak, nonatomic) IBOutlet UILabel *labExerciseMinutesUnit;
@property (weak, nonatomic) IBOutlet UIButton *btnStart;
@property (weak, nonatomic) IBOutlet UIButton *btnStop;
@property (weak, nonatomic) IBOutlet UIButton *btnPause;
@property (weak, nonatomic) IBOutlet UIButton *btnContinue;


@end

@implementation activityMode

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [NewBle sharedManager].delegate = self;
    [self myMasonry];
    
    _labTitle.text = LocalForkey(@"运动模式");
    _labStepName.text = LocalForkey(@"步数");
    _labHRName.text = LocalForkey(@"心率");
    _labCaloriesName.text = LocalForkey(@"运动时间");
    _labExerciseMinutesName.text = LocalForkey(@"运动时间");
    _labStepUnit.text = LocalForkey(@"步");
    _labCaloriesUnit.text = LocalForkey(@"千卡");
    _labActivityType.text = LocalForkey(@"运动类型");
    _labExerciseMinutesUnit.text = LocalForkey(@"秒");
    [_btnStart setTitle:LocalForkey(@"开始运动模式") forState:UIControlStateNormal];
    [_btnStop setTitle:LocalForkey(@"退出运动模式") forState:UIControlStateNormal];
    [_btnPause setTitle:LocalForkey(@"暂停运动模式") forState:UIControlStateNormal];
    [_btnContinue setTitle:LocalForkey(@"继续运动模式") forState:UIControlStateNormal];
    arrayActivityType = [NSArray arrayWithObjects:LocalForkey(@"跑步"),LocalForkey(@"骑行"),LocalForkey(@"步行"), LocalForkey(@"羽毛球"),LocalForkey(@"足球"),LocalForkey(@"网球"),LocalForkey(@"呼吸训练"),LocalForkey(@"跳舞"), LocalForkey(@"篮球"),LocalForkey(@"举重"),LocalForkey(@"板球"), LocalForkey(@"徒步"),LocalForkey(@"有氧训练"),LocalForkey(@"乒乓球"),LocalForkey(@"跳绳"),LocalForkey(@"仰卧起坐"), LocalForkey(@"排球"),LocalForkey(@"手球"),LocalForkey(@"棒球"),LocalForkey(@"曲棍球"),LocalForkey(@"击剑"),LocalForkey(@"拳击"),LocalForkey(@"自由搏击"),LocalForkey(@"摔跤"), LocalForkey(@"标枪"),LocalForkey(@"撑杆跳"),LocalForkey(@"跳高"),LocalForkey(@"双人划船"),LocalForkey(@"帆船"),LocalForkey(@"划船"),LocalForkey(@"平衡木"),LocalForkey(@"艺术体操"),LocalForkey(@"跳远"),LocalForkey(@"铅球"),LocalForkey(@"链球"),LocalForkey(@"蹦床"),LocalForkey(@"吊环"),LocalForkey(@"鞍马"),LocalForkey(@"单杠"),LocalForkey(@"铁人三项"),LocalForkey(@"保龄球"), LocalForkey(@"滑雪"),LocalForkey(@"滑冰"),LocalForkey(@"跑步机"),LocalForkey(@"动感单车"), nil];
}

-(void)myMasonry
{
    _btnStart.layer.cornerRadius  = 10 * Proportion;
    _btnStop.layer.cornerRadius  = 10 * Proportion;
    _btnPause.layer.cornerRadius  = 10 * Proportion;
    _btnContinue.layer.cornerRadius  = 10 * Proportion;
    [_labActivityType mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.top.mas_equalTo(self.view.mas_top).offset(120*Proportion);
        make.width.mas_equalTo(300*Proportion);
        make.height.mas_equalTo(40*Proportion);
    }];
    
    [_pickerActivityType mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.top.mas_equalTo(_labActivityType.mas_bottom).offset(20*Proportion);
        make.width.mas_equalTo(Width);
        make.height.mas_equalTo(200*Proportion);
    }];
    
    [_labStepName mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(self.view.mas_left).offset(40*Proportion);
        make.top.mas_equalTo(_pickerActivityType.mas_bottom).offset(10*Proportion);
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
    
    
    [_labHRName mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStepName.mas_centerX);
        make.top.mas_equalTo(_labCaloriesName.mas_bottom).offset(10*Proportion);
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

    [_labExerciseMinutesName mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStepName.mas_centerX);
        make.top.mas_equalTo(_labHRName.mas_bottom).offset(10*Proportion);
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
    
    [_btnStart mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(self.view.mas_left).offset(20*Proportion);
        make.bottom.mas_equalTo(self.view.mas_bottom).offset(-80*Proportion);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    [_btnStop mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.right.mas_equalTo(self.view.mas_right).offset(-20*Proportion);
        make.centerY.mas_equalTo(_btnStart.mas_centerY);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    
    [_btnPause mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(self.view.mas_left).offset(20*Proportion);
        make.bottom.mas_equalTo(self.view.mas_bottom).offset(-20*Proportion);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    [_btnContinue mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.right.mas_equalTo(self.view.mas_right).offset(-20*Proportion);
        make.centerY.mas_equalTo(_btnPause.mas_centerY);
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

    if(deviceData.dataType == StartActivityMode_X3)
    {
        /* @{@"enterActivityModeSuccess":@(byte[1]==1?YES:NO),@"startTime":strStartTime};*/
        NSDictionary * dicData = deviceData.dicData;
        NSNumber *  enterActivityModeSuccess = dicData[@"enterActivityModeSuccess"];
        if(enterActivityModeSuccess.boolValue==YES)
        {
            [PishumToast showToastWithMessage:LocalForkey(@"进入运动模式成功") Length:TOAST_SHORT ParentView:self.view];
            
        }
        else
            [PishumToast showToastWithMessage:LocalForkey(@"请先退出手表当前的运动模式") Length:TOAST_SHORT ParentView:self.view];
        
    }
    else if (deviceData.dataType == StopActivityMode_X3)
    {
        
            [PishumToast showToastWithMessage:LocalForkey(@"退出运动模式成功!") Length:TOAST_SHORT ParentView:self.view];
    }
    else if (deviceData.dataType == ContinueActivityMode_X3)
    {
        [PishumToast showToastWithMessage:LocalForkey(@"继续运动模式成功!") Length:TOAST_SHORT ParentView:self.view];
    }
    else if (deviceData.dataType == PauseActivityMode_X3)
    {
        [PishumToast showToastWithMessage:LocalForkey(@"暂停运动模式成功!") Length:TOAST_SHORT ParentView:self.view];
    }
    if(deviceData.dataType == DeviceSendDataToAPP_X3)
    {
        /* NSDictionary * dicData = [NSDictionary dictionaryWithObjectsAndKeys:numberHR,@"heartRate", numberStep,@"step",numberCalories,@"calories",numberTime,@"activeMinutes",nil];*/
        NSDictionary * dicData = deviceData.dicData;
        _labStepValue.text = [NSString stringWithFormat:@"%@",dicData[@"step"]];
        _labHRValue.text = [NSString stringWithFormat:@"%@",dicData[@"heartRate"]];
        _labCaloriesValue.text = [NSString stringWithFormat:@"%@",dicData[@"calories"]];
        _labExerciseMinutesValue.text = [NSString stringWithFormat:@"%@",dicData[@"activeMinutes"]];
        BOOL end = deviceData.dataEnd;
        if(end==YES)
        {
           
            [PishumToast showToastWithMessage:LocalForkey(@"退出运动模式成功!") Length:TOAST_SHORT ParentView:self.view];
        }
    }

}




#pragma mark PickViewDelegate
#pragma mark UIPickViewDataResource
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component

{
    return 40*Proportion;
}



// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return arrayActivityType.count;
}


- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    
    UILabel *myView = nil;
    myView = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, Width, 40*Proportion)];
    myView.textAlignment = NSTextAlignmentCenter;
    myView.text = [NSString stringWithFormat:@"%@",[arrayActivityType objectAtIndex:row]];
    myView.font = [UIFont systemFontOfSize:30];         //用label来设置字体大小
    myView.backgroundColor = [UIColor clearColor];
    
    
    
    return myView;
}


- (IBAction)start:(UIButton *)sender {
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
         activityType = (int)[_pickerActivityType selectedRowInComponent:0];
        MyBreathParameter_X3  breathParameter;
        if(activityType == 6)
        {
            breathParameter.breathMode = 2;
            breathParameter.DurationOfBreathingExercise = 5;// unit is minutes
            
        }
        else
        {
            breathParameter.breathMode = 0;
            breathParameter.DurationOfBreathingExercise = 0;// unit is minutes
        }
        NSMutableData * data = [[BleSDK_X3 sharedManager] startActivityMode:activityType WorkMode:startActivity ActivityTime:10 BreathParameter:breathParameter];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
}

- (IBAction)stop:(UIButton *)sender {
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        
        MyBreathParameter_X3  breathParameter;
        
        breathParameter.breathMode = 0;
        breathParameter.DurationOfBreathingExercise = 0;// unit is minutes
        NSMutableData * data = [[BleSDK_X3 sharedManager] startActivityMode:activityType WorkMode:stopActivity ActivityTime:0 BreathParameter:breathParameter];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
}


- (IBAction)pause:(UIButton *)sender {
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        
        MyBreathParameter_X3  breathParameter;
        
        breathParameter.breathMode = 0;
        breathParameter.DurationOfBreathingExercise = 0;// unit is minutes
        NSMutableData * data = [[BleSDK_X3 sharedManager] startActivityMode:activityType WorkMode:pauseActivity ActivityTime:0 BreathParameter:breathParameter];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
}

- (IBAction)continueActivity:(UIButton *)sender {
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        
        MyBreathParameter_X3  breathParameter;
        
        breathParameter.breathMode = 0;
        breathParameter.DurationOfBreathingExercise = 0;// unit is minutes
        NSMutableData * data = [[BleSDK_X3 sharedManager] startActivityMode:activityType WorkMode:continueActivity ActivityTime:continueActivity BreathParameter:breathParameter];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
}


- (IBAction)showInfo:(UIButton *)sender {
    
    infoView * myInfoView = [[infoView alloc] init];
    myInfoView.infoType = 9;
    [self.navigationController pushViewController:myInfoView animated:YES];
}

- (IBAction)back:(UIButton *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
