//
//  QNBaseUpload.m
//  InspurOSSSDK
//
//  Created by WorkSpace_Sun on 2020/4/19.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurZoneInfo.h"
#import "InspurResponseInfo.h"
#import "InspurDefine.h"
#import "InspurBaseUpload.h"
#import "InspurUploadDomainRegion.h"

NSString *const QNUploadUpTypeForm = @"form";
NSString *const QNUploadUpTypeResumableV1 = @"resumable_v1";
NSString *const QNUploadUpTypeResumableV2 = @"resumable_v2";

@interface InspurBaseUpload ()

@property (nonatomic, strong) InspurBaseUpload *strongSelf;

@property (nonatomic,   copy) NSString *key;
@property (nonatomic,   copy) NSString *fileName;
@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong) id <InspurUploadSource> uploadSource;
@property (nonatomic, strong) InspurUpToken *token;
@property (nonatomic,   copy) NSString *identifier;
@property (nonatomic, strong) InspurUploadOption *option;
@property (nonatomic, strong) InspurConfiguration *config;
@property (nonatomic, strong) id <InspurRecorderDelegate> recorder;
@property (nonatomic,   copy) NSString *recorderKey;
@property (nonatomic, strong) QNUpTaskCompletionHandler completionHandler;

@property (nonatomic, assign)NSInteger currentRegionIndex;
@property (nonatomic, strong)NSMutableArray <id <InspurUploadRegion> > *regions;

@property (nonatomic, strong)InspurUploadRegionRequestMetrics *currentRegionRequestMetrics;
@property (nonatomic, strong) InspurUploadTaskMetrics *metrics;

@end

@implementation InspurBaseUpload

- (instancetype)initWithSource:(id<InspurUploadSource>)uploadSource
                           key:(NSString *)key
                         token:(InspurUpToken *)token
                        option:(InspurUploadOption *)option
                 configuration:(InspurConfiguration *)config
                      recorder:(id<InspurRecorderDelegate>)recorder
                   recorderKey:(NSString *)recorderKey
             completionHandler:(QNUpTaskCompletionHandler)completionHandler{
    return [self initWithSource:uploadSource data:nil fileName:[uploadSource getFileName] key:key token:token option:option configuration:config recorder:recorder recorderKey:recorderKey completionHandler:completionHandler];
}

- (instancetype)initWithData:(NSData *)data
                         key:(NSString *)key
                    fileName:(NSString *)fileName
                       token:(InspurUpToken *)token
                      option:(InspurUploadOption *)option
               configuration:(InspurConfiguration *)config
           completionHandler:(QNUpTaskCompletionHandler)completionHandler{
    return [self initWithSource:nil data:data fileName:fileName key:key token:token option:option configuration:config recorder:nil recorderKey:nil completionHandler:completionHandler];
}

- (instancetype)initWithSource:(id<InspurUploadSource>)uploadSource
                          data:(NSData *)data
                      fileName:(NSString *)fileName
                           key:(NSString *)key
                         token:(InspurUpToken *)token
                        option:(InspurUploadOption *)option
                 configuration:(InspurConfiguration *)config
                      recorder:(id<InspurRecorderDelegate>)recorder
                   recorderKey:(NSString *)recorderKey
             completionHandler:(QNUpTaskCompletionHandler)completionHandler{
    if (self = [super init]) {
        _uploadSource = uploadSource;
        _data = data;
        _fileName = fileName ?: @"?";
        _key = key;
        _token = token;
        _config = config;
        _option = option ?: [InspurUploadOption defaultOptions];
        _recorder = recorder;
        _recorderKey = recorderKey;
        _completionHandler = completionHandler;
        [self initData];
    }
    return self;
}

- (instancetype)init{
    if (self = [super init]) {
        [self initData];
    }
    return self;
}

- (void)initData{
    _strongSelf = self;
    _currentRegionIndex = 0;
}

- (void)run {
    [self.metrics start];
    
    kInspurWeakSelf;
    [_config.zone preQuery:self.token actionType:[self actionType] on:^(int code, InspurResponseInfo *responseInfo, InspurUploadRegionRequestMetrics *metrics) {
        kInspurStrongSelf;
        self.metrics.ucQueryMetrics = metrics;
        
        if (code == 0) {
            int prepareCode = [self prepareToUpload];
            if (prepareCode == 0) {
                [self startToUpload];
            } else {
                InspurResponseInfo *responseInfoP = [InspurResponseInfo errorResponseInfo:prepareCode errorDesc:nil];
                [self complete:responseInfoP response:responseInfoP.responseDictionary];
            }
        } else {
            [self complete:responseInfo response:responseInfo.responseDictionary];
        }
    }];
}

- (BOOL)reloadUploadInfo {
    return YES;
}

- (int)prepareToUpload{
    int ret = 0;
    if (![self setupRegions]) {
        ret = -1;
    }
    return ret;
}

