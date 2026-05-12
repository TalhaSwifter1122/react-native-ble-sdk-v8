//
//  heartRateHistoryData.m
//  Ble SDK Demo
//
//  Created by yang sai on 2022/4/22.
//

#import "heartRateHistoryData.h"
#import "infoView.h"
@interface heartRateHistoryData ()<MyBleDelegate>
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

@implementation heartRateHistoryData

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [NewBle sharedManager].delegate = self;
    [self myMasonry];
    
}

-(void)myMasonry
{
    _labTitle.text = LocalForkey(@"心率数据");
    [_segDadaType setTitle:LocalForkey(@"连续心率") forSegmentAtIndex:0];
    [_segDadaType setTitle:LocalForkey(@"单次心率") forSegmentAtIndex:1];
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
    if(deviceData.dataType == DynamicHR_X3)
    {
        
        /*  NSDictionary * dicData = @{@"date":strDate,@"arrayHR":arrayDynamic};*/
        count +=1;
        NSDictionary * dicData = deviceData.dicData;
        NSArray * arrayDynamicHR = dicData[@"arrayContinuousHR"];
        for (int i = 0; i< arrayDynamicHR.count; i++) {
            NSString * strTemp;
            NSDictionary * dic = arrayDynamicHR[i];
            NSArray * arrayHR = dic[@"arrayHR"];
            NSString * strArrayHR = [arrayHR componentsJoinedByString:@","];
            strTemp = [NSString stringWithFormat:@"date : %@\nheartbeatPerMinute : %@\n\n\n",dic[@"date"],strArrayHR];
            strText  = [strText stringByAppendingString:strTemp];
        }
        if(count==50&&end==NO)
        {
            // 继续读取剩下的数据
            NSData * data = [[BleSDK_X3 sharedManager] GetContinuousHRDataWithMode:2 withStartDate:nil];
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
    if(deviceData.dataType == StaticHR_X3)
    {
        count +=1;
        NSDictionary * dicData = deviceData.dicData;
        NSArray * arrayStaticHR = dicData[@"arraySingleHR"];
        for (int i = 0; i< arrayStaticHR.count; i++) {
            NSString * strTemp;
            NSDictionary * dic = arrayStaticHR[i];
            strTemp = [NSString stringWithFormat:@"date : %@\nheartbeatPerMinute : %@\n\n\n",dic[@"date"],dic[@"singleHR"]];
            strText  = [strText stringByAppendingString:strTemp];
        }
        
        
        if(count==50&&end==NO)
        {
            // 继续读取剩下的数据
            NSData * data = [[BleSDK_X3 sharedManager] GetSingleHRDataWithMode:2 withStartDate:nil];
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


- (IBAction)getData:(UIButton *)sender {
    
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        
            count = 0;
            _textViewData.text = LocalForkey(@"正在读取数据");
            strText = @"";
        NSData * data;
        if(_segDadaType.selectedSegmentIndex==0)
            data = [[BleSDK_X3 sharedManager] GetContinuousHRDataWithMode:0 withStartDate:[[MyDate sharedManager] dateFromString:@"2022.04.10" WithStringFormat:@"YYYY.MM.dd"]];
        else
            data = [[BleSDK_X3 sharedManager] GetSingleHRDataWithMode:0 withStartDate:nil];
        
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
            data = [[BleSDK_X3 sharedManager] GetContinuousHRDataWithMode:0x99 withStartDate:nil];
        else
            data = [[BleSDK_X3 sharedManager] GetSingleHRDataWithMode:0x99 withStartDate:nil];
        
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
}


- (IBAction)showInfo:(UIButton *)sender {
    
    infoView * myInfoView = [[infoView alloc] init];
    myInfoView.infoType = 5;
    [self.navigationController pushViewController:myInfoView animated:YES];
}



- (IBAction)back:(UIButton *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
