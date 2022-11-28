//
//  QNServerConfig.h
//  QiniuSDK
//
//  Created by Brook on 2021/8/30.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface InspurServerRegionConfig : NSObject

@property(nonatomic, assign, readonly)long clearId;
@property(nonatomic, assign, readonly)BOOL clearCache;

+ (instancetype)config:(NSDictionary *)info;

@end


@interface InspurServerDnsServer : NSObject

@property(nonatomic, assign, readonly)BOOL isOverride;
@property(nonatomic, strong, readonly)NSArray <NSString *> *servers;

+ (instancetype)config:(NSDictionary *)info;

@end

@interface InspurServerDohConfig : NSObject

@property(nonatomic, strong, readonly)NSNumber *enable;
@property(nonatomic, strong, readonly)InspurServerDnsServer *ipv4Server;
@property(nonatomic, strong, readonly)InspurServerDnsServer *ipv6Server;

+ (instancetype)config:(NSDictionary *)info;

@end


@interface InspurServerUdpDnsConfig : NSObject

@property(nonatomic, strong, readonly)NSNumber *enable;
@property(nonatomic, strong, readonly)InspurServerDnsServer *ipv4Server;
@property(nonatomic, strong, readonly)InspurServerDnsServer *ipv6Server;

+ (instancetype)config:(NSDictionary *)info;

@end


@interface InspurServerDnsConfig : NSObject

@property(nonatomic, strong, readonly)NSNumber *enable;
@property(nonatomic, assign, readonly)long clearId;
@property(nonatomic, assign, readonly)BOOL clearCache;
@property(nonatomic, strong, readonly)InspurServerUdpDnsConfig *udpConfig;
@property(nonatomic, strong, readonly)InspurServerDohConfig *dohConfig;

+ (instancetype)config:(NSDictionary *)info;

@end


@interface InspurServerConfig : NSObject

@property(nonatomic, assign, readonly)BOOL isValid;
@property(nonatomic, assign, readonly)long ttl;
@property(nonatomic, strong, readonly)InspurServerRegionConfig *regionConfig;
@property(nonatomic, strong, readonly)InspurServerDnsConfig *dnsConfig;

@property(nonatomic, strong, readonly)NSDictionary *info;

+ (instancetype)config:(NSDictionary *)info;

@end

NS_ASSUME_NONNULL_END
