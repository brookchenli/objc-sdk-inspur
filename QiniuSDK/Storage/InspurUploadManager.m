//
//  QNUploader.h
//  QiniuSDK
//
//  Created by bailong on 14-9-28.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import <MobileCoreServices/MobileCoreServices.h>
#import <UIKit/UIKit.h>

#if !TARGET_OS_MACCATALYST
#import <AssetsLibrary/AssetsLibrary.h>
#import "InspurALAssetFile.h"
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
#import "InspurPHAssetFile.h"
#import <Photos/Photos.h>
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
#import "InspurPHAssetResource.h"
#endif

#else
#import <CoreServices/CoreServices.h>
#endif

#import "InspurUploadManager.h"

#import "QNAsyncRun.h"
#import "InspurConfiguration.h"
#import "InspurCrc32.h"
#import "InspurFile.h"
#import "InspurUtils.h"
#import "InspurResponseInfo.h"

#import "InspurFormUpload.h"
#import "InspurPartsUpload.h"
#import "InspurConcurrentResumeUpload.h"

#import "InspurUpToken.h"
#import "InspurUploadOption.h"
#import "InspurReportItem.h"

#import "InspurServerConfigMonitor.h"
#import "InspurDnsPrefetch.h"
#import "QNZone.h"

#import "InspurUploadSourceFile.h"
#import "InspurUploadSourceStream.h"

@interface InspurUploadManager ()
@property (nonatomic) InspurConfiguration *config;
@end

@implementation InspurUploadManager

- (instancetype)init {
    return [self initWithConfiguration:nil];
}

- (instancetype)initWithRecorder:(id<InspurRecorderDelegate>)recorder {
    return [self initWithRecorder:recorder recorderKeyGenerator:nil];
}

- (instancetype)initWithRecorder:(id<InspurRecorderDelegate>)recorder
            recorderKeyGenerator:(QNRecorderKeyGenerator)recorderKeyGenerator {
    InspurConfiguration *config = [InspurConfiguration build:^(InspurConfigurationBuilder *builder) {
        builder.recorder = recorder;
        builder.recorderKeyGen = recorderKeyGenerator;
    }];
    return [self initWithConfiguration:config];
}

- (instancetype)initWithConfiguration:(InspurConfiguration *)config {
    if (self = [super init]) {
        if (config == nil) {
            config = [InspurConfiguration build:^(InspurConfigurationBuilder *builder){
            }];
        }
        _config = config;
        [[InspurTransactionManager shared] addDnsLocalLoadTransaction];
        [InspurServerConfigMonitor startMonitor];
    }
    return self;
}

+ (instancetype)sharedInstanceWithConfiguration:(InspurConfiguration *)config {
    static InspurUploadManager *sharedInstance = nil;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] initWithConfiguration:config];
    });

    return sharedInstance;
}

- (void)putData:(NSData *)data
         bucket:(NSString *)bucket
            key:(NSString *)key
        accessKey:(NSString *)accessKey
signatureHanlder:(QNUpSignatureHandler)signatureHandler
       complete:(QNUpCompletionHandler)completionHandler
         option:(InspurUploadOption *)option {
    [self putData:data bucket:bucket fileName:nil key:key accessKey:accessKey signatureHanlder:signatureHandler complete:completionHandler option:option];
}

- (void)putData:(NSData *)data
         bucket:(NSString *)bucket
       fileName:(NSString *)fileName
            key:(NSString *)key
      accessKey:(NSString *)accessKey
