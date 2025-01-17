//
//  InspurPartsUploadPerformer.m
//  InspurOSSSDK
//
//  Created by Brook on 2020/12/1.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurLogUtil.h"
#import "InspurAsyncRun.h"
#import "InspurUpToken.h"
#import "InspurZoneInfo.h"
#import "InspurUploadOption.h"
#import "InspurConfiguration.h"
#import "InspurUploadInfo.h"
#import "InspurUploadRegionInfo.h"
#import "InspurRecorderDelegate.h"
#import "InspurUploadDomainRegion.h"
#import "InspurPartsUploadPerformer.h"
#import "InspurUpProgress.h"
#import "InspurRequestTransaction.h"

#define kInspurRecordFileInfoKey @"recordFileInfo"
#define kInspurRecordZoneInfoKey @"recordZoneInfo"

@interface InspurPartsUploadPerformer()

@property (nonatomic,   copy) NSString *key;
@property (nonatomic,   copy) NSString *fileName;
@property (nonatomic, strong) id <InspurUploadSource> uploadSource;
@property (nonatomic, strong) InspurUpToken *token;

@property (nonatomic, strong) InspurUploadOption *option;
@property (nonatomic, strong) InspurConfiguration *config;
@property (nonatomic, strong) id <InspurRecorderDelegate> recorder;
@property (nonatomic,   copy) NSString *recorderKey;

@property (nonatomic, strong) NSNumber *recoveredFrom;
@property (nonatomic, strong) id <InspurUploadRegion> targetRegion;
@property (nonatomic, strong) id <InspurUploadRegion> currentRegion;
@property (nonatomic, strong) InspurUploadInfo *uploadInfo;

@property(nonatomic, strong) InspurUpProgress *progress;
@property(nonatomic, strong) NSMutableArray <InspurRequestTransaction *> *uploadTransactions;
@property (nonatomic, strong) NSMutableDictionary <NSString *, NSString *> *signatureCache;


@end
@implementation InspurPartsUploadPerformer

- (instancetype)initWithSource:(id<InspurUploadSource>)uploadSource
                      fileName:(NSString *)fileName
                           key:(NSString *)key
                         token:(InspurUpToken *)token
                        option:(InspurUploadOption *)option
                 configuration:(InspurConfiguration *)config
                   recorderKey:(NSString *)recorderKey {
    if (self = [super init]) {
        _uploadSource = uploadSource;
        _fileName = fileName;
        _key = key;
        _token = token;
        _option = option;
        _config = config;
        _recorder = config.recorder;
        _recorderKey = recorderKey;
        _signatureCache = [NSMutableDictionary dictionary];
        [self initData];
    }
    return self;
}

- (void)initData {
    self.uploadTransactions = [NSMutableArray array];
    
    if (!self.uploadInfo) {
        self.uploadInfo = [self getDefaultUploadInfo];
    }
    [self recoverUploadInfoFromRecord];
}

- (BOOL)couldReloadInfo {
    return [self.uploadInfo couldReloadSource];
}

- (BOOL)reloadInfo {
    self.recoveredFrom = nil;
    [self.uploadInfo clearUploadState];
    return [self.uploadInfo reloadSource];
}

- (void)switchRegion:(id <InspurUploadRegion>)region {
    self.currentRegion = region;
    if (!self.targetRegion) {
        self.targetRegion = region;
    }
}

- (void)notifyProgress:(BOOL)isCompleted {
    if (self.uploadInfo == nil) {
        return;
    }
    
    if (isCompleted) {
        [self.progress notifyDone:self.key totalBytes:[self.uploadInfo getSourceSize]];
    } else {
        [self.progress progress:self.key uploadBytes:[self.uploadInfo uploadSize] totalBytes:[self.uploadInfo getSourceSize]];
    }
}

- (void)recordUploadInfo {

    NSString *key = self.recorderKey;
    if (self.recorder == nil || key == nil || key.length == 0) {
        return;
    }
    @synchronized (self) {
        NSDictionary *zoneInfo = [self.currentRegion zoneInfo].detailInfo;
        NSDictionary *uploadInfo = [self.uploadInfo toDictionary];
        if (zoneInfo && uploadInfo) {
            NSDictionary *info = @{kInspurRecordZoneInfoKey : zoneInfo,
                                   kInspurRecordFileInfoKey : uploadInfo};
            NSData *data = [NSJSONSerialization dataWithJSONObject:info options:NSJSONWritingPrettyPrinted error:nil];
            if (data) {
                [self.recorder set:key data:data];
            }
        }
    }
    InspurLogInfo(@"key:%@ recorderKey:%@ recordUploadInfo", self.key, self.recorderKey);
}

- (void)removeUploadInfoRecord {
    
    self.recoveredFrom = nil;
    [self.uploadInfo clearUploadState];
    [self.recorder del:self.recorderKey];
    InspurLogInfo(@"key:%@ recorderKey:%@ removeUploadInfoRecord", self.key, self.recorderKey);
}

- (void)recoverUploadInfoFromRecord {
    InspurLogInfo(@"key:%@ recorderKey:%@ recorder:%@ recoverUploadInfoFromRecord", self.key, self.recorderKey, self.recorder);
    
    NSString *key = self.recorderKey;
    if (self.recorder == nil || key == nil || [key isEqualToString:@""]) {
        return;
    }

    NSData *data = [self.recorder get:key];
    if (data == nil) {
        InspurLogInfo(@"key:%@ recorderKey:%@ recoverUploadInfoFromRecord data:nil", self.key, self.recorderKey);
        return;
    }

    NSError *error = nil;
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
    if (error != nil || ![info isKindOfClass:[NSDictionary class]]) {
        InspurLogInfo(@"key:%@ recorderKey:%@ recoverUploadInfoFromRecord json error", self.key, self.recorderKey);
        [self.recorder del:self.key];
        return;
    }

    InspurZoneInfo *zoneInfo = [InspurZoneInfo zoneInfoFromDictionary:info[kInspurRecordZoneInfoKey]];
    InspurUploadInfo *recoverUploadInfo = [self getFileInfoWithDictionary:info[kInspurRecordFileInfoKey]];
    
    if (zoneInfo && self.uploadInfo && [recoverUploadInfo isValid]
        && [self.uploadInfo isSameUploadInfo:recoverUploadInfo]) {
        InspurLogInfo(@"key:%@ recorderKey:%@ recoverUploadInfoFromRecord valid", self.key, self.recorderKey);
        
        [recoverUploadInfo checkInfoStateAndUpdate];
        self.uploadInfo = recoverUploadInfo;
        
        InspurUploadDomainRegion *region = [[InspurUploadDomainRegion alloc] init];
        [region setupRegionData:zoneInfo];
        self.currentRegion = region;
        self.targetRegion = region;
        self.recoveredFrom = @([recoverUploadInfo uploadSize]);
    } else {
        InspurLogInfo(@"key:%@ recorderKey:%@ recoverUploadInfoFromRecord invalid", self.key, self.recorderKey);
        
        [self.recorder del:self.key];
        self.currentRegion = nil;
        self.targetRegion = nil;
        self.recoveredFrom = nil;
    }
}

- (InspurRequestTransaction *)createUploadRequestTransaction {
    InspurRequestTransaction *transaction = [[InspurRequestTransaction alloc] initWithConfig:self.config
                                                                        uploadOption:self.option
                                                                        targetRegion:self.targetRegion
                                                                       currentRegion:self.currentRegion
                                                                                 key:self.key
                                                                               token:self.token];
    transaction.signatureCache = self.signatureCache;
    @synchronized (self) {
        [self.uploadTransactions addObject:transaction];
    }
    return transaction;
}

- (void)destroyUploadRequestTransaction:(InspurRequestTransaction *)transaction {
    if (transaction) {
        @synchronized (self) {
            [self.uploadTransactions removeObject:transaction];
        }
    }
}

- (InspurUploadInfo *)getFileInfoWithDictionary:(NSDictionary *)fileInfoDictionary {
    return nil;
}

- (InspurUploadInfo *)getDefaultUploadInfo {
    return nil;
}

- (void)serverInit:(void (^)(InspurResponseInfo * _Nullable,
                             InspurUploadRegionRequestMetrics * _Nullable,
                             NSDictionary * _Nullable))completeHandler {}

- (void)uploadNextData:(void (^)(BOOL stop,
                                 InspurResponseInfo * _Nullable,
                                 InspurUploadRegionRequestMetrics * _Nullable,
                                 NSDictionary * _Nullable))completeHandler {}

- (void)completeUpload:(void (^)(InspurResponseInfo * _Nullable,
                                 InspurUploadRegionRequestMetrics * _Nullable,
                                 NSDictionary * _Nullable))completeHandler {}

- (void)updateKeyIfNeeded:(InspurResponseInfo *)responseInfo {
    NSString *key = self.key;
    NSString *objectName = responseInfo.responseHeader[@"object-name"];
    if (!key && objectName.length > 0) {
        self.key = objectName;
    }
}

- (InspurUpProgress *)progress {
    if (_progress == nil) {
        _progress = [InspurUpProgress progress:self.option.progressHandler byteProgress:self.option.byteProgressHandler];
    }
    return _progress;
}

@end
