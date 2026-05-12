//
//  personalInfo.m
//  Ble SDK Demo
//
//  Created by yang sai on 2022/4/19.
//

#import "personalInfo.h"

@interface personalInfo ()<UIPickerViewDelegate,UIPickerViewDataSource,MyBleDelegate>
{
    NSMutableArray * arrayAge;
    NSMutableArray * arrayHeight;
    NSMutableArray * arrayWeight;
    NSMutableArray * arrayStride;
    int dataType;
    
   
    
}
@property (weak, nonatomic) IBOutlet UILabel *_labTitle;
@property (weak, nonatomic) IBOutlet UILabel *labNameGender;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segGender;
@property (weak, nonatomic) IBOutlet UILabel *labNameAge;
@property (weak, nonatomic) IBOutlet UIButton *btnValueAge;
@property (weak, nonatomic) IBOutlet UILabel *labNameHeigth;
@property (weak, nonatomic) IBOutlet UIButton *btnValueHeigth;
@property (weak, nonatomic) IBOutlet UILabel *labUnitHeigth;

@property (weak, nonatomic) IBOutlet UILabel *labNameWeight;
@property (weak, nonatomic) IBOutlet UIButton *btnValueWeight;
@property (weak, nonatomic) IBOutlet UILabel *labUnitWeight;

@property (weak, nonatomic) IBOutlet UILabel *labNameStride;
@property (weak, nonatomic) IBOutlet UIButton *btnValueStride;
@property (weak, nonatomic) IBOutlet UILabel *labUnitStride;

@property (weak, nonatomic) IBOutlet UIButton *btnSetPersonalInfo;
@property (weak, nonatomic) IBOutlet UIButton *btnGetPersonalInfo;


@property (strong, nonatomic) IBOutlet UIView *viewData;
@property (weak, nonatomic) IBOutlet UILabel *labTitle_dataView;
@property (weak, nonatomic) IBOutlet UIPickerView *myPickerView_dataView;
@property (weak, nonatomic) IBOutlet UIButton *btnCancel_dataView;
@property (weak, nonatomic) IBOutlet UIButton *btnMakesure_dataView;

@end

@implementation personalInfo

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [NewBle sharedManager].delegate = self;
    
    arrayAge = [[NSMutableArray alloc]init];
    arrayWeight = [[NSMutableArray alloc] init];
    arrayHeight = [[NSMutableArray alloc] init];
    arrayStride = [[NSMutableArray alloc] init];
    
    for (int i = 5; i<=100; i++) {
        [arrayAge addObject:[NSNumber numberWithInt:i]];
    }
    
    for (int i = 30; i<=130; i++) {
        [arrayWeight addObject:[NSNumber numberWithInt:i]];
    }
    
    for (int i = 50; i<=250; i++) {
        [arrayHeight addObject:[NSNumber numberWithInt:i]];
    }
    for (int i = 30 ; i<=120; i++) {
        [arrayStride addObject:[NSNumber numberWithInt:i]];
    }
    [self.view addSubview:_viewData];
    
    [_viewData setFrame:CGRectMake((Width-_viewData.frame.size.width)/2, -_viewData.frame.size.height, 288*Proportion, 260*Proportion)];
    _viewData.hidden = YES;
    
    [self myMasonry];
}



