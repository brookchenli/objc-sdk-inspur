//
//  QNUploadInfoV2.h
//  QiniuSDK
//
//  Created by yangsen on 2021/5/13.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "InspurConfiguration.h"
#import "InspurUploadData.h"
#import "InspurUploadInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface InspurUploadInfoV2 : InspurUploadInfo

@property(nonatomic,   copy, nullable)NSString *uploadId;
@property(nonatomic, strong, nullable)NSNumber *expireAt;

+ (instancetype)info:(id <InspurUploadSource>)source
       configuration:(InspurConfiguration *)configuration;


+ (instancetype)info:(id <InspurUploadSource>)source
          dictionary:(NSDictionary *)dictionary;

- (InspurUploadData *)nextUploadData:(NSError **)error;

- (NSInteger)getPartIndexOfData:(InspurUploadData *)data;

- (NSArray <NSDictionary <NSString *, NSObject *> *> *)getPartInfoArray;

@end

NS_ASSUME_NONNULL_END
