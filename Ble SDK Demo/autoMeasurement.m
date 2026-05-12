//
//  autoMeasurement.m
//  Ble SDK Demo
//
//  Created by yang sai on 2022/4/21.
//

#import "autoMeasurement.h"
#import "infoView.h"
@interface autoMeasurement ()<UITableViewDelegate,UITableViewDataSource,UIPickerViewDelegate,UIPickerViewDataSource,MyBleDelegate>
{
    NSMutableArray * arrayIntervalTime;
    NSMutableArray * arrayWeeks;
    MyWeeks_X3  currentWeeks;
}


@property (weak, nonatomic) IBOutlet UILabel *labTitle;
@property (weak, nonatomic) IBOutlet UIButton *btnSetAutoMeasurement;
@property (weak, nonatomic) IBOutlet UIButton *btnGetAutoMeasurement;

@property (strong, nonatomic) IBOutlet UIScrollView *myScrollView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segSwitch;
@property (weak, nonatomic) IBOutlet UILabel *labStartTime;
@property (weak, nonatomic) IBOutlet UILabel *labEndTime;
@property (weak, nonatomic) IBOutlet UIDatePicker *datePickerStartTime;
@property (weak, nonatomic) IBOutlet UIDatePicker *datePickerEndTime;
@property (weak, nonatomic) IBOutlet UITableView *myTableView;
@property (weak, nonatomic) IBOutlet UILabel *labIntervalTime;
@property (weak, nonatomic) IBOutlet UIPickerView *pickerIntervalTime;
@property (weak, nonatomic) IBOutlet UILabel *labDataType;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segDataType;

@end

@implementation autoMeasurement

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    
    [NewBle sharedManager].delegate = self;
    
    arrayIntervalTime = [[NSMutableArray alloc] init];
    for (int i = 1 ; i<=24  ; i++) {
        [arrayIntervalTime addObject:@(i*5)];
    }
    arrayWeeks = [[NSMutableArray alloc] initWithObjects:LocalForkey(@"周日"),LocalForkey(@"周一"),LocalForkey(@"周二"),LocalForkey(@"周三"),LocalForkey(@"周四"),LocalForkey(@"周五"),LocalForkey(@"周六"), nil];
    
    
    [self myMasonry];
}

