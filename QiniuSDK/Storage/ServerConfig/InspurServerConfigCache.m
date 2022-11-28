//
//  QNServerConfigCache.m
//  QiniuSDK
//
//  Created by yangsen on 2021/8/30.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "InspurServerConfigCache.h"
#import "InspurUtils.h"
#import "InspurFileRecorder.h"

#define kQNServerConfigDiskKey @"config"
#define kQNServerUserConfigDiskKey @"userConfig"

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
        data = [self.recorder get:kQNServerConfigDiskKey];
    }
    if (data == nil) {
        return nil;
    }

    NSError *error = nil;
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
    if (error != nil || ![info isKindOfClass:[NSDictionary class]]) {
        @synchronized (self) {
            [self.recorder del:kQNServerConfigDiskKey];
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
            [self.recorder set:kQNServerConfigDiskKey data:data];
        }
    }
}

//MARK: --- user config
- (InspurServerUserConfig *)getUserConfigFromDisk {
    NSData *data = nil;
    @synchronized (self) {
        data = [self.recorder get:kQNServerUserConfigDiskKey];
    }
    if (data == nil) {
        return nil;
    }

    NSError *error = nil;
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
    
    if (error != nil || ![info isKindOfClass:[NSDictionary class]]) {
        @synchronized (self) {
            [self.recorder del:kQNServerUserConfigDiskKey];
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
            [self.recorder set:kQNServerUserConfigDiskKey data:data];
        }
    }
}

- (void)removeConfigCache {
    @synchronized (self) {
        [self.recorder del:kQNServerConfigDiskKey];
        [self.recorder del:kQNServerUserConfigDiskKey];
    }
}

@end
