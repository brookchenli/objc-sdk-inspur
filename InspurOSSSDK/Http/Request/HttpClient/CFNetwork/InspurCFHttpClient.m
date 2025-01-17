//
//  InspurCFHttpClient.m
//  InspurOSSSDK
//
//  Created by Brook on 2021/10/11.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurAsyncRun.h"
#import "InspurCFHttpClient.h"
#import "InspurCFHttpClientInner.h"
#import "NSURLRequest+InspurRequest.h"
#import "InspurUploadRequestMetrics.h"
#import "InspurCFHttpThreadPool.h"

@interface InspurCFHttpClient() <InspurCFHttpClientInnerDelegate>

@property(nonatomic, assign)BOOL hasCallBack;
@property(nonatomic, assign)NSInteger redirectCount;
@property(nonatomic, assign)NSInteger maxRedirectCount;

@property(nonatomic, strong)NSURLRequest *request;
@property(nonatomic, strong)NSURLResponse *response;
@property(nonatomic, strong)NSDictionary *connectionProxy;
@property(nonatomic, strong)InspurUploadSingleRequestMetrics *requestMetrics;
@property(nonatomic, strong)NSMutableData *responseData;
@property(nonatomic,  copy)void(^progress)(long long totalBytesWritten, long long totalBytesExpectedToWrite);
@property(nonatomic,  copy)InspurRequestClientCompleteHandler complete;

@property(nonatomic, strong)InspurCFHttpClientInner *httpClient;
@property(nonatomic, strong)InspurCFHttpThread *thread;

@end
@implementation InspurCFHttpClient

- (NSString *)clientId {
    return @"CFNetwork";
}

- (instancetype)init {
    if (self = [super init]) {
        self.redirectCount = 0;
        self.maxRedirectCount = 15;
        self.hasCallBack = false;
        self.thread = [[InspurCFHttpThreadPool shared] getOneThread];
    }
    return self;
}

- (void)request:(NSURLRequest *)request
         server:(id <InspurUploadServer>)server
connectionProxy:(NSDictionary *)connectionProxy
       progress:(void (^)(long long, long long))progress
       complete:(InspurRequestClientCompleteHandler)complete {
    
    [[InspurCFHttpThreadPool shared] addOperationCountOfThread:self.thread];
    
    // 有 ip 才会使用
    if (server && server.ip.length > 0 && server.host.length > 0) {
        NSString *urlString = request.URL.absoluteString;
        urlString = [urlString stringByReplacingOccurrencesOfString:server.host withString:server.ip];
        NSMutableURLRequest *requestNew = [request mutableCopy];
        requestNew.URL = [NSURL URLWithString:urlString];
        requestNew.inspur_domain = server.host;
        self.request = [requestNew copy];
    } else {
        self.request = request;
    }
    
    self.connectionProxy = connectionProxy;
    self.progress = progress;
    self.complete = complete;
    self.requestMetrics = [InspurUploadSingleRequestMetrics emptyMetrics];
    self.requestMetrics.request = self.request;
    self.requestMetrics.remoteAddress = self.request.inspur_ip;
    self.requestMetrics.remotePort = self.request.inspur_isHttps ? @443 : @80;
    [self.requestMetrics start];
    
    self.responseData = [NSMutableData data];
    self.httpClient = [InspurCFHttpClientInner client:self.request connectionProxy:connectionProxy];
    self.httpClient.delegate = self;
    [self.httpClient performSelector:@selector(main)
                            onThread:self.thread
                          withObject:nil
                       waitUntilDone:NO];
}

- (void)cancel {
    [self.httpClient performSelector:@selector(cancel)
                            onThread:self.thread
                          withObject:nil
                       waitUntilDone:NO];
}

- (void)completeAction:(NSError *)error {
    @synchronized (self) {
        if (self.hasCallBack) {
            return;
        }
        self.hasCallBack = true;
    }
    self.requestMetrics.response = self.response;
    [self.requestMetrics end];
    [[InspurCFHttpThreadPool shared] subtractOperationCountOfThread:self.thread];
    if (self.complete) {
        self.complete(self.response, self.requestMetrics, self.responseData, error);
    }
}

//MARK: -- delegate
- (void)didSendBodyData:(int64_t)bytesSent
         totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend{
    self.requestMetrics.countOfRequestBodyBytesSent = totalBytesSent;
    if (self.progress) {
        self.progress(totalBytesSent, totalBytesExpectedToSend);
    }
}

- (void)didFinish {
    self.requestMetrics.responseEndDate = [NSDate date];
    [self completeAction:nil];
}

- (void)didLoadData:(nonnull NSData *)data {
    [self.responseData appendData:data];
}

- (void)onError:(nonnull NSError *)error {
    [self completeAction:error];
}

- (void)onReceiveResponse:(NSURLResponse *)response httpVersion:(NSString *)httpVersion{
    self.requestMetrics.responseStartDate = [NSDate date];
    if ([httpVersion isEqualToString:@"http/1.0"]) {
        self.requestMetrics.httpVersion = @"1.0";
    } else if ([httpVersion isEqualToString:@"http/1.1"]) {
        self.requestMetrics.httpVersion = @"1.1";
    } else if ([httpVersion isEqualToString:@"h2"]) {
        self.requestMetrics.httpVersion = @"2";
    } else if ([httpVersion isEqualToString:@"h3"]) {
        self.requestMetrics.httpVersion = @"3";
    } else {
        self.requestMetrics.httpVersion = httpVersion;
    }
    self.response = response;
}

- (void)redirectedToRequest:(nonnull NSURLRequest *)request redirectResponse:(nonnull NSURLResponse *)redirectResponse {
    if (self.redirectCount < self.maxRedirectCount) {
        self.redirectCount += 1;
        [self request:request server:nil connectionProxy:self.connectionProxy progress:self.progress complete:self.complete];
    } else {
        [self didFinish];
    }
}

@end
