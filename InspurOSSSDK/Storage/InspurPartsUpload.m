//
//  InspurPartsUpload.m
//  InspurOSSSDK_Mac
//
//  Created by Brook on 2020/5/7.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurDefine.h"
#import "InspurUtils.h"
#import "InspurLogUtil.h"
#import "InspurPartsUpload.h"
#import "InspurZoneInfo.h"
#import "InspurReportItem.h"
#import "InspurRequestTransaction.h"
#import "InspurPartsUploadPerformerV1.h"
#import "InspurPartsUploadPerformerV2.h"

#define kInspurRecordFileInfoKey @"recordFileInfo"
#define kInspurRecordZoneInfoKey @"recordZoneInfo"


@interface InspurPartsUpload()

@property(nonatomic, strong)InspurPartsUploadPerformer *uploadPerformer;

@property(nonatomic, strong)InspurResponseInfo *uploadDataErrorResponseInfo;
@property(nonatomic, strong)NSDictionary *uploadDataErrorResponse;

@end
@implementation InspurPartsUpload

- (void)initData {
    [super initData];
    // 根据文件从本地恢复上传信息，如果没有则重新构建上传信息
    if (self.config.resumeUploadVersion == InspurResumeUploadVersionV1) {
        InspurLogInfo(@"key:%@ 分片V1", self.key);
        self.uploadPerformer = [[InspurPartsUploadPerformerV1 alloc] initWithSource:self.uploadSource
                                                                       fileName:self.fileName
                                                                            key:self.key
                                                                          token:self.token
                                                                         option:self.option
                                                                  configuration:self.config
                                                                    recorderKey:self.recorderKey];
    } else {
        InspurLogInfo(@"key:%@ 分片V2", self.key);
        self.uploadPerformer = [[InspurPartsUploadPerformerV2 alloc] initWithSource:self.uploadSource
                                                                       fileName:self.fileName
                                                                            key:self.key
                                                                          token:self.token
                                                                         option:self.option
                                                                  configuration:self.config
                                                                    recorderKey:self.recorderKey];
    }
}

- (BOOL)isAllUploaded {
    return [self.uploadPerformer.uploadInfo isAllUploaded];
}

- (void)setErrorResponseInfo:(InspurResponseInfo *)responseInfo errorResponse:(NSDictionary *)response{
    if (!responseInfo) {
        return;
    }
    if (!self.uploadDataErrorResponseInfo || responseInfo.statusCode != kInspurSDKInteriorError) {
        self.uploadDataErrorResponseInfo = responseInfo;
        self.uploadDataErrorResponse = response ?: responseInfo.responseDictionary;
    }
}

- (int)prepareToUpload{
    int code = [super prepareToUpload];
    if (code != 0) {
        return code;
    }
    
    // 配置当前region
    if (self.uploadPerformer.currentRegion && self.uploadPerformer.currentRegion.isValid) {
        // currentRegion有值，为断点续传，将region插入至regionList第一处
        [self insertRegionAtFirst:self.uploadPerformer.currentRegion];
        InspurLogInfo(@"key:%@ 使用缓存region", self.key);
    } else {
        // currentRegion无值 切换region
        [self.uploadPerformer switchRegion:[self getCurrentRegion]];
    }
    InspurLogInfo(@"key:%@ region:%@", self.key, self.uploadPerformer.currentRegion.zoneInfo.regionId);
    
    if (self.uploadSource == nil) {
        code = kInspurLocalIOError;
    }
    return code;
}

- (BOOL)switchRegion{
    BOOL isSuccess = [super switchRegion];
    if (isSuccess) {
        [self.uploadPerformer switchRegion:self.getCurrentRegion];
        InspurLogInfo(@"key:%@ 切换region：%@", self.key , self.uploadPerformer.currentRegion.zoneInfo.regionId);
    }
    return isSuccess;
}

- (BOOL)switchRegionAndUploadIfNeededWithErrorResponse:(InspurResponseInfo *)errorResponseInfo {
    [self reportBlock];
    return [super switchRegionAndUploadIfNeededWithErrorResponse:errorResponseInfo];
}

- (BOOL)reloadUploadInfo {
    BOOL success = [super reloadUploadInfo];
    if (![super reloadUploadInfo]) {
        return NO;
    }
    
    // 重新加载资源
    return [self.uploadPerformer couldReloadInfo] && [self.uploadPerformer reloadInfo];
}

