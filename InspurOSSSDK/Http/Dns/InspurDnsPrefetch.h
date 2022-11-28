//
//  QNDnsPrefetch.h
//  QnDNS
//
//  Created by Brook on 2020/3/26.
//  Copyright © 2020 com.inspur. All rights reserved.
//

#import "InspurDns.h"
#import "InspurUpToken.h"
#import "InspurConfiguration.h"
#import "InspurTransactionManager.h"

NS_ASSUME_NONNULL_BEGIN

#define kInspurDnsPrefetch [InspurDnsPrefetch shared]
@interface InspurDnsPrefetch : NSObject

/// 最近一次预取错误信息
@property(nonatomic,  copy, readonly)NSString *lastPrefetchedErrorMessage;

+ (instancetype)shared;

/// 根据host从缓存中读取DNS信息
/// @param host 域名
- (NSArray <id <InspurIDnsNetworkAddress> > *)getInetAddressByHost:(NSString *)host;

/// 通过安全的方式预取 dns
- (NSString *)prefetchHostBySafeDns:(NSString *)host error:(NSError **)error;

- (void)clearDnsCache:(NSError **)error;

@end



@interface InspurTransactionManager(Dns)

/// 添加加载本地dns事务
- (void)addDnsLocalLoadTransaction;

/// 添加检测并预取dns事务 如果未开启DNS 或 事务队列中存在token对应的事务未处理，则返回NO
/// @param currentZone 当前区域
/// @param token token信息
- (BOOL)addDnsCheckAndPrefetchTransaction:(InspurZone *)currentZone token:(InspurUpToken *)token;

/// 设置定时事务：检测已缓存DNS有效情况事务 无效会重新预取
- (void)setDnsCheckWhetherCachedValidTransactionAction;

@end

#define kInspurDnsSourceDoh @"doh"
#define kInspurDnsSourceUdp @"dns"
#define kInspurDnsSourceDnspod @"dnspod"
#define kInspurDnsSourceSystem @"system"
#define kInspurDnsSourceCustom @"customized"
#define kInspurDnsSourceNone @"none"

BOOL kInspurIsDnsSourceDoh(NSString * _Nullable source);
BOOL kInspurIsDnsSourceUdp(NSString * _Nullable source);
BOOL kInspurIsDnsSourceDnsPod(NSString * _Nullable source);
BOOL kInspurIsDnsSourceSystem(NSString * _Nullable source);
BOOL kInspurIsDnsSourceCustom(NSString * _Nullable source);

NS_ASSUME_NONNULL_END
