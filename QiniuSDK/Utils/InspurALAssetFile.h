//
//  QNALAssetFile.h
//  QiniuSDK
//
//  Created by Brook on 15/7/25.
//  Copyright (c) 2015年 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "InspurFileDelegate.h"

#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED)
#if !TARGET_OS_MACCATALYST
@class ALAsset;
@interface InspurALAssetFile : NSObject <InspurFileDelegate>

/**
 *    打开指定文件
 *
 *    @param asset      资源文件
 *    @param error     输出的错误信息
 *
 *    @return 实例
 */
- (instancetype)init:(ALAsset *)asset
               error:(NSError *__autoreleasing *)error;
@end
#endif
#endif