-(void)myMasonry
{
    
    _labTitle.text = LocalForkey(@"自动测量");
    [_btnGetAutoMeasurement setTitle:LocalForkey(@"获取自动测量") forState:UIControlStateNormal];
    [_btnSetAutoMeasurement setTitle:LocalForkey(@"设置自动测量") forState:UIControlStateNormal];
    _labDataType.text = LocalForkey(@"数据类型");
    
    _btnGetAutoMeasurement.layer.cornerRadius = 10 * Proportion;
    _btnSetAutoMeasurement.layer.cornerRadius = 10 * Proportion;
    
    
    if (@available(iOS 11.0, *)) {
        _myScrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }else {
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    
    [self.view addSubview:_myScrollView];
    _myScrollView.contentSize = CGSizeMake(Width,930*Proportion);
    
    
    [_myScrollView mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.top.mas_equalTo(self.view.mas_top).offset(90*Proportion);
        make.width.mas_equalTo(Width);
        make.height.mas_equalTo(Height - 160*Proportion);
    }];
    
    [_btnSetAutoMeasurement mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(self.view.mas_left).offset(20*Proportion);
        make.bottom.mas_equalTo(self.view.mas_bottom).offset(-15*Proportion);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    
    [_btnGetAutoMeasurement mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.right.mas_equalTo(self.view.mas_right).offset(-20*Proportion);
        make.centerY.mas_equalTo(_btnSetAutoMeasurement.mas_centerY);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    
    [_segSwitch mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_myScrollView.mas_centerX);
        make.top.mas_equalTo(_myScrollView.mas_top);
        make.width.mas_equalTo(295*Proportion);
        make.height.mas_equalTo(32);
    }];
    
    [_labStartTime mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(_segSwitch.mas_left).offset(13*Proportion);
        make.top.mas_equalTo(_segSwitch.mas_bottom).offset(10*Proportion);
        make.width.mas_equalTo(150*Proportion);
        make.height.mas_equalTo(20*Proportion);
    }];
    [_datePickerStartTime mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labStartTime.mas_centerX);
        make.top.mas_equalTo(_labStartTime.mas_bottom).offset(10*Proportion);
        make.width.mas_equalTo(176*Proportion);
        make.height.mas_equalTo(162*Proportion);
    }];
    
    [_labEndTime mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.right.mas_equalTo(self.view.mas_right).offset(-13*Proportion);
        make.centerY.mas_equalTo(_labStartTime.mas_centerY);
        make.width.mas_equalTo(150*Proportion);
        make.height.mas_equalTo(20*Proportion);
    }];
    [_datePickerEndTime mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_labEndTime.mas_centerX);
        make.top.mas_equalTo(_labEndTime.mas_bottom).offset(10*Proportion);
        make.width.mas_equalTo(176*Proportion);
        make.height.mas_equalTo(162*Proportion);
    }];
    
    [_myTableView mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_myScrollView.mas_centerX);
        make.top.mas_equalTo(_datePickerEndTime.mas_bottom).offset(10*Proportion);
        make.width.mas_equalTo(320*Proportion);
        make.height.mas_equalTo(280*Proportion);
    }];
    
    [_labIntervalTime mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_myScrollView.mas_centerX);
        make.top.mas_equalTo(_myTableView.mas_bottom).offset(10*Proportion);
        make.width.mas_equalTo(150*Proportion);
        make.height.mas_equalTo(20*Proportion);
    }];
    [_pickerIntervalTime mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_myScrollView.mas_centerX);
        make.top.mas_equalTo(_labIntervalTime.mas_bottom).offset(10*Proportion);
        make.width.mas_equalTo(Width);
        make.height.mas_equalTo(162*Proportion);
    }];
    
    [_labDataType mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_myScrollView.mas_centerX);
        make.top.mas_equalTo(_pickerIntervalTime.mas_bottom).offset(10*Proportion);
        make.width.mas_equalTo(150*Proportion);
        make.height.mas_equalTo(20*Proportion);
    }];
    [_segDataType mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(_myScrollView.mas_centerX);
        make.top.mas_equalTo(_labDataType.mas_bottom).offset(10*Proportion);
        make.width.mas_equalTo(350*Proportion);
        make.height.mas_equalTo(32);
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
    if(deviceData.dataType == GetAutomaticMonitoring_X3)
    {
        /* NSMutableDictionary * dicData = [NSMutableDictionary dictionaryWithObjectsAndKeys:workMode,@"workMode",strStartTime,@"startTime",strEndTime,@"endTime",weekValue,@"weeks",intervalTime,@"intervalTime",dataType,@"dataType",nil];*/
        NSDictionary * dicData = deviceData.dicData;
        
        NSNumber * workMode = dicData[@"workMode"];
        NSString * strStartTime = dicData[@"startTime"];
        NSString * strEndTime = dicData[@"endTime"];
        NSNumber * weeks = dicData[@"weeks"];
        NSNumber * intervalTime = dicData[@"intervalTime"];
        NSNumber * dataType = dicData[@"dataType"];
        
        if(workMode.intValue==2)
            _segSwitch.selectedSegmentIndex = 1;
        else
            _segSwitch.selectedSegmentIndex = 0;
        
        NSDate * startDate = [[MyDate sharedManager] dateFromString:strStartTime WithStringFormat:@"HH:mm"];
        _datePickerStartTime.date = startDate;
        NSDate * endDate = [[MyDate sharedManager] dateFromString:strEndTime WithStringFormat:@"HH:mm"];
        _datePickerEndTime.date = endDate;
        if(weeks.intValue&(1<<0))
            currentWeeks.sunday = YES;
        else
            currentWeeks.sunday = NO;
        if(weeks.intValue&(1<<1))
            currentWeeks.monday = YES;
        else
            currentWeeks.monday = NO;
        if(weeks.intValue&(1<<2))
            currentWeeks.Tuesday = YES;
        else
            currentWeeks.Tuesday = NO;
        if(weeks.intValue&(1<<3))
            currentWeeks.Wednesday = YES;
        else
            currentWeeks.Wednesday = NO;
        if(weeks.intValue&(1<<4))
            currentWeeks.Thursday = YES;
        else
            currentWeeks.Thursday = NO;
        if(weeks.intValue&(1<<5))
            currentWeeks.Friday = YES;
        else
            currentWeeks.Friday = NO;
        if(weeks.intValue&(1<<6))
            currentWeeks.Saturday = YES;
        else
            currentWeeks.Saturday = NO;
        
        int selectRow =  (intervalTime.intValue/5-1);
        if(selectRow<0)
            selectRow = 0;
        if(selectRow>23)
            selectRow = 23;
        [_pickerIntervalTime selectRow:selectRow inComponent:0 animated:YES];
        
        int myDataType = dataType.intValue;
        if(myDataType<1)
            myDataType = 1;
        if(myDataType>4)
            myDataType = 4;
        
        _segDataType.selectedSegmentIndex = myDataType-1;
        [_myTableView reloadData];
        
    }
    else if(deviceData.dataType == SetAutomaticMonitoring_X3 )
    {
        [PishumToast showToastWithMessage:LocalForkey(@"设置自动测量成功!") Length:TOAST_SHORT ParentView:self.view];
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
    return arrayIntervalTime.count;
}


- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    
    UILabel *myView = nil;
    myView = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, Width, 40*Proportion)];
    myView.textAlignment = NSTextAlignmentCenter;
    myView.text = [NSString stringWithFormat:@"%@",[arrayIntervalTime objectAtIndex:row]];
    myView.font = [UIFont systemFontOfSize:30];         //用label来设置字体大小
    myView.backgroundColor = [UIColor clearColor];
    
    
    
    return myView;
}


