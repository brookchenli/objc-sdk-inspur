//
//  InspurPHAssetFile.h
//  Pods
//
//  Created by   Brook on 15/10/21.
//
//

#import <Foundation/Foundation.h>

#import "InspurFileDelegate.h"

@class PHAsset;
API_AVAILABLE(ios(9.1)) @interface InspurPHAssetFile : NSObject <InspurFileDelegate>
/**
 *    打开指定文件
 *
 *    @param phAsset      文件资源
 *    @param error     输出的错误信息
 *
 *    @return 实例
 */
- (instancetype)init:(PHAsset *)phAsset
               error:(NSError *__autoreleasing *)error;
@end
