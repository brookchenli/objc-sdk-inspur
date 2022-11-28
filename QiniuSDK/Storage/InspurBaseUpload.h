//
//  QNBaseUpload.h
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2020/4/19.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "InspurConfiguration.h"
#import "InspurCrc32.h"
#import "InspurRecorderDelegate.h"
#import "InspurUpToken.h"
#import "InspurUrlSafeBase64.h"
#import "InspurAsyncRun.h"
#import "InspurUploadManager.h"
#import "InspurUploadOption.h"
#import "InspurZone.h"
#import "InspurUploadSource.h"
#import "InspurUploadRequestMetrics.h"

extern NSString *const QNUploadUpTypeForm;
extern NSString *const QNUploadUpTypeResumableV1;
extern NSString *const QNUploadUpTypeResumableV2;

typedef void (^QNUpTaskCompletionHandler)(InspurResponseInfo *info, NSString *key, InspurUploadTaskMetrics *metrics, NSDictionary *resp);

@interface InspurBaseUpload : NSObject

@property (nonatomic,   copy, readonly) NSString *upType;
@property (nonatomic,   copy, readonly) NSString *key;
@property (nonatomic,   copy, readonly) NSString *fileName;
@property (nonatomic, strong, readonly) NSData *data;
@property (nonatomic, strong, readonly) id <InspurUploadSource> uploadSource;
@property (nonatomic, strong, readonly) InspurUpToken *token;
@property (nonatomic, strong, readonly) InspurUploadOption *option;
@property (nonatomic, strong, readonly) InspurConfiguration *config;
@property (nonatomic, strong, readonly) id <InspurRecorderDelegate> recorder;
@property (nonatomic,   copy, readonly) NSString *recorderKey;
@property (nonatomic, strong, readonly) QNUpTaskCompletionHandler completionHandler;

@property (nonatomic, strong, readonly) InspurUploadRegionRequestMetrics *currentRegionRequestMetrics;
@property (nonatomic, strong, readonly) InspurUploadTaskMetrics *metrics;


//MARK:-- 构造函数

/// file构造函数
/// @param file file信息
/// @param key 上传key
/// @param token 上传token
/// @param option 上传option
/// @param config 上传config
/// @param recorder 断点续传记录信息
/// @param recorderKey 断电上传信息保存的key值，需确保唯一性
/// @param completionHandler 上传完成回调
- (instancetype)initWithSource:(id<InspurUploadSource>)uploadSource
                           key:(NSString *)key
                         token:(InspurUpToken *)token
                        option:(InspurUploadOption *)option
                 configuration:(InspurConfiguration *)config
                      recorder:(id<InspurRecorderDelegate>)recorder
                   recorderKey:(NSString *)recorderKey
             completionHandler:(QNUpTaskCompletionHandler)completionHandler;

/// data 构造函数
/// @param data 上传data流
/// @param key 上传key
/// @param fileName 上传fileName
/// @param token 上传token
/// @param option 上传option
/// @param config 上传config
/// @param completionHandler 上传完成回调
- (instancetype)initWithData:(NSData *)data
                         key:(NSString *)key
                    fileName:(NSString *)fileName
                       token:(InspurUpToken *)token
                      option:(InspurUploadOption *)option
               configuration:(InspurConfiguration *)config
           completionHandler:(QNUpTaskCompletionHandler)completionHandler;

/// 初始化数据
- (void)initData;

//MARK: -- 上传

/// 开始上传流程
- (void)run;

/// 准备上传
- (int)prepareToUpload;

/// 重新加载上传数据
- (BOOL)reloadUploadInfo;

/// 开始上传
- (void)startToUpload;

/// 切换区域
- (BOOL)switchRegionAndUpload;
// 根据错误信息进行切换region并上传，return:是否切换region并上传
- (BOOL)switchRegionAndUploadIfNeededWithErrorResponse:(InspurResponseInfo *)errorResponseInfo;

/// 上传结束调用回调方法，在上传结束时调用，该方法内部会调用回调，已通知上层上传结束
/// @param info 上传返回信息
/// @param response 上传字典信息
- (void)complete:(InspurResponseInfo *)info
        response:(NSDictionary *)response;

//MARK: -- 机房管理

/// 在区域列表头部插入一个区域
- (void)insertRegionAtFirst:(id <InspurUploadRegion>)region;
/// 切换区域
- (BOOL)switchRegion;
/// 获取目标区域
- (id <InspurUploadRegion>)getTargetRegion;
/// 获取当前区域
- (id <InspurUploadRegion>)getCurrentRegion;

//MARK: -- upLog

// 一个上传流程可能会发起多个上传操作（如：上传多个分片），每个上传操作均是以一个Region的host做重试操作
- (void)addRegionRequestMetricsOfOneFlow:(InspurUploadRegionRequestMetrics *)metrics;

@end