- (void)startToUpload{
    [super startToUpload];

    // 重置错误信息
    self.uploadDataErrorResponseInfo = nil;
    self.uploadDataErrorResponse = nil;
    
    
    InspurLogInfo(@"key:%@ serverInit", self.key);
    
    // 1. 启动upload
    kInspurWeakSelf;
    [self serverInit:^(InspurResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
        kInspurStrongSelf;
        
        if (!responseInfo.isOK) {
            if (![self switchRegionAndUploadIfNeededWithErrorResponse:responseInfo]) {
                [self complete:responseInfo response:response];
            }
            return;
        }
        [self updateKeyIfNeeded:responseInfo];
        [self.uploadPerformer updateKeyIfNeeded:responseInfo];
        InspurLogInfo(@"key:%@ uploadRestData", self.key);
        
        // 2. 上传数据
        kInspurWeakSelf;
        [self uploadRestData:^{
            kInspurStrongSelf;
            
            if (![self isAllUploaded]) {
                if (![self switchRegionAndUploadIfNeededWithErrorResponse:self.uploadDataErrorResponseInfo]) {
                    [self complete:self.uploadDataErrorResponseInfo response:self.uploadDataErrorResponse];
                }
                return;
            }
            
            // 只有再读取结束再能知道文件大小，需要检测
            if ([self.uploadPerformer.uploadInfo getSourceSize] == 0) {
                InspurResponseInfo *responseInfo = [InspurResponseInfo responseInfoOfZeroData:@"file is empty"];
                [self complete:responseInfo response:responseInfo.responseDictionary];
                return;
            }
            
            InspurLogInfo(@"key:%@ completeUpload errorResponseInfo:%@", self.key, self.uploadDataErrorResponseInfo);
            
            // 3. 组装文件
            kInspurWeakSelf;
            [self completeUpload:^(InspurResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
                kInspurStrongSelf;
                                
                if (!responseInfo.isOK) {
                    if (![self switchRegionAndUploadIfNeededWithErrorResponse:responseInfo]) {
                        [self complete:responseInfo response:response];
                    }
                    return;
                }
                [self complete:responseInfo response:response];
            }];
        }];
    }];
}

- (void)uploadRestData:(dispatch_block_t)completeHandler {
    InspurLogInfo(@"key:%@ 串行分片", self.key);
    [self performUploadRestData:completeHandler];
}

- (void)performUploadRestData:(dispatch_block_t)completeHandler {
    if ([self isAllUploaded]) {
        completeHandler();
        return;
    }
    
    kInspurWeakSelf;
    [self uploadNextData:^(BOOL stop, InspurResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
        kInspurStrongSelf;
        
        if (stop || !responseInfo.isOK) {
            completeHandler();
        } else {
            [self performUploadRestData:completeHandler];
        }
    }];
}

