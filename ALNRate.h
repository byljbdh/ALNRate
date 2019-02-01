//
//  ALNRate.h
//  tripBySoyoung
//
//  Created by alanLuo on 2019/1/29.
//  Copyright © 2019 soyoung. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ALNRate : NSObject
+ (instancetype)sharedInstance;
/**use it to show view*/
- (void)showAlertView;
@property (nonatomic, assign,readonly) BOOL shouldPrompt;

@property (nonatomic, assign) BOOL OnlyPromptForLatestVersion;
/**how long should prompt after installed or updated, default is 7 days*/
@property (nonatomic, assign) NSInteger daysUntilPrompt;
/**how many times should prompt within a week, default is 7 times*/
@property (nonatomic, assign) NSInteger usesUntilPrompt;
/**how many times should prompt again since user declined, default is 3 times*/
@property (nonatomic, assign) NSInteger usesCountAfterLastDecline;
@end

NS_ASSUME_NONNULL_END
