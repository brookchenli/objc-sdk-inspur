//
//  QNNetworkStatusManager.m
//  QiniuSDK
//
//  Created by Brook on 2020/11/17.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurUtils.h"
#import "InspurAsyncRun.h"
#import "InspurFileRecorder.h"
#import "InspurRecorderDelegate.h"
#import "InspurNetworkStatusManager.h"

@interface InspurNetworkStatus()
@property(nonatomic, assign)int speed;
@end
@implementation InspurNetworkStatus
- (instancetype)init{
    if (self = [super init]) {
        _speed = 200;
    }
    return self;
}
- (NSDictionary *)toDictionary{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setObject:@(self.speed) forKey:@"speed"];
    return dictionary;
}
+ (InspurNetworkStatus *)statusFromDictionary:(NSDictionary *)dictionary{
    InspurNetworkStatus *status = [[InspurNetworkStatus alloc] init];
    status.speed = [dictionary[@"speed"] intValue];
    return status;
}
@end


@interface InspurNetworkStatusManager()

@property(nonatomic, assign)BOOL isHandlingNetworkInfoOfDisk;
@property(nonatomic, strong)id<InspurRecorderDelegate> recorder;
@property(nonatomic, strong)NSMutableDictionary<NSString *, InspurNetworkStatus *> *networkStatusInfo;

@end
@implementation InspurNetworkStatusManager

+ (instancetype)sharedInstance{
    static InspurNetworkStatusManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[InspurNetworkStatusManager alloc] init];
        [manager initData];
    });
    return manager;
}

- (void)initData{
    self.isHandlingNetworkInfoOfDisk = NO;
    self.networkStatusInfo = [NSMutableDictionary dictionary];
    self.recorder = [InspurFileRecorder fileRecorderWithFolder:[[InspurUtils sdkCacheDirectory] stringByAppendingString:@"/NetworkStatus"] error:nil];
    [self asyncRecoverNetworkStatusFromDisk];
}

+ (NSString *)getNetworkStatusType:(NSString *)host
                                ip:(NSString *)ip {
    return [InspurUtils getIpType:ip host:host];
}

- (InspurNetworkStatus *)getNetworkStatus:(NSString *)type{
    if (type == nil || type.length == 0) {
        return nil;
    }
    InspurNetworkStatus *status = nil;
    @synchronized (self) {
        status = self.networkStatusInfo[type];
    }
    if (status == nil) {
        status = [[InspurNetworkStatus alloc] init];
    }
    return status;
}

- (void)updateNetworkStatus:(NSString *)type speed:(int)speed{
    if (type == nil || type.length == 0) {
        return;
    }
    
    @synchronized (self) {
        InspurNetworkStatus *status = self.networkStatusInfo[type];
        if (status == nil) {
            status = [[InspurNetworkStatus alloc] init];
            self.networkStatusInfo[type] = status;
        }
        status.speed = speed;
    }
    
    [self asyncRecordNetworkStatusInfo];
}


// ----- status 持久化
#define kNetworkStatusDiskKey @"NetworkStatus:v1.0.1"
- (void)asyncRecordNetworkStatusInfo{
    @synchronized (self) {
        if (self.isHandlingNetworkInfoOfDisk) {
            return;
        }
        self.isHandlingNetworkInfoOfDisk = YES;
    }
    InspurAsyncRun(^{
        [self recordNetworkStatusInfo];
        self.isHandlingNetworkInfoOfDisk = NO;
    });
}

- (void)asyncRecoverNetworkStatusFromDisk{
    @synchronized (self) {
        if (self.isHandlingNetworkInfoOfDisk) {
            return;
        }
        self.isHandlingNetworkInfoOfDisk = YES;
    }
    InspurAsyncRun(^{
        [self recoverNetworkStatusFromDisk];
        self.isHandlingNetworkInfoOfDisk = NO;
    });
}

- (void)recordNetworkStatusInfo{
    if (self.recorder == nil || self.networkStatusInfo == nil) {
        return;
    }
    
    NSDictionary *networkStatusInfo = nil;
    @synchronized(self) {
        networkStatusInfo = [self.networkStatusInfo copy];
    }
    NSMutableDictionary *statusInfo = [NSMutableDictionary dictionary];
    for (NSString *key in networkStatusInfo.allKeys) {
        NSDictionary *statusDictionary = [networkStatusInfo[key] toDictionary];
        if (statusDictionary) {
            [statusInfo setObject:statusDictionary forKey:key];
        }
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:statusInfo options:NSJSONWritingPrettyPrinted error:nil];
    if (data) {
        [self.recorder set:kNetworkStatusDiskKey data:data];
    }
}

- (void)recoverNetworkStatusFromDisk{
    if (self.recorder == nil) {
        return;
    }

    NSData *data = [self.recorder get:kNetworkStatusDiskKey];
    if (data == nil) {
        return;
    }

    NSError *error = nil;
    NSDictionary *statusInfo = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
    if (error != nil || ![statusInfo isKindOfClass:[NSDictionary class]]) {
        [self.recorder del:kNetworkStatusDiskKey];
        return;
    }

    NSMutableDictionary *networkStatusInfo = [NSMutableDictionary dictionary];
    for (NSString *key in statusInfo.allKeys) {
        NSDictionary *value = statusInfo[key];
        InspurNetworkStatus *status = [InspurNetworkStatus statusFromDictionary:value];
        if (status) {
            [networkStatusInfo setObject:status forKey:key];
        }
    }
    
    @synchronized(self) {
        [self.networkStatusInfo setValuesForKeysWithDictionary:networkStatusInfo];
    }
}

@end
