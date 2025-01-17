//
//  InspurHttpManager.m
//  InspurOSSSDK
//
//  Created by Brook on 14/10/1.
//  Copyright (c) 2014年 Inspur. All rights reserved.
//

#import "InspurAsyncRun.h"
#import "InspurConfiguration.h"
#import "InspurSessionManager.h"
#import "InspurUserAgent.h"

#import "InspurResponseInfo.h"
#import "NSURLRequest+InspurRequest.h"

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1090)

typedef void (^InspurSessionComplete)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);
@interface InspurSessionDelegateHandler : NSObject <NSURLSessionDataDelegate>

@property (nonatomic, copy) InspurInternalProgressBlock progressBlock;
@property (nonatomic, copy) InspurCancelBlock cancelBlock;
@property (nonatomic, copy) InspurSessionComplete completeBlock;
@property (nonatomic, strong) NSData *responseData;

@end

@implementation InspurSessionDelegateHandler

#pragma mark - NSURLSessionDataDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    _responseData = data;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error {
    // bytes_sent & bytes_total
    self.completeBlock(_responseData, task.response, error);
    [session finishTasksAndInvalidate];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
             didSendBodyData:(int64_t)bytesSent
              totalBytesSent:(int64_t)totalBytesSent
    totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {

    if (_progressBlock) {
        _progressBlock(totalBytesSent, totalBytesExpectedToSend);
    }
    if (_cancelBlock && _cancelBlock()) {
        [task cancel];
    }
}

- (uint64_t)getTimeintervalWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate {
    
    if (!startDate || !endDate) return 0;
    NSTimeInterval interval = [endDate timeIntervalSinceDate:startDate];
    return interval * 1000;
}

@end

@interface InspurSessionManager ()
@property UInt32 timeout;
@property (nonatomic, strong) InspurUrlConvert converter;
@property (nonatomic, strong) NSDictionary *proxyDict;
@property (nonatomic, strong) NSOperationQueue *delegateQueue;
@property (nonatomic, strong) NSMutableArray *sessionArray;
@property (nonatomic, strong) NSLock *lock;
@end

@implementation InspurSessionManager

- (instancetype)initWithProxy:(NSDictionary *)proxyDict
                      timeout:(UInt32)timeout
                 urlConverter:(InspurUrlConvert)converter {
    if (self = [super init]) {
        _delegateQueue = [[NSOperationQueue alloc] init];
        _timeout = timeout;
        _converter = converter;
        _proxyDict = proxyDict;
        _sessionArray = [NSMutableArray array];

        _lock = [[NSLock alloc] init];
    }
    return self;
}

- (instancetype)init {
    return [self initWithProxy:nil timeout:60 urlConverter:nil];
}

- (void)sendRequest:(NSMutableURLRequest *)request
     withIdentifier:(NSString *)identifier
  withCompleteBlock:(InspurCompleteBlock)completeBlock
  withProgressBlock:(InspurInternalProgressBlock)progressBlock
    withCancelBlock:(InspurCancelBlock)cancelBlock
         withAccess:(NSString *)access {
    
    NSString *domain = request.URL.host;
    NSString *u = request.URL.absoluteString;
    NSURL *url = request.URL;
    if (_converter != nil) {
        url = [[NSURL alloc] initWithString:_converter(u)];
        request.URL = url;
        domain = url.host;
    }

    request.inspur_domain = request.URL.host;
    [request setTimeoutInterval:_timeout];
    [request setValue:[[InspurUserAgent sharedInstance] getUserAgent:access] forHTTPHeaderField:@"User-Agent"];
    [request setValue:nil forHTTPHeaderField:@"Accept-Language"];
    
    InspurSessionDelegateHandler *delegate = [[InspurSessionDelegateHandler alloc] init];
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.connectionProxyDictionary = _proxyDict ? _proxyDict : nil;

    __block NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:delegate delegateQueue:_delegateQueue];
    [_sessionArray addObject:@{@"identifier":identifier,@"session":session}];

    delegate.cancelBlock = cancelBlock;
    delegate.progressBlock = progressBlock ? progressBlock : ^(long long totalBytesWritten, long long totalBytesExpectedToWrite) {
    };
    delegate.completeBlock = ^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [self finishSession:session];
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        InspurResponseInfo *info = [[InspurResponseInfo alloc] initWithResponseInfoHost:request.inspur_domain response:httpResponse body:data error:error];
        completeBlock(info, info.responseDictionary);
    };
    
    NSURLSessionDataTask *uploadTask = [session dataTaskWithRequest:request];
    [uploadTask resume];
}

