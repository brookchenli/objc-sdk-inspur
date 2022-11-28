//
//  QNUploadRequestMetrics.m
//  QiniuSDK
//
//  Created by Brook on 2020/4/29.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurUtils.h"
#import "InspurUploadRequestMetrics.h"
#import "NSURLRequest+InspurRequest.h"
#import "InspurZoneInfo.h"

@interface InspurUploadMetrics()

@property (nullable, strong) NSDate *startDate;
@property (nullable, strong) NSDate *endDate;

@end
@implementation InspurUploadMetrics
//MARK:-- 构造
+ (instancetype)emptyMetrics {
    return [[self alloc] init];
}

- (NSNumber *)totalElapsedTime{
    return [InspurUtils dateDuration:self.startDate endDate:self.endDate];
}

- (void)start {
    self.startDate = [NSDate date];
}

- (void)end {
    self.endDate = [NSDate date];
}
@end

@interface InspurUploadSingleRequestMetrics()
@property (nonatomic, assign) int64_t countOfRequestHeaderBytes;
@property (nonatomic, assign) int64_t countOfRequestBodyBytes;
@end
@implementation InspurUploadSingleRequestMetrics

+ (instancetype)emptyMetrics{
    InspurUploadSingleRequestMetrics *metrics = [[InspurUploadSingleRequestMetrics alloc] init];
    return metrics;
}

- (instancetype)init{
    if (self = [super init]) {
        [self initData];
    }
    return self;
}

- (void)initData{
    _countOfRequestHeaderBytesSent = 0;
    _countOfRequestBodyBytesSent = 0;
    _countOfResponseHeaderBytesReceived = 0;
    _countOfResponseBodyBytesReceived = 0;
}

- (void)setRequest:(NSURLRequest *)request{
    NSMutableURLRequest *newRequest = [NSMutableURLRequest requestWithURL:request.URL
                                                              cachePolicy:request.cachePolicy
                                                          timeoutInterval:request.timeoutInterval];
    newRequest.allHTTPHeaderFields = request.allHTTPHeaderFields;
    
    self.countOfRequestHeaderBytes = [NSString stringWithFormat:@"%@", request.allHTTPHeaderFields].length;
    self.countOfRequestBodyBytes = [request.qn_getHttpBody length];
    _totalBytes = @(self.countOfRequestHeaderBytes + self.countOfRequestBodyBytes);
    _request = [newRequest copy];
}

- (void)setResponse:(NSURLResponse *)response {
    if ([response isKindOfClass:[NSHTTPURLResponse class]] &&
        [(NSHTTPURLResponse *)response statusCode] >= 200 &&
        [(NSHTTPURLResponse *)response statusCode] < 300) {
        _countOfRequestHeaderBytesSent = _countOfRequestHeaderBytes;
        _countOfRequestBodyBytesSent = _countOfRequestBodyBytes;
    }
    if (_countOfResponseBodyBytesReceived <= 0) {
        _countOfResponseBodyBytesReceived = response.expectedContentLength;
    }
    if (_countOfResponseHeaderBytesReceived <= 0 && [response isKindOfClass:[NSHTTPURLResponse class]]) {
        _countOfResponseHeaderBytesReceived = [NSString stringWithFormat:@"%@", [(NSHTTPURLResponse *)response allHeaderFields]].length;
    }
    _response = [response copy];
}

- (BOOL)isForsureHijacked {
    return [self.hijacked isEqualToString:kQNMetricsRequestHijacked];
}

- (BOOL)isMaybeHijacked {
    return [self.hijacked isEqualToString:kQNMetricsRequestMaybeHijacked];
}

- (NSNumber *)totalElapsedTime{
    return [self timeFromStartDate:self.startDate
                         toEndDate:self.endDate];
}

- (NSNumber *)totalDnsTime{
    return [self timeFromStartDate:self.domainLookupStartDate
                         toEndDate:self.domainLookupEndDate];
}

- (NSNumber *)totalConnectTime{
    return [self timeFromStartDate:self.connectStartDate
                         toEndDate:self.connectEndDate];
}

- (NSNumber *)totalSecureConnectTime{
    return [self timeFromStartDate:self.secureConnectionStartDate
                         toEndDate:self.secureConnectionEndDate];
}

- (NSNumber *)totalRequestTime{
    return [self timeFromStartDate:self.requestStartDate
                         toEndDate:self.requestEndDate];
}

- (NSNumber *)totalWaitTime{
    return [self timeFromStartDate:self.requestEndDate
                         toEndDate:self.responseStartDate];
}

- (NSNumber *)totalResponseTime{
    return [self timeFromStartDate:self.responseStartDate
                         toEndDate:self.responseEndDate];
}

- (NSNumber *)bytesSend{
    int64_t totalBytes = [self totalBytes].integerValue;
    int64_t senderBytes = self.countOfRequestBodyBytesSent + self.countOfRequestHeaderBytesSent;
    int64_t bytes = MIN(totalBytes, senderBytes);
    return @(bytes);
}

- (NSNumber *)timeFromStartDate:(NSDate *)startDate toEndDate:(NSDate *)endDate{
    return [InspurUtils dateDuration:startDate endDate:endDate];
}

- (NSNumber *)perceptiveSpeed {
    int64_t size = self.bytesSend.longLongValue + _countOfResponseHeaderBytesReceived + _countOfResponseBodyBytesReceived;
    if (size == 0 || self.totalElapsedTime == nil) {
        return nil;
    }
    
    return [InspurUtils calculateSpeed:size totalTime:self.totalElapsedTime.longLongValue];
}

@end


@interface InspurUploadRegionRequestMetrics()

