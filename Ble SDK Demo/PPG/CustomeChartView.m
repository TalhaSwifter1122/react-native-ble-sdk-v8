//
//  CustomeChartView.m
//  B031心率带
//
//  Created by LiPeng on 2017/7/24.
//  Copyright © 2017年 LiPeng. All rights reserved.
//

#import "CustomeChartView.h"




@interface CustomeChartView ()
{
    
    BOOL start;
    int Count;
    float chartwidth;
    float chartheight;
        
    NSMutableArray *allDatas;
    int DataBase;//基础值
}
@property(nonatomic,assign)NSInteger index;
@end



@implementation CustomeChartView

@synthesize MaxCount,MinValue,MaxValue,LineWidth,LineColor,LineColor1,SingleNumber,blankCount;



- (instancetype)initWithFrame:(CGRect)frame WithSingleNumber:(int)singleNumber WithMaxSeconds:(int)maxSeconds
{
    self = [super initWithFrame:frame];
    
    if (self) {
        self.backgroundColor =  [UIColor clearColor];
        
        chartwidth = self.frame.size.width;    //上边title30,下边刻度20
        chartheight = self.frame.size.height - 30;  //左边刻度30，右边标注20
        
        _ShowTime = maxSeconds;
        MaxCount = _ShowTime*singleNumber;
        SingleNumber = singleNumber;
        LineWidth = 1.5;
    
        LineColor = [UIColor colorWithRed:228 / 255.0 green:35 / 255.0 blue:42 / 255.0 alpha:1];
        allDatas = [[[NSMutableArray alloc] init] mutableCopy];
        [self addCalibration];
    }
    
    return self;
}


- (void)addCalibration
{
    float width = chartwidth/_ShowTime;
    for (int i = 0; i < (int)(chartwidth/width)+1; i++) {

            UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
            label.tag = 2;
            label.text = [NSString stringWithFormat:@"%dS",i];
            label.textColor = [UIColor colorWithRed:0xc8/255.0 green:0xc8/255.0 blue:0xc8/255.0 alpha:1];
            label.font = [UIFont systemFontOfSize:10];
         if(i==(int)(chartwidth/width))
            label.center = CGPointMake(width*i, chartheight+8);
         else
            label.center = CGPointMake(10+width*i, chartheight+8);
        if(i!=0)
             label.textAlignment = NSTextAlignmentLeft;
        else
            label.textAlignment = NSTextAlignmentCenter;
            [self addSubview:label];
    }
    
}
- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextClearRect(context, rect);
    CGContextSetShouldAntialias(context, YES ); //抗锯齿
    CGContextSetRGBStrokeColor(context, 1 / 255.0, 0x34 / 255.0, 0x49 / 255.0, 0.2);  //线的颜色
    //画粗线格子
    float width = chartwidth/_ShowTime/5.0; //每秒钟分成5格  每格200ms
    
    int temp = (int)(chartheight/width)+1;
    float tempHeight = (temp * width-chartheight);
    CGContextSetLineWidth(context, 0.3);
    //横线
    for (int i = 0; i < (int)(chartheight/width)+1; i++) {
        CGContextBeginPath(context);
        CGContextMoveToPoint(context,0, chartheight-i*width-tempHeight);
        CGContextAddLineToPoint(context, chartwidth, chartheight-i*width-tempHeight);
        CGContextStrokePath(context);
    }
    //竖线
    for (int i = 0; i < (int)(chartwidth/width)+1; i++) {
        if(i%5==0&&i!=0)
            CGContextSetLineWidth(context, 1);
        else
            CGContextSetLineWidth(context, 0.3);
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, width*i, chartheight);
        CGContextAddLineToPoint(context,width*i, 0);
        CGContextStrokePath(context);
    }
    CGContextSetLineWidth(context, 1);
    CGContextSetStrokeColorWithColor(context, LineColor.CGColor);
    CGContextSetLineJoin(context,kCGLineJoinRound);
    for (int i = 0; i < allDatas.count; i++) {
        NSNumber *value = allDatas[i];
        CGPoint pointitem = CGPointMake(i*(chartwidth/(_ShowTime*SingleNumber)),(DataBase-value.floatValue)/((float)(MaxValue-MinValue))*chartheight);
       // CGContextRef context2 = UIGraphicsGetCurrentContext();
        if (i==0) {
            NSInteger idx = self.index == 0?(allDatas.count-1):self.index;
            
            if(allDatas.count<=idx){
                return;
            }
            NSNumber *value2 = allDatas[idx];
            if(allDatas.count>idx && idx>0){
                value2 = allDatas[idx - 1];
            }
            
            CGPoint pointitem2 = CGPointMake(idx*(chartwidth/(_ShowTime*SingleNumber)),(DataBase-value2.floatValue)/((float)(MaxValue-MinValue))*chartheight);
            
            
            CGFloat glowRadius = 6;
            CGContextSetShadowWithColor(context, CGSizeZero, glowRadius, [[UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:0.8] CGColor]);
            CGContextSetRGBFillColor(context, 0xfb/255.0, 0x0e/255.0, 0x3b/255.0, 1);//颜色
            CGContextAddArc(context, pointitem2.x, pointitem2.y, 4, 0, 2*M_PI, 0);
            CGContextFillPath(context);
         
            
            CGContextDrawPath(context, kCGPathFill);
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, pointitem.x, pointitem.y);
             
            
            
            
        }
        else if (i != allDatas.count - 1) {
            if (self.index !=0 && i >=self.index && i<=(self.index+blankCount)) {
                
                if (i == self.index+blankCount-1) {
                    CGContextMoveToPoint(context, pointitem.x, pointitem.y);
                }
                
            }else{
                CGContextAddLineToPoint(context, pointitem.x, pointitem.y);
            }
            
        }
        else {
            CGContextStrokePath(context);
        }
    }
}



