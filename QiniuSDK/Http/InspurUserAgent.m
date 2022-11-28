//
//  QNUserAgent.m
//  QiniuSDK
//
//  Created by Brook on 14-9-29.
//  Copyright (c) 2014年 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>
#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import <MobileCoreServices/MobileCoreServices.h>
#import <UIKit/UIKit.h>
#else
#import <CoreServices/CoreServices.h>
#endif

#import "InspurUserAgent.h"
#import "InspurUtils.h"

static NSString *qn_clientId(void) {
#if __IPHONE_OS_VERSION_MIN_REQUIRED
    NSString *s = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    if (s == nil) {
        s = @"simulator";
    }
    return s;
#else
    long long now_timestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    int r = arc4random() % 1000;
    return [NSString stringWithFormat:@"%lld%u", now_timestamp, r];
#endif
}

static NSString *qn_userAgent(NSString *id, NSString *ak) {
    NSString *addition = @"";
#if DEBUG
    addition = @"_Debug";
#endif
    
#if __IPHONE_OS_VERSION_MIN_REQUIRED
    return [NSString stringWithFormat:@"QiniuObject-C%@/%@ (%@; iOS %@; %@; %@)", addition, [InspurUtils sdkVersion], [[UIDevice currentDevice] model], [[UIDevice currentDevice] systemVersion], id, ak];
#else
    return [NSString stringWithFormat:@"QiniuObject-C%@/%@ (Mac OS X %@; %@; %@)", addition, [QNUtils sdkVersion], [[NSProcessInfo processInfo] operatingSystemVersionString], id, ak];
#endif
}

@interface InspurUserAgent ()
@property (nonatomic) NSString *ua;
@end

@implementation InspurUserAgent

- (NSString *)description {
    return _ua;
}

- (instancetype)init {
    if (self = [super init]) {
        _id = qn_clientId();
    }
    return self;
}

/**
 *  UserAgent
 */
- (NSString *)getUserAgent:(NSString *)access {
    NSString *ak;
    if (access == nil || access.length == 0) {
        ak = @"-";
    } else {
        ak = access;
    }
    return qn_userAgent(_id, ak);
}

/**
 *  单例
 */
+ (instancetype)sharedInstance {
    static InspurUserAgent *sharedInstance = nil;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });

    return sharedInstance;
}

@end