@property (nonatomic, strong) id <InspurUploadRegion> region;
@property (nonatomic,   copy) NSMutableArray<InspurUploadSingleRequestMetrics *> *metricsListInter;

@end
@implementation InspurUploadRegionRequestMetrics

+ (instancetype)emptyMetrics{
    InspurUploadRegionRequestMetrics *metrics = [[InspurUploadRegionRequestMetrics alloc] init];
    return metrics;
}

- (instancetype)initWithRegion:(id<InspurUploadRegion>)region{
    if (self = [super init]) {
        _region = region;
        _metricsListInter = [NSMutableArray array];
    }
    return self;
}

- (InspurUploadSingleRequestMetrics *)lastMetrics {
    @synchronized (self) {
        return self.metricsListInter.lastObject;
    }
}

- (NSNumber *)requestCount{
    if (self.metricsList) {
        return @(self.metricsList.count);
    } else {
        return @(0);
    }
}

- (NSNumber *)bytesSend{
    if (self.metricsList) {
        long long bytes = 0;
        for (InspurUploadSingleRequestMetrics *metrics in self.metricsList) {
            bytes += metrics.bytesSend.longLongValue;
        }
        return @(bytes);
    } else {
        return @(0);
    }
}

- (void)addMetricsList:(NSArray<InspurUploadSingleRequestMetrics *> *)metricsList{
    @synchronized (self) {
        [_metricsListInter addObjectsFromArray:metricsList];
    }
}

- (void)addMetrics:(InspurUploadRegionRequestMetrics*)metrics{
    if ([metrics.region.zoneInfo.regionId isEqualToString:self.region.zoneInfo.regionId]) {
        @synchronized (self) {
            [_metricsListInter addObjectsFromArray:metrics.metricsListInter];
        }
    }
}

- (NSArray<InspurUploadSingleRequestMetrics *> *)metricsList{
    @synchronized (self) {
        return [_metricsListInter copy];
    }
}

@end


@interface InspurUploadTaskMetrics()

@property (nonatomic,   copy) NSString *upType;
@property (nonatomic,   copy) NSMutableArray<NSString *> *metricsKeys;
@property (nonatomic, strong) NSMutableDictionary<NSString *, InspurUploadRegionRequestMetrics *> *metricsInfo;

@end
@implementation InspurUploadTaskMetrics

+ (instancetype)emptyMetrics{
    InspurUploadTaskMetrics *metrics = [[InspurUploadTaskMetrics alloc] init];
    return metrics;
}

+ (instancetype)taskMetrics:(NSString *)upType {
    InspurUploadTaskMetrics *metrics = [self emptyMetrics];
    metrics.upType = upType;
    return metrics;
}

- (instancetype)init{
    if (self = [super init]) {
        _metricsKeys = [NSMutableArray array];
        _metricsInfo = [NSMutableDictionary dictionary];
    }
    return self;
}

- (InspurUploadRegionRequestMetrics *)lastMetrics {
    if (self.metricsKeys.count < 1) {
        return nil;
    }
    
    @synchronized (self) {
        NSString *key = self.metricsKeys.lastObject;
        if (key == nil) {
            return nil;
        }
        return self.metricsInfo[key];
    }
}
- (NSNumber *)totalElapsedTime{
    NSDictionary *metricsInfo = [self syncCopyMetricsInfo];
    if (metricsInfo) {
        double time = 0;
        for (InspurUploadRegionRequestMetrics *metrics in metricsInfo.allValues) {
            time += metrics.totalElapsedTime.doubleValue;
        }
        return time > 0 ? @(time) : nil;
    } else {
        return nil;
    }
}

- (NSNumber *)requestCount{
    NSDictionary *metricsInfo = [self syncCopyMetricsInfo];
    if (metricsInfo) {
        NSInteger count = 0;
        for (InspurUploadRegionRequestMetrics *metrics in metricsInfo.allValues) {
            count += metrics.requestCount.integerValue;
        }
        return @(count);
    } else {
        return @(0);
    }
}

- (NSNumber *)bytesSend{
    NSDictionary *metricsInfo = [self syncCopyMetricsInfo];
    if (metricsInfo) {
        long long bytes = 0;
        for (InspurUploadRegionRequestMetrics *metrics in metricsInfo.allValues) {
            bytes += metrics.bytesSend.longLongValue;
        }
        return @(bytes);
    } else {
        return @(0);
    }
}

- (NSNumber *)regionCount{
    NSDictionary *metricsInfo = [self syncCopyMetricsInfo];
    if (metricsInfo) {
        int count = 0;
        for (InspurUploadRegionRequestMetrics *metrics in metricsInfo.allValues) {
            if (![metrics.region.zoneInfo.regionId isEqualToString:QNZoneInfoEmptyRegionId]) {
                count += 1;
            }
        }
        return @(count);
    } else {
        return @(0);
    }
}

- (void)setUcQueryMetrics:(InspurUploadRegionRequestMetrics *)ucQueryMetrics {
    _ucQueryMetrics = ucQueryMetrics;
    [self addMetrics:ucQueryMetrics];
}

- (void)addMetrics:(InspurUploadRegionRequestMetrics *)metrics{
    NSString *regionId = metrics.region.zoneInfo.regionId;
    if (!regionId) {
        return;
    }
    @synchronized (self) {
        InspurUploadRegionRequestMetrics *metricsOld = self.metricsInfo[regionId];
        if (metricsOld) {
            [metricsOld addMetrics:metrics];
        } else {
            [self.metricsKeys addObject:regionId];
            self.metricsInfo[regionId] = metrics;
        }
    }
}

- (NSDictionary<NSString *, InspurUploadRegionRequestMetrics *> *)syncCopyMetricsInfo {
    @synchronized (self) {
        return [_metricsInfo copy];
    }
}


@end