signatureHanlder:(QNUpSignatureHandler)signatureHandler
       complete:(QNUpCompletionHandler)completionHandler
         option:(InspurUploadOption *)option {

    if ([InspurUploadManager checkAndNotifyError:key token:@"" input:data complete:completionHandler]) {
        return;
    }
    long deadLine = [[NSDate date] timeIntervalSince1970] + self.config.signatureTimeoutInterval;
    InspurUpToken *t = [[InspurUpToken alloc] initBucket:bucket
                                        deadLine:deadLine
                                       accessKey:accessKey];
    t.signatureHandler = ^(NSString *contentNeedSignature, QNUpTokenSignatureResultHandler result) {
        signatureHandler(contentNeedSignature, ^(NSString *signature, NSError *error){
            result(signature, error);
        });
    };
    
    if (t == nil || ![t isValid]) {
        InspurResponseInfo *info = [InspurResponseInfo responseInfoWithInvalidToken:@"invalid token"];
        [InspurUploadManager complete:[t toString]
                              key:key
                           source:data
                     responseInfo:info
                         response:nil
                      taskMetrics:nil
                         complete:completionHandler];
        return;
    }
    
    InspurServerConfigMonitor.token = [t toString];
    [[InspurTransactionManager shared] addDnsCheckAndPrefetchTransaction:self.config.zone token:t];
    
    QNUpTaskCompletionHandler complete = ^(InspurResponseInfo *info, NSString *key, QNUploadTaskMetrics *metrics, NSDictionary *resp) {
        [InspurUploadManager complete:[t toString]
                              key:key
                           source:data
                     responseInfo:info
                         response:resp
                      taskMetrics:metrics
                         complete:completionHandler];
    };
    InspurFormUpload *up = [[InspurFormUpload alloc] initWithData:data
                                                      key:key
                                                 fileName:fileName
                                                    token:t
                                                   option:option
                                            configuration:self.config
                                        completionHandler:complete];
    QNAsyncRun(^{
        [up run];
    });
}


- (void)putInputStream:(NSInputStream *)inputStream
              sourceId:(NSString *)sourceId
                  size:(long long)size
              fileName:(NSString *)fileName
                   key:(NSString *)key
                 token:(NSString *)token
              complete:(QNUpCompletionHandler)completionHandler
                option:(InspurUploadOption *)option {
    
    if ([InspurUploadManager checkAndNotifyError:key token:token input:inputStream complete:completionHandler]) {
        return;
    }

    @autoreleasepool {
        //QNUploadSourceStream *source = [QNUploadSourceStream stream:inputStream sourceId:sourceId size:size fileName:fileName];
        //[self putInternal:source key:key token:token complete:completionHandler option:option];
    }
}
- (void)putFile:(NSString *)filePath
         bucket:(NSString *)bucket
            key:(NSString *)key
      accessKey:(NSString *)accessKey
signatureHanlder:(QNUpSignatureHandler)signatureHandler
       complete:(QNUpCompletionHandler)completionHandler
         option:(InspurUploadOption *)option {
    
    if ([InspurUploadManager checkAndNotifyError:key token:@"" input:filePath complete:completionHandler]) {
        return;
    }

    @autoreleasepool {
        NSError *error = nil;
        __block InspurFile *file = [[InspurFile alloc] init:filePath error:&error];
        if (error) {
            InspurResponseInfo *info = [InspurResponseInfo responseInfoWithFileError:error];
            [InspurUploadManager complete:@""
                                  key:key
                               source:nil
                         responseInfo:info
                             response:nil
                          taskMetrics:nil
                             complete:completionHandler];
            return;
        }
        [self putFileInternal:file key:key bucket:bucket accessKey:accessKey signatureHanlder:signatureHandler complete:completionHandler option:option];
    }
}

#if !TARGET_OS_MACCATALYST
- (void)putALAsset:(ALAsset *)asset
               key:(NSString *)key
             token:(NSString *)token
          complete:(QNUpCompletionHandler)completionHandler
            option:(InspurUploadOption *)option {
#if __IPHONE_OS_VERSION_MIN_REQUIRED
    
    if ([InspurUploadManager checkAndNotifyError:key token:token input:asset complete:completionHandler]) {
        return;
    }

    @autoreleasepool {
        NSError *error = nil;
        __block InspurALAssetFile *file = [[InspurALAssetFile alloc] init:asset error:&error];
        if (error) {
            InspurResponseInfo *info = [InspurResponseInfo responseInfoWithFileError:error];
            [InspurUploadManager complete:token
                                  key:key
                               source:nil
                         responseInfo:info
                             response:nil
                          taskMetrics:nil
                             complete:completionHandler];
            return;
        }
        //[self putFileInternal:file key:key token:token complete:completionHandler option:option];
    }
#endif
}
#endif