-(void)myMasonry
{
    
    __labTitle.text = LocalForkey(@"个人信息");
    [_btnSetPersonalInfo setTitle:LocalForkey(@"设置个人信息") forState:UIControlStateNormal];
    [_btnGetPersonalInfo setTitle:LocalForkey(@"获取个人信息") forState:UIControlStateNormal];
    _viewData.layer.cornerRadius = 10 * Proportion;
    _btnValueAge.layer.cornerRadius  = 10 * Proportion;
    _btnValueHeigth.layer.cornerRadius  = 10 * Proportion;
    _btnValueWeight.layer.cornerRadius  = 10 * Proportion;
    _btnValueStride.layer.cornerRadius  = 10 * Proportion;
    _btnSetPersonalInfo.layer.cornerRadius  = 10 * Proportion;
    _btnGetPersonalInfo.layer.cornerRadius  = 10 * Proportion;
    _btnCancel_dataView.layer.cornerRadius  = 10 * Proportion;
    _btnMakesure_dataView.layer.cornerRadius = 10 * Proportion;
    
    
    [__labTitle mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.top.mas_equalTo(self.view.mas_top).offset(120*Proportion);
        make.width.mas_equalTo(200*Proportion);
        make.height.mas_equalTo(40*Proportion);
    }];
    [_labNameGender mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.top.mas_equalTo(self.view.mas_top).offset(180*Proportion);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(20*Proportion);
    }];
    [_segGender mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.top.mas_equalTo(_labNameGender.mas_bottom).offset(10*Proportion);
        make.width.mas_equalTo(140*Proportion);
        make.height.mas_equalTo(29);
    }];
    
    float xLocation = (Width - (80 * Proportion * 4))/5.0;
    
    
    
    [_labNameAge mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(self.view.mas_left).offset(xLocation);
        make.top.mas_equalTo(_segGender.mas_bottom).offset(20*Proportion);
        make.width.mas_equalTo(80*Proportion);
        make.height.mas_equalTo(20*Proportion);
    }];
    [_btnValueAge mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labNameAge.mas_centerX);
        make.top.mas_equalTo(_labNameAge.mas_bottom).offset(5*Proportion);
        make.width.mas_equalTo(80*Proportion);
        make.height.mas_equalTo(40*Proportion);
    }];
    
    
    [_labNameHeigth mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(self.view.mas_left).offset(2*xLocation+80*Proportion);
        make.top.mas_equalTo(_segGender.mas_bottom).offset(20*Proportion);
        make.width.mas_equalTo(80*Proportion);
        make.height.mas_equalTo(20*Proportion);
    }];
    [_btnValueHeigth mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labNameHeigth.mas_centerX);
        make.top.mas_equalTo(_labNameHeigth.mas_bottom).offset(5*Proportion);
        make.width.mas_equalTo(80*Proportion);
        make.height.mas_equalTo(40*Proportion);
    }];
    [_labUnitHeigth mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labNameHeigth.mas_centerX);
        make.top.mas_equalTo(_btnValueHeigth.mas_bottom).offset(5*Proportion);
        make.width.mas_equalTo(80*Proportion);
        make.height.mas_equalTo(40*Proportion);
    }];
    
    [_labNameWeight mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(self.view.mas_left).offset(3*xLocation+80*Proportion*2);
        make.top.mas_equalTo(_segGender.mas_bottom).offset(20*Proportion);
        make.width.mas_equalTo(80*Proportion);
        make.height.mas_equalTo(20*Proportion);
    }];
    [_btnValueWeight mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labNameWeight.mas_centerX);
        make.top.mas_equalTo(_labNameWeight.mas_bottom).offset(5*Proportion);
        make.width.mas_equalTo(80*Proportion);
        make.height.mas_equalTo(40*Proportion);
    }];
    [_labUnitWeight mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labNameWeight.mas_centerX);
        make.top.mas_equalTo(_btnValueWeight.mas_bottom).offset(5*Proportion);
        make.width.mas_equalTo(80*Proportion);
        make.height.mas_equalTo(40*Proportion);
    }];
    
    [_labNameStride mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(self.view.mas_left).offset(4*xLocation+80*Proportion*3);
        make.top.mas_equalTo(_segGender.mas_bottom).offset(20*Proportion);
        make.width.mas_equalTo(80*Proportion);
        make.height.mas_equalTo(20*Proportion);
    }];
    [_btnValueStride mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labNameStride.mas_centerX);
        make.top.mas_equalTo(_labNameStride.mas_bottom).offset(5*Proportion);
        make.width.mas_equalTo(80*Proportion);
        make.height.mas_equalTo(40*Proportion);
    }];
    [_labUnitStride mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labNameStride.mas_centerX);
        make.top.mas_equalTo(_btnValueStride.mas_bottom).offset(5*Proportion);
        make.width.mas_equalTo(80*Proportion);
        make.height.mas_equalTo(40*Proportion);
    }];
    
    [_btnSetPersonalInfo mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(self.view.mas_left).offset(20*Proportion);
        make.top.mas_equalTo(_labUnitWeight.mas_bottom).offset(20*Proportion);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    
    [_btnGetPersonalInfo mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.right.mas_equalTo(self.view.mas_right).offset(-20*Proportion);
        make.centerY.mas_equalTo(_btnSetPersonalInfo.mas_centerY);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    
    [_labTitle_dataView mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_viewData.mas_centerX);
        make.top.mas_equalTo(_viewData.mas_top).offset(10*Proportion);
        make.width.mas_equalTo(120*Proportion);
        make.height.mas_equalTo(20*Proportion);
    }];
    
    [_myPickerView_dataView mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_viewData.mas_centerX);
        make.top.mas_equalTo(_labTitle_dataView.mas_bottom).offset(20*Proportion);
        make.width.mas_equalTo(288*Proportion);
        make.height.mas_equalTo(120*Proportion);
    }];
    [_btnCancel_dataView mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(_viewData.mas_left).offset(20*Proportion);
        make.top.mas_equalTo(_myPickerView_dataView.mas_bottom).offset(20*Proportion);
        make.width.mas_equalTo(118*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    [_btnMakesure_dataView mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.right.mas_equalTo(_viewData.mas_right).offset(-20*Proportion);
        make.top.mas_equalTo(_myPickerView_dataView.mas_bottom).offset(20*Proportion);
        make.width.mas_equalTo(118*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    
}


#pragma mark PickViewDelegate
#pragma mark UIPickViewDataResource
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 2;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component

{
    return 40;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component
{
    if(component==0)
    return 150*Proportion;
    else
        return pickerView.frame.size.width- 150*Proportion;
    
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    if(component==0)
    {
        int count = 0;
        switch (dataType) {
            case 1:
                count = (int)arrayAge.count;
                break;
            case 2:
                count = (int)arrayHeight.count;
                break;
            case 3:
                count = (int)arrayWeight.count;
                break;
            case 4:
                count = (int)arrayStride.count;
                break;
            default:
                break;
        }
        return count;
    }
    else
        return 1;
}


- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    
    UILabel *myView = nil;
    
    myView = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, 91, 30)];
    
    myView.textAlignment = NSTextAlignmentCenter;
    
    if(dataType==1)
    {
        if(component==0)
        {
            myView.text = [NSString stringWithFormat:@"%@",[arrayAge objectAtIndex:row]];
        }
        else
            myView.text = @"Age";
    }
    else if (dataType==2)
    {
        if(component==0)
            myView.text = [NSString stringWithFormat:@"%@",[arrayHeight objectAtIndex:row]];
        else
            myView.text = NSLocalizedString(@"CM", nil);
    }
    else if(dataType==3)
    {
        if(component==0)
            myView.text = [NSString stringWithFormat:@"%@",[arrayWeight objectAtIndex:row]];
        
        else
            myView.text = NSLocalizedString(@"KG", nil);
        
    }
    else
    {
        if(component==0)
            myView.text = [NSString stringWithFormat:@"%@",[arrayStride objectAtIndex:row]];
        
        else
            myView.text = NSLocalizedString(@"CM", nil);
    }
    
    
    myView.font = [UIFont systemFontOfSize:30];         //用label来设置字体大小
    myView.backgroundColor = [UIColor clearColor];
    
    
    
    return myView;
}






-(void)showWihtType
{
         
        switch (dataType) {
            case 1:
            {
                NSInteger age = _btnValueAge.titleLabel.text.integerValue;
                _labTitle_dataView.text = NSLocalizedString(@"Age", nil);
                [_myPickerView_dataView reloadAllComponents];
                [_myPickerView_dataView selectRow:age-5 inComponent:0 animated:YES];
            }
                break;
            case 2:
            {
                NSInteger heigth = _btnValueHeigth.titleLabel.text.integerValue;
                _labTitle_dataView.text = NSLocalizedString(@"Height", nil);
                [_myPickerView_dataView reloadAllComponents];
                [_myPickerView_dataView selectRow:heigth-50 inComponent:0 animated:YES];
            }
                break;
            case 3:
            {
                NSInteger weight = _btnValueWeight.titleLabel.text.integerValue;
                _labTitle_dataView.text = NSLocalizedString(@"Weight", nil);
                [_myPickerView_dataView reloadAllComponents];
                [_myPickerView_dataView selectRow:weight-30 inComponent:0 animated:YES];
            }
                break;
            case 4:
            {
                NSInteger stride = _btnValueStride.titleLabel.text.integerValue;
                _labTitle_dataView.text = NSLocalizedString(@"Stride", nil);
                [_myPickerView_dataView reloadAllComponents];
                [_myPickerView_dataView selectRow:stride-30 inComponent:0 animated:YES];
            }
                break;
            default:
                break;
        
    }
    if(_viewData.hidden==YES)
    {
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:0.5];
        CGPoint center = self.view.center;
        _viewData.center = center;
        _viewData.hidden = NO;
        [UIView commitAnimations];
    }
    
}


