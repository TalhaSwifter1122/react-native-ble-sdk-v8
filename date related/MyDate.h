//
//  MyDate.h
//  GPS
//
//  Created by  on 2018/7/11.
//  Copyright © 2018年 杨赛. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MyDate : NSObject
+ (MyDate *)sharedManager;
//时间转星期
- (NSString*)weekdayStringFromDate:(NSDate*)inputDate;
-(int)weekdayFromDate:(NSDate*)inputDate;
- (NSString *)stringFromDate:(NSDate *)date WithStringFormat:(NSString*)strFormat;
- (NSDate *)dateFromString:(NSString *)dateString WithStringFormat:(NSString*)strFormat;

//当前的日期的月份
-(NSInteger)GetMonthFromDate:(NSDate*)date;
//获取月份
-(NSInteger)GetMonthFromClickTimes:(int)clickTimes;


//当前的日期的年份
-(NSInteger)GetYearFromDate:(NSDate*)date;
-(int)GetYear;
- (int) getDaysOfYear:(int)year Month:(int)month;
- (int) getFrontDaysOfYear:(int)year Month:(int)month;

-(NSString*)strDateWithType:(int)type AndClickTimes:(int)clickTimes;
-(NSString*)strDateConversionWithDate:(NSString*)strDate type:(int)dateType;
#pragma mark 获取当前的系统语言
-(NSString*)GetLanguageName;
-(int)timeZone;
//获取当月有多少天
- (NSInteger)getNumberOfDaysInMonth;
//获取当年有多少天
- (NSInteger)getNumberOfDaysInYear;




@end
