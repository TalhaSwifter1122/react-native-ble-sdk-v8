//
//  FileView.m
//  1638 test APP
//
//  Created by  on 2018/7/10.
//  Copyright © 2018年 杨赛. All rights reserved.
//

#import "MyFileView.h"

@implementation MyFileView
+(MyFileView *)sharedManager
{
    static MyFileView *sharedAccountManagerInstance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        sharedAccountManagerInstance = [[self alloc] init];
    });
    return sharedAccountManagerInstance;
}
-(BOOL)CreateFile:(NSString*)strName
{
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    //获取document路径,括号中属性为当前应用程序独享
    
    NSArray *directoryPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,      NSUserDomainMask, YES);
    
    NSString *documentDirectory = [directoryPaths objectAtIndex:0];
    
    
    
    //定义记录文件全名以及路径的字符串filePath

    
    NSString * FilePath = [documentDirectory stringByAppendingPathComponent:strName];
    //查找文件，如果不存在，就创建一个文件
    if ([fileManager fileExistsAtPath:FilePath])
    {
        NSDate  * date = [UserDefaults objectForKey:@"logDate"];
        if(date==nil){
            date = [NSDate date];
            [UserDefaults setObject:date forKey:@"logDate"];
        }
        int diff = ([NSDate date].timeIntervalSince1970 - date.timeIntervalSince1970)/86400;
        if(diff<7)
           return YES;
        else
            [fileManager removeItemAtPath:FilePath error:NULL];
    }
    
        //保存日志的日期
        [UserDefaults setObject:[NSDate date] forKey:@"logDate"];
        [UserDefaults synchronize];
        return  [fileManager createFileAtPath:FilePath contents:nil attributes:nil];
    
}
-(void)WriteWithData:(NSString*)strData WithFileName:(NSString*)strFileName
{
    // NSFileManager *fileManager = [NSFileManager defaultManager];
    //获取document路径,括号中属性为当前应用程序独
    NSString * strDate = [NSString stringWithFormat:@"%@",[[MyDate sharedManager] stringFromDate:[NSDate date] WithStringFormat:@"yyyy-MM-dd HH:mm:ss"]];
    strData = [strDate stringByAppendingString:[NSString stringWithFormat:@":%@\n",strData]];
    NSArray *directoryPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,      NSUserDomainMask, YES);
    
    NSString *documentDirectory = [directoryPaths objectAtIndex:0];
    NSString* FilePath = [documentDirectory stringByAppendingPathComponent:strFileName];
    
    NSData *data = [strData  dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle* outFile = [NSFileHandle fileHandleForWritingAtPath:FilePath];
    if(outFile == nil)
    {
        NSLog(@"Open of file for writing failed");
    }
    
    //找到并定位到outFile的末尾位置(在此后追加文件)
    [outFile seekToEndOfFile];
    //读取inFile并且将其内容写到outFile中
    [outFile writeData:data];
    //关闭读写文件
    [outFile closeFile];
}


@end