-(void)HiddenView
{
 
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.5];
    [_viewData setFrame:CGRectMake((Width-_viewData.frame.size.width)/2, -_viewData.frame.size.height, 288*Proportion, 260*Proportion)];
    [UIView commitAnimations];
    _viewData.hidden = YES;
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
    if(deviceData.dataType == SetPersonalInfo_X3)
    {
        [PishumToast showToastWithMessage:LocalForkey(@"设置个人信息成功") Length:TOAST_SHORT ParentView:self.view];
    }
    else if (deviceData.dataType == GetPersonalInfo_X3)
    {
        NSDictionary * dicPersonalInfo = deviceData.dicData;
        NSNumber * MyGender = dicPersonalInfo[@"gender"];
        NSNumber * MyAge = dicPersonalInfo[@"age"];
        NSNumber * MyHeight = dicPersonalInfo[@"height"];
        NSNumber * MyWeight = dicPersonalInfo[@"weight"];
        NSNumber * MyStride = dicPersonalInfo[@"stride"];
        _segGender.selectedSegmentIndex = MyGender.integerValue;
        [_btnValueAge setTitle:[NSString stringWithFormat:@"%@",MyAge] forState:UIControlStateNormal];
        [_btnValueHeigth setTitle:[NSString stringWithFormat:@"%@",MyHeight] forState:UIControlStateNormal];
        [_btnValueWeight setTitle:[NSString stringWithFormat:@"%@",MyWeight] forState:UIControlStateNormal];
        [_btnValueStride setTitle:[NSString stringWithFormat:@"%@",MyStride] forState:UIControlStateNormal];
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




- (IBAction)cancelDataView:(UIButton *)sender {
    [self HiddenView];
}
- (IBAction)makesureDataView:(UIButton *)sender {
    [self HiddenView];
    switch (dataType) {
        case 1:
        {
            
             NSNumber * number = [arrayAge objectAtIndex:[_myPickerView_dataView selectedRowInComponent:0]];
             [_btnValueAge setTitle:[NSString stringWithFormat:@"%@",number] forState:UIControlStateNormal];
        }
            break;
        case 2:
        {
            NSNumber * number = [arrayHeight objectAtIndex:[_myPickerView_dataView selectedRowInComponent:0]];

            [_btnValueHeigth setTitle:[NSString stringWithFormat:@"%@",number] forState:UIControlStateNormal];
        }
            break;
        case 3:
        {
            NSNumber * number = [arrayWeight objectAtIndex:[_myPickerView_dataView selectedRowInComponent:0]];
            [_btnValueWeight setTitle:[NSString stringWithFormat:@"%@",number] forState:UIControlStateNormal];
        }
            break;
        case 4:
        {
            NSNumber * number = [arrayStride objectAtIndex:[_myPickerView_dataView selectedRowInComponent:0]];

            [_btnValueStride setTitle:[NSString stringWithFormat:@"%@",number] forState:UIControlStateNormal];
        }
            break;
        default:
            break;
    }
    
    
    
    [self HiddenView];
}

- (IBAction)changeVaule:(UIButton *)sender {
    dataType = (int)sender.tag;
    
    [self showWihtType];
}


- (IBAction)setPersonalInfo:(UIButton *)sender {
    
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
    int gender =  (int)_segGender.selectedSegmentIndex;
    int age =  _btnValueAge.titleLabel.text.intValue;
    int height, weight,stride;
    height = _btnValueHeigth.titleLabel.text.intValue;
    weight = _btnValueWeight.titleLabel.text.intValue;
    stride = _btnValueStride.titleLabel.text.intValue;
    MyPersonalInfo_X3 personalInfo;
    personalInfo.age = age;
    personalInfo.gender = gender; //1 means male 0 means female
    personalInfo.height = height;//cm
    personalInfo.weight = weight;//kg
    personalInfo.stride = stride;//cm
    NSMutableData * data = [[BleSDK_X3 sharedManager] SetPersonalInfo:personalInfo];
    [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
    
}

- (IBAction)getPersonalInfo:(UIButton *)sender {
    
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        NSMutableData * data = [[BleSDK_X3 sharedManager] GetPersonalInfo];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
    
}
- (IBAction)back:(UIButton *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}
@end
