//
//  QNReportConfig.m
//  QiniuSDK
//
//  Created by Brook on 2020/7/14.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurReportConfig.h"
#import "InspurConfig.h"
#import "InspurUtils.h"

@implementation InspurReportConfig

+ (instancetype)sharedInstance {
    
    static InspurReportConfig *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _reportEnable = YES;
        _interval = 0.5;
        _serverHost = kInspurUpLogHost;
        _recordDirectory = [NSString stringWithFormat:@"%@/report", [InspurUtils sdkCacheDirectory]];
        _maxRecordFileSize = 20 * 1024 * 1024;
        _uploadThreshold = 16 * 1024;
        _timeoutInterval = 10;
    }
    return self;
}

- (NSString *)serverURL {
    return [NSString stringWithFormat:@"https://%@/log/4?compressed=gzip", _serverHost];
}
@end
