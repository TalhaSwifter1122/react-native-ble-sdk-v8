//
//  ppgView.m
//  Ble SDK Demo
//
//  Created by yang sai on 2022/7/8.
//

#import "ppgView.h"
#import "CustomeChartView.h"
#import "PPGWaveView.h"
#define testTime 300
@interface ppgView ()<MyBleDelegate>
{
    int myMeasurementTime;
    BOOL isMeasurment;
    CustomeChartView * chartView_PPG;
    NSMutableArray * arrayPPGData;
    NSMutableArray * arrayAllPPGData;
    NSTimer * myTimer;
}
@property (weak, nonatomic) IBOutlet UIButton *btnStart;
@property (weak, nonatomic) IBOutlet UIButton *btnStop;
@property (weak, nonatomic) IBOutlet UILabel *labProgress;
@property (weak, nonatomic) IBOutlet UIButton *btnQuit;
@property (nonatomic, strong) PPGWaveView *ppgView;
@end


@implementation ppgView

- (void)viewDidLoad {
    
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    arrayPPGData = [[NSMutableArray alloc] init];
    arrayAllPPGData = [[NSMutableArray alloc] init];
    [NewBle sharedManager].delegate = self;
    [self addECGAndPPGView];
    [self myMasonry];
    isMeasurment = NO;
    
    
//    self.ppgView = [[PPGWaveView alloc] initWithFrame:CGRectMake(20, 200, self.view.frame.size.width - 40, 150)];
//     self.ppgView.backgroundColor = [UIColor blackColor];
//     [self.view addSubview:self.ppgView];
    
}


-(void)myMasonry
{
    [_btnStart mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(self.view.mas_left).offset(12*Proportion);
        make.top.mas_equalTo(self.view.mas_top).offset(125*Proportion);
        make.width.mas_equalTo(100*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    [_btnStop mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.centerY.mas_equalTo(_btnStart.mas_centerY);
        make.width.mas_equalTo(100*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    [_btnQuit mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.right.mas_equalTo(self.view.mas_right).offset(-12*Proportion);
        make.centerY.mas_equalTo(_btnStart.mas_centerY);
        make.width.mas_equalTo(100*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    [_labProgress mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.top.mas_equalTo(_btnStart.mas_bottom).offset(10*Proportion);
        make.width.mas_equalTo(150*Proportion);
        make.height.mas_equalTo(25*Proportion);
    }];

}


#pragma mark addECGAndPPGView
-(void)addECGAndPPGView
{

    chartView_PPG = [[CustomeChartView alloc] initWithFrame:CGRectMake(0, 260*Proportion,Width,200*Proportion) WithSingleNumber:83 WithMaxSeconds:8];
    //fb0e3b
    chartView_PPG.LineColor = [UIColor colorWithRed:0xfb/255.0 green:0x0e/255.0 blue:0x3b/255.0 alpha:1];
    chartView_PPG.LineWidth = 1.0;
    chartView_PPG.blankCount = 200;
    [self.view addSubview:chartView_PPG];

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
    if(deviceData.dataType == ppgStartSucessed_X3)
    {
       if(isMeasurment==NO)
       {
           isMeasurment = YES;
           myMeasurementTime = 0;
           if([myTimer isValid])
           {
               [myTimer invalidate];
               myTimer = nil;
           }
           myTimer = [NSTimer  scheduledTimerWithTimeInterval:1 target:self selector:@selector(showLabTime) userInfo:nil repeats:YES];
       }
       else{
           [myTimer setFireDate:[NSDate distantPast]];
       }
    }
    else if (deviceData.dataType == ppgStartFailed_X3)
    {
        
    }
    else if (deviceData.dataType == ppgResult_X3)
    {
      
    }
    else if (deviceData.dataType == ppgStop_X3)
    {
        
    }
    else if (deviceData.dataType == ppgMeasurementProgress_X3)
    {
       
    }
    else if (deviceData.dataType == ppgQuit_X3)
    {
        if([myTimer isValid])
        {
            [myTimer invalidate];
            myTimer = nil;
        }
        isMeasurment = NO;
    }
    else if(deviceData.dataType == realtimePPGData_X3)
    {
      
        NSDictionary * dicData = deviceData.dicData;
        NSArray * arrayPPGData = dicData[@"arrayPPGData"];
     
        [chartView_PPG addShowDatasPPG:arrayPPGData];
        //[self.ppgView addPPGValues:arrayPPGData];
    }
        
    
}

#pragma mark 倒计时
-(void)showLabTime
{
    if(myMeasurementTime<=testTime){
        
        
        NSData * data = [[BleSDK_X3 sharedManager] ppgWithMode:4 ppgStatus:(myMeasurementTime/(float)testTime*100)];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
        
        NSString * progressValue = [NSString stringWithFormat:@"%.0f%%",(myMeasurementTime/(float)testTime*100)];
        _labProgress.text = progressValue ;
        
        myMeasurementTime +=1;
    }
    else
    {
        NSData * data = [[BleSDK_X3 sharedManager] ppgWithMode:3 ppgStatus:0];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
        
        if([myTimer isValid])
        {
            [myTimer invalidate];
            myTimer = nil;
        }
        isMeasurment = NO;

    }
}




- (IBAction)start:(UIButton *)sender {
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        NSData * data = [[BleSDK_X3 sharedManager] ppgWithMode:1 ppgStatus:0];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
    
}

- (IBAction)stop:(UIButton *)sender {
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        [myTimer setFireDate:[NSDate distantFuture]];
        NSData * data = [[BleSDK_X3 sharedManager] ppgWithMode:3 ppgStatus:0];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
}
- (IBAction)quit:(UIButton *)sender {
    if([[NewBle sharedManager] isConnectOrConnecting]==YES){
        NSData * data = [[BleSDK_X3 sharedManager] ppgWithMode:5 ppgStatus:0];
        [[NewBle sharedManager] writeValue:SERVICE characteristicUUID:SEND_CHAR p:[NewBle sharedManager].activityPeripheral data:data];
    }
    else
        [PishumToast showToastWithMessage:LocalForkey(@"设备未连接") Length:TOAST_SHORT ParentView:self.view];
}


- (IBAction)back:(UIButton *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
