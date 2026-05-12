//
//  activityHistoryData.m
//  Ble SDK Demo
//
//  Created by yang sai on 2022/4/22.
//

#import "activityHistoryData.h"
#import "infoView.h"
@interface activityHistoryData ()<MyBleDelegate>
{
    int count;
    NSString * strText;
}
@property (weak, nonatomic) IBOutlet UILabel *labTitle;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segDadaType;
@property (weak, nonatomic) IBOutlet UITextView *textViewData;
@property (weak, nonatomic) IBOutlet UIButton *btnGetData;
@property (weak, nonatomic) IBOutlet UIButton *btnDeleteData;
@end

@implementation activityHistoryData

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [NewBle sharedManager].delegate = self;
    [self myMasonry];
    
}

-(void)myMasonry
{
    _labTitle.text = LocalForkey(@"运动数据");
    [_segDadaType setTitle:LocalForkey(@"总数据") forSegmentAtIndex:0];
    [_segDadaType setTitle:LocalForkey(@"详细数据") forSegmentAtIndex:1];
    [_segDadaType setTitle:LocalForkey(@"运动类型") forSegmentAtIndex:2];
    [_btnGetData setTitle:LocalForkey(@"获取数据") forState:UIControlStateNormal];
    [_btnDeleteData setTitle:LocalForkey(@"删除数据") forState:UIControlStateNormal];
    _btnGetData.layer.cornerRadius  = 10 * Proportion;
    _btnDeleteData.layer.cornerRadius  = 10 * Proportion;
    [_segDadaType mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.top.mas_equalTo(self.view.mas_top).offset(95*Proportion);
        make.width.mas_equalTo(350*Proportion);
        make.height.mas_equalTo(32);
    }];
    
    [_textViewData mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.top.mas_equalTo(_segDadaType.mas_bottom).offset(10*Proportion);
        make.width.mas_equalTo(350*Proportion);
        make.height.mas_equalTo(Height-220*Proportion);
    }];
    
    [_btnGetData mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(self.view.mas_left).offset(20*Proportion);
        make.bottom.mas_equalTo(self.view.mas_bottom).offset(-20*Proportion);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    [_btnDeleteData mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.right.mas_equalTo(self.view.mas_right).offset(-20*Proportion);
        make.centerY.mas_equalTo(_btnGetData.mas_centerY);
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
    BOOL end = deviceData.dataEnd;
    if(deviceData.dataType == TotalActivityData_X3)
    {
        count +=1;
        NSDictionary * dicData = deviceData.dicData;
        NSArray * arrayTotalActivityData = dicData[@"arrayTotalActivityData"];
        for (int i = 0; i< arrayTotalActivityData.count; i++) {
            NSString * strTemp;
            NSDictionary * dic = arrayTotalActivityData[i];
            
            strTemp = [NSString stringWithFormat:@"date : %@\ntotalStep : %@\ntotalExerciseMinutes : %@ %@\ntotalDistance : %@ %@\ntotalCalories : %@ %@\ndailyGoal : %@\ntotalActiveMinutes : %@ %@\n\n\n",dic[@"date"],dic[@"step"],dic[@"exerciseMinutes"],LocalForkey(@"分钟"),dic[@"distance"],LocalForkey(@"千米"),dic[@"calories"],LocalForkey(@"千卡"),dic[@"goal"],dic[@"activeMinutes"],LocalForkey(@"分钟")];
            strText  = [strText stringByAppendingString:strTemp];
        }
        
        
        if(count==50&&end==NO)
        {
            // 继续读取剩下的数据
            NSData * data = [[BleSDK_X3 sharedManager] GetTotalActivityDataWithMode:2 withStartDate:nil];
            [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
        }
        else if(end==YES)
        {
            
            if(strText.length>0)
                _textViewData.text = strText;
            else
                _textViewData.text = LocalForkey(@"无数据");
        }
    }
    if(deviceData.dataType == DetailActivityData_X3)
    {
        count +=1;
        NSDictionary * dicData = deviceData.dicData;
        NSArray * arrayDetailActivityData = dicData[@"arrayDetailActivityData"];
        for (int i = 0; i< arrayDetailActivityData.count; i++) {
            NSString * strTemp;
            NSDictionary * dic = arrayDetailActivityData[i];
            NSArray * arrayStep = dic[@"arraySteps"];
            NSString * strArrayStep = [arrayStep componentsJoinedByString:@","];
            strTemp = [NSString stringWithFormat:@"date : %@\nstep : %@\ncalories : %@ %@\ndistance : %@ %@\nstepsPerMinute : %@\n\n\n",dic[@"date"],dic[@"step"],dic[@"calories"],LocalForkey(@"千卡"),dic[@"distance"],LocalForkey(@"千米"),strArrayStep];
            strText  = [strText stringByAppendingString:strTemp];
        }
        
        
        if(count==50&&end==NO)
        {
            // 继续读取剩下的数据
            NSData * data = [[BleSDK_X3 sharedManager] GetDetailActivityDataWithMode:2 withStartDate:nil];
            [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
        }
        else if(end==YES)
        {
            
            if(strText.length>0)
                _textViewData.text = strText;
            else
                _textViewData.text = LocalForkey(@"无数据");
        }
    }
    if(deviceData.dataType == ActivityModeData_X3)
    {
        
        
        count +=1;
        NSDictionary * dicData = deviceData.dicData;
        NSArray * arrayTotalActivityData = dicData[@"arrayActivityModeData"];
        for (int i = 0; i< arrayTotalActivityData.count; i++) {
            NSString * strTemp;
            NSNumber * activityMode = dicData[@"activityMode"];
            
            NSDictionary * dic = arrayTotalActivityData[i];
            strTemp = [NSString stringWithFormat:@"date : %@\nactivityMode : %@\navgHR : %@\nactiveMinutes : %@ %@\nsteps : %@\ncalories : %@ %@\ndistance : %@ %@\npace : %@'%@\"\n\n\n",dic[@"date"],[self getDataTypeNameWithDataType:activityMode.intValue],dic[@"heartRate"],dic[@"activeMinutes"],LocalForkey(@"秒"),dic[@"step"],dic[@"calories"],LocalForkey(@"千卡"),dic[@"distance"],LocalForkey(@"千米"),dic[@"paceMinutes"],dic[@"paceSeconds"]];
            strText  = [strText stringByAppendingString:strTemp];
        }
        
        
        if(count==50&&end==NO)
        {
            // 继续读取剩下的数据
            NSData * data = [[BleSDK_X3 sharedManager] GetActivityModeDataWithMode:2 withStartDate:nil];
            [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
        }
        else if(end==YES)
        {
            
            if(strText.length>0)
                _textViewData.text = strText;
            else
                _textViewData.text = LocalForkey(@"无数据");
        }
    }
    
}


#pragma mark getDataTypeNameWithDataType
-(NSString*)getDataTypeNameWithDataType:(int)dataType
{
    
    /* 0 跑步  1  骑车 2 羽毛球  3 足球  4网球 5 瑜伽  6冥想 7 跳舞 8篮球 9徒步 10 举重   */
    NSString * strName;
    switch (dataType) {
        case 0:
            strName = LocalForkey(@"跑步");
            break;
        case 1:
            strName = LocalForkey(@"骑行");
            break;
        case 2:
            strName = LocalForkey(@"羽毛球");
            break;
        case 3:
            strName = LocalForkey(@"足球");
            break;
        case 4:
            strName = LocalForkey(@"网球");
            break;
        case 5:
            strName = LocalForkey(@"瑜伽");
            break;
        case 6:
            strName = LocalForkey(@"呼吸训练");
            break;
        case 7:
            strName = LocalForkey(@"跳舞");
            break;
        case 8:
            strName = LocalForkey(@"篮球");
            break;
        case 9:
            strName = LocalForkey(@"步行");
            break;
        case 10:
            strName = LocalForkey(@"举重");
            break;
        case 11:
            strName = LocalForkey(@"板球");
            break;
        case 12:
            strName = LocalForkey(@"徒步");
            break;
        case 13:
            strName = LocalForkey(@"有氧训练");
            break;
        case 14:
            strName = LocalForkey(@"乒乓球");
            break;
        case 15:
            strName = LocalForkey(@"跳绳");
            break;
        case 16:
            strName = LocalForkey(@"仰卧起坐");
            break;
        case 17:
            strName = LocalForkey(@"排球");
            break;
        default:
            strName = LocalForkey(@"跑步");
            break;
    }
    return strName;
}


- (IBAction)getData:(UIButton *)sender {
    
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        
            count = 0;
            _textViewData.text = LocalForkey(@"正在读取数据");
            strText = @"";
        NSData * data;
        if(_segDadaType.selectedSegmentIndex==0)
            data = [[BleSDK_X3 sharedManager] GetTotalActivityDataWithMode:0 withStartDate:[[MyDate sharedManager] dateFromString:@"2022.04.10" WithStringFormat:@"YYYY.MM.dd"]];
        else if (_segDadaType.selectedSegmentIndex==1)
            data = [[BleSDK_X3 sharedManager] GetDetailActivityDataWithMode:0 withStartDate:nil];
        else
            data = [[BleSDK_X3 sharedManager] GetActivityModeDataWithMode:0 withStartDate:nil];
        
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];

}

- (IBAction)deleteData:(UIButton *)sender {
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        count = 0;
        _textViewData.text = LocalForkey(@"正在删除数据");
        strText = @"";
        NSData * data;
        if(_segDadaType.selectedSegmentIndex==0)
            data = [[BleSDK_X3 sharedManager] GetTotalActivityDataWithMode:0x99 withStartDate:nil];
        else if (_segDadaType.selectedSegmentIndex==1)
            data = [[BleSDK_X3 sharedManager] GetDetailActivityDataWithMode:0x99 withStartDate:nil];
        else
            data = [[BleSDK_X3 sharedManager] GetActivityModeDataWithMode:0x99 withStartDate:nil];
        
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
}

- (IBAction)showInfo:(UIButton *)sender {
    
    infoView * myInfoView = [[infoView alloc] init];
    myInfoView.infoType = 3;
    [self.navigationController pushViewController:myInfoView animated:YES];
}


- (IBAction)back:(UIButton *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