- (void)multipartPost:(NSString *)url
             withData:(NSData *)data
           withParams:(NSDictionary *)params
         withFileName:(NSString *)key
         withMimeType:(NSString *)mime
       withIdentifier:(NSString *)identifier
    withCompleteBlock:(InspurCompleteBlock)completeBlock
    withProgressBlock:(InspurInternalProgressBlock)progressBlock
      withCancelBlock:(InspurCancelBlock)cancelBlock
           withAccess:(NSString *)access {
    NSURL *URL = [[NSURL alloc] initWithString:url];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:URL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30];
    request.HTTPMethod = @"POST";
    NSString *boundary = @"werghnvt54wef654rjuhgb56trtg34tweuyrgf";
    request.allHTTPHeaderFields = @{
        @"Content-Type" : [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary]
    };
    NSMutableData *postData = [[NSMutableData alloc] init];
    for (NSString *paramsKey in params) {
        NSString *pair = [NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n", boundary, paramsKey];
        [postData appendData:[pair dataUsingEncoding:NSUTF8StringEncoding]];

        id value = [params objectForKey:paramsKey];
        if ([value isKindOfClass:[NSString class]]) {
            [postData appendData:[value dataUsingEncoding:NSUTF8StringEncoding]];
        } else if ([value isKindOfClass:[NSData class]]) {
            [postData appendData:value];
        }
        [postData appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }
    NSString *filePair = [NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"%@\"; filename=\"%@\"\nContent-Type:%@\r\n\r\n", boundary, @"file", key, mime];
    [postData appendData:[filePair dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:data];
    [postData appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    request.HTTPBody = postData;
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)postData.length] forHTTPHeaderField:@"Content-Length"];

    [self sendRequest:request withIdentifier:identifier withCompleteBlock:completeBlock withProgressBlock:progressBlock withCancelBlock:cancelBlock
               withAccess:access];
}

- (void)post:(NSString *)url
             withData:(NSData *)data
           withParams:(NSDictionary *)params
          withHeaders:(NSDictionary *)headers
withIdentifier:(NSString *)identifier
    withCompleteBlock:(InspurCompleteBlock)completeBlock
    withProgressBlock:(InspurInternalProgressBlock)progressBlock
      withCancelBlock:(InspurCancelBlock)cancelBlock
           withAccess:(NSString *)access {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[[NSURL alloc] initWithString:url]];
    if (headers) {
        [request setAllHTTPHeaderFields:headers];
    }
    [request setHTTPMethod:@"POST"];
    if (params) {
        [request setValuesForKeysWithDictionary:params];
    }
    [request setHTTPBody:data];
    identifier = !identifier ? [[NSUUID UUID] UUIDString] : identifier;
    InspurAsyncRun(^{
        [self sendRequest:request
           withIdentifier:identifier
            withCompleteBlock:completeBlock
            withProgressBlock:progressBlock
              withCancelBlock:cancelBlock
                   withAccess:access];
    });
}

- (void)get:(NSString *)url
          withHeaders:(NSDictionary *)headers
    withCompleteBlock:(InspurCompleteBlock)completeBlock {
    InspurAsyncRun(^{
        NSURL *URL = [NSURL URLWithString:url];

//        NSString *domain = URL.host;
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
        request.inspur_domain = URL.host;
        InspurSessionDelegateHandler *delegate = [[InspurSessionDelegateHandler alloc] init];
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        __block NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:delegate delegateQueue:self.delegateQueue];
        NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request];
        delegate.cancelBlock = nil;
        delegate.progressBlock = nil;
        delegate.completeBlock = ^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            [self finishSession:session];
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            InspurResponseInfo *info = [[InspurResponseInfo alloc] initWithResponseInfoHost:request.inspur_domain response:httpResponse body:data error:error];
            completeBlock(info, info.responseDictionary);
        };
        [dataTask resume];
    });
}

- (void)finishSession:(NSURLSession *)session {
    [_lock lock];
    for (int i = 0; i < _sessionArray.count; i++) {
        NSDictionary *sessionInfo = _sessionArray[i];
        if (sessionInfo[@"session"] == session) {
            [session finishTasksAndInvalidate];
            [_sessionArray removeObject:sessionInfo];
            break;
        }
    }
    [_lock unlock];
}

- (void)invalidateSessionWithIdentifier:(NSString *)identifier {
    [_lock lock];
    for (int i = 0; i < _sessionArray.count; i++) {
        NSDictionary *sessionInfo = _sessionArray[i];
        if ([sessionInfo[@"identifier"] isEqualToString:identifier]) {
            NSURLSession *session = sessionInfo[@"session"];
            [session invalidateAndCancel];
            [_sessionArray removeObject:sessionInfo];
            break;
        }
    }
    [_lock unlock];
}

@end

#endif
