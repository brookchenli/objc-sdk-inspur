//
//  QNUploadSourceFile.h
//  InspurOSSSDK
//
//  Created by Brook on 2021/5/10.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurFileDelegate.h"
#import "InspurUploadSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface InspurUploadSourceFile : NSObject <InspurUploadSource>

+ (instancetype)file:(id <InspurFileDelegate>)file;

@end

NS_ASSUME_NONNULL_END
