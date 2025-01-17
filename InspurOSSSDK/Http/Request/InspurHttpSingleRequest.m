//
//  InspurHttpRequest+SingleRequestRetry.m
//  InspurOSSSDK
//
//  Created by Brook on 2020/4/29.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurDefine.h"
#import "InspurAsyncRun.h"
#import "InspurVersion.h"
#import "InspurUtils.h"
#import "InspurLogUtil.h"
#import "InspurHttpSingleRequest.h"
#import "InspurConfiguration.h"
#import "InspurUploadOption.h"
#import "InspurUpToken.h"
#import "InspurResponseInfo.h"
#import "InspurNetworkStatusManager.h"
#import "InspurRequestClient.h"
#import "InspurUploadRequestState.h"

#import "InspurConnectChecker.h"
#import "InspurDnsPrefetch.h"

#import "InspurReportItem.h"

#import "InspurCFHttpClient.h"
#import "InspurUploadSystemClient.h"
#import "NSURLRequest+InspurRequest.h"



@interface InspurHttpSingleRequest()

@property(nonatomic, assign)int currentRetryTime;
@property(nonatomic, strong)InspurConfiguration *config;
@property(nonatomic, strong)InspurUploadOption *uploadOption;
@property(nonatomic, strong)InspurUpToken *token;
@property(nonatomic, strong)InspurUploadRequestInfo *requestInfo;
@property(nonatomic, strong)InspurUploadRequestState *requestState;

@property(nonatomic, strong)NSMutableArray <InspurUploadSingleRequestMetrics *> *requestMetricsList;

@property(nonatomic, strong)id <InspurRequestClient> client;

@end
@implementation InspurHttpSingleRequest

- (instancetype)initWithConfig:(InspurConfiguration *)config
                  uploadOption:(InspurUploadOption *)uploadOption
                         token:(InspurUpToken *)token
                   requestInfo:(InspurUploadRequestInfo *)requestInfo
                  requestState:(InspurUploadRequestState *)requestState{
    if (self = [super init]) {
        _config = config;
        _uploadOption = uploadOption;
        _token = token;
        _requestInfo = requestInfo;
        _requestState = requestState;
        _currentRetryTime = 0;
    }
    return self;
}

- (void)request:(NSURLRequest *)request
         server:(id <InspurUploadServer>)server
    shouldRetry:(BOOL(^)(InspurResponseInfo *responseInfo, NSDictionary *response))shouldRetry
       progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
       complete:(InspurSingleRequestCompleteHandler)complete{
    
    _currentRetryTime = 0;
    _requestMetricsList = [NSMutableArray array];
    [self retryRequest:request server:server shouldRetry:shouldRetry progress:progress complete:complete];
}

