//
//  temperatureHistoryData.m
//  Ble SDK Demo
//
//  Created by yang sai on 2022/4/22.
//

#import "temperatureHistoryData.h"
#import "infoView.h"
@interface temperatureHistoryData ()<MyBleDelegate>
{
    int count;
    NSString * strText;
}
@property (weak, nonatomic) IBOutlet UILabel *labTitle;
@property (weak, nonatomic) IBOutlet UITextView *textViewData;
@property (weak, nonatomic) IBOutlet UIButton *btnGetData;
@property (weak, nonatomic) IBOutlet UIButton *btnDeleteData;
@end

@implementation temperatureHistoryData

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [NewBle sharedManager].delegate = self;
    [self myMasonry];
    
}

-(void)myMasonry
{
    _labTitle.text = LocalForkey(@"体温数据");
    [_btnGetData setTitle:LocalForkey(@"获取数据") forState:UIControlStateNormal];
    [_btnDeleteData setTitle:LocalForkey(@"删除数据") forState:UIControlStateNormal];
    _btnGetData.layer.cornerRadius  = 10 * Proportion;
    _btnDeleteData.layer.cornerRadius  = 10 * Proportion;

    
    [_textViewData mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.top.mas_equalTo(self.view.mas_top).offset(100*Proportion);
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
    if(deviceData.dataType == TemperatureData_X3)
    {
        
        count +=1;
        NSDictionary * dicData = deviceData.dicData;
        NSArray * arrayemperatureData = dicData[@"arrayemperatureData"];
        for (int i = 0; i< arrayemperatureData.count; i++) {
            NSString * strTemp;
            NSDictionary * dic = arrayemperatureData[i];
            strTemp = [NSString stringWithFormat:@"date : %@\nautoTemperature : %@\n\n\n",dic[@"date"],dic[@"temperature"]];
            strText  = [strText stringByAppendingString:strTemp];
        }
        if(count==50&&end==NO)
        {
            // 继续读取剩下的数据
            NSData * data = [[BleSDK_X3 sharedManager] GetTemperatureDataWithMode:2 withStartDate:nil];
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
        NSData * data = [[BleSDK_X3 sharedManager] GetTemperatureDataWithMode:0 withStartDate:nil];
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
        NSData * data = [[BleSDK_X3 sharedManager] GetTemperatureDataWithMode:0x99 withStartDate:nil];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
}


- (IBAction)showInfo:(UIButton *)sender {
    
    infoView * myInfoView = [[infoView alloc] init];
    myInfoView.infoType = 6;
    [self.navigationController pushViewController:myInfoView animated:YES];
}


- (IBAction)back:(UIButton *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}
@end
