//
//  InspurFile.h
//  InspurOSSSDK
//
//  Created by Brook on 15/7/25.
//  Copyright (c) 2015年 Inspur. All rights reserved.
//

#import "InspurFileDelegate.h"
#import <Foundation/Foundation.h>

@interface InspurFile : NSObject <InspurFileDelegate>
/**
 *    打开指定文件
 *
 *    @param path      文件路径
 *    @param error     输出的错误信息
 *
 *    @return 实例
 */
- (instancetype)init:(NSString *)path
               error:(NSError *__autoreleasing *)error;

@end
