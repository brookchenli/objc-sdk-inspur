//
//  QNPartsUpload.h
//  QiniuSDK_Mac
//
//  Created by Brook on 2020/5/7.
//  Copyright © 2020 Inspur. All rights reserved.
//
/// 分片上传，默认为串行

#import "InspurBaseUpload.h"
#import "InspurUploadInfo.h"

NS_ASSUME_NONNULL_BEGIN

@class InspurRequestTransaction;
@interface InspurPartsUpload : InspurBaseUpload

/// 上传剩余的数据，此方法整合上传流程，上传操作为performUploadRestData，默认串行上传
- (void)uploadRestData:(dispatch_block_t)completeHandler;
- (void)performUploadRestData:(dispatch_block_t)completeHandler;

@end

NS_ASSUME_NONNULL_END
