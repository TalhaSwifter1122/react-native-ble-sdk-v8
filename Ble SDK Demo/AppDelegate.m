//
//  AppDelegate.m
//  Ble SDK Demo
//
//  Created by yang sai on 2022/4/18.
//

#import "AppDelegate.h"
#import "mainView.h"
@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    
    mainView * myMianView= [[mainView alloc]init];
    UINavigationController * nav = [[UINavigationController alloc]initWithRootViewController:myMianView];
    [nav setNavigationBarHidden:YES];
    [nav preferredStatusBarStyle];
    self.window.rootViewController = nav;
    [self baseSet];
    return YES;
}


-(void)baseSet
{
    [[YCLanguageTools shareInstance] initUserLanguage];
    [[NewBle sharedManager] SetUpCentralManager];
    [[MyFileView sharedManager] CreateFile:@"Ble SDK Demo.txt"];
    // Server URL is configured from React Native via WearableModule.configure()
}



@end
