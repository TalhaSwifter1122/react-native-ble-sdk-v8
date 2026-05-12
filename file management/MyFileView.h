//
//  FileView.h
//  1638 test APP
//
//  Created by  on 2018/7/10.
//  Copyright © 2018年 杨赛. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MyFileView : NSObject
+(MyFileView *)sharedManager;
-(BOOL)CreateFile:(NSString*)strName;
-(void)WriteWithData:(NSString*)strData WithFileName:(NSString*)strFileName;

@end