- (void)putPHAsset:(PHAsset *)asset
               key:(NSString *)key
             token:(NSString *)token
          complete:(QNUpCompletionHandler)completionHandler
            option:(InspurUploadOption *)option {
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 90100)
    
    if ([InspurUploadManager checkAndNotifyError:key token:token input:asset complete:completionHandler]) {
        return;
    }

    @autoreleasepool {
        NSError *error = nil;
        __block InspurPHAssetFile *file = [[InspurPHAssetFile alloc] init:asset error:&error];
        if (error) {
            InspurResponseInfo *info = [InspurResponseInfo responseInfoWithFileError:error];
            [InspurUploadManager complete:token
                                  key:key
                               source:nil
                         responseInfo:info
                             response:nil
                          taskMetrics:nil
                             complete:completionHandler];
            return;
        }
        //[self putFileInternal:file key:key token:token complete:completionHandler option:option];
    }
#endif
}

- (void)putPHAssetResource:(PHAssetResource *)assetResource
                       key:(NSString *)key
                     token:(NSString *)token
                  complete:(QNUpCompletionHandler)completionHandler
                    option:(InspurUploadOption *)option {
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000)
    
    if ([InspurUploadManager checkAndNotifyError:key token:token input:assetResource complete:completionHandler]) {
        return;
    }
    @autoreleasepool {
        NSError *error = nil;
        __block InspurPHAssetResource *file = [[InspurPHAssetResource alloc] init:assetResource error:&error];
        if (error) {
            InspurResponseInfo *info = [InspurResponseInfo responseInfoWithFileError:error];
            [InspurUploadManager complete:token
                                  key:key
                               source:nil
                         responseInfo:info
                             response:nil
                          taskMetrics:nil
                             complete:completionHandler];
            return;
        }
        //[self putFileInternal:file key:key token:token complete:completionHandler option:option];
    }
#endif
}

- (void)putFileInternal:(id<InspurFileDelegate>)file
                    key:(NSString *)key
                 bucket:(NSString *)bucket
              accessKey:(NSString *)accessKey
        signatureHanlder:(QNUpSignatureHandler)signatureHandler
               complete:(QNUpCompletionHandler)completionHandler
                 option:(InspurUploadOption *)option {
    [self putInternal:[InspurUploadSourceFile file:file]
                  key:key
               bucket:bucket
            accessKey:accessKey
     signatureHanlder:signatureHandler
             complete:completionHandler
               option:option];
}

