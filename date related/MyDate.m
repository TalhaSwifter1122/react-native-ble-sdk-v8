//
//  MyDate.m
//  GPS
//
//  Created by  on 2018/7/11.
//  Copyright © 2018年 杨赛. All rights reserved.
//

#import "MyDate.h"

@implementation MyDate


+(MyDate *)sharedManager
{
    static MyDate *sharedAccountManagerInstance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        sharedAccountManagerInstance = [[self alloc] init];
    });
    return sharedAccountManagerInstance;
}

-(int)GetYear
{
    NSDate *currentDate = [NSDate date];
    NSCalendar* calendar = [NSCalendar currentCalendar];
    NSDateComponents* components = [calendar components:NSCalendarUnitYear fromDate:currentDate]; // Get necessary date components
    return  (int)[components year]; // gives you year
}


-(NSInteger)secondsFromGMT
{
    NSTimeZone *localZone = [NSTimeZone localTimeZone];
    NSInteger seconds= [localZone secondsFromGMT];
    return seconds;
}




-(int)weekdayFromDate:(NSDate*)inputDate
{
   NSInteger zones  =  [self secondsFromGMT]/3600;
  NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    
    [calendar setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT:zones*3600]];
    
    NSCalendarUnit calendarUnit = NSCalendarUnitWeekday;
    
    NSDateComponents *theComponents = [calendar components:calendarUnit fromDate:inputDate];
    
    return ((int)theComponents.weekday-1)==0?7:((int)theComponents.weekday-1);
}
//时间转星期
-(NSString*)weekdayStringFromDate:(NSDate*)inputDate {
    
    
    NSInteger zones  =  [self secondsFromGMT]/3600;
    
    NSArray *weekdays = [NSArray arrayWithObjects: [NSNull null], LocalForkey(@"周日"), LocalForkey(@"周一"), LocalForkey(@"周二"), LocalForkey(@"周三"), LocalForkey(@"周四"), LocalForkey(@"周五"), LocalForkey(@"周六"), nil];
    
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    
    [calendar setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT:zones*3600]];
    
    NSCalendarUnit calendarUnit = NSCalendarUnitWeekday;
    
    NSDateComponents *theComponents = [calendar components:calendarUnit fromDate:inputDate];
    
    return (NSString*)[weekdays objectAtIndex:theComponents.weekday];
    
}


- (NSString *)stringFromDate:(NSDate *)date WithStringFormat:(NSString*)strFormat
{
    //@"yyyy-MM-dd"
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    //zzz表示时区，zzz可以删除，这样返回的日期字符将不包含时区信息。
    [dateFormatter setDateFormat:strFormat];
    NSString *destDateString = [dateFormatter stringFromDate:date];
    return destDateString;
}

- (NSDate *)dateFromString:(NSString *)dateString WithStringFormat:(NSString*)strFormat{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:strFormat];
    NSDate *destDate= [dateFormatter dateFromString:dateString];
    return destDate;
}


//当前的日期的月份
-(NSInteger)GetMonthFromDate:(NSDate*)date
{
   NSCalendar *calender = [NSCalendar currentCalendar];
    NSDateComponents *comps =[calender components:(  NSCalendarUnitMonth) fromDate:date];
    return  [comps month];
}
//获取月份
-(NSInteger)GetMonthFromClickTimes:(int)clickTimes
{
    NSCalendar *calender = [NSCalendar currentCalendar];
     NSDateComponents *comps =[calender components:(  NSCalendarUnitMonth) fromDate:[NSDate date]];
    NSInteger month = [comps month];
    month -= clickTimes;
    while (month<=0) {
        month +=12;
    }
    NSLog(@"month = %d",month);
    return month;
}


//当前的日期的年份
-(NSInteger)GetYearFromDate:(NSDate*)date
{
   NSCalendar *calender = [NSCalendar currentCalendar];
    NSDateComponents *comps =[calender components:(  NSCalendarUnitYear) fromDate:date];
    return  [comps year];
}


-(int) getDaysOfYear:(int)year Month:(int)month
{
    int days = 0;
    
    if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12)
    {
        days = 31;
    }
    else if (month == 4 || month == 6 || month == 9 || month == 11)
    {
        days = 30;
    }
    else
    { // 2月份，闰年29天、平年28天
        if ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0)
        {
            days = 29;
        }
        else
        {
            days = 28;
        }
    }
    
    return days;
}

-(int) getFrontDaysOfYear:(int)year Month:(int)month
{
    int days = 0;
    
    if(month==1){
        month = 12;
        year -= 1;
    }
    else
        month -= 1;
    if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12)
    {
        days = 31;
    }
    else if (month == 4 || month == 6 || month == 9 || month == 11)
    {
        days = 30;
    }
    else
    { // 2月份，闰年29天、平年28天
        if ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0)
        {
            days = 29;
        }
        else
        {
            days = 28;
        }
    }
    
    return days;
}

#pragma mark 英文日期格式
-(NSString *)monthEn:(NSInteger)month{
    NSCalendar *caldendar = [NSCalendar currentCalendar];// 获取日历
    NSArray *monthArr = [NSArray arrayWithArray:caldendar.shortMonthSymbols];  // 获取日历月数组
    return monthArr[month - 1];  // 获得数字月份下的对应英文月缩写
}

