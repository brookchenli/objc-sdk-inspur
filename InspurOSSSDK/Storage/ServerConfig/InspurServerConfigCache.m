//
//  InspurServerConfigCache.m
//  InspurOSSSDK
//
//  Created by Brook on 2021/8/30.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurServerConfigCache.h"
#import "InspurUtils.h"
#import "InspurFileRecorder.h"

#define kInspurServerConfigDiskKey @"config"
#define kInspurServerUserConfigDiskKey @"userConfig"

@interface InspurServerConfigCache(){
    InspurServerConfig *_config;
    InspurServerUserConfig *_userConfig;
}
@property(nonatomic, strong)id<InspurRecorderDelegate> recorder;
@end
@implementation InspurServerConfigCache

- (instancetype)init {
    if (self = [super init]) {
        self.recorder = [InspurFileRecorder fileRecorderWithFolder:[[InspurUtils sdkCacheDirectory] stringByAppendingString:@"/ServerConfig"] error:nil];
    }
    return self;
}

//MARK: --- config
- (InspurServerConfig *)getConfigFromDisk {
    NSData *data = nil;
    @synchronized (self) {
        data = [self.recorder get:kInspurServerConfigDiskKey];
    }
    if (data == nil) {
        return nil;
    }

    NSError *error = nil;
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
    if (error != nil || ![info isKindOfClass:[NSDictionary class]]) {
        @synchronized (self) {
            [self.recorder del:kInspurServerConfigDiskKey];
        }
        return nil;
    }
    return [InspurServerConfig config:info];
}

- (void)saveConfigToDisk:(InspurServerConfig *)config {
    if (self.recorder == nil || config.info == nil) {
        return;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:config.info options:NSJSONWritingPrettyPrinted error:nil];
    if (data) {
        @synchronized (self) {
            [self.recorder set:kInspurServerConfigDiskKey data:data];
        }
    }
}

//MARK: --- user config
- (InspurServerUserConfig *)getUserConfigFromDisk {
    NSData *data = nil;
    @synchronized (self) {
        data = [self.recorder get:kInspurServerUserConfigDiskKey];
    }
    if (data == nil) {
        return nil;
    }

    NSError *error = nil;
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
    
    if (error != nil || ![info isKindOfClass:[NSDictionary class]]) {
        @synchronized (self) {
            [self.recorder del:kInspurServerUserConfigDiskKey];
        }
        return nil;
    }
    return [InspurServerUserConfig config:info];
}

- (void)saveUserConfigToDisk:(InspurServerUserConfig *)config {
    if (self.recorder == nil || config.info == nil) {
        return;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:config.info options:NSJSONWritingPrettyPrinted error:nil];
    if (data) {
        @synchronized (self) {
            [self.recorder set:kInspurServerUserConfigDiskKey data:data];
        }
    }
}

- (void)removeConfigCache {
    @synchronized (self) {
        [self.recorder del:kInspurServerConfigDiskKey];
        [self.recorder del:kInspurServerUserConfigDiskKey];
    }
}

@end
