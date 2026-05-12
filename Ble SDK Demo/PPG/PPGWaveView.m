//
//  PPGWaveView.m
//  Ble SDK Demo
//
//  Created by yang sai on 2025/7/22.
//

#import "PPGWaveView.h"

@interface PPGWaveView ()

@property (nonatomic, strong) NSMutableArray<NSNumber *> *ppgValues;
@property (nonatomic, strong) CAShapeLayer *waveLayer;
@property (nonatomic, strong) CADisplayLink *displayLink;

@property (nonatomic, assign) CGFloat maxAmplitude;
@property (nonatomic, assign) CGFloat scrollSpeed; // 每次滚动像素
@property (nonatomic, assign) NSInteger maxVisiblePoints;

@end

@implementation PPGWaveView


- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _ppgValues = [NSMutableArray array];
        _waveLayer = [CAShapeLayer layer];
        _waveLayer.strokeColor = [UIColor greenColor].CGColor;
        _waveLayer.fillColor = [UIColor clearColor].CGColor;
        _waveLayer.lineWidth = 2.0;
        [self.layer addSublayer:_waveLayer];

        _maxAmplitude = 100.0; // Y轴振幅（根据需要设置）
        _scrollSpeed = 1.0;    // 每帧横向移动多少像素
        _maxVisiblePoints = frame.size.width / _scrollSpeed;

        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateWave)];
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return self;
}

- (void)addPPGValues:(NSArray<NSNumber *> *)values {
    if (values.count == 0) return;

    // 限制最大数据量
    [self.ppgValues addObjectsFromArray:values];
    
    if (self.ppgValues.count > 2000) {
        [self.ppgValues removeObjectsInRange:NSMakeRange(0, self.ppgValues.count - 1000)];
    }
}


- (void)updateMaxAmplitudeIfNeeded {
    NSInteger count = self.ppgValues.count;
    if (count == 0) return;

    // 取最近500个点（或全部）用于动态评估
    NSInteger range = MIN(500, count);
    NSArray *recent = [self.ppgValues subarrayWithRange:NSMakeRange(count - range, range)];

    CGFloat max = 0;
    for (NSNumber *num in recent) {
        CGFloat val = fabs(num.floatValue);
        if (val > max) {
            max = val;
        }
    }

    // 设置最小限制，避免过小
    CGFloat minLimit = 30.0;

    max = MAX(max, minLimit);

    // 平滑调整：动画式趋近当前最大值
    CGFloat oldAmplitude = self.maxAmplitude;
    CGFloat newAmplitude = oldAmplitude * 0.9 + max * 0.1;

    self.maxAmplitude = newAmplitude;
}

- (void)updateWave {
    
    [self updateMaxAmplitudeIfNeeded]; // 动态调整 Y 轴范围
    
    if (self.ppgValues.count == 0) return;

    NSArray *visiblePoints = self.ppgValues.count > self.maxVisiblePoints ?
        [self.ppgValues subarrayWithRange:NSMakeRange(self.ppgValues.count - self.maxVisiblePoints, self.maxVisiblePoints)] :
        [self.ppgValues copy];

    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat x = 0;
    CGFloat height = self.bounds.size.height;
    CGFloat centerY = height / 2;
    
    NSMutableArray<NSValue *> *points = [NSMutableArray array];

    for (NSNumber *num in visiblePoints) {
        CGFloat value = [num floatValue];
        CGFloat normalized = value / _maxAmplitude; // [0 ~ 1]
        CGFloat y = centerY - normalized * (height * 0.4); // 占 80% 高度，避免贴边
        [points addObject:[NSValue valueWithCGPoint:CGPointMake(x, y)]];
        x += _scrollSpeed;
    }

    if (points.count < 2) return;

    // 平滑绘制（使用二次贝塞尔曲线）
    [path moveToPoint:points[0].CGPointValue];
    for (NSInteger i = 1; i < points.count - 1; i++) {
        CGPoint prev = points[i - 1].CGPointValue;
        CGPoint curr = points[i].CGPointValue;
        CGPoint next = points[i + 1].CGPointValue;

        // 控制点为当前点和前后点的中点
        CGPoint mid1 = CGPointMake((prev.x + curr.x) / 2.0, (prev.y + curr.y) / 2.0);
        CGPoint mid2 = CGPointMake((curr.x + next.x) / 2.0, (curr.y + next.y) / 2.0);

        [path addQuadCurveToPoint:mid2 controlPoint:curr];
    }

    self.waveLayer.path = path.CGPath;
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
