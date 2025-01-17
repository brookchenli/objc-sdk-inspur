//
//  InspurUploader.h
//  InspurOSSSDK
//
//  Created by Brook on 14-9-28.
//  Copyright (c) 2014年 Inspur. All rights reserved.
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

#import "InspurAsyncRun.h"
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
#import "InspurZone.h"

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
            recorderKeyGenerator:(InspurRecorderKeyGenerator)recorderKeyGenerator {
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
          domin:(NSString *)domin
         bucket:(NSString *)bucket
            key:(NSString *)key
       deadLine:(NSTimeInterval)deadLine
        accessKey:(NSString *)accessKey
signatureHanlder:(InspurUpSignatureHandler)signatureHandler
       complete:(InspurUpCompletionHandler)completionHandler
         option:(InspurUploadOption *)option {
    [self putData:data
            domin:domin
           bucket:bucket
         fileName:nil
              key:key
         deadLine:deadLine
        accessKey:accessKey
 signatureHanlder:signatureHandler
         complete:completionHandler option:option];
}

- (void)putData:(NSData *)data
          domin:(NSString *)domin
         bucket:(NSString *)bucket
       fileName:(NSString *)fileName
            key:(NSString *)key
       deadLine:(NSTimeInterval)deadLine
      accessKey:(NSString *)accessKey
signatureHanlder:(InspurUpSignatureHandler)signatureHandler
       complete:(InspurUpCompletionHandler)completionHandler
         option:(InspurUploadOption *)option {

    if ([InspurUploadManager checkAndNotifyError:key token:@"" input:data complete:completionHandler]) {
        return;
    }
    if (deadLine == 0 || deadLine < [[NSDate date] timeIntervalSince1970]) {
        deadLine = [[NSDate date] timeIntervalSince1970] + 24*3600;
    }
    InspurUpToken *t = [[InspurUpToken alloc] initBucket:bucket
                                        deadLine:deadLine
                                       accessKey:accessKey
                                                   domin:domin];
    t.signatureHandler = ^(NSArray<NSString *> * _Nullable contentsNeedSignature, InspurUpTokenSignatureResultHandler  _Nullable result) {
        signatureHandler(contentsNeedSignature, ^(NSArray <NSString *>*signaturedContents, NSError *error){
            result(signaturedContents, error);
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
    
    InspurUpTaskCompletionHandler complete = ^(InspurResponseInfo *info, NSString *key, InspurUploadTaskMetrics *metrics, NSDictionary *resp) {
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
    InspurAsyncRun(^{
        [up run];
    });
}

- (void)putFile:(NSString *)filePath
          domin:(NSString *)domin
         bucket:(NSString *)bucket
            key:(NSString *)key
       deadLine:(NSTimeInterval)deadLine
      accessKey:(NSString *)accessKey
signatureHanlder:(InspurUpSignatureHandler)signatureHandler
       complete:(InspurUpCompletionHandler)completionHandler
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
        [self putFileInternal:file
                        domin:domin
                          key:key
                     deadLine:deadLine
                       bucket:bucket
                    accessKey:accessKey
             signatureHanlder:signatureHandler
                     complete:completionHandler option:option];
    }
}

- (void)putPHAsset:(PHAsset *)asset
             domin:(NSString *)domin
            bucket:(NSString *)bucket
               key:(NSString *)key
          deadLine:(NSTimeInterval)deadLine
         accessKey:(NSString *)accessKey
  signatureHanlder:(InspurUpSignatureHandler)signatureHandler
          complete:(InspurUpCompletionHandler)completionHandler
            option:(InspurUploadOption *)option {
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 90100)
    InspurUpToken *token = [[InspurUpToken alloc] initBucket:bucket
                                        deadLine:deadLine
                                       accessKey:accessKey
                                                   domin:domin];
    if ([InspurUploadManager checkAndNotifyError:key token:token input:asset complete:completionHandler]) {
        return;
    }

    @autoreleasepool {
        NSError *error = nil;
        __block InspurPHAssetFile *file = [[InspurPHAssetFile alloc] init:asset error:&error];
        if (error) {
            InspurResponseInfo *info = [InspurResponseInfo responseInfoWithFileError:error];
            [InspurUploadManager complete:[token toString]
                                  key:key
                               source:nil
                         responseInfo:info
                             response:nil
                          taskMetrics:nil
                             complete:completionHandler];
            return;
        }
        [self putFileInternal:file
                        domin:domin
                          key:key
                     deadLine:deadLine
                       bucket:bucket
                    accessKey:accessKey
             signatureHanlder:signatureHandler
                     complete:completionHandler option:option];
    }
#endif
}

- (void)putPHAssetResource:(PHAssetResource *)assetResource
                     domin:(NSString *)domin
                    bucket:(NSString *)bucket
                       key:(NSString *)key
                  deadLine:(NSTimeInterval)deadLine
                 accessKey:(NSString *)accessKey
          signatureHanlder:(InspurUpSignatureHandler)signatureHandler
                  complete:(InspurUpCompletionHandler)completionHandler
                    option:(InspurUploadOption *)option {
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000)
    InspurUpToken *token = [[InspurUpToken alloc] init];
    if ([InspurUploadManager checkAndNotifyError:key token:[token toString] input:assetResource complete:completionHandler]) {
        return;
    }
    @autoreleasepool {
        NSError *error = nil;
        __block InspurPHAssetResource *file = [[InspurPHAssetResource alloc] init:assetResource error:&error];
        if (error) {
            InspurResponseInfo *info = [InspurResponseInfo responseInfoWithFileError:error];
            [InspurUploadManager complete:[token toString]
                                  key:key
                               source:nil
                         responseInfo:info
                             response:nil
                          taskMetrics:nil
                             complete:completionHandler];
            return;
        }
        [self putFileInternal:file
                        domin:domin
                          key:key
                     deadLine:deadLine
                       bucket:bucket
                    accessKey:accessKey
             signatureHanlder:signatureHandler
                     complete:completionHandler option:option];
    }
#endif
}

- (void)putFileInternal:(id<InspurFileDelegate>)file
                  domin:(NSString *)domin
                    key:(NSString *)key
               deadLine:(NSTimeInterval)deadLine
                 bucket:(NSString *)bucket
              accessKey:(NSString *)accessKey
        signatureHanlder:(InspurUpSignatureHandler)signatureHandler
               complete:(InspurUpCompletionHandler)completionHandler
                 option:(InspurUploadOption *)option {
    [self putInternal:[InspurUploadSourceFile file:file]
                domin:domin
                  key:key
             deadLine:deadLine
               bucket:bucket
            accessKey:accessKey
     signatureHanlder:signatureHandler
             complete:completionHandler
               option:option];
}

- (void)putInternal:(id<InspurUploadSource>)source
              domin:(NSString *)domin
                key:(NSString *)key
           deadLine:(NSTimeInterval)deadLine
             bucket:(NSString *)bucket
          accessKey:(NSString *)accessKey
    signatureHanlder:(InspurUpSignatureHandler)signatureHandler
           complete:(InspurUpCompletionHandler)completionHandler
             option:(InspurUploadOption *)option {
    
    @autoreleasepool {
        if (deadLine == 0 || deadLine < [[NSDate date] timeIntervalSince1970]) {
            deadLine = [[NSDate date] timeIntervalSince1970] + 24 * 3600;
        }
        InspurUpToken *t = [[InspurUpToken alloc] initBucket:bucket
                                            deadLine:deadLine
                                           accessKey:accessKey
                                                       domin:domin];
        t.signatureHandler = ^(NSArray<NSString *> * _Nullable contentsNeedSignature, InspurUpTokenSignatureResultHandler  _Nullable result) {
            signatureHandler(contentsNeedSignature, ^(NSArray <NSString *>*signaturedContents, NSError *error){
                result(signaturedContents, error);
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


        InspurUpTaskCompletionHandler complete = ^(InspurResponseInfo *info, NSString *key, InspurUploadTaskMetrics *metrics, NSDictionary *resp) {
            [InspurUploadManager complete:[t toString]
                                  key:key
                               source:source
                         responseInfo:info
                             response:resp
                          taskMetrics:metrics
                             complete:completionHandler];
        };

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
                    domin:domin
                   bucket:bucket
                 fileName:[source getFileName]
                      key:key
                 deadLine:deadLine
                accessKey:accessKey
         signatureHanlder:signatureHandler
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
            InspurAsyncRun(^{
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
            InspurAsyncRun(^{
                [up run];
            });
        }
    }
}

+ (BOOL)checkAndNotifyError:(NSString *)key
                      token:(NSString *)token
                      input:(NSObject *)input
                   complete:(InspurUpCompletionHandler)completionHandler {
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
     taskMetrics:(InspurUploadTaskMetrics *)taskMetrics
        complete:(InspurUpCompletionHandler)completionHandler {
    
    InspurAsyncRunInMain(^{
        if (completionHandler) {
            completionHandler(responseInfo, key, response);
        }
    });
}


//MARK:-- 统计quality日志
+ (void)reportQuality:(NSString *)key
               source:(NSObject *)source
         responseInfo:(InspurResponseInfo *)responseInfo
          taskMetrics:(InspurUploadTaskMetrics *)taskMetrics
                token:(NSString *)token{
    
    InspurUpToken *upToken = [InspurUpToken parse:token];
    InspurUploadTaskMetrics *taskMetricsP = taskMetrics ?: [InspurUploadTaskMetrics emptyMetrics];
    
    InspurReportItem *item = [InspurReportItem item];
    [item setReportValue:InspurReportLogTypeQuality forKey:InspurReportQualityKeyLogType];
    [item setReportValue:taskMetricsP.upType forKey:InspurReportQualityKeyUpType];
    [item setReportValue:@([[NSDate date] timeIntervalSince1970]) forKey:InspurReportQualityKeyUpTime];
    [item setReportValue:responseInfo.qualityResult forKey:InspurReportQualityKeyResult];
    [item setReportValue:upToken.bucket forKey:InspurReportQualityKeyTargetBucket];
    [item setReportValue:key forKey:InspurReportQualityKeyTargetKey];
    [item setReportValue:taskMetricsP.totalElapsedTime forKey:InspurReportQualityKeyTotalElapsedTime];
    [item setReportValue:taskMetricsP.ucQueryMetrics.totalElapsedTime forKey:InspurReportQualityKeyUcQueryElapsedTime];
    [item setReportValue:taskMetricsP.requestCount forKey:InspurReportQualityKeyRequestsCount];
    [item setReportValue:taskMetricsP.regionCount forKey:InspurReportQualityKeyRegionsCount];
    [item setReportValue:taskMetricsP.bytesSend forKey:InspurReportQualityKeyBytesSent];
    
    [item setReportValue:[InspurUtils systemName] forKey:InspurReportQualityKeyOsName];
    [item setReportValue:[InspurUtils systemVersion] forKey:InspurReportQualityKeyOsVersion];
    [item setReportValue:[InspurUtils sdkLanguage] forKey:InspurReportQualityKeySDKName];
    [item setReportValue:[InspurUtils sdkVersion] forKey:InspurReportQualityKeySDKVersion];
    
    [item setReportValue:responseInfo.requestReportErrorType forKey:InspurReportQualityKeyErrorType];
    NSString *errorDesc = responseInfo.requestReportErrorType ? responseInfo.message : nil;
    [item setReportValue:errorDesc forKey:InspurReportQualityKeyErrorDescription];
    
    [item setReportValue:taskMetricsP.lastMetrics.lastMetrics.hijacked forKey:InspurReportBlockKeyHijacking];
    
    long long fileSize = -1;
    if ([source conformsToProtocol:@protocol(InspurUploadSource)]) {
        fileSize = [(id <InspurUploadSource>)source getSize];
    } else if ([source isKindOfClass:[NSData class]]) {
        fileSize = [(NSData *)source length];
    }
    [item setReportValue:@(fileSize) forKey:InspurReportQualityKeyFileSize];
    if (responseInfo.isOK && fileSize > 0 && taskMetrics.totalElapsedTime) {
        NSNumber *speed = [InspurUtils calculateSpeed:fileSize totalTime:taskMetrics.totalElapsedTime.longLongValue];
        [item setReportValue:speed forKey:InspurReportQualityKeyPerceptiveSpeed];
    }
    
    [kInspurReporter reportItem:item token:token];
}

@end