- (void)retryRequest:(NSURLRequest *)request
              server:(id <InspurUploadServer>)server
         shouldRetry:(BOOL(^)(InspurResponseInfo *responseInfo, NSDictionary *response))shouldRetry
            progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
            complete:(InspurSingleRequestCompleteHandler)complete{
    
    if (kInspurIsHttp3(server.httpVersion)) {
        self.client = [[InspurUploadSystemClient alloc] init];
    } else {
        if ([self shouldUseCFClient:request server:server]) {
            self.client = [[InspurCFHttpClient alloc] init];
        } else {
            self.client = [[InspurUploadSystemClient alloc] init];
        }
    }
    
    kInspurWeakSelf;
    BOOL (^checkCancelHandler)(void) = ^{
        kInspurStrongSelf;
        
        BOOL isCancelled = self.requestState.isUserCancel;
        if (!isCancelled && self.uploadOption.cancellationSignal) {
            isCancelled = self.uploadOption.cancellationSignal();
        }
        return isCancelled;
    };

    InspurLogInfo(@"key:%@ retry:%d url:%@", self.requestInfo.key, self.currentRetryTime, request.URL);
    
    [self.client request:request server:server connectionProxy:self.config.proxy progress:^(long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        kInspurStrongSelf;
        
        if (progress) {
            progress(totalBytesWritten, totalBytesExpectedToWrite);
        }
        
        if (checkCancelHandler()) {
            self.requestState.isUserCancel = YES;
            [self.client cancel];
        }
    } complete:^(NSURLResponse *response, InspurUploadSingleRequestMetrics *metrics, NSData * responseData, NSError * error) {
        kInspurStrongSelf;
        
        if (metrics) {
            [self.requestMetricsList addObject:metrics];
        }
        
        InspurResponseInfo *responseInfo = nil;
        if (checkCancelHandler()) {
            responseInfo = [InspurResponseInfo cancelResponse];
            [self reportRequest:responseInfo server:server requestMetrics:metrics];
            [self complete:responseInfo server:server response:nil requestMetrics:metrics complete:complete];
            return;
        }
        
        NSDictionary *responseDic = nil;

        
        responseInfo = [[InspurResponseInfo alloc] initWithResponse:(NSHTTPURLResponse *)response body:responseData error:error];
        responseDic = responseInfo.responseDictionary;
        
    
        InspurLogInfo(@"key:%@ response:%@", self.requestInfo.key, responseInfo);
        if (shouldRetry(responseInfo, responseDic)
            && self.currentRetryTime < self.config.retryMax) {
            self.currentRetryTime += 1;
            InspurAsyncRunAfter(self.config.retryInterval, kInspurBackgroundQueue, ^{
                [self retryRequest:request server:server shouldRetry:shouldRetry progress:progress complete:complete];
            });
        } else {
            [self complete:responseInfo server:server response:responseDic requestMetrics:metrics complete:complete];
        }
    }];
    
}

- (BOOL)shouldCheckConnect:(InspurResponseInfo *)responseInfo {
    if (!kInspurGlobalConfiguration.connectCheckEnable) {
        return NO;
    }
    
    return responseInfo.statusCode == kInspurNetworkError ||
    responseInfo.statusCode == kInspurUnexpectedSysCallError || // CF 内部部分错误码 归结到了调用错误
    responseInfo.statusCode == NSURLErrorTimedOut /* NSURLErrorTimedOut */ ||
    responseInfo.statusCode == -1003 /* NSURLErrorCannotFindHost */ ||
    responseInfo.statusCode == -1004 /* NSURLErrorCannotConnectToHost */ ||
    responseInfo.statusCode == -1005 /* NSURLErrorNetworkConnectionLost */ ||
    responseInfo.statusCode == -1006 /* NSURLErrorDNSLookupFailed */ ||
    responseInfo.statusCode == -1009 /* NSURLErrorNotConnectedToInternet */  ||
    responseInfo.statusCode == -1200 /* NSURLErrorSecureConnectionFailed */  ||
    responseInfo.statusCode == -1204 /* NSURLErrorServerCertificateNotYetValid */  ||
    responseInfo.statusCode == -1205 /* NSURLErrorClientCertificateRejected */;
}

- (void)complete:(InspurResponseInfo *)responseInfo
            server:(id<InspurUploadServer>)server
          response:(NSDictionary *)response
    requestMetrics:(InspurUploadSingleRequestMetrics *)requestMetrics
          complete:(InspurSingleRequestCompleteHandler)complete {
    [self updateHostNetworkStatus:responseInfo server:server requestMetrics:requestMetrics];
    if (complete) {
        complete(responseInfo, [self.requestMetricsList copy], response);
    }
}

- (BOOL)shouldUseCFClient:(NSURLRequest *)request server:(id <InspurUploadServer>)server {
    if (request.inspur_isHttps && server.host.length > 0 && server.ip.length > 0) {
        return YES;
    } else {
        return NO;
    }
}

