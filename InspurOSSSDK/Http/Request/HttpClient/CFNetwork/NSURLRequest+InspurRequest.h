//
//  NSURLRequest+InspurRequest.h
//  AppTest
//
//  Created by Brook on 2020/4/8.
//  Copyright © 2020 com.inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURLRequest(InspurRequest)

/// 请求id【内部使用】
/// 只有通过设置inspur_domain才会有效
@property(nonatomic, strong, nullable, readonly)NSString *inspur_identifier;

/// 请求domain【内部使用】
/// 只有通过NSMutableURLRequest设置才会有效
@property(nonatomic, strong, nullable, readonly)NSString *inspur_domain;

/// 请求ip【内部使用】
/// 只有通过NSMutableURLRequest设置才会有效
@property(nonatomic, strong, nullable, readonly)NSString *inspur_ip;

/// 请求头信息 去除七牛内部标记占位
@property(nonatomic, strong, nullable, readonly)NSDictionary *inspur_allHTTPHeaderFields;

+ (instancetype)inspur_requestWithURL:(NSURL *)url;

/// 获取请求体
- (NSData *)inspur_getHttpBody;

- (BOOL)inspur_isHttps;

@end


@interface NSMutableURLRequest(InspurRequest)

/// 请求domain【内部使用】
@property(nonatomic, strong, nullable)NSString *inspur_domain;
/// 请求ip【内部使用】
@property(nonatomic, strong, nullable)NSString *inspur_ip;

@end

NS_ASSUME_NONNULL_END