- (void)startToUpload{
    self.currentRegionRequestMetrics = [[InspurUploadRegionRequestMetrics alloc] initWithRegion:[self getCurrentRegion]];
    [self.currentRegionRequestMetrics start];
}

// 内部不再调用
- (BOOL)switchRegionAndUpload{
    if (self.currentRegionRequestMetrics) {
        [self.currentRegionRequestMetrics end];
        [self.metrics addMetrics:self.currentRegionRequestMetrics];
        self.currentRegionRequestMetrics = nil;
    }
    
    BOOL isSwitched = [self switchRegion];
    if (isSwitched) {
        [self startToUpload];
    }
    return isSwitched;
}

// 根据错误信息进行切换region并上传，return:是否切换region并上传
- (BOOL)switchRegionAndUploadIfNeededWithErrorResponse:(InspurResponseInfo *)errorResponseInfo {
    if (!errorResponseInfo || errorResponseInfo.isOK || // 不存在 || 成功 不需要重试
        ![errorResponseInfo couldRetry] || ![self.config allowBackupHost]) {  // 不能重试
        return false;
    }
    
    if (self.currentRegionRequestMetrics) {
        [self.currentRegionRequestMetrics end];
        [self.metrics addMetrics:self.currentRegionRequestMetrics];
        self.currentRegionRequestMetrics = nil;
    }
    
    // 重新加载上传数据，上传记录 & Resource index 归零
    if (![self reloadUploadInfo]) {
        return false;
    }
    
    // 切换区域，当为 context 过期错误不需要切换区域
    if (!errorResponseInfo.isCtxExpiedError && ![self switchRegion]) {
        // 非 context 过期错误，但是切换 region 失败
        return false;
    }
    
    [self startToUpload];
    
    return true;
}

- (void)complete:(InspurResponseInfo *)info
        response:(NSDictionary *)response{
    
    [self.metrics end];
    [self.currentRegionRequestMetrics end];
    
    if (self.currentRegionRequestMetrics) {
        [self.metrics addMetrics:self.currentRegionRequestMetrics];
    }
    if (self.completionHandler) {
        self.completionHandler(info, _key, _metrics, response);
    }
    self.strongSelf = nil;
}

- (QNActionType)actionType {
    if ([self.upType containsString:QNUploadUpTypeForm]) {
        return QNActionTypeUploadByForm;
    } else if ([self.upType containsString:QNUploadUpTypeResumableV1]) {
        return QNActionTypeUploadByResumeV1;
    } else if ([self.upType containsString:QNUploadUpTypeResumableV2]) {
        return QNActionTypeUploadByResumeV2;
    } else {
        return QNActionTypeNone;
    }
}

//MARK:-- region
- (BOOL)setupRegions{
    NSMutableArray *defaultRegions = [NSMutableArray array];
    NSArray *zoneInfos = [self.config.zone getZonesInfoWithToken:self.token actionType:[self actionType]].zonesInfo;
    for (InspurZoneInfo *zoneInfo in zoneInfos) {
        InspurUploadDomainRegion *region = [[InspurUploadDomainRegion alloc] init];
        [region setupRegionData:zoneInfo];
        if (region.isValid) {
            [defaultRegions addObject:region];
        }
    }
    self.regions = defaultRegions;
    self.metrics.regions = defaultRegions;
    return defaultRegions.count > 0;
}

- (void)insertRegionAtFirst:(id <InspurUploadRegion>)region{
    BOOL hasRegion = NO;
    for (id <InspurUploadRegion> regionP in self.regions) {
        if ([regionP.zoneInfo.regionId isEqualToString:region.zoneInfo.regionId]) {
            hasRegion = YES;
            break;
        }
    }
    if (!hasRegion) {
        [self.regions insertObject:region atIndex:0];
    }
}

- (BOOL)switchRegion{
    BOOL ret = NO;
    @synchronized (self) {
        NSInteger regionIndex = _currentRegionIndex + 1;
        if (regionIndex < self.regions.count) {
            _currentRegionIndex = regionIndex;
            ret = YES;
        }
    }
    return ret;
}

- (id <InspurUploadRegion>)getTargetRegion{
    return self.regions.firstObject;
}

- (id <InspurUploadRegion>)getCurrentRegion{
    id <InspurUploadRegion> region = nil;
    @synchronized (self) {
        if (self.currentRegionIndex < self.regions.count) {
            region = self.regions[self.currentRegionIndex];
        }
    }
    return region;
}

- (void)addRegionRequestMetricsOfOneFlow:(InspurUploadRegionRequestMetrics *)metrics{
    if (metrics == nil) {
        return;
    }
    
    @synchronized (self) {
        if (self.currentRegionRequestMetrics == nil) {
            self.currentRegionRequestMetrics = metrics;
            return;
        }
    }
    
    [self.currentRegionRequestMetrics addMetrics:metrics];
}

- (InspurUploadTaskMetrics *)metrics {
    if (_metrics == nil) {
        _metrics = [InspurUploadTaskMetrics taskMetrics:self.upType];
    }
    return _metrics;
}
@end