//MARK:-- concurrent upload model API
- (void)serverInit:(void(^)(InspurResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler {
    
    kInspurWeakSelf;
    void(^completeHandlerP)(InspurResponseInfo *, InspurUploadRegionRequestMetrics *, NSDictionary *) = ^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response){
        kInspurStrongSelf;
        
        if (!responseInfo.isOK) {
            [self setErrorResponseInfo:responseInfo errorResponse:response];
        }
        [self addRegionRequestMetricsOfOneFlow:metrics];
        completeHandler(responseInfo, response);
    };
    
    [self.uploadPerformer serverInit:completeHandlerP];
}

- (void)uploadNextData:(void(^)(BOOL stop, InspurResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler {
    
    kInspurWeakSelf;
    void(^completeHandlerP)(BOOL, InspurResponseInfo *, InspurUploadRegionRequestMetrics *, NSDictionary *) = ^(BOOL stop, InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response){
        kInspurStrongSelf;
        
        if (!responseInfo.isOK) {
            [self setErrorResponseInfo:responseInfo errorResponse:response];
        }
        [self addRegionRequestMetricsOfOneFlow:metrics];
        completeHandler(stop, responseInfo, response);
    };
    
    [self.uploadPerformer uploadNextData:completeHandlerP];
}

- (void)completeUpload:(void(^)(InspurResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler {
    
    kInspurWeakSelf;
    void(^completeHandlerP)(InspurResponseInfo *, InspurUploadRegionRequestMetrics *, NSDictionary *) = ^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response){
        kInspurStrongSelf;
        
        if (!responseInfo.isOK) {
            [self setErrorResponseInfo:responseInfo errorResponse:response];
        }
        [self addRegionRequestMetricsOfOneFlow:metrics];
        completeHandler(responseInfo, response);
    };
    [self.uploadPerformer completeUpload:completeHandlerP];
}


- (void)complete:(InspurResponseInfo *)info response:(NSDictionary *)response{
    [self.uploadSource close];
    if ([self shouldRemoveUploadInfoRecord:info]) {
        [self.uploadPerformer removeUploadInfoRecord];
    }
    
    [super complete:info response:response];
    
    [self reportBlock];
}

- (BOOL)shouldRemoveUploadInfoRecord:(InspurResponseInfo *)info {
    return info.isOK || info.statusCode == 612 || info.statusCode == 614 || info.statusCode == 701;
}

//MARK:-- 统计block日志
- (void)reportBlock{
    
    InspurUploadRegionRequestMetrics *metrics = self.currentRegionRequestMetrics ?: [InspurUploadRegionRequestMetrics emptyMetrics];
    
    InspurReportItem *item = [InspurReportItem item];
    [item setReportValue:InspurReportLogTypeBlock forKey:InspurReportBlockKeyLogType];
    [item setReportValue:@([[NSDate date] timeIntervalSince1970]) forKey:InspurReportBlockKeyUpTime];
    [item setReportValue:self.token.bucket forKey:InspurReportBlockKeyTargetBucket];
    [item setReportValue:self.key forKey:InspurReportBlockKeyTargetKey];
    [item setReportValue:[self getTargetRegion].zoneInfo.regionId forKey:InspurReportBlockKeyTargetRegionId];
    [item setReportValue:[self getCurrentRegion].zoneInfo.regionId forKey:InspurReportBlockKeyCurrentRegionId];
    [item setReportValue:metrics.totalElapsedTime forKey:InspurReportBlockKeyTotalElapsedTime];
    [item setReportValue:metrics.bytesSend forKey:InspurReportBlockKeyBytesSent];
    [item setReportValue:self.uploadPerformer.recoveredFrom forKey:InspurReportBlockKeyRecoveredFrom];
    [item setReportValue:@([self.uploadSource getSize]) forKey:InspurReportBlockKeyFileSize];
    [item setReportValue:@([InspurUtils getCurrentProcessID]) forKey:InspurReportBlockKeyPid];
    [item setReportValue:@([InspurUtils getCurrentThreadID]) forKey:InspurReportBlockKeyTid];
    
    [item setReportValue:metrics.metricsList.lastObject.hijacked forKey:InspurReportBlockKeyHijacking];
    
    // 统计当前 region 上传速度 文件大小 / 总耗时
    if (self.uploadDataErrorResponseInfo == nil && [self.uploadSource getSize] > 0 && [metrics totalElapsedTime] > 0) {
        NSNumber *speed = [InspurUtils calculateSpeed:[self.uploadSource getSize] totalTime:[metrics totalElapsedTime].longLongValue];
        [item setReportValue:speed forKey:InspurReportBlockKeyPerceptiveSpeed];
    }

    if (self.config.resumeUploadVersion == InspurResumeUploadVersionV1) {
        [item setReportValue:@(1) forKey:InspurReportBlockKeyUpApiVersion];
    } else {
        [item setReportValue:@(2) forKey:InspurReportBlockKeyUpApiVersion];
    }
    
    [item setReportValue:[InspurUtils getCurrentNetworkType] forKey:InspurReportBlockKeyClientTime];
    [item setReportValue:[InspurUtils systemName] forKey:InspurReportBlockKeyOsName];
    [item setReportValue:[InspurUtils systemVersion] forKey:InspurReportBlockKeyOsVersion];
    [item setReportValue:[InspurUtils sdkLanguage] forKey:InspurReportBlockKeySDKName];
    [item setReportValue:[InspurUtils sdkVersion] forKey:InspurReportBlockKeySDKVersion];
    
    [kInspurReporter reportItem:item token:self.token.token];
}

- (NSString *)upType {
    if (self.config == nil) {
        return nil;
    }
    
    NSString *sourceType = @"";
    if ([self.uploadSource respondsToSelector:@selector(sourceType)]) {
        sourceType = [self.uploadSource sourceType];
    }
    if (self.config.resumeUploadVersion == InspurResumeUploadVersionV1) {
        return [NSString stringWithFormat:@"%@<%@>",InspurUploadUpTypeResumableV1, sourceType];
    } else {
        return [NSString stringWithFormat:@"%@<%@>",InspurUploadUpTypeResumableV2, sourceType];
    }
}

@end
