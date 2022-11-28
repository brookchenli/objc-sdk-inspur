//
//  QNUpProgress.h
//  QiniuSDK
//
//  Created by yangsen on 2021/5/21.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "InspurUploadOption.h"

NS_ASSUME_NONNULL_BEGIN

@interface InspurUpProgress : NSObject

+ (instancetype)progress:(QNUpProgressHandler)progress byteProgress:(QNUpByteProgressHandler)byteProgress;

- (void)progress:(NSString *)key uploadBytes:(long long)uploadBytes totalBytes:(long long)totalBytes;

- (void)notifyDone:(NSString *)key totalBytes:(long long)totalBytes;

@end

NS_ASSUME_NONNULL_END