- (void)putInternal:(id<InspurUploadSource>)source
                key:(NSString *)key
             bucket:(NSString *)bucket
          accessKey:(NSString *)accessKey
    signatureHanlder:(QNUpSignatureHandler)signatureHandler
           complete:(QNUpCompletionHandler)completionHandler
             option:(InspurUploadOption *)option {
    
    @autoreleasepool {
        
        long deadLine = [[NSDate date] timeIntervalSince1970] + self.config.signatureTimeoutInterval;
        InspurUpToken *t = [[InspurUpToken alloc] initBucket:bucket
                                            deadLine:deadLine
                                           accessKey:accessKey];
        t.signatureHandler = ^(NSString *contentNeedSignature, QNUpTokenSignatureResultHandler result) {
            signatureHandler(contentNeedSignature, ^(NSString *signature, NSError *error){
                result(signature, error);
            });
        };
        
        if (t == nil || ![t isValid]) {
            InspurResponseInfo *info = [InspurResponseInfo responseInfoWithInvalidToken:@"invalid token"];
            [InspurUploadManager complete:[t toString]
                                  key:key
                               source:source
                         responseInfo:info
                             response:nil
                          taskMetrics:nil
                             complete:completionHandler];
            return;
        }


        QNUpTaskCompletionHandler complete = ^(InspurResponseInfo *info, NSString *key, QNUploadTaskMetrics *metrics, NSDictionary *resp) {
            [InspurUploadManager complete:[t toString]
                                  key:key
                               source:source
                         responseInfo:info
                             response:resp
                          taskMetrics:metrics
                             complete:completionHandler];
        };

        //QNServerConfigMonitor.token = [t toString];
        //[[QNTransactionManager shared] addDnsCheckAndPrefetchTransaction:self.config.zone token:t];

        long long sourceSize = [source getSize];
        if (sourceSize > 0 && sourceSize <= self.config.putThreshold) {
            NSError *error;
            NSData *data = [source readData:(NSInteger)sourceSize dataOffset:0 error:&error];
            [source close];
            if (error) {
                InspurResponseInfo *info = [InspurResponseInfo responseInfoWithFileError:error];
                [InspurUploadManager complete:[t toString]
                                      key:key
                                   source:source
                             responseInfo:info
                                 response:nil
                              taskMetrics:nil
                                 complete:completionHandler];
                return;
            }
            [self putData:data
                   bucket:@""
                 fileName:[source getFileName]
                      key:key
                accessKey:@""
         signatureHanlder:nil
                 complete:completionHandler
                   option:option];
            /*
            [self putData:data
                 fileName:[source getFileName]
                      key:key
                    token:token
                 complete:completionHandler
                   option:option];
             */
            return;
        }

        NSString *recorderKey = key;
        if (self.config.recorder != nil && self.config.recorderKeyGen != nil) {
            recorderKey = self.config.recorderKeyGen(key, [source getId]);
        }
        
        if (self.config.useConcurrentResumeUpload) {
            InspurConcurrentResumeUpload *up = [[InspurConcurrentResumeUpload alloc]
                                            initWithSource:source
                                            key:key
                                            token:t
                                            option:option
                                            configuration:self.config
                                            recorder:self.config.recorder
                                            recorderKey:recorderKey
                                            completionHandler:complete];
            QNAsyncRun(^{
                [up run];
            });
        } else {
            InspurPartsUpload *up = [[InspurPartsUpload alloc]
                                 initWithSource:source
                                 key:key
                                 token:t
                                 option:option
                                 configuration:self.config
                                 recorder:self.config.recorder
                                 recorderKey:recorderKey
                                 completionHandler:complete];
            QNAsyncRun(^{
                [up run];
            });
        }
    }
}

+ (BOOL)checkAndNotifyError:(NSString *)key
                      token:(NSString *)token
                      input:(NSObject *)input
                   complete:(QNUpCompletionHandler)completionHandler {
    if (completionHandler == nil) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                   reason:@"no completionHandler"
                                     userInfo:nil];
        return YES;
    }
    
    InspurResponseInfo *info = nil;
    if (input == nil) {
        info = [InspurResponseInfo responseInfoOfZeroData:@"no input data"];
    } else if ([input isKindOfClass:[NSData class]] && [(NSData *)input length] == 0) {
        info = [InspurResponseInfo responseInfoOfZeroData:@"no input data"];
    }
    /*
    else if (token == nil || [token isEqual:[NSNull null]] || [token isEqualToString:@""]) {
        info = [QNResponseInfo responseInfoWithInvalidToken:@"no token"];
    }
     */
    if (info != nil) {
        [InspurUploadManager complete:token
                              key:key
                           source:nil
                     responseInfo:info
                         response:nil
                      taskMetrics:nil
                         complete:completionHandler];
        return YES;
    } else {
        return NO;
    }
}