//MARK:-- 统计网络状态
- (void)updateHostNetworkStatus:(InspurResponseInfo *)responseInfo
                         server:(id <InspurUploadServer>)server
                 requestMetrics:(InspurUploadSingleRequestMetrics *)requestMetrics{
    long long bytes = requestMetrics.bytesSend.longLongValue;
    if (requestMetrics.startDate && requestMetrics.endDate && bytes >= 1024 * 1024) {
        double duration = [requestMetrics.endDate timeIntervalSinceDate:requestMetrics.startDate] * 1000;
        NSNumber *speed = [InspurUtils calculateSpeed:bytes totalTime:duration];
        if (speed) {
            NSString *type = [InspurNetworkStatusManager getNetworkStatusType:server.host ip:server.ip];
            [kInspurNetworkStatusManager updateNetworkStatus:type speed:(int)(speed.longValue / 1000)];
        }
    }
}

//MARK:-- 统计quality日志
- (void)reportRequest:(InspurResponseInfo *)info
               server:(id <InspurUploadServer>)server
       requestMetrics:(InspurUploadSingleRequestMetrics *)requestMetrics {
    
    if (! [self.requestInfo shouldReportRequestLog]) {
        return;
    }
    
    InspurUploadSingleRequestMetrics *requestMetricsP = requestMetrics ?: [InspurUploadSingleRequestMetrics emptyMetrics];
    
    NSInteger currentTimestamp = [InspurUtils currentTimestamp];
    InspurReportItem *item = [InspurReportItem item];
    [item setReportValue:InspurReportLogTypeRequest forKey:InspurReportRequestKeyLogType];
    [item setReportValue:@(currentTimestamp/1000) forKey:InspurReportRequestKeyUpTime];
    [item setReportValue:info.requestReportStatusCode forKey:InspurReportRequestKeyStatusCode];
    [item setReportValue:info.reqId forKey:InspurReportRequestKeyRequestId];
    [item setReportValue:requestMetricsP.request.inspur_domain forKey:InspurReportRequestKeyHost];
    [item setReportValue:requestMetricsP.remoteAddress forKey:InspurReportRequestKeyRemoteIp];
    [item setReportValue:requestMetricsP.remotePort forKey:InspurReportRequestKeyPort];
    [item setReportValue:self.requestInfo.bucket forKey:InspurReportRequestKeyTargetBucket];
    [item setReportValue:self.requestInfo.key forKey:InspurReportRequestKeyTargetKey];
    [item setReportValue:requestMetricsP.totalElapsedTime forKey:InspurReportRequestKeyTotalElapsedTime];
    [item setReportValue:requestMetricsP.totalDnsTime forKey:InspurReportRequestKeyDnsElapsedTime];
    [item setReportValue:requestMetricsP.totalConnectTime forKey:InspurReportRequestKeyConnectElapsedTime];
    [item setReportValue:requestMetricsP.totalSecureConnectTime forKey:InspurReportRequestKeyTLSConnectElapsedTime];
    [item setReportValue:requestMetricsP.totalRequestTime forKey:InspurReportRequestKeyRequestElapsedTime];
    [item setReportValue:requestMetricsP.totalWaitTime forKey:InspurReportRequestKeyWaitElapsedTime];
    [item setReportValue:requestMetricsP.totalWaitTime forKey:InspurReportRequestKeyResponseElapsedTime];
    [item setReportValue:requestMetricsP.totalResponseTime forKey:InspurReportRequestKeyResponseElapsedTime];
    [item setReportValue:self.requestInfo.fileOffset forKey:InspurReportRequestKeyFileOffset];
    [item setReportValue:requestMetricsP.bytesSend forKey:InspurReportRequestKeyBytesSent];
    [item setReportValue:requestMetricsP.totalBytes forKey:InspurReportRequestKeyBytesTotal];
    [item setReportValue:@([InspurUtils getCurrentProcessID]) forKey:InspurReportRequestKeyPid];
    [item setReportValue:@([InspurUtils getCurrentThreadID]) forKey:InspurReportRequestKeyTid];
    [item setReportValue:self.requestInfo.targetRegionId forKey:InspurReportRequestKeyTargetRegionId];
    [item setReportValue:self.requestInfo.currentRegionId forKey:InspurReportRequestKeyCurrentRegionId];
    [item setReportValue:info.requestReportErrorType forKey:InspurReportRequestKeyErrorType];
    NSString *errorDesc = info.requestReportErrorType ? info.message : nil;
    [item setReportValue:errorDesc forKey:InspurReportRequestKeyErrorDescription];
    [item setReportValue:self.requestInfo.requestType forKey:InspurReportRequestKeyUpType];
    [item setReportValue:[InspurUtils systemName] forKey:InspurReportRequestKeyOsName];
    [item setReportValue:[InspurUtils systemVersion] forKey:InspurReportRequestKeyOsVersion];
    [item setReportValue:[InspurUtils sdkLanguage] forKey:InspurReportRequestKeySDKName];
    [item setReportValue:[InspurUtils sdkVersion] forKey:InspurReportRequestKeySDKVersion];
    [item setReportValue:@([InspurUtils currentTimestamp]) forKey:InspurReportRequestKeyClientTime];
    [item setReportValue:[InspurUtils getCurrentNetworkType] forKey:InspurReportRequestKeyNetworkType];
    [item setReportValue:[InspurUtils getCurrentSignalStrength] forKey:InspurReportRequestKeySignalStrength];
    
    [item setReportValue:server.source forKey:InspurReportRequestKeyPrefetchedDnsSource];
    if (server.ipPrefetchedTime) {
        NSInteger prefetchTime = currentTimestamp/1000 - [server.ipPrefetchedTime integerValue];
        [item setReportValue:@(prefetchTime) forKey:InspurReportRequestKeyPrefetchedBefore];
    }
    [item setReportValue:kInspurDnsPrefetch.lastPrefetchedErrorMessage forKey:InspurReportRequestKeyPrefetchedErrorMessage];
    
    [item setReportValue:requestMetricsP.httpVersion forKey:InspurReportRequestKeyHttpVersion];

    if (!kInspurGlobalConfiguration.connectCheckEnable) {
        [item setReportValue:@"disable" forKey:InspurReportRequestKeyNetworkMeasuring];
    } else if (requestMetricsP.connectCheckMetrics) {
        InspurUploadSingleRequestMetrics *metrics = requestMetricsP.connectCheckMetrics;
        NSString *connectCheckDuration = [NSString stringWithFormat:@"%.2lf", [metrics.totalElapsedTime doubleValue]];
        NSString *connectCheckStatusCode = @"";
        if (metrics.response) {
            connectCheckStatusCode = [NSString stringWithFormat:@"%ld", (long)((NSHTTPURLResponse *)metrics.response).statusCode];
        } else if (metrics.error) {
            connectCheckStatusCode = [NSString stringWithFormat:@"%ld", (long)metrics.error.code];
        }
        NSString *networkMeasuring = [NSString stringWithFormat:@"duration:%@ status_code:%@",connectCheckDuration, connectCheckStatusCode];
        [item setReportValue:networkMeasuring forKey:InspurReportRequestKeyNetworkMeasuring];
    }
    // 劫持标记
    [item setReportValue:requestMetricsP.hijacked forKey:InspurReportRequestKeyHijacking];
    [item setReportValue:requestMetricsP.syncDnsSource forKey:InspurReportRequestKeyDnsSource];
    [item setReportValue:[requestMetricsP.syncDnsError description] forKey:InspurReportRequestKeyDnsErrorMessage];
    
    // 成功统计速度
    if (info.isOK) {
        [item setReportValue:requestMetricsP.perceptiveSpeed forKey:InspurReportRequestKeyPerceptiveSpeed];
    }
    
    [item setReportValue:self.client.clientId forKey:InspurReportRequestKeyHttpClient];
    
    [kInspurReporter reportItem:item token:self.token.token];
}

@end
