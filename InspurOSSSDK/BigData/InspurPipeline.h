//
//  InspurPipeline.h
//  InspurOSSSDK
//
//  Created by Brook on 2017/7/25.
//  Copyright © 2017年 Inspur. All rights reserved.
//

#ifndef InspurPipeline_h
#define InspurPipeline_h

@class InspurResponseInfo;

@interface InspurPipelineConfig : NSObject

/**
 * 上报打点域名
 */
@property (copy, nonatomic, readonly) NSString *host;

/**
 *    超时时间 单位 秒
 */
@property (assign) UInt32 timeoutInterval;

- (instancetype)initWithHost:(NSString *)host;

- (instancetype)init;

@end

/**
 *    上传完成后的回调函数
 *
 *    @param info 上下文信息，包括状态码，错误值
 */
typedef void (^InspurPipelineCompletionHandler)(InspurResponseInfo *info);

@interface InspurPipeline : NSObject

- (instancetype)init:(InspurPipelineConfig *)config;

- (void)pumpRepo:(NSString *)repo
           event:(NSDictionary *)data
           token:(NSString *)token
         handler:(InspurPipelineCompletionHandler)handler;

- (void)pumpRepo:(NSString *)repo
          events:(NSArray<NSDictionary *> *)data
           token:(NSString *)token
         handler:(InspurPipelineCompletionHandler)handler;

@end

#endif /* InspurPipeline_h */
