//
//  QNUploadServer.h
//  AppTest
//
//  Created by Brook on 2020/4/23.
//  Copyright © 2020 com.inspur. All rights reserved.
//

#import "InspurUploadRegionInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface InspurUploadServer : NSObject <InspurUploadServer>

@property(nonatomic,  copy)NSString *httpVersion;

/// 上传server构造方法
/// @param host host
/// @param ip host对应的IP
/// @param source ip查询来源，@"system"，@"httpdns"， @"none"， @"customized" 自定义请使用@"customized"
/// @param ipPrefetchedTime 根据host获取IP的时间戳
+ (instancetype)server:(NSString * _Nullable)host
                    ip:(NSString * _Nullable)ip
                source:(NSString * _Nullable)source
      ipPrefetchedTime:(NSNumber * _Nullable)ipPrefetchedTime;

@end

NS_ASSUME_NONNULL_END
