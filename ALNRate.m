//
//  ALNRate.m
//  tripBySoyoung
//
//  Created by alanLuo on 2019/1/29.
//  Copyright © 2019 soyoung. All rights reserved.
//

#import "ALNRate.h"
#import <StoreKit/StoreKit.h>
static NSString *const updatedDateKey = @"updatedDateKey";
static NSString *const useCountKey = @"useCountKey";
static NSString *const aNewWeekStartDateKey = @"aNewWeekStartDateKey";
static NSString *const usesPerWeekKey = @"usesPerWeekKey";
static NSString *const OnlyPromptForLatestVersionKey = @"OnlyPromptForLatestVersionKey";
static NSString *const daysUntilPromptKey = @"daysUntilPromptKey";
static NSString *const usesUntilPromptKey = @"usesUntilPromptKey";
static NSString *const usesCountAfterLastDeclineKey = @"usesCountAfterLastDeclineKey";
static NSString *const usesCountAfterDeclineKey = @"usesCountAfterDeclineKey";
static NSString *const ratedCurrentVersionKey = @"ratedCurrentVersionKey";

@interface ALNRate ()<UIAlertViewDelegate,SKStoreProductViewControllerDelegate>
@property (nonatomic, strong) UIAlertView *visibleAlert;

@property (nonatomic, strong) NSString *appStoreCountry;

@property (nonatomic, assign) BOOL shouldPrompt;

@property (nonatomic, assign) BOOL sameVersionWithAppstore;

@property (nonatomic, assign) BOOL ratedCurrentVersion;

/**date app installed or updated*/
@property (nonatomic, copy) NSDate *updatedDate;

/**total useCount since app installed*/
@property (nonatomic, assign) NSInteger useCount;

/**use time after user decline*/
@property (nonatomic, assign) NSInteger usesCountAfterDecline;

@property (nonatomic, copy) NSDate *aNewWeekStartDate;

/**uses count since aNewWeekStartDate*/
@property (nonatomic, assign) NSInteger usesPerWeek;
@end
@implementation ALNRate
static ALNRate *sharedInstance = nil;
+ (void)load{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self sharedInstance];
    });
}
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}
- (instancetype)init{
    self = [super init];
    NSAssert([self appStoreID] != nil, @"appStore ID could not be nil");
    self.shouldPrompt = NO;
    [self setUpProperty];
    [self checkVersionAtAppsotre];
    return self;
}
- (void)setUpProperty{
    [self updateUpdatedDate];
    self.useCount += 1;
    [self updateUsesPerWeek];
}
#pragma mark - checkOutShouldPrompt
- (void)checkOutShouldPrompt{
    self.shouldPrompt = YES;
    if(![self checkDaysUntilPrompt]){
        NSLog(@"it should not prompt while no reach the daysUntilPrompt,");
        self.shouldPrompt = NO;
        return;
    }
    if(self.OnlyPromptForLatestVersion == YES && self.sameVersionWithAppstore == NO){
        //after version check request done, the sameVersionWithAppstore would be set
        NSLog(@"it's old version and the OnlyPromptForLatestVersion is YES, no prompt");
        self.shouldPrompt = NO;
        return;
    }else{
        self.shouldPrompt = YES;
    }
    if(self.usesPerWeek < self.usesUntilPrompt){
        self.shouldPrompt = NO;
        NSLog(@"it's not enough use times compare with usesUntilPrompt, no prompt");
        return;
    }
    if(self.usesCountAfterDecline != 0 && self.useCount - self.usesCountAfterDecline < self.usesCountAfterLastDecline){
        self.shouldPrompt = NO;
        NSLog(@"it's not far from the day decline, set usesCountAfterLastDecline to change , no prompt");
        return;
    }
    if(self.ratedCurrentVersion == YES){
        self.shouldPrompt = NO;
        NSLog(@"done rated for this version, no prompt");
        return;
    }
}

