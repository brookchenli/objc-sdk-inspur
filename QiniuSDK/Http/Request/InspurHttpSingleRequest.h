//
//  QNHttpRequest+SingleRequestRetry.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "InspurUploadRequestInfo.h"
#import "InspurIUploadServer.h"

NS_ASSUME_NONNULL_BEGIN

@class InspurUploadRequestState, InspurResponseInfo, InspurConfiguration, InspurUploadOption, InspurUpToken, QNUploadSingleRequestMetrics;

typedef void(^QNSingleRequestCompleteHandler)(InspurResponseInfo * _Nullable responseInfo, NSArray <QNUploadSingleRequestMetrics *> * _Nullable metrics, NSDictionary * _Nullable response);

@interface InspurHttpSingleRequest : NSObject

- (instancetype)initWithConfig:(InspurConfiguration *)config
                  uploadOption:(InspurUploadOption *)uploadOption
                         token:(InspurUpToken *)token
                   requestInfo:(InspurUploadRequestInfo *)requestInfo
                  requestState:(InspurUploadRequestState *)requestState;


/// 网络请求
/// @param request 请求内容
/// @param server server信息，目前仅用于日志统计
/// @param shouldRetry 判断是否需要重试的block
/// @param progress 上传进度回调
/// @param complete 上传完成回调
- (void)request:(NSURLRequest *)request
         server:(id <InspurUploadServer>)server
    shouldRetry:(BOOL(^)(InspurResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))shouldRetry
       progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
       complete:(QNSingleRequestCompleteHandler)complete;

@end

NS_ASSUME_NONNULL_END
