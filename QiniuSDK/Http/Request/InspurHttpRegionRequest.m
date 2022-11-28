//
//  QNHttpRequest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "InspurDefine.h"
#import "InspurLogUtil.h"
#import "InspurAsyncRun.h"
#import "InspurDnsPrefetch.h"
#import "InspurUploadRequestState.h"
#import "InspurHttpRegionRequest.h"
#import "InspurConfiguration.h"
#import "InspurUploadOption.h"
#import "NSURLRequest+InspurRequest.h"
#import "InspurZoneInfo.h"

#import "InspurUploadRequestMetrics.h"
#import "InspurResponseInfo.h"

@interface InspurHttpRegionRequest()

@property(nonatomic, strong)InspurConfiguration *config;
@property(nonatomic, strong)InspurUploadOption *uploadOption;
@property(nonatomic, strong)InspurUploadRequestInfo *requestInfo;
@property(nonatomic, strong)InspurUploadRequestState *requestState;

@property(nonatomic, strong)InspurUploadRegionRequestMetrics *requestMetrics;
@property(nonatomic, strong)InspurHttpSingleRequest *singleRequest;

@property(nonatomic, strong)id <InspurUploadServer> currentServer;
@property(nonatomic, strong)id <InspurUploadRegion> region;

@end
@implementation InspurHttpRegionRequest

- (instancetype)initWithConfig:(InspurConfiguration *)config
                  uploadOption:(InspurUploadOption *)uploadOption
                         token:(InspurUpToken *)token
                        region:(id <InspurUploadRegion>)region
                   requestInfo:(InspurUploadRequestInfo *)requestInfo
                  requestState:(InspurUploadRequestState *)requestState {
    if (self = [super init]) {
        _config = config;
        _uploadOption = uploadOption;
        _region = region;
        _requestInfo = requestInfo;
        _requestState = requestState;
        _singleRequest = [[InspurHttpSingleRequest alloc] initWithConfig:config
                                                        uploadOption:uploadOption
                                                               token:token
                                                         requestInfo:requestInfo
                                                        requestState:requestState];
    }
    return self;
}

- (void)get:(NSString *)action
    headers:(NSDictionary *)headers
shouldRetry:(BOOL(^)(InspurResponseInfo *responseInfo, NSDictionary *response))shouldRetry
   complete:(QNRegionRequestCompleteHandler)complete{
    
    self.requestMetrics = [[InspurUploadRegionRequestMetrics alloc] initWithRegion:self.region];
    [self.requestMetrics start];
    [self performRequest:[self getNextServer:nil]
                  action:action
                 headers:headers
                  method:@"GET"
                    body:nil
             shouldRetry:shouldRetry
                progress:nil
                complete:complete];
}

- (void)post:(NSString *)action
     headers:(NSDictionary *)headers
        body:(NSData *)body
 shouldRetry:(BOOL(^)(InspurResponseInfo *responseInfo, NSDictionary *response))shouldRetry
    progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
    complete:(QNRegionRequestCompleteHandler)complete{
    
    self.requestMetrics = [[InspurUploadRegionRequestMetrics alloc] initWithRegion:self.region];
    [self.requestMetrics start];
    [self performRequest:[self getNextServer:nil]
                  action:action
                 headers:headers
                  method:@"POST"
                    body:body
             shouldRetry:shouldRetry
                progress:progress
                complete:complete];
}


- (void)put:(NSString *)action
    headers:(NSDictionary *)headers
       body:(NSData *)body
shouldRetry:(BOOL(^)(InspurResponseInfo *responseInfo, NSDictionary *response))shouldRetry
   progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
   complete:(QNRegionRequestCompleteHandler)complete{
    
    self.requestMetrics = [[InspurUploadRegionRequestMetrics alloc] initWithRegion:self.region];
    [self.requestMetrics start];
    [self performRequest:[self getNextServer:nil]
                  action:action
                 headers:headers
                  method:@"PUT"
                    body:body
             shouldRetry:shouldRetry
                progress:progress
                complete:complete];
}


