//
//  InspurUploadRequestMetrics.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "InspurUploadRegionInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface InspurUploadMetrics : NSObject

@property (nonatomic, nullable, strong, readonly) NSDate *startDate;
@property (nonatomic, nullable, strong, readonly) NSDate *endDate;
@property (nonatomic, nullable, strong, readonly) NSNumber *totalElapsedTime;

//MARK:-- 构造
+ (instancetype)emptyMetrics;

- (void)start;
- (void)end;

@end


#define kQNMetricsRequestHijacked @"forsure"
#define kQNMetricsRequestMaybeHijacked @"maybe"

@interface InspurUploadSingleRequestMetrics : InspurUploadMetrics

// 请求的 httpVersion
@property (nonatomic,  copy)NSString *httpVersion;

// 请求是否劫持
@property (nonatomic,   copy)NSString *hijacked;
@property (nonatomic, assign, readonly)BOOL isForsureHijacked;
@property (nonatomic, assign, readonly)BOOL isMaybeHijacked;
@property (nonatomic,   copy) NSString *syncDnsSource;
@property (nonatomic, strong) NSError *syncDnsError;

// 只有进行网络检测才会有 connectCheckMetrics
@property (nonatomic, nullable , strong) InspurUploadSingleRequestMetrics *connectCheckMetrics;

// 错误信息
@property (nonatomic, nullable , strong) NSError *error;

@property (nonatomic, nullable, copy) NSURLRequest *request;
@property (nonatomic, nullable, copy) NSURLResponse *response;

@property (nonatomic, nullable, copy) NSDate *domainLookupStartDate;
@property (nonatomic, nullable, copy) NSDate *domainLookupEndDate;
@property (nonatomic, nullable, strong, readonly) NSNumber *totalDnsTime;

@property (nonatomic, nullable, copy) NSDate *connectStartDate;
@property (nonatomic, nullable, copy) NSDate *connectEndDate;
@property (nonatomic, nullable, strong, readonly) NSNumber *totalConnectTime;

@property (nonatomic, nullable, copy) NSDate *secureConnectionStartDate;
@property (nonatomic, nullable, copy) NSDate *secureConnectionEndDate;
@property (nonatomic, nullable, strong, readonly) NSNumber *totalSecureConnectTime;

@property (nonatomic, nullable, copy) NSDate *requestStartDate;
@property (nonatomic, nullable, copy) NSDate *requestEndDate;
@property (nonatomic, nullable, strong, readonly) NSNumber *totalRequestTime;

@property (nonatomic, nullable, strong, readonly) NSNumber *totalWaitTime;

@property (nonatomic, nullable, copy) NSDate *responseStartDate;
@property (nonatomic, nullable, copy) NSDate *responseEndDate;
@property (nonatomic, nullable, strong, readonly) NSNumber *totalResponseTime;

@property (nonatomic, assign) int64_t countOfRequestHeaderBytesSent;
@property (nonatomic, assign) int64_t countOfRequestBodyBytesSent;

@property (nonatomic, assign) int64_t countOfResponseHeaderBytesReceived;
@property (nonatomic, assign) int64_t countOfResponseBodyBytesReceived;

@property (nonatomic, nullable, copy) NSString *localAddress;
@property (nonatomic, nullable, copy) NSNumber *localPort;
@property (nonatomic, nullable, copy) NSString *remoteAddress;
@property (nonatomic, nullable, copy) NSNumber *remotePort;

@property (nonatomic, strong, readonly) NSNumber *totalBytes;
@property (nonatomic, strong, readonly) NSNumber *bytesSend;
@property (nonatomic, strong, readonly) NSNumber *perceptiveSpeed;


@end


@interface InspurUploadRegionRequestMetrics : InspurUploadMetrics

@property (nonatomic, strong, readonly) NSNumber *requestCount;
@property (nonatomic, strong, readonly) NSNumber *bytesSend;
@property (nonatomic, strong, readonly) id <InspurUploadRegion> region;
@property (nonatomic, strong, readonly) InspurUploadSingleRequestMetrics *lastMetrics;
@property (nonatomic,   copy, readonly) NSArray<InspurUploadSingleRequestMetrics *> *metricsList;

//MARK:-- 构造
- (instancetype)initWithRegion:(id <InspurUploadRegion>)region;

- (void)addMetricsList:(NSArray <InspurUploadSingleRequestMetrics *> *)metricsList;
- (void)addMetrics:(InspurUploadRegionRequestMetrics*)metrics;

@end


@interface InspurUploadTaskMetrics : InspurUploadMetrics

@property (nonatomic,   copy, readonly) NSString *upType;
@property (nonatomic, strong, readonly) NSNumber *requestCount;
@property (nonatomic, strong, readonly) NSNumber *bytesSend;
@property (nonatomic, strong, readonly) NSNumber *regionCount;
@property (nonatomic, strong, readonly) InspurUploadRegionRequestMetrics *lastMetrics;

@property (nonatomic, strong) InspurUploadRegionRequestMetrics *ucQueryMetrics;
@property (nonatomic, strong) NSArray<id <InspurUploadRegion>> *regions;

+ (instancetype)taskMetrics:(NSString *)upType;

- (void)addMetrics:(InspurUploadRegionRequestMetrics *)metrics;

@end

NS_ASSUME_NONNULL_END
