//
//  QNConfiguration.m
//  QiniuSDK
//
//  Created by bailong on 15/5/21.
//  Copyright (c) 2015年 Qiniu. All rights reserved.
//

#import "InspurConfiguration.h"
#import "InspurResponseInfo.h"
#import "InspurUpToken.h"
#import "InspurReportConfig.h"
#import "InspurAutoZone.h"
#import "InspurFixedZone.h"

const UInt32 kQNBlockSize = 4 * 1024 * 1024;
const UInt32 kQNDefaultDnsCacheTime = 2 * 60;


@implementation InspurConfiguration

+ (instancetype)defaultConfiguration{
    InspurConfigurationBuilder *builder = [[InspurConfigurationBuilder alloc] init];
    return [[InspurConfiguration alloc] initWithBuilder:builder];
}

+ (instancetype)build:(QNConfigurationBuilderBlock)block {
    InspurConfigurationBuilder *builder = [[InspurConfigurationBuilder alloc] init];
    block(builder);
    return [[InspurConfiguration alloc] initWithBuilder:builder];
}

- (instancetype)initWithBuilder:(InspurConfigurationBuilder *)builder {
    if (self = [super init]) {
        _useConcurrentResumeUpload = builder.useConcurrentResumeUpload;
        _resumeUploadVersion = builder.resumeUploadVersion;
        _concurrentTaskCount = builder.concurrentTaskCount;
        
        _chunkSize = builder.chunkSize;
        if (builder.resumeUploadVersion == QNResumeUploadVersionV1) {
            if (_chunkSize < 1024) {
                _chunkSize = 1024;
            }
        } else if (builder.resumeUploadVersion == QNResumeUploadVersionV2) {
            if (_chunkSize < 1024 * 1024) {
                _chunkSize = 1024 * 1024;
            }
        }
        
        _putThreshold = builder.putThreshold;
        _retryMax = builder.retryMax;
        _retryInterval = builder.retryInterval;
        _timeoutInterval = builder.timeoutInterval;

        _recorder = builder.recorder;
        _recorderKeyGen = builder.recorderKeyGen;

        _proxy = builder.proxy;

        _converter = builder.converter;
        
        _zone = builder.zone;

        _useHttps = builder.useHttps;

        _allowBackupHost = builder.allowBackupHost;
        
        _signatureTimeoutInterval = builder.signatureTimeoutInterval;

    }
    return self;
}

@end

@interface QNGlobalConfiguration()
@property(nonatomic, strong)NSArray *defaultDohIpv4Servers;
@property(nonatomic, strong)NSArray *defaultDohIpv6Servers;
@property(nonatomic, strong)NSArray *defaultUdpDnsIpv4Servers;
@property(nonatomic, strong)NSArray *defaultUdpDnsIpv6Servers;
@end
@implementation QNGlobalConfiguration
+ (instancetype)shared{
    static QNGlobalConfiguration *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [[QNGlobalConfiguration alloc] init];
        [config setupData];
    });
    return config;
}
- (void)setupData{
    _isDnsOpen = NO;
    _dnsResolveTimeout = 2;
    _dnsCacheDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/Dns"];
    _dnsRepreHostNum = 2;
    _dnsCacheTime = kQNDefaultDnsCacheTime;
    _dnsCacheMaxTTL = 10*60;
    
    _dohEnable = true;
    _defaultDohIpv4Servers = @[@"https://223.6.6.6/dns-query", @"https://8.8.8.8/dns-query"];
    
    _udpDnsEnable = true;
    _defaultUdpDnsIpv4Servers = @[@"223.5.5.5", @"114.114.114.114", @"1.1.1.1", @"8.8.8.8"];
    
    _globalHostFrozenTime = 10;
    _partialHostFrozenTime = 5*60;
    
    _connectCheckEnable = YES;
    _connectCheckTimeout = 2;
    _connectCheckURLStrings = @[@"https://www.baidu.com", @"https://www.google.com"];
}

- (BOOL)isDohEnable {
    return _dohEnable && (_dohIpv4Servers.count > 0) ;
}

- (NSArray<NSString *> *)dohIpv4Servers {
    if (_dohIpv4Servers) {
        return _dohIpv4Servers;
    } else {
        return _defaultDohIpv4Servers;
    }
}

- (NSArray<NSString *> *)dohIpv6Servers {
    if (_dohIpv6Servers) {
        return _dohIpv6Servers;
    } else {
        return _defaultDohIpv6Servers;
    }
}

- (NSArray<NSString *> *)udpDnsIpv4Servers {
    if (_udpDnsIpv4Servers) {
        return _udpDnsIpv4Servers;
    } else {
        return _defaultUdpDnsIpv4Servers;
    }
}

- (NSArray<NSString *> *)udpDnsIpv6Servers {
    if (_udpDnsIpv6Servers) {
        return _udpDnsIpv6Servers;
    } else {
        return _defaultUdpDnsIpv6Servers;
    }
}

- (BOOL)isUdpDnsEnable {
    return _udpDnsEnable && (_udpDnsIpv4Servers.count > 0) ;
}
@end

@implementation InspurConfigurationBuilder

- (instancetype)init {
    if (self = [super init]) {
        //_zone = [[QNAutoZone alloc] init];
        _zone = [InspurFixedZone north3];
        _chunkSize = 5 * 1024 * 1024;
        _putThreshold = 5 * 1024 * 1024;
        _retryMax = 1;
        _timeoutInterval = 90;
        _retryInterval = 0.5;

        _recorder = nil;
        _recorderKeyGen = nil;

        _proxy = nil;
        _converter = nil;

        _useHttps = YES;
        _allowBackupHost = YES;
        _useConcurrentResumeUpload = NO;
        _resumeUploadVersion = QNResumeUploadVersionV2;
        _concurrentTaskCount = 3;
        
        _signatureTimeoutInterval = 24*3600;
    }
    return self;
}

@end

