//
//  QNServerConfig.m
//  InspurOSSSDK
//
//  Created by Brook on 2021/8/30.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurServerConfig.h"

@interface InspurServerRegionConfig()
@property(nonatomic, assign)long clearId;
@property(nonatomic, assign)BOOL clearCache;
@end
@implementation InspurServerRegionConfig
+ (instancetype)config:(NSDictionary *)info {
    InspurServerRegionConfig *config = [[InspurServerRegionConfig alloc] init];
    config.clearId = [info[@"clear_id"] longValue];
    config.clearCache = [info[@"clear_cache"] longValue];
    return config;
}
@end

@interface InspurServerDnsServer()
@property(nonatomic, assign)BOOL isOverride;
@property(nonatomic, strong)NSArray <NSString *> *servers;
@end
@implementation InspurServerDnsServer
+ (instancetype)config:(NSDictionary *)info {
    InspurServerDnsServer *config = [[InspurServerDnsServer alloc] init];
    config.isOverride = [info[@"override_default"] boolValue];
    if (info[@"ips"] && [info[@"ips"] isKindOfClass:[NSArray class]]) {
        config.servers = info[@"ips"];
    } else if ([info[@"urls"] isKindOfClass:[NSArray class]]){
        config.servers = info[@"urls"];
    }
    return config;
}
@end

@interface InspurServerDohConfig()
@property(nonatomic, strong)NSNumber *enable;
@property(nonatomic, strong)InspurServerDnsServer *ipv4Server;
@property(nonatomic, strong)InspurServerDnsServer *ipv6Server;
@end
@implementation InspurServerDohConfig
+ (instancetype)config:(NSDictionary *)info {
    InspurServerDohConfig *config = [[InspurServerDohConfig alloc] init];
    config.enable = info[@"enabled"];
    config.ipv4Server = [InspurServerDnsServer config:info[@"ipv4"]];
    config.ipv6Server = [InspurServerDnsServer config:info[@"ipv6"]];
    return config;
}
@end

@interface InspurServerUdpDnsConfig()
@property(nonatomic, strong)NSNumber *enable;
@property(nonatomic, strong)InspurServerDnsServer *ipv4Server;
@property(nonatomic, strong)InspurServerDnsServer *ipv6Server;
@end
@implementation InspurServerUdpDnsConfig
+ (instancetype)config:(NSDictionary *)info {
    InspurServerUdpDnsConfig *config = [[InspurServerUdpDnsConfig alloc] init];
    config.enable = info[@"enabled"];
    config.ipv4Server = [InspurServerDnsServer config:info[@"ipv4"]];
    config.ipv6Server = [InspurServerDnsServer config:info[@"ipv6"]];
    return config;
}
@end


@interface InspurServerDnsConfig()
@property(nonatomic, strong)NSNumber *enable;
@property(nonatomic, assign)long clearId;
@property(nonatomic, assign)BOOL clearCache;
@property(nonatomic, strong)InspurServerUdpDnsConfig *udpConfig;
@property(nonatomic, strong)InspurServerDohConfig *dohConfig;
@end
@implementation InspurServerDnsConfig
+ (instancetype)config:(NSDictionary *)info {
    InspurServerDnsConfig *config = [[InspurServerDnsConfig alloc] init];
    config.enable = info[@"enabled"];
    config.clearId = [info[@"clear_id"] longValue];
    config.clearCache = [info[@"clear_cache"] longValue];
    config.dohConfig = [InspurServerDohConfig config:info[@"doh"]];
    config.udpConfig = [InspurServerUdpDnsConfig config:info[@"udp"]];
    return config;
}
@end


@interface InspurServerConfig()
@property(nonatomic, strong)NSDictionary *info;
@property(nonatomic, assign)double timestamp;
@property(nonatomic, assign)long ttl;
@property(nonatomic, strong)InspurServerRegionConfig *regionConfig;
@property(nonatomic, strong)InspurServerDnsConfig *dnsConfig;
@end
@implementation InspurServerConfig

+ (instancetype)config:(NSDictionary *)info {
    InspurServerConfig *config = [[InspurServerConfig alloc] init];
    config.ttl = [info[@"ttl"] longValue];
    config.regionConfig = [InspurServerRegionConfig config:info[@"region"]];
    config.dnsConfig = [InspurServerDnsConfig config:info[@"dns"]];
    
    if (config.ttl < 10) {
        config.ttl = 10;
    }
    
    NSMutableDictionary *mutableInfo = [info mutableCopy];
    if (info[@"timestamp"] != nil) {
        config.timestamp = [info[@"timestamp"] doubleValue];
    }
    if (config.timestamp == 0) {
        config.timestamp = [[NSDate date] timeIntervalSince1970];
        mutableInfo[@"timestamp"] = @(config.timestamp);
    }
    config.info = [mutableInfo copy];
    return config;
}

- (BOOL)isValid {
    return [[NSDate date] timeIntervalSince1970] < (self.timestamp + self.ttl);
}

@end