#pragma mark UITableViewDataSource
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    for(UIView * view in cell.contentView.subviews){
        if([view isKindOfClass:[UILabel class]])
            [view removeFromSuperview];
    }
    
    UILabel * labName = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 120*Proportion, 40*Proportion)];
    labName.text = arrayWeeks[indexPath.row];
    labName.font = [UIFont systemFontOfSize:16];
    labName.textColor = UIColor.blackColor;
    [cell.contentView addSubview:labName];
    
   
    BOOL select = NO;
    switch (indexPath.row) {
        case 0:
            select = currentWeeks.sunday;
            break;
        case 1:
            select = currentWeeks.monday;
            break;
        case 2:
            select = currentWeeks.Tuesday;
            break;
        case 3:
            select = currentWeeks.Wednesday;
            break;
        case 4:
            select = currentWeeks.Thursday;
            break;
        case 5:
            select = currentWeeks.Friday;
            break;
        case 6:
            select = currentWeeks.Saturday;
            break;
        default:
            break;
    }
    if(select==YES)
    {
        [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
        cell.tintColor  = UIColor.blackColor;
    }
    else
        [cell setAccessoryType:UITableViewCellAccessoryNone];
    

    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = UIColor.clearColor;
    return cell;
    
    
} // 创建单元格



- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
{
    return  arrayWeeks.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    return  40*Proportion;
}


-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.row) {
        case 0:
            currentWeeks.sunday = !currentWeeks.sunday;
            break;
        case 1:
            currentWeeks.monday = !currentWeeks.monday;
            break;
        case 2:
            currentWeeks.Tuesday = !currentWeeks.Tuesday;
            break;
        case 3:
            currentWeeks.Wednesday = !currentWeeks.Wednesday;
            break;
        case 4:
            currentWeeks.Thursday = !currentWeeks.Thursday;
            break;
        case 5:
            currentWeeks.Friday = !currentWeeks.Friday;
            break;
        case 6:
            currentWeeks.Saturday = !currentWeeks.Saturday;
            break;
        default:
            break;
    }
    [_myTableView reloadData];
}

- (IBAction)setAutoMeasurement:(id)sender {
    
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        
        MyAutomaticMonitoring_X3  automaticMonitoring;
        automaticMonitoring.mode = (_segSwitch.selectedSegmentIndex==0?0:2);
        automaticMonitoring.dataType = ((int)_segDataType.selectedSegmentIndex +1);
        automaticMonitoring.weeks = currentWeeks;
        NSInteger selectRow = [_pickerIntervalTime selectedRowInComponent:0];
        automaticMonitoring.intervalTime = ((int)selectRow+1) * 5;
        
        NSDate * startDate = _datePickerStartTime.date;
        NSDate * endDate = _datePickerEndTime.date;
        NSCalendar * cal = [NSCalendar currentCalendar];
        NSUInteger unitFlags = NSCalendarUnitHour|NSCalendarUnitMinute;
        NSDateComponents * conponent = [cal components:unitFlags fromDate:startDate];
        int startHour = (int)[conponent hour];
        int startMinute = (int)[conponent minute];
        conponent = [cal components:unitFlags fromDate:endDate];
        int endHour = (int)[conponent hour];
        int endMinute = (int)[conponent minute];
        automaticMonitoring.startTime_Hour = startHour;
        automaticMonitoring.startTime_Minutes = startMinute;
        automaticMonitoring.endTime_Hour = endHour;
        automaticMonitoring.endTime_Minutes = endMinute;

        
        NSMutableData * data = [[BleSDK_X3 sharedManager] SetAutomaticHRMonitoring:automaticMonitoring];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
    
}

- (IBAction)getAutoMeasurement:(UIButton *)sender {
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        NSMutableData * data = [[BleSDK_X3 sharedManager] GetAutomaticMonitoringWithDataType:(int)_segDataType.selectedSegmentIndex+1];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
}


- (IBAction)showInfo:(UIButton *)sender {
    
    infoView * myInfoView = [[infoView alloc] init];
    myInfoView.infoType = 1;
    [self.navigationController pushViewController:myInfoView animated:YES];
}



- (IBAction)back:(UIButton *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
