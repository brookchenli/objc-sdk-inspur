//
//  QNHttpRequest.h
//  QiniuSDK
//
//  Created by Brook on 2020/4/29.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "InspurHttpSingleRequest.h"
#import "InspurUploadRegionInfo.h"

NS_ASSUME_NONNULL_BEGIN


@class InspurUploadRequestState, InspurResponseInfo, InspurConfiguration, InspurUploadOption, InspurUpToken, InspurUploadRegionRequestMetrics;

typedef void(^QNRegionRequestCompleteHandler)(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response);

@interface InspurHttpRegionRequest : NSObject

@property(nonatomic, strong, readonly)InspurConfiguration *config;
@property(nonatomic, strong, readonly)InspurUploadOption *uploadOption;


- (instancetype)initWithConfig:(InspurConfiguration *)config
                  uploadOption:(InspurUploadOption *)uploadOption
                         token:(InspurUpToken *)token
                        region:(id <InspurUploadRegion>)region
                   requestInfo:(InspurUploadRequestInfo *)requestInfo
                  requestState:(InspurUploadRequestState *)requestState;


- (void)get:(NSString * _Nullable)action
    headers:(NSDictionary * _Nullable)headers
shouldRetry:(BOOL(^)(InspurResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))shouldRetry
   complete:(QNRegionRequestCompleteHandler)complete;

- (void)post:(NSString * _Nullable)action
     headers:(NSDictionary * _Nullable)headers
        body:(NSData * _Nullable)body
 shouldRetry:(BOOL(^)(InspurResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))shouldRetry
    progress:(void(^_Nullable)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
    complete:(QNRegionRequestCompleteHandler)complete;


- (void)put:(NSString *)action
    headers:(NSDictionary * _Nullable)headers
       body:(NSData * _Nullable)body
shouldRetry:(BOOL(^)(InspurResponseInfo *responseInfo, NSDictionary *response))shouldRetry
   progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
   complete:(QNRegionRequestCompleteHandler)complete;

@end

NS_ASSUME_NONNULL_END