#pragma mark 获取当前的系统语言
-(NSString*)GetLanguageName
{
    NSArray *appLanguages = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"];
    NSString *languageName = [appLanguages objectAtIndex:0];
    return languageName;
}






#pragma mark 标题日期
-(NSString*)strDateWithType:(int)type AndClickTimes:(int)clickTimes
{
     NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSDate * date = [NSDate date];
    //
    if(type==0)
    {
       //今天是星期几
        int week = (int)[self weekdayFromDate:date];
        [dateFormatter setDateFormat:@"yyyy.MM.dd"];
        NSString *  strStartTime= [dateFormatter stringFromDate:[date dateByAddingTimeInterval:((1-week)-clickTimes*7)*24*3600]];
        NSString * strEndTime = [dateFormatter stringFromDate:[date dateByAddingTimeInterval:((7-week)-clickTimes*7)*24*3600]];
        return [NSString stringWithFormat:@"%@—%@",strStartTime,strEndTime];
    }
    else if (type==1)
    {
       [dateFormatter setDateFormat:@"yyyy.MM"];
        NSString * strDate = [dateFormatter stringFromDate:date];
        int year = [strDate substringWithRange:NSMakeRange(0, 4)].intValue;
        int month = [strDate substringWithRange:NSMakeRange(5,2)].intValue;
        month -=clickTimes;
        if(month<=0)
        {
            do {
                month +=12;
                year -=1;
            } while (month<=0);
        }
        
        return [NSString stringWithFormat:@"%d.%02d",year,month];
        
    }
    else if(type==2)
    {
        [dateFormatter setDateFormat:@"yyyy"];
        NSString * strDate = [dateFormatter stringFromDate:date];
        int year = strDate.intValue;
        year -=clickTimes;
        return [NSString stringWithFormat:@"%d",year];
    }
    else if (type==3)
    {
        [dateFormatter setDateFormat:@"yyyy.MM.dd"];
        return [dateFormatter stringFromDate:[date dateByAddingTimeInterval:-clickTimes*3600*24]];
    }
    return nil;
}

-(NSString*)strDateConversionWithDate:(NSString*)strDate type:(int)dateType
{
    switch (dateType) {
        case 0:
        {
            //2012.02.02-2012.02.02
            int year1 = [strDate substringWithRange:NSMakeRange(0, 4)].intValue;
            NSInteger month1 = [strDate substringWithRange:NSMakeRange(5, 2)].integerValue;
            int day1 = [strDate substringWithRange:NSMakeRange(8, 2)].intValue;
            int year2 = [strDate substringWithRange:NSMakeRange(11, 4)].intValue;
            NSInteger month2 = [strDate substringWithRange:NSMakeRange(16, 2)].integerValue;
            int day2 = [strDate substringWithRange:NSMakeRange(19, 2)].intValue;
            strDate = [NSString stringWithFormat:@"%@ %d,%d-%@ %d,%d",[self monthEn:month1],day1,year1,[self monthEn:month2],day2,year2];
        }
            break;
        case 1:
        {
           //
            int year = [strDate substringWithRange:NSMakeRange(0, 4)].intValue;
            NSInteger month = [strDate substringWithRange:NSMakeRange(5, 2)].integerValue;
             strDate = [NSString stringWithFormat:@"%@ %d",[self monthEn:month],year];
        }
            break;
        case 3:
        {
            int year = [strDate substringWithRange:NSMakeRange(0, 4)].intValue;
            NSInteger month = [strDate substringWithRange:NSMakeRange(5, 2)].integerValue;
            int day = [strDate substringWithRange:NSMakeRange(8, 2)].intValue;
            strDate = [NSString stringWithFormat:@"%@ %d,%d",[self monthEn:month],day,year];
        }
            break;
        default:
            break;
    }
    return strDate;
}

-(int)timeZone
{
    NSTimeZone *zone = [NSTimeZone localTimeZone];
    NSInteger seconds = [zone secondsFromGMT];
    int value = (int)seconds/3600;
     value = value>0?value+0x80:-value;
    return value;
}

//获取当月有多少天
- (NSInteger)getNumberOfDaysInMonth
{
   NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
   NSRange range = [calendar rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitMonth forDate:[NSDate date]];
   NSUInteger numberOfDaysInMonth = range.length;
    NSLog(@"getNumberOfDaysInMonth --- : %ld", numberOfDaysInMonth);

    return numberOfDaysInMonth;
}

//获取当年有多少天
- (NSInteger)getNumberOfDaysInYear
{
    NSCalendar *calender = [NSCalendar currentCalendar];
    NSDateComponents *comps =[calender components:(NSCalendarUnitYear | NSCalendarUnitMonth  | NSCalendarUnitWeekOfYear) fromDate:[NSDate date]];
    NSInteger count = 365;
    for (int i=1; i<=12; i++) {
        [comps setMonth:i];
        NSRange range = [calender rangeOfUnit:NSCalendarUnitDay inUnit: NSCalendarUnitMonth forDate: [calender dateFromComponents:comps]];
        count += range.length;
    }
    NSLog(@"getNumberOfDaysInYear --- : %ld", count);
    
    return count;
}

@end