+ (void)complete:(NSString *)token
             key:(NSString *)key
          source:(NSObject *)source
    responseInfo:(InspurResponseInfo *)responseInfo
        response:(NSDictionary *)response
     taskMetrics:(QNUploadTaskMetrics *)taskMetrics
        complete:(QNUpCompletionHandler)completionHandler {
    
    //[QNUploadManager reportQuality:key source:source responseInfo:responseInfo taskMetrics:taskMetrics token:token];
    
    QNAsyncRunInMain(^{
        if (completionHandler) {
            completionHandler(responseInfo, key, response);
        }
    });
}


//MARK:-- 统计quality日志
+ (void)reportQuality:(NSString *)key
               source:(NSObject *)source
         responseInfo:(InspurResponseInfo *)responseInfo
          taskMetrics:(QNUploadTaskMetrics *)taskMetrics
                token:(NSString *)token{
    
    InspurUpToken *upToken = [InspurUpToken parse:token];
    QNUploadTaskMetrics *taskMetricsP = taskMetrics ?: [QNUploadTaskMetrics emptyMetrics];
    
    InspurReportItem *item = [InspurReportItem item];
    [item setReportValue:QNReportLogTypeQuality forKey:QNReportQualityKeyLogType];
    [item setReportValue:taskMetricsP.upType forKey:QNReportQualityKeyUpType];
    [item setReportValue:@([[NSDate date] timeIntervalSince1970]) forKey:QNReportQualityKeyUpTime];
    [item setReportValue:responseInfo.qualityResult forKey:QNReportQualityKeyResult];
    [item setReportValue:upToken.bucket forKey:QNReportQualityKeyTargetBucket];
    [item setReportValue:key forKey:QNReportQualityKeyTargetKey];
    [item setReportValue:taskMetricsP.totalElapsedTime forKey:QNReportQualityKeyTotalElapsedTime];
    [item setReportValue:taskMetricsP.ucQueryMetrics.totalElapsedTime forKey:QNReportQualityKeyUcQueryElapsedTime];
    [item setReportValue:taskMetricsP.requestCount forKey:QNReportQualityKeyRequestsCount];
    [item setReportValue:taskMetricsP.regionCount forKey:QNReportQualityKeyRegionsCount];
    [item setReportValue:taskMetricsP.bytesSend forKey:QNReportQualityKeyBytesSent];
    
    [item setReportValue:[InspurUtils systemName] forKey:QNReportQualityKeyOsName];
    [item setReportValue:[InspurUtils systemVersion] forKey:QNReportQualityKeyOsVersion];
    [item setReportValue:[InspurUtils sdkLanguage] forKey:QNReportQualityKeySDKName];
    [item setReportValue:[InspurUtils sdkVersion] forKey:QNReportQualityKeySDKVersion];
    
    [item setReportValue:responseInfo.requestReportErrorType forKey:QNReportQualityKeyErrorType];
    NSString *errorDesc = responseInfo.requestReportErrorType ? responseInfo.message : nil;
    [item setReportValue:errorDesc forKey:QNReportQualityKeyErrorDescription];
    
    [item setReportValue:taskMetricsP.lastMetrics.lastMetrics.hijacked forKey:QNReportBlockKeyHijacking];
    
    long long fileSize = -1;
    if ([source conformsToProtocol:@protocol(InspurUploadSource)]) {
        fileSize = [(id <InspurUploadSource>)source getSize];
    } else if ([source isKindOfClass:[NSData class]]) {
        fileSize = [(NSData *)source length];
    }
    [item setReportValue:@(fileSize) forKey:QNReportQualityKeyFileSize];
    if (responseInfo.isOK && fileSize > 0 && taskMetrics.totalElapsedTime) {
        NSNumber *speed = [InspurUtils calculateSpeed:fileSize totalTime:taskMetrics.totalElapsedTime.longLongValue];
        [item setReportValue:speed forKey:QNReportQualityKeyPerceptiveSpeed];
    }
    
    [kQNReporter reportItem:item token:token];
}

@end
