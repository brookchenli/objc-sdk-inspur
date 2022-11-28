//
//  QNUploadSourceFile.h
//  QiniuSDK
//
//  Created by yangsen on 2021/5/10.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "InspurFileDelegate.h"
#import "InspurUploadSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface InspurUploadSourceFile : NSObject <InspurUploadSource>

+ (instancetype)file:(id <InspurFileDelegate>)file;

@end

NS_ASSUME_NONNULL_END
