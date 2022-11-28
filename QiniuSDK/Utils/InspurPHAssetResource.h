//
//  QNPHAssetResource.h
//  InspurOSSSDK
//
//  Created by   Brook on 16/2/14.
//  Copyright © 2016年 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "InspurFileDelegate.h"

@class PHAssetResource;
API_AVAILABLE(ios(9.0)) @interface InspurPHAssetResource : NSObject <InspurFileDelegate>

/**
 *    打开指定文件
 *
 *    @param phAssetResource      PHLivePhoto的PHAssetResource文件
 *    @param error     输出的错误信息
 *
 *    @return 实例
 */
- (instancetype)init:(PHAssetResource *)phAssetResource
               error:(NSError *__autoreleasing *)error;

@end
