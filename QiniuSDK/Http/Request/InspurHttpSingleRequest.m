//
//  QNHttpRequest+SingleRequestRetry.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNDefine.h"
#import "QNAsyncRun.h"
#import "QNVersion.h"
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
       complete:(QNSingleRequestCompleteHandler)complete{
    
    _currentRetryTime = 0;
    _requestMetricsList = [NSMutableArray array];
    [self retryRequest:request server:server shouldRetry:shouldRetry progress:progress complete:complete];
}

- (void)retryRequest:(NSURLRequest *)request
              server:(id <InspurUploadServer>)server
         shouldRetry:(BOOL(^)(InspurResponseInfo *responseInfo, NSDictionary *response))shouldRetry
            progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
            complete:(QNSingleRequestCompleteHandler)complete{
    
    if (kQNIsHttp3(server.httpVersion)) {
        self.client = [[InspurUploadSystemClient alloc] init];
    } else {
        if ([self shouldUseCFClient:request server:server]) {
            self.client = [[InspurCFHttpClient alloc] init];
        } else {
            self.client = [[InspurUploadSystemClient alloc] init];
        }
    }
    
    kQNWeakSelf;
    BOOL (^checkCancelHandler)(void) = ^{
        kQNStrongSelf;
        
        BOOL isCancelled = self.requestState.isUserCancel;
        if (!isCancelled && self.uploadOption.cancellationSignal) {
            isCancelled = self.uploadOption.cancellationSignal();
        }
        return isCancelled;
    };

    QNLogInfo(@"key:%@ retry:%d url:%@", self.requestInfo.key, self.currentRetryTime, request.URL);
    
    [self.client request:request server:server connectionProxy:self.config.proxy progress:^(long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        kQNStrongSelf;
        
        if (progress) {
            progress(totalBytesWritten, totalBytesExpectedToWrite);
        }
        
        if (checkCancelHandler()) {
            self.requestState.isUserCancel = YES;
            [self.client cancel];
        }
    } complete:^(NSURLResponse *response, InspurUploadSingleRequestMetrics *metrics, NSData * responseData, NSError * error) {
        kQNStrongSelf;
        
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
        /*
        if (responseData) {
            responseDic = [NSJSONSerialization JSONObjectWithData:responseData
                                                          options:NSJSONReadingMutableLeaves
                                                            error:nil];
        }
       
        
        responseInfo = [[QNResponseInfo alloc] initWithResponseInfoHost:request.qn_domain
                                                               response:(NSHTTPURLResponse *)response
                                                                   body:responseData
                                                                  error:error];
         
         */
        
        responseInfo = [[InspurResponseInfo alloc] initWithResponse:(NSHTTPURLResponse *)response body:responseData error:error];
        responseDic = responseInfo.responseDictionary;
        
        /*
        BOOL isSafeDnsSource = kQNIsDnsSourceCustom(server.source) || kQNIsDnsSourceDoh(server.source) || kQNIsDnsSourceDnsPod(server.source);
        BOOL hijacked = responseInfo.isNotQiniu && !isSafeDnsSource;
        if (hijacked) {
            metrics.hijacked = kQNMetricsRequestHijacked;
            NSError *err = nil;
            metrics.syncDnsSource = [kQNDnsPrefetch prefetchHostBySafeDns:server.host error:&err];
            metrics.syncDnsError = err;
        }
        */
        
        /*
        if (!hijacked && [self shouldCheckConnect:responseInfo]) {
            // 网络状态检测
            QNUploadSingleRequestMetrics *connectCheckMetrics = [QNConnectChecker check];
            metrics.connectCheckMetrics = connectCheckMetrics;
            if (![QNConnectChecker isConnected:connectCheckMetrics]) {
                NSString *message = [NSString stringWithFormat:@"check origin statusCode:%d error:%@", responseInfo.statusCode, responseInfo.error];
                responseInfo = [QNResponseInfo errorResponseInfo:NSURLErrorNotConnectedToInternet errorDesc:message];
            } else if (!isSafeDnsSource) {
                metrics.hijacked = kQNMetricsRequestMaybeHijacked;
                NSError *err = nil;
                [kQNDnsPrefetch prefetchHostBySafeDns:server.host error:&err];
                metrics.syncDnsError = err;
            }
        }
        
        [self reportRequest:responseInfo server:server requestMetrics:metrics];
        */
        
        QNLogInfo(@"key:%@ response:%@", self.requestInfo.key, responseInfo);
        if (shouldRetry(responseInfo, responseDic)
            && self.currentRetryTime < self.config.retryMax) {
            self.currentRetryTime += 1;
            QNAsyncRunAfter(self.config.retryInterval, kQNBackgroundQueue, ^{
                [self retryRequest:request server:server shouldRetry:shouldRetry progress:progress complete:complete];
            });
        } else {
            [self complete:responseInfo server:server response:responseDic requestMetrics:metrics complete:complete];
        }
    }];
    
}

