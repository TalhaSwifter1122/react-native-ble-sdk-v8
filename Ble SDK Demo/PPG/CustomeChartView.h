//
//  CustomeChartView.h
//  B031心率带
//
//  Created by LiPeng on 2017/7/24.
//  Copyright © 2017年 LiPeng. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CustomeChartView : UIView




@property(nonatomic,assign) float ShowTime;
@property (nonatomic, assign) int SingleNumber;
@property (nonatomic, assign) float MinValue;
@property (nonatomic,assign)  float MaxValue;
@property (nonatomic, assign) int MaxCount;
@property (nonatomic, assign) int blankCount;//空白的个数
@property (nonatomic, assign) float LineWidth;
@property (nonatomic, strong) UIColor *LineColor;
@property (nonatomic, strong) UIColor *LineColor1;


- (instancetype)initWithFrame:(CGRect)frame WithSingleNumber:(int)singleNumber WithMaxSeconds:(int)maxSeconds;
- (void)addShowDatasPPG:(NSArray *)datas;
- (void)addShowDatasECG:(NSArray *)datas;







@end
