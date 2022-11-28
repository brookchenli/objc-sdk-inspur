//
//  QNConnectChecker.m
//  QiniuSDK_Mac
//
//  Created by Brook on 2021/1/8.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurDefine.h"
#import "InspurLogUtil.h"
#import "InspurConfiguration.h"
#import "InspurSingleFlight.h"
#import "InspurConnectChecker.h"
#import "InspurUploadSystemClient.h"

@interface InspurConnectChecker()

@end
@implementation InspurConnectChecker

+ (InspurSingleFlight *)singleFlight {
    static InspurSingleFlight *singleFlight = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleFlight = [[InspurSingleFlight alloc] init];
    });
    return singleFlight;
}

+ (dispatch_queue_t)checkQueue {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.qiniu.NetworkCheckQueue", DISPATCH_QUEUE_CONCURRENT);
    });
    return queue;
}

+ (BOOL)isConnected:(InspurUploadSingleRequestMetrics *)metrics {
    return metrics && ((NSHTTPURLResponse *)metrics.response).statusCode > 99;
}

+ (InspurUploadSingleRequestMetrics *)check {
    __block InspurUploadSingleRequestMetrics *metrics = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [self check:^(InspurUploadSingleRequestMetrics *metricsP) {
        metrics = metricsP;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return metrics;
}

+ (void)check:(void (^)(InspurUploadSingleRequestMetrics *))complete {
    InspurSingleFlight *singleFlight = [self singleFlight];
    
    kInspurWeakSelf;
    [singleFlight perform:@"connect_check" action:^(QNSingleFlightComplete  _Nonnull singleFlightComplete) {
        kInspurStrongSelf;
        
        [self checkAllHosts:^(InspurUploadSingleRequestMetrics *metrics) {
            singleFlightComplete(metrics, nil);
        }];
        
    } complete:^(id  _Nullable value, NSError * _Nullable error) {
        if (complete) {
            complete(value);
        }
    }];
}


+ (void)checkAllHosts:(void (^)(InspurUploadSingleRequestMetrics *metrics))complete {
    
    __block int completeCount = 0;
    __block BOOL isCompleted = false;
    kInspurWeakSelf;
    NSArray *allHosts = [kQNGlobalConfiguration.connectCheckURLStrings copy];
    for (NSString *host in allHosts) {
        [self checkHost:host complete:^(InspurUploadSingleRequestMetrics *metrics) {
            kInspurStrongSelf;
            
            BOOL isHostConnected = [self isConnected:metrics];
            @synchronized (self) {
                completeCount += 1;
            }
            if (isHostConnected || completeCount == allHosts.count) {
                @synchronized (self) {
                    if (isCompleted) {
                        QNLogInfo(@"== check all hosts has completed totalCount:%d completeCount:%d", allHosts.count, completeCount);
                        return;
                    } else {
                        QNLogInfo(@"== check all hosts completed totalCount:%d completeCount:%d", allHosts.count, completeCount);
                        isCompleted = true;
                    }
                }
                complete(metrics);
            } else {
                QNLogInfo(@"== check all hosts not completed totalCount:%d completeCount:%d", allHosts.count, completeCount);
            }
        }];
    }
}

+ (void)checkHost:(NSString *)host complete:(void (^)(InspurUploadSingleRequestMetrics *metrics))complete {
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    request.URL = [NSURL URLWithString:host];
    request.HTTPMethod = @"HEAD";
    request.timeoutInterval = kQNGlobalConfiguration.connectCheckTimeout;
    
    __block BOOL hasCallback = false;
    
    InspurUploadSingleRequestMetrics *timeoutMetric = [InspurUploadSingleRequestMetrics emptyMetrics];
    [timeoutMetric start];
    
    InspurUploadSystemClient *client = [[InspurUploadSystemClient alloc] init];
    [client request:request server:nil connectionProxy:nil progress:nil complete:^(NSURLResponse *response, InspurUploadSingleRequestMetrics * metrics, NSData * _Nullable data, NSError * error) {
        @synchronized (self) {
            if (hasCallback) {
                return;
            }
            hasCallback = true;
        }
        QNLogInfo(@"== checkHost:%@ responseInfo:%@", host, response);
        complete(metrics);
    }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * kQNGlobalConfiguration.connectCheckTimeout), [self checkQueue], ^{
        @synchronized (self) {
            if (hasCallback) {
                return;
            }
            hasCallback = true;
        }
        [client cancel];
        [timeoutMetric end];
        timeoutMetric.error = [NSError errorWithDomain:@"com.qiniu.NetworkCheck" code:NSURLErrorTimedOut userInfo:nil];
        complete(timeoutMetric);
    });
}

@end
