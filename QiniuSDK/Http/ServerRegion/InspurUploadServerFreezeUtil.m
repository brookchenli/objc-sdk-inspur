//
//  QNUploadServerFreezeUtil.m
//  QiniuSDK
//
//  Created by Brook on 2021/2/4.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurUtils.h"
#import "InspurUploadServerFreezeUtil.h"

@implementation InspurUploadServerFreezeUtil

+ (InspurUploadServerFreezeManager *)sharedHttp2Freezer {
    static InspurUploadServerFreezeManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[InspurUploadServerFreezeManager alloc] init];
    });
    return manager;
}

+ (InspurUploadServerFreezeManager *)sharedHttp3Freezer {
    static InspurUploadServerFreezeManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[InspurUploadServerFreezeManager alloc] init];
    });
    return manager;
}

+ (BOOL)isType:(NSString *)type frozenByFreezeManagers:(NSArray <InspurUploadServerFreezeManager *> *)freezeManagerList{
    if (!type || type.length == 0) {
        return YES;
    }
    if (!freezeManagerList || freezeManagerList.count == 0) {
        return NO;
    }
    
    BOOL isFrozen = NO;
    for (InspurUploadServerFreezeManager *freezeManager in freezeManagerList) {
        isFrozen = [freezeManager isTypeFrozen:type];
        if (isFrozen) {
            break;
        }
    }
    return isFrozen;
}

+ (NSString *)getFrozenType:(NSString *)host ip:(NSString *)ip {
    NSString *ipType = [InspurUtils getIpType:ip host:host];
    return [NSString stringWithFormat:@"%@-%@", host, ipType];
}

@end
