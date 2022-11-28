//
//  QNDnsCacheFile.h
//  QnDNS
//
//  Created by Brook on 2020/3/26.
//  Copyright © 2020 com.inspur. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "InspurRecorderDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface InspurDnsCacheFile : NSObject<InspurRecorderDelegate>

/// DNS解析信息本地缓存路径
@property(nonatomic,  copy, readonly)NSString *directory;

/// 构造方法 路径不存在，或进行创建，创建失败返回为nil
/// @param directory 路径
/// @param perror 构造错误时，会有值
+ (instancetype _Nullable)dnsCacheFile:(NSString *)directory
                                 error:(NSError **)error;

- (void)clearCache:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
