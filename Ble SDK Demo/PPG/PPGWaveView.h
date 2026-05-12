//
//  PPGWaveView.h
//  Ble SDK Demo
//
//  Created by yang sai on 2025/7/22.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPGWaveView : UIView
// 添加一个数据点
- (void)addPPGValues:(NSArray<NSNumber *> *)values;
@end

NS_ASSUME_NONNULL_END