- (BOOL)shouldCheckConnect:(InspurResponseInfo *)responseInfo {
    if (!kQNGlobalConfiguration.connectCheckEnable) {
        return NO;
    }
    
    return responseInfo.statusCode == kQNNetworkError ||
    responseInfo.statusCode == kQNUnexpectedSysCallError || // CF 内部部分错误码 归结到了调用错误
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
          complete:(QNSingleRequestCompleteHandler)complete {
    [self updateHostNetworkStatus:responseInfo server:server requestMetrics:requestMetrics];
    if (complete) {
        complete(responseInfo, [self.requestMetricsList copy], response);
    }
}

- (BOOL)shouldUseCFClient:(NSURLRequest *)request server:(id <InspurUploadServer>)server {
    if (request.qn_isHttps && server.host.length > 0 && server.ip.length > 0) {
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
            [kQNNetworkStatusManager updateNetworkStatus:type speed:(int)(speed.longValue / 1000)];
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
    [item setReportValue:QNReportLogTypeRequest forKey:QNReportRequestKeyLogType];
    [item setReportValue:@(currentTimestamp/1000) forKey:QNReportRequestKeyUpTime];
    [item setReportValue:info.requestReportStatusCode forKey:QNReportRequestKeyStatusCode];
    [item setReportValue:info.reqId forKey:QNReportRequestKeyRequestId];
    [item setReportValue:requestMetricsP.request.qn_domain forKey:QNReportRequestKeyHost];
    [item setReportValue:requestMetricsP.remoteAddress forKey:QNReportRequestKeyRemoteIp];
    [item setReportValue:requestMetricsP.remotePort forKey:QNReportRequestKeyPort];
    [item setReportValue:self.requestInfo.bucket forKey:QNReportRequestKeyTargetBucket];
    [item setReportValue:self.requestInfo.key forKey:QNReportRequestKeyTargetKey];
    [item setReportValue:requestMetricsP.totalElapsedTime forKey:QNReportRequestKeyTotalElapsedTime];
    [item setReportValue:requestMetricsP.totalDnsTime forKey:QNReportRequestKeyDnsElapsedTime];
    [item setReportValue:requestMetricsP.totalConnectTime forKey:QNReportRequestKeyConnectElapsedTime];
    [item setReportValue:requestMetricsP.totalSecureConnectTime forKey:QNReportRequestKeyTLSConnectElapsedTime];
    [item setReportValue:requestMetricsP.totalRequestTime forKey:QNReportRequestKeyRequestElapsedTime];
    [item setReportValue:requestMetricsP.totalWaitTime forKey:QNReportRequestKeyWaitElapsedTime];
    [item setReportValue:requestMetricsP.totalWaitTime forKey:QNReportRequestKeyResponseElapsedTime];
    [item setReportValue:requestMetricsP.totalResponseTime forKey:QNReportRequestKeyResponseElapsedTime];
    [item setReportValue:self.requestInfo.fileOffset forKey:QNReportRequestKeyFileOffset];
    [item setReportValue:requestMetricsP.bytesSend forKey:QNReportRequestKeyBytesSent];
    [item setReportValue:requestMetricsP.totalBytes forKey:QNReportRequestKeyBytesTotal];
    [item setReportValue:@([InspurUtils getCurrentProcessID]) forKey:QNReportRequestKeyPid];
    [item setReportValue:@([InspurUtils getCurrentThreadID]) forKey:QNReportRequestKeyTid];
    [item setReportValue:self.requestInfo.targetRegionId forKey:QNReportRequestKeyTargetRegionId];
    [item setReportValue:self.requestInfo.currentRegionId forKey:QNReportRequestKeyCurrentRegionId];
    [item setReportValue:info.requestReportErrorType forKey:QNReportRequestKeyErrorType];
    NSString *errorDesc = info.requestReportErrorType ? info.message : nil;
    [item setReportValue:errorDesc forKey:QNReportRequestKeyErrorDescription];
    [item setReportValue:self.requestInfo.requestType forKey:QNReportRequestKeyUpType];
    [item setReportValue:[InspurUtils systemName] forKey:QNReportRequestKeyOsName];
    [item setReportValue:[InspurUtils systemVersion] forKey:QNReportRequestKeyOsVersion];
    [item setReportValue:[InspurUtils sdkLanguage] forKey:QNReportRequestKeySDKName];
    [item setReportValue:[InspurUtils sdkVersion] forKey:QNReportRequestKeySDKVersion];
    [item setReportValue:@([InspurUtils currentTimestamp]) forKey:QNReportRequestKeyClientTime];
    [item setReportValue:[InspurUtils getCurrentNetworkType] forKey:QNReportRequestKeyNetworkType];
    [item setReportValue:[InspurUtils getCurrentSignalStrength] forKey:QNReportRequestKeySignalStrength];
    
    [item setReportValue:server.source forKey:QNReportRequestKeyPrefetchedDnsSource];
    if (server.ipPrefetchedTime) {
        NSInteger prefetchTime = currentTimestamp/1000 - [server.ipPrefetchedTime integerValue];
        [item setReportValue:@(prefetchTime) forKey:QNReportRequestKeyPrefetchedBefore];
    }
    [item setReportValue:kQNDnsPrefetch.lastPrefetchedErrorMessage forKey:QNReportRequestKeyPrefetchedErrorMessage];
    
    [item setReportValue:requestMetricsP.httpVersion forKey:QNReportRequestKeyHttpVersion];

    if (!kQNGlobalConfiguration.connectCheckEnable) {
        [item setReportValue:@"disable" forKey:QNReportRequestKeyNetworkMeasuring];
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
        [item setReportValue:networkMeasuring forKey:QNReportRequestKeyNetworkMeasuring];
    }
    // 劫持标记
    [item setReportValue:requestMetricsP.hijacked forKey:QNReportRequestKeyHijacking];
    [item setReportValue:requestMetricsP.syncDnsSource forKey:QNReportRequestKeyDnsSource];
    [item setReportValue:[requestMetricsP.syncDnsError description] forKey:QNReportRequestKeyDnsErrorMessage];
    
    // 成功统计速度
    if (info.isOK) {
        [item setReportValue:requestMetricsP.perceptiveSpeed forKey:QNReportRequestKeyPerceptiveSpeed];
    }
    
    [item setReportValue:self.client.clientId forKey:QNReportRequestKeyHttpClient];
    
    [kQNReporter reportItem:item token:self.token.token];
}

@end