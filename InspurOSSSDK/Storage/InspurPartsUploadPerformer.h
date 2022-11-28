//
//  QNPartsUploadPerformer.h
//  InspurOSSSDK
//
//  Created by Brook on 2020/12/1.
//  Copyright © 2020 Inspur. All rights reserved.
//
/// 抽象类，不可以直接使用，需要使用子类

#import "InspurFileDelegate.h"
#import "InspurUploadSource.h"
#import "InspurResponseInfo.h"
#import "InspurUploadOption.h"
#import "InspurConfiguration.h"
#import "InspurUpToken.h"

NS_ASSUME_NONNULL_BEGIN

@protocol InspurUploadRegion;
@class InspurUploadInfo, InspurRequestTransaction, InspurUploadRegionRequestMetrics;

@interface InspurPartsUploadPerformer : NSObject

@property (nonatomic,   copy, readonly) NSString *key;
@property (nonatomic,   copy, readonly) NSString *fileName;
@property (nonatomic, strong, readonly) id <InspurUploadSource> uploadSource;
@property (nonatomic, strong, readonly) InspurUpToken *token;

@property (nonatomic, strong, readonly) InspurUploadOption *option;
@property (nonatomic, strong, readonly) InspurConfiguration *config;
@property (nonatomic, strong, readonly) id <InspurRecorderDelegate> recorder;
@property (nonatomic,   copy, readonly) NSString *recorderKey;

/// 断点续传时，起始上传偏移
@property(nonatomic, strong, readonly)NSNumber *recoveredFrom;
@property(nonatomic, strong, readonly)id <InspurUploadRegion> currentRegion;
@property(nonatomic, strong, readonly)InspurUploadInfo *uploadInfo;

- (instancetype)initWithSource:(id<InspurUploadSource>)uploadSource
                      fileName:(NSString *)fileName
                           key:(NSString *)key
                         token:(InspurUpToken *)token
                        option:(InspurUploadOption *)option
                 configuration:(InspurConfiguration *)config
                   recorderKey:(NSString *)recorderKey;

// 是否可以重新加载资源
- (BOOL)couldReloadInfo;

// 重新加载资源
- (BOOL)reloadInfo;

- (void)switchRegion:(id <InspurUploadRegion>)region;

/// 通知回调当前进度
- (void)notifyProgress:(BOOL)isCompleted;

/// 分片信息保存本地
- (void)recordUploadInfo;
/// 分片信息从本地移除
- (void)removeUploadInfoRecord;

/// 根据字典构造分片信息 【子类实现】
- (InspurUploadInfo *)getFileInfoWithDictionary:(NSDictionary * _Nonnull)fileInfoDictionary;
/// 根据配置构造分片信息 【子类实现】
- (InspurUploadInfo *)getDefaultUploadInfo;

- (InspurRequestTransaction *)createUploadRequestTransaction;
- (void)destroyUploadRequestTransaction:(InspurRequestTransaction *)transaction;

/// 上传前，服务端配置工作 【子类实现】
- (void)serverInit:(void(^)(InspurResponseInfo * _Nullable responseInfo,
                            InspurUploadRegionRequestMetrics * _Nullable metrics,
                            NSDictionary * _Nullable response))completeHandler;
/// 上传文件分片 【子类实现】
- (void)uploadNextData:(void(^)(BOOL stop,
                                InspurResponseInfo * _Nullable responseInfo,
                                InspurUploadRegionRequestMetrics * _Nullable metrics,
                                NSDictionary * _Nullable response))completeHandler;
/// 完成上传，服务端组织文件信息 【子类实现】
- (void)completeUpload:(void(^)(InspurResponseInfo * _Nullable responseInfo,
                                InspurUploadRegionRequestMetrics * _Nullable metrics,
                                NSDictionary * _Nullable response))completeHandler;

@end

NS_ASSUME_NONNULL_END
