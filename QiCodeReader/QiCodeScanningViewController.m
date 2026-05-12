//
//  QiCodeScanningViewController.m
//  QiQRCode
//
//  Created by huangxianshuai on 2018/11/13.
//  Copyright © 2018年 QiShare. All rights reserved.
//

#import "QiCodeScanningViewController.h"
#import "QiCodePreviewView.h"
#import "QiCodeManager.h"

@interface QiCodeScanningViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) QiCodePreviewView *previewView;
@property (nonatomic, strong) QiCodeManager *codeManager;

@end

@implementation QiCodeScanningViewController
- (void)viewDidLoad {
    
    [super viewDidLoad];
    _previewView = [[QiCodePreviewView alloc] initWithFrame:self.view.bounds];
    _previewView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_previewView];
    
    [self SacenavigationViewTiteStr:LocalForkey(@"扫一扫") RigtButStr:@"图片选择扫一扫"];
    
    __weak typeof(self) weakSelf = self;
    _codeManager = [[QiCodeManager alloc] initWithPreviewView:_previewView completion:^{
        [weakSelf startScanning];
    }];
}


//扫一扫导航栏
- (void)SacenavigationViewTiteStr:(NSString *)TiteStr RigtButStr:(NSString *)RigtButStr{
    self.navigationV = [[UIView alloc]initWithFrame:CGRectMake(0, 0, Width, kNavBarAndStatusBarHeight)];
    self.navigationV.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.navigationV];
    
    UIButton *BackBut= [[UIButton alloc]init];
    [self.navigationV addSubview:BackBut];
    [BackBut addTarget:self action:@selector(BackAction) forControlEvents:UIControlEventTouchUpInside];
    [BackBut setBackgroundImage:[UIImage imageNamed:@"返回"] forState:UIControlStateNormal];
    [BackBut mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(self.navigationV.mas_left);
        make.bottom.mas_equalTo(self.navigationV.mas_bottom);
        make.width.mas_equalTo(76*Proportion*0.8);
        make.height.mas_equalTo(45*Proportion*0.8);
    }];
    
    UIImageView *Rigt_ImageView =[[UIImageView alloc]init];
    [self.navigationV addSubview:Rigt_ImageView];
    Rigt_ImageView.image = [UIImage imageNamed:RigtButStr];
    [Rigt_ImageView mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.right.mas_equalTo(self.navigationV.mas_right).offset(-18*Proportion);
        make.bottom.mas_equalTo(self.navigationV.mas_bottom).offset(-15*Proportion);
        make.width.mas_equalTo(20*Proportion);
        make.height.mas_equalTo(18*Proportion);
    }];
    
    UIButton *RigtBut= [[UIButton alloc]init];
    [self.navigationV addSubview:RigtBut];
    RigtBut.backgroundColor = [UIColor clearColor];
    [RigtBut addTarget:self action:@selector(RigtButAction) forControlEvents:UIControlEventTouchUpInside];
    [RigtBut mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.right.mas_equalTo(self.navigationV.mas_right);
        make.bottom.mas_equalTo(self.navigationV.mas_bottom);
        make.width.mas_equalTo(50*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    
    
    UILabel *TiteLabel= [[UILabel alloc]initWithFrame:CGRectMake1(16.5,224.5,342,14)];
    TiteLabel.textAlignment = NSTextAlignmentCenter;
    [self.navigationV addSubview:TiteLabel];
    TiteLabel.textColor = [UIColor whiteColor];
    TiteLabel.font = [UIFont systemFontOfSize:15];
    TiteLabel.text = TiteStr;
    [TiteLabel mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(self.navigationV.mas_left);
        make.right.mas_equalTo(self.navigationV.mas_right);
        make.bottom.mas_equalTo(self.navigationV.mas_bottom);
        make.height.mas_equalTo(45*Proportion);
    }];
}


- (void)BackAction{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    [self startScanning];
}

- (void)viewWillDisappear:(BOOL)animated {
    
    [super viewWillDisappear:animated];
    
    [_codeManager stopScanning];
}

- (void)dealloc {
    
    NSLog(@"%s", __func__);
}


#pragma mark - Action functions

- (void)RigtButAction{
    
    __weak typeof(self) weakSelf = self;
    [_codeManager presentPhotoLibraryWithRooter:self callback:^(NSString * _Nonnull code) {
        NSLog(@"photo:%@",code);
        if (self.sureBlock) {
            self.sureBlock(code);
        }
        if(![self.navigationController popViewControllerAnimated:YES]){
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }];
}


#pragma mark - Private functions

- (void)startScanning {
    
    __weak typeof(self) weakSelf = self;
    [_codeManager startScanningWithCallback:^(NSString * _Nonnull code) {
         NSLog(@"startScanning:%@",code);
        if (self.sureBlock) {
            self.sureBlock(code);
        }
        if(![self.navigationController popViewControllerAnimated:YES]){
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    } autoStop:YES];
}






@end
