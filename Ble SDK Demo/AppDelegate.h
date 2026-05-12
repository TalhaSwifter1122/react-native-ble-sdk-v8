//
//  AppDelegate.h
//  Ble SDK Demo
//
//  Created by yang sai on 2022/4/18.
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property float autoSizeScaleX;

@property float autoSizeScaleY;

@end

CG_INLINE CGRect
CGRectMake1(CGFloat x, CGFloat y, CGFloat width, CGFloat height)

{
    
    AppDelegate *myDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    
    CGRect rect;
    
    rect.origin.x = x * myDelegate.autoSizeScaleX; rect.origin.y = y * myDelegate.autoSizeScaleY;
    
    rect.size.width = width * myDelegate.autoSizeScaleX; rect.size.height = height * myDelegate.autoSizeScaleY;
    
    return rect;
    
}

CG_INLINE CGPoint
CGPointMake1(CGFloat x, CGFloat y)
{
    AppDelegate *myDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    CGPoint point;
    point.x = x * myDelegate.autoSizeScaleX;
    point.y = y * myDelegate.autoSizeScaleY;
    return point;
}