- (void)performRequest:(id <InspurUploadServer>)server
                action:(NSString *)action
               headers:(NSDictionary *)headers
                method:(NSString *)method
                  body:(NSData *)body
           shouldRetry:(BOOL(^)(InspurResponseInfo *responseInfo, NSDictionary *response))shouldRetry
              progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
              complete:(QNRegionRequestCompleteHandler)complete{
    
    if (!server.host || server.host.length == 0) {
        InspurResponseInfo *responseInfo = [InspurResponseInfo responseInfoWithSDKInteriorError:@"server error"];
        [self complete:responseInfo response:nil complete:complete];
        return;
    }
    
    NSString *serverHost = server.host;
    //NSString *serverIP = server.ip;
    /*
    if (self.config.converter) {
        serverHost = self.config.converter(serverHost);
        serverIP = nil;
    }
    */
    self.currentServer = server;
    
    NSString *scheme = self.config.useHttps ? @"https://" : @"http://";
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *urlString = [NSString stringWithFormat:@"%@%@.%@%@", scheme, self.region.zoneInfo.regionId, serverHost, action ?: @""];
    request.URL = [NSURL URLWithString:urlString];
    request.HTTPMethod = method;
    [request setAllHTTPHeaderFields:headers];
    [request setTimeoutInterval:self.config.timeoutInterval];
    request.HTTPBody = body;
    
    QNLogInfo(@"key:%@ url:%@", self.requestInfo.key, request.URL);
    QNLogInfo(@"key:%@ headers:%@", self.requestInfo.key, headers);
    
    NSLog(@"key:%@ url:%@", self.requestInfo.key, request.URL);
    
    kInspurWeakSelf;
    [self.singleRequest request:request
                         server:server
                    shouldRetry:shouldRetry
                       progress:progress
                       complete:^(InspurResponseInfo * _Nullable responseInfo, NSArray<InspurUploadSingleRequestMetrics *> * _Nullable metrics, NSDictionary * _Nullable response) {
        kInspurStrongSelf;
        
        [self.requestMetrics addMetricsList:metrics];
        
        BOOL hijacked = metrics.lastObject.isMaybeHijacked || metrics.lastObject.isForsureHijacked;
        BOOL isSafeDnsSource = kQNIsDnsSourceCustom(metrics.lastObject.syncDnsSource) || kQNIsDnsSourceDoh(metrics.lastObject.syncDnsSource) || kQNIsDnsSourceDnsPod(metrics.lastObject.syncDnsSource);
        BOOL hijackedAndNeedRetry = hijacked && isSafeDnsSource;
        if (hijackedAndNeedRetry) {
            [self.region updateIpListFormHost:server.host];
        }
        
        if ((shouldRetry(responseInfo, response)
            && self.config.allowBackupHost
            && responseInfo.couldRegionRetry) || hijackedAndNeedRetry) {
            
            id <InspurUploadServer> newServer = [self getNextServer:responseInfo];
            if (newServer) {
                QNAsyncRunAfter(self.config.retryInterval, kQNBackgroundQueue, ^{
                    [self performRequest:newServer
                                  action:action
                                 headers:headers
                                  method:method
                                    body:body
                             shouldRetry:shouldRetry
                                progress:progress
                                complete:complete];
                });
            } else if (complete) {
                [self complete:responseInfo response:response complete:complete];
            }
        } else if (complete) {
            [self complete:responseInfo response:response complete:complete];
        }
    }];
}

- (void)complete:(InspurResponseInfo *)responseInfo
        response:(NSDictionary *)response
        complete:(QNRegionRequestCompleteHandler)completionHandler {
    [self.requestMetrics end];
    
    if (completionHandler) {
        completionHandler(responseInfo, self.requestMetrics, response);
    }
    self.singleRequest = nil;
}

//MARK: --
- (id <InspurUploadServer>)getNextServer:(InspurResponseInfo *)responseInfo{

    if (responseInfo.isTlsError) {
        self.requestState.isUseOldServer = YES;
    }
    
    return [self.region getNextServer:[self.requestState copy] responseInfo:responseInfo freezeServer:self.currentServer];
}

@end