- (void)checkVersionAtAppsotre{
    //if the OnlyPromptForLatestVersion is set to NO, no need to checkversion At Appstore, just check prompt
    if(self.OnlyPromptForLatestVersion == NO){
        [self checkOutShouldPrompt];
        return;
    }
    NSDictionary *infoDic=[[NSBundle mainBundle] infoDictionary];
    NSLog(@"%@",infoDic);
    NSString *currentVersion = infoDic[@"CFBundleShortVersionString"];
    
    __block NSError *jsonError;
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionTask *task = [session dataTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[self configureAppStoreUrl]]] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if(data == nil){
            NSLog(@"dataEmpty");
            return;
        }
        NSDictionary *appInfoDic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&jsonError];
        if (jsonError) {
            NSLog(@"UpdateAppError:%@",jsonError);
            return;
        }
        
        NSArray *array = appInfoDic[@"results"];
        if (array.count < 1) {
            NSLog(@"not app match this appID");
            return;
        }
        
        NSDictionary *dic = array[0];
        NSString *appStoreVersion = dic[@"version"];
        
        // sameversion with appStore , should check prompt or not
        if([currentVersion floatValue] == [appStoreVersion floatValue]) {
            self.sameVersionWithAppstore = YES;
        }
        [self checkOutShouldPrompt];
    }];
    [task resume];
}
- (BOOL)checkDaysUntilPrompt{
    NSTimeInterval updatedDateSince1970 = [self.updatedDate timeIntervalSince1970] ;

    NSTimeInterval currentDateSince1970 = [[NSDate date] timeIntervalSince1970];
    
    NSInteger daysBetween = (NSInteger)(currentDateSince1970 - updatedDateSince1970)/(24*60*60);
    
    return daysBetween >= self.daysUntilPrompt;
}
- (void)updateUsesPerWeek{
    //判断是否是又一个七天了.
    NSTimeInterval aNewWeekStartDateSince1970 = [self.aNewWeekStartDate timeIntervalSince1970] ;
    
    NSTimeInterval currentDateSince1970 = [[NSDate date] timeIntervalSince1970];
    
    NSInteger daysBetween = (NSInteger)(currentDateSince1970 - aNewWeekStartDateSince1970)/(24*60*60);
    if(daysBetween >= 7){//如果超过7天,需要更新为新的一周
        self.aNewWeekStartDate = [NSDate date];
        self.usesPerWeek = 1;
    }else{
        self.usesPerWeek += 1;
    }
}
- (void)showAlertView{
    if(self.shouldPrompt == NO){
        return;
    }
    NSString *title = @"给个好评吧";
    NSString *message = @"APP需要亲的支持~\n";
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:(id<UIAlertViewDelegate>)self
                                          cancelButtonTitle:nil
                                          otherButtonTitles:self.rateButtonLabel, nil];
    if ([self showRemindButton])
    {
        [alert addButtonWithTitle:self.remindButtonLabel];
    }
    
    self.visibleAlert = alert;
    [self.visibleAlert show];
}


#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if(buttonIndex == 0){//just go comment
        if(([[[UIDevice currentDevice] systemVersion] floatValue] >= 12.0)){
            [self loadAppStoreController];
        }else{
            [self jump2AppStore];
        }
    }else{//user decline
        [self remindMeLater];
    }
}
- (void)didRate{
    self.ratedCurrentVersion = YES;
    self.usesCountAfterDecline = 0;
}
- (void)remindMeLater{
    self.usesCountAfterDecline = self.useCount;
}
- (void)jump2AppStore{
    __weak typeof(self) weakSelf = self;
    if([[UIApplication sharedApplication] openURL:[NSURL URLWithString:[self configureAppStoreCommentUrl]]]){
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[self configureAppStoreCommentUrl]] options:@{} completionHandler:^(BOOL success) {
            [weakSelf didRate];
        }];
    }
}
//iOS12 could use AppStoreController
- (void)loadAppStoreController{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *keyVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        if(keyVC == nil){
            [self jump2AppStore];
            return;
        }
        SKStoreProductViewController *storeProductViewContorller = [[SKStoreProductViewController alloc] init];
        storeProductViewContorller.delegate=self;
        [storeProductViewContorller loadProductWithParameters:@{SKStoreProductParameterITunesItemIdentifier:[self appStoreID]} completionBlock:^(BOOL result, NSError * _Nullable error) {
            if(error)  {
                NSLog(@"loading failed");
            }else{
                // 模态弹出appstore
                [keyVC presentViewController:storeProductViewContorller animated:YES completion:nil];
            }
        }];
    });

}

