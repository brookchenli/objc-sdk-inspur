//
//  InspurRequestTransaction.h
//  InspurOSSSDK
//
//  Created by Brook on 2020/4/30.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "InspurUploadRegionInfo.h"

NS_ASSUME_NONNULL_BEGIN

@class InspurUpToken, InspurConfiguration, InspurUploadOption, InspurResponseInfo, InspurUploadRegionRequestMetrics;

typedef void(^QNRequestTransactionCompleteHandler)(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response);

// 单个对象只能执行一个事务，多个事务需要创建多个事务对象完成
@interface InspurRequestTransaction : NSObject

//MARK:-- 构造方法
- (instancetype)initWithHosts:(NSArray <NSString *> *)hosts
                     regionId:(NSString * _Nullable)regionId
                        token:(InspurUpToken *)token;

//MARK:-- upload事务构造方法 选择
- (instancetype)initWithConfig:(InspurConfiguration *)config
                  uploadOption:(InspurUploadOption *)uploadOption
                  targetRegion:(id <InspurUploadRegion>)targetRegion
                 currentRegion:(id <InspurUploadRegion>)currentRegion
                           key:(NSString * _Nullable)key
                         token:(InspurUpToken *)token;
- (instancetype)initWithConfig:(InspurConfiguration *)config
                  uploadOption:(InspurUploadOption *)uploadOption
                         hosts:(NSArray <NSString *> *)hosts
                      regionId:(NSString * _Nullable)regionId
                           key:(NSString * _Nullable)key
                         token:(InspurUpToken *)token;

- (void)queryUploadHosts:(QNRequestTransactionCompleteHandler)complete;

- (void)putData:(NSData *)data
       fileName:(NSString *)fileName
       progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
       complete:(QNRequestTransactionCompleteHandler)complete;

- (void)uploadFormData:(NSData *)data
              fileName:(NSString *)fileName
              progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
              complete:(QNRequestTransactionCompleteHandler)complete;

- (void)makeBlock:(long long)blockOffset
        blockSize:(long long)blockSize
   firstChunkData:(NSData *)firstChunkData
         progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
         complete:(QNRequestTransactionCompleteHandler)complete;

- (void)uploadChunk:(NSString *)blockContext
        blockOffset:(long long)blockOffset
          chunkData:(NSData *)chunkData
        chunkOffset:(long long)chunkOffset
           progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
           complete:(QNRequestTransactionCompleteHandler)complete;

- (void)makeFile:(long long)fileSize
        fileName:(NSString *)fileName
   blockContexts:(NSArray <NSString *> *)blockContexts
        complete:(QNRequestTransactionCompleteHandler)complete;


- (void)initPart:(QNRequestTransactionCompleteHandler)complete;

- (void)uploadPart:(NSString *)uploadId
         partIndex:(NSInteger)partIndex
          partData:(NSData *)partData
          progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
          complete:(QNRequestTransactionCompleteHandler)complete;

/**
 * partInfoArray
 *         |_ NSDictionary : { "etag": "<Etag>", "partNumber": <PartNumber> }
 */
- (void)completeParts:(NSString *)fileName
             uploadId:(NSString *)uploadId
        partInfoArray:(NSArray <NSDictionary *> *)partInfoArray
             complete:(QNRequestTransactionCompleteHandler)complete;

/**
 * 上传日志
 */
- (void)reportLog:(NSData *)logData
      logClientId:(NSString *)logClientId
         complete:(QNRequestTransactionCompleteHandler)complete;

/**
 * 获取服务端配置
 */
- (void)serverConfig:(QNRequestTransactionCompleteHandler)complete;

/**
 * 获取服务端针对某个用户的配置
 */
- (void)serverUserConfig:(QNRequestTransactionCompleteHandler)complete;

@end

NS_ASSUME_NONNULL_END
