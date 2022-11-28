//
//  QNUploadInfoV1.h
//  QiniuSDK
//
//  Created by yangsen on 2021/5/10.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "InspurConfiguration.h"
#import "InspurUploadData.h"
#import "InspurUploadBlock.h"
#import "InspurUploadInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface InspurUploadInfoV1 : InspurUploadInfo

+ (instancetype)info:(id <InspurUploadSource>)source
       configuration:(InspurConfiguration *)configuration;


+ (instancetype)info:(id <InspurUploadSource>)source
          dictionary:(NSDictionary *)dictionary;

- (BOOL)isFirstData:(InspurUploadData *)data;

- (InspurUploadBlock *)nextUploadBlock:(NSError **)error;

- (InspurUploadData *)nextUploadData:(InspurUploadBlock *)block;

- (NSArray <NSString *> *)allBlocksContexts;

@end

NS_ASSUME_NONNULL_END