- (void)addShowDatasECG:(NSArray *)datas
{
   
    
    if(datas.count==0)
       {
           self.index = 0;
           start = NO;
           [allDatas removeAllObjects];
       }
    if (allDatas.count+datas.count<=MaxCount) {
          [allDatas addObjectsFromArray:datas];
      }
      else {
          [allDatas removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(self.index, datas.count)]];
          NSMutableIndexSet *idxSet1 = [[NSMutableIndexSet alloc] init];
          [idxSet1 addIndexesInRange:NSMakeRange(self.index, datas.count)];
          [allDatas insertObjects:datas atIndexes:idxSet1];
          self.index += datas.count;
          if (self.index >= MaxCount) {
              self.index = self.index - MaxCount;
          }
      }
      self.MaxValue = 2;
      self.MinValue = -2;
         DataBase = 2;
      [self setNeedsDisplay];

}

- (void)addShowDatasPPG:(NSArray *)datas
{
    
    
    if(datas.count==0)
    {
        self.index = 0;
        [allDatas removeAllObjects];
    }
    if (allDatas.count+datas.count<=MaxCount) {
        [allDatas addObjectsFromArray:datas];
    }
    else {
        int diff = (int)(allDatas.count+datas.count)-MaxCount;
        if(diff%(datas.count)!=0)
        {
            NSArray * array =  [datas subarrayWithRange:NSMakeRange(0, datas.count-diff)];
            [allDatas addObjectsFromArray:array];
            
            NSArray * tempArray = [datas subarrayWithRange:NSMakeRange(datas.count-diff, diff)];
            [allDatas removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(self.index, tempArray.count)]];
            NSMutableIndexSet *idxSet1 = [[NSMutableIndexSet alloc] init];
            [idxSet1 addIndexesInRange:NSMakeRange(self.index, tempArray.count)];
            [allDatas insertObjects:tempArray atIndexes:idxSet1];
            self.index += tempArray.count;
            if (self.index >= MaxCount) {
                self.index = self.index - MaxCount;
            }
        }
        else
        {
            if(self.index+datas.count>MaxCount)
            {
               int diff = (int)(self.index+datas.count)-MaxCount;
                NSArray * array =  [datas subarrayWithRange:NSMakeRange(0, datas.count-diff)];
               [allDatas removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(self.index, array.count)]];
                NSMutableIndexSet *idxSet = [[NSMutableIndexSet alloc] init];
                [idxSet addIndexesInRange:NSMakeRange(self.index, array.count)];
                [allDatas insertObjects:array atIndexes:idxSet];
                
                NSArray * tempArray = [datas subarrayWithRange:NSMakeRange(datas.count-diff, diff)];
                [allDatas removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, tempArray.count)]];
                NSMutableIndexSet *idxSet1 = [[NSMutableIndexSet alloc] init];
                [idxSet1 addIndexesInRange:NSMakeRange(0, tempArray.count)];
                [allDatas insertObjects:tempArray atIndexes:idxSet1];
            }
            else{
                [allDatas removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(self.index, datas.count)]];
                NSMutableIndexSet *idxSet1 = [[NSMutableIndexSet alloc] init];
                [idxSet1 addIndexesInRange:NSMakeRange(self.index, datas.count)];
                [allDatas insertObjects:datas atIndexes:idxSet1];
            }
            self.index += datas.count;
            if (self.index >= MaxCount) {
                self.index = self.index - MaxCount;
            }
        }
    }
    float max = [[allDatas valueForKeyPath:@"@max.intValue"] floatValue];//求最大值
    float min = [[allDatas valueForKeyPath:@"@min.intValue"] floatValue];//求最小值
    self.MaxValue = max+(max-min)/2;
    self.MinValue = min-(max-min)/2;
    DataBase = max+(max-min)/2;
    [self setNeedsDisplay];
}











@end
