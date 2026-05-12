//
//  YCLanguageTools.m
//  Test_Arr
//
//  Created by 唐斌 on 14-7-28.
//  Copyright (c) 2014年 com.yongche. All rights reserved.
//

#import "YCLanguageTools.h"
#import <CommonCrypto/CommonDigest.h>
#define BaseBundle  @"Base"
@interface YCLanguageTools(){
    NSBundle *_languageBundle;
}
@end
@implementation YCLanguageTools

+(YCLanguageTools *)shareInstance{
    static YCLanguageTools *languageTools;
    static  dispatch_once_t  onceToken;
    dispatch_once(&onceToken, ^{
        languageTools = [[YCLanguageTools alloc] init];
    });
    return languageTools;
}
-(void)initUserLanguage{
//    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
//
//   NSString *userLanguage = [def valueForKey:kUserLanguage];
//    NSLog(@"  userLanguage    %@    %@" ,userLanguage,kUserLanguage);
//    if (!userLanguage) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSArray *languages = [defaults objectForKey : @"AppleLanguages" ];
        // 获得当前iPhone使用的语言
        NSString* currentLanguage = [languages objectAtIndex:0];
//      NSString *  userLanguage = currentLanguage;
//        [self saveDefineUserLanguage:userLanguage];
//    }
    if ([currentLanguage hasPrefix:@"zh"]) {
        currentLanguage = @"zh-Hans";
    }else if([currentLanguage hasPrefix:@"ru"])
        currentLanguage = @"ru";
    else
        currentLanguage = @"en";
    //获取文件路径
    NSString *languagePath;
   languagePath = [[NSBundle mainBundle] pathForResource:currentLanguage ofType:@"lproj"];
    if (languagePath.length == 0) {
        languagePath = [[NSBundle mainBundle] pathForResource:@"en" ofType:@"lproj"];
    }
    _languageBundle = [NSBundle bundleWithPath:languagePath];//生成bundle
}

-(void)saveDefineUserLanguage:(NSString *)userLanguage{
    if (!userLanguage) {
        return;
    }
    //
    if (userLanguage == _currentLanguage) {
        return;
    }
    _currentLanguage = userLanguage;
    
    NSString *path = [[NSBundle mainBundle] pathForResource:userLanguage ofType:@"lproj" ];
    _languageBundle = [NSBundle bundleWithPath:path];
    
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def setValue:userLanguage forKey:kUserLanguage];
    [def synchronize];
}
-(NSString *)defineUserLanguage{
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    NSString *userLanguage = [def valueForKey:kUserLanguage];
    return userLanguage;
}

//获取标签
-(NSString *)locatizedStringForkey:(NSString *)keyStr{
    //默认为本地资源文件名 为Localizable.strings
    
    NSString *str = [_languageBundle localizedStringForKey:keyStr value:nil table:@"Localizable"];
    if(str)
    return str;
    else
    return keyStr;
}

-(BOOL)isChinese
{
    NSArray *appLanguages = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"];
    NSString *languageName = [appLanguages objectAtIndex:0];
     if ([languageName hasPrefix:@"zh"])
         return YES;
    else
        return NO;
}


-(BOOL)isPhoneNumber:(NSString*)strPhone
{
    if (strPhone.length == 0||[strPhone hasPrefix:@"0"]) {
        return NO;
    }
    NSString *regex = @"[0-9]*";
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",regex];
    if ([pred evaluateWithObject:strPhone]) {
        return YES;
    }
    return NO;
}
-(BOOL)isEmailAddress:(NSString*)strEmail
{
    NSString*emailRegex =@"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}";

    NSPredicate*emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];

    return [emailTest evaluateWithObject:strEmail];

}

-(NSString *) md5: (NSString *) inPutText
{
    const char *cStr = [inPutText UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cStr, strlen(cStr), digest );
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [result appendFormat:@"%02x", digest[i]];
    
    return result;
}


- (NSString *) sha:(NSString *)input
{
    //const char *cstr = [input cStringUsingEncoding:NSUTF8StringEncoding];
    //NSData *data = [NSData dataWithBytes:cstr length:input.length];
    
    NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
    
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1(data.bytes, (unsigned int)data.length, digest);
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for(int i=0; i<CC_SHA1_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    return output;
}
@end
