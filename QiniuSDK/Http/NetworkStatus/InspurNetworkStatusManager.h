//
//  QNNetworkStatusManager.h
//  InspurOSSSDK
//
//  Created by Brook on 2020/11/17.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface InspurNetworkStatus : NSObject

/// 网速 单位：kb/s   默认：200kb/s
@property(nonatomic, assign, readonly)int speed;

@end


#define kQNNetworkStatusManager [InspurNetworkStatusManager sharedInstance]
@interface InspurNetworkStatusManager : NSObject


+ (instancetype)sharedInstance;

+ (NSString *)getNetworkStatusType:(NSString *)host
                                ip:(NSString *)ip;

- (InspurNetworkStatus *)getNetworkStatus:(NSString *)type;

- (void)updateNetworkStatus:(NSString *)type
                      speed:(int)speed;

@end

NS_ASSUME_NONNULL_END