//AppStore取消按钮监听
- (void)productViewControllerDidFinish:(SKStoreProductViewController*)viewController{
    [self didRate];
    [viewController dismissViewControllerAnimated:YES completion:nil];
}
#pragma mark - property setter getter
- (NSString *)appStoreCountry{
    if(!_appStoreCountry){
        _appStoreCountry = [(NSLocale *)[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
    }
    return _appStoreCountry;
}
- (NSString *)configureAppStoreUrl{
    return [NSString stringWithFormat:@"https://itunes.apple.com/%@/lookup?id=%@",self.appStoreCountry,[self appStoreID]];
}
- (NSString *)configureAppStoreCommentUrl{
    return [NSString stringWithFormat:
            @"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=%@",
            [self appStoreID]];
}
- (BOOL)showRemindButton
{
    return [self.remindButtonLabel length];
}

- (BOOL)showCancelButton
{
    return NO;
}

- (NSString *)rateButtonLabel
{
    return @"现在就去";
}

- (NSString *)remindButtonLabel
{
    return @"下次再说";
}
- (NSDate *)updatedDate{
    return [[NSUserDefaults standardUserDefaults] objectForKey:updatedDateKey];
}

- (void)setUpdatedDate:(NSDate *)updatedDate{
    [[NSUserDefaults standardUserDefaults] setObject:updatedDate forKey:updatedDateKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (NSInteger)useCount{
    return [[NSUserDefaults standardUserDefaults] integerForKey:useCountKey];
}
- (void)setUseCount:(NSInteger)useCount{
    [[NSUserDefaults standardUserDefaults] setInteger:useCount forKey:useCountKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (NSInteger)usesPerWeek{
    return [[NSUserDefaults standardUserDefaults] integerForKey:usesPerWeekKey];
}
- (void)setUsesPerWeek:(NSInteger)usesPerWeek{
    [[NSUserDefaults standardUserDefaults] setInteger:usesPerWeek forKey:usesPerWeekKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (NSDate *)aNewWeekStartDate{
    return [[NSUserDefaults standardUserDefaults] objectForKey:aNewWeekStartDateKey];
}
- (void)setaNewWeekStartDate:(NSDate *)aNewWeekStartDate{
    [[NSUserDefaults standardUserDefaults] setObject:aNewWeekStartDate forKey:aNewWeekStartDateKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (BOOL)OnlyPromptForLatestVersion{
    return [[NSUserDefaults standardUserDefaults] boolForKey:OnlyPromptForLatestVersionKey];
}
- (void)setOnlyPromptForLatestVersion:(BOOL)OnlyPromptForLatestVersion{
    [[NSUserDefaults standardUserDefaults] setBool:OnlyPromptForLatestVersion forKey:OnlyPromptForLatestVersionKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (NSInteger)daysUntilPrompt{
    return [[NSUserDefaults standardUserDefaults] integerForKey:daysUntilPromptKey];
}
- (void)setDaysUntilPrompt:(NSInteger)daysUntilPrompt{
    [[NSUserDefaults standardUserDefaults] setInteger:daysUntilPrompt forKey:daysUntilPromptKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (NSInteger)usesUntilPrompt{
    return [[NSUserDefaults standardUserDefaults] integerForKey:usesUntilPromptKey];
}
- (void)setUsesUntilPrompt:(NSInteger)usesUntilPrompt{
    [[NSUserDefaults standardUserDefaults] setInteger:usesUntilPrompt forKey:usesUntilPromptKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (NSInteger)usesCountAfterLastDecline{
    return [[NSUserDefaults standardUserDefaults] integerForKey:usesCountAfterLastDeclineKey];
}
- (void)setUsesCountAfterLastDecline:(NSInteger)usesCountAfterLastDecline{
    [[NSUserDefaults standardUserDefaults] setInteger:usesCountAfterLastDecline forKey:usesCountAfterLastDeclineKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (NSInteger)usesCountAfterDecline{
    return [[NSUserDefaults standardUserDefaults] integerForKey:usesCountAfterDeclineKey];
}
- (void)setusesCountAfterDecline:(NSInteger)usesCountAfterDecline{
    [[NSUserDefaults standardUserDefaults] setInteger:usesCountAfterDecline forKey:usesCountAfterDeclineKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (BOOL)ratedCurrentVersion{
    return [[NSUserDefaults standardUserDefaults] boolForKey:ratedCurrentVersionKey];
}
- (void)setRatedCurrentVersion:(BOOL)ratedCurrentVersion{
    [[NSUserDefaults standardUserDefaults] setBool:ratedCurrentVersion forKey:ratedCurrentVersionKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (NSString *)appStoreID{
        return @"";
}
#pragma mark - private
- (void)firstInit{//only run one time set the default property
    self.updatedDate = [NSDate date];
    self.aNewWeekStartDate = [NSDate date];
    self.daysUntilPrompt = 7;
    self.OnlyPromptForLatestVersion = YES;
    self.usesUntilPrompt = 7;
    self.usesCountAfterLastDecline = 3;
}
- (void)updateUpdatedDate{
    NSString *currentVersion = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"];
    NSString *preVersion = [self getPreVersionForKey:@"preVersion"];
    if(preVersion == nil || preVersion.length == 0){//firstUsed
        [self firstInit];
        [self saveVersion:currentVersion forkey:@"preVersion"];
    }else{
        if ([preVersion isEqualToString:currentVersion]){//sameVersion
            NSLog(@"sameVersion");
        }else{
            self.updatedDate = [NSDate date];
            [self saveVersion:currentVersion forkey:@"preVersion"];
        }
    }
    
}
- (NSString *)getPreVersionForKey:(NSString *)key{
    return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}

- (void)saveVersion:(NSString *)curVersion forkey:(NSString *)key{
    [[NSUserDefaults standardUserDefaults] setValue:curVersion forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];

}
@end
