//
//  logFile.m
//  Ble SDK Demo
//
//  Created by yang sai on 2022/4/25.
//

#import "logFile.h"

@interface logFile ()<UIDocumentInteractionControllerDelegate>

@property (weak, nonatomic) IBOutlet UILabel *labTitle;
@property (weak, nonatomic) IBOutlet UIButton *btnExportLogFile;
@property (weak, nonatomic) IBOutlet UIButton *btnDeleteLogFile;
@end

@implementation logFile

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self myMasonry];
}

-(void)myMasonry
{
    _labTitle.text = LocalForkey(@"日志文件");
    [_btnExportLogFile setTitle:LocalForkey(@"导出日志") forState:UIControlStateNormal];
    [_btnDeleteLogFile setTitle:LocalForkey(@"删除日志") forState:UIControlStateNormal];
    _btnExportLogFile.layer.cornerRadius  = 10 * Proportion;
    _btnDeleteLogFile.layer.cornerRadius  = 10 * Proportion;
    
    [_btnExportLogFile mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.left.mas_equalTo(self.view.mas_left).offset(20*Proportion);
        make.bottom.mas_equalTo(self.view.mas_bottom).offset(-100*Proportion);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
    [_btnDeleteLogFile mas_makeConstraints:^(MASConstraintMaker * make)
     {
        make.right.mas_equalTo(self.view.mas_right).offset(-20*Proportion);
        make.centerY.mas_equalTo(_btnExportLogFile.mas_centerY);
        make.width.mas_equalTo(160*Proportion);
        make.height.mas_equalTo(50*Proportion);
    }];
}

#pragma mark UIDocumentInteractionControllerDelegate
- ( UIViewController *)documentInteractionControllerViewControllerForPreview:( UIDocumentInteractionController *)interactionController{
    return self;
}

#pragma mark 导出日志
- (void)exportFile{
    
    //导出xls文件
    NSArray *directoryPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,      NSUserDomainMask, YES);
    NSString *documentDirectory = [directoryPaths objectAtIndex:0];
    
    NSString* filePath = [documentDirectory stringByAppendingPathComponent:@"Ble SDK Demo.txt"];
    UIDocumentInteractionController *docu = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:filePath]];
    docu.delegate = self;
    CGRect rect = CGRectMake(0, 0, 320, 300);  //这里感觉没什么用
    
    [docu presentOpenInMenuFromRect:rect inView:self.view animated:YES];
    [docu presentPreviewAnimated:YES];
    
}

- (IBAction)exportLogFile:(id)sender {
    [self exportFile];
}
- (IBAction)deleteLogFile:(UIButton *)sender {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    //获取document路径,括号中属性为当前应用程序独享
    
    NSArray *directoryPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,      NSUserDomainMask, YES);
    
    NSString *documentDirectory = [directoryPaths objectAtIndex:0];
    
    
    
    //定义记录文件全名以及路径的字符串filePath

    
    NSString * FilePath = [documentDirectory stringByAppendingPathComponent:@"Ble SDK Demo.txt"];
    //查找文件，如果不存在，就创建一个文件
    if ([fileManager fileExistsAtPath:FilePath])
    {
         [fileManager removeItemAtPath:FilePath error:NULL];
    }
    
}



- (IBAction)back:(UIButton *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
