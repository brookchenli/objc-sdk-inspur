//
//  QNServerUserConfig.m
//  QiniuSDK
//
//  Created by Brook on 2021/8/30.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurServerUserConfig.h"

@interface InspurServerUserConfig()
@property(nonatomic, strong)NSDictionary *info;
@property(nonatomic, assign)double timestamp;
@property(nonatomic, assign)long ttl;
@property(nonatomic, strong)NSNumber *http3Enable;
@property(nonatomic, strong)NSNumber *retryMax;
@property(nonatomic, strong)NSNumber *networkCheckEnable;
@end
@implementation InspurServerUserConfig

+ (instancetype)config:(NSDictionary *)info {
    InspurServerUserConfig *config = [[InspurServerUserConfig alloc] init];
    config.ttl = [info[@"ttl"] longValue];
    config.http3Enable = info[@"http3"][@"enabled"];
    config.networkCheckEnable = info[@"network_check"][@"enabled"];
    
    if (config.ttl < 10) {
        config.ttl = 10;
    }
    
    NSMutableDictionary *mutableInfo = [info mutableCopy];
    if (info[@"timestamp"] != nil) {
        config.timestamp = [info[@"timestamp"] doubleValue];
    }
    if (config.timestamp == 0) {
        config.timestamp = [[NSDate date] timeIntervalSince1970];
        mutableInfo[@"timestamp"] = @(config.timestamp);
    }
    config.info = [mutableInfo copy];
    return config;
}

- (BOOL)isValid {
    return [[NSDate date] timeIntervalSince1970] < (self.timestamp + self.ttl);
}

@end
