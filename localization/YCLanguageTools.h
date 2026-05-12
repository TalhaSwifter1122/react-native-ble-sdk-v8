//
//  YCLanguageTools.h
//  Test_Arr
//
//  Created by 唐斌 on 14-7-28.
//  Copyright (c) 2014年 com.yongche. All rights reserved.
//

#import <Foundation/Foundation.h>
#define kUserLanguage @"userLanguage"
@interface YCLanguageTools : NSObject

@property (nonatomic,strong)NSString *currentLanguage;
@property (nonatomic,strong)NSBundle *languageBundle;

+(YCLanguageTools *)shareInstance;
-(void)initUserLanguage;
-(void)saveDefineUserLanguage:(NSString *)userLanguage;
-(NSString *)defineUserLanguage;

-(NSString *)locatizedStringForkey:(NSString *)keyStr;

///
#pragma mark
-(BOOL)isChinese;
-(BOOL)isPhoneNumber:(NSString*)strPhone;
-(BOOL)isEmailAddress:(NSString*)strEmail;
-(NSString *) md5: (NSString *) inPutText;
- (NSString *) sha:(NSString *)input;
@end
