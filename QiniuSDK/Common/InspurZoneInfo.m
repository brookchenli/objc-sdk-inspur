//
//  QNZoneInfo.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "InspurZoneInfo.h"

NSString * const QNZoneInfoSDKDefaultIOHost = @"default_io_host";
NSString * const QNZoneInfoEmptyRegionId = @"none";

@interface InspurZoneInfo()

@property(nonatomic, strong) NSDate *buildDate;

@property(nonatomic,   copy)NSString *regionId;
@property(nonatomic, assign) long ttl;
@property(nonatomic, assign)BOOL http3Enabled;
@property(nonatomic, strong)NSArray<NSString *> *domains;
@property(nonatomic, strong)NSArray<NSString *> *old_domains;

@property(nonatomic, strong)NSArray <NSString *> *allHosts;
@property(nonatomic, strong) NSDictionary *detailInfo;

@end
@implementation InspurZoneInfo

+ (InspurZoneInfo *)zoneInfoWithMainHosts:(NSArray <NSString *> *)mainHosts
                             regionId:(NSString * _Nullable)regionId{
    return [self zoneInfoWithMainHosts:mainHosts oldHosts:nil regionId:regionId];
}

+ (InspurZoneInfo *)zoneInfoWithMainHosts:(NSArray <NSString *> *)mainHosts
                             oldHosts:(NSArray <NSString *> * _Nullable)oldHosts
                             regionId:(NSString * _Nullable)regionId{
    
    if (!mainHosts || ![mainHosts isKindOfClass:[NSArray class]] || mainHosts.count == 0) {
        return nil;
    }
    
    if (mainHosts && ![mainHosts isKindOfClass:[NSArray class]]) {
        mainHosts = nil;
    }
    
    InspurZoneInfo *zoneInfo = [InspurZoneInfo zoneInfoFromDictionary:@{@"ttl" : @(-1),
                                                                @"region" : regionId ?: QNZoneInfoEmptyRegionId,
                                                                @"up" : @{@"domains" : mainHosts ?: @[],
                                                                          @"old" : oldHosts ?: @[]},
                                                                }];
    return zoneInfo;
}

+ (InspurZoneInfo *)zoneInfoFromDictionary:(NSDictionary *)detailInfo {
    if (![detailInfo isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    NSString *regionId = [detailInfo objectForKey:@"region"];
    if (regionId == nil) {
        regionId = QNZoneInfoEmptyRegionId;
    }
    long ttl = [[detailInfo objectForKey:@"ttl"] longValue];
    BOOL http3Enabled = false;
    if ([detailInfo[@"features"] isKindOfClass:[NSDictionary class]] &&
        [detailInfo[@"features"][@"http3"] isKindOfClass:[NSDictionary class]]) {
        http3Enabled = [detailInfo[@"features"][@"http3"][@"enabled"] boolValue];
    }
    NSDictionary *up = [detailInfo objectForKey:@"up"];
    NSArray *domains = [up objectForKey:@"domains"];
    NSArray *old_domains = [up objectForKey:@"old"];
    
    NSMutableArray *allHosts = [NSMutableArray array];
    InspurZoneInfo *zoneInfo = [[InspurZoneInfo alloc] init:ttl regionId:regionId];
    zoneInfo.http3Enabled = http3Enabled;
    if ([domains isKindOfClass:[NSArray class]]) {
        zoneInfo.domains = domains;
        [allHosts addObjectsFromArray:domains];
    }
    if ([old_domains isKindOfClass:[NSArray class]]) {
        zoneInfo.old_domains = old_domains;
        [allHosts addObjectsFromArray:old_domains];
    }
    zoneInfo.allHosts = [allHosts copy];
    
    zoneInfo.detailInfo = detailInfo;
    
    return zoneInfo;
}

- (instancetype)init:(long)ttl
            regionId:(NSString *)regionId {
    if (self = [super init]) {
        _ttl = ttl;
        _buildDate = [NSDate date];
        _regionId = regionId;
    }
    return self;
}

- (BOOL)isValid{
    if (self.ttl < 0) {
        return true;
    }
    
    NSDate *currentDate = [NSDate date];
    return self.ttl > [currentDate timeIntervalSinceDate:self.buildDate];
}

- (id)copyWithZone:(NSZone *)zone {
    InspurZoneInfo *zoneInfo = [[InspurZoneInfo allocWithZone:zone] init];
    zoneInfo.ttl = self.ttl;
    zoneInfo.buildDate = self.buildDate;
    zoneInfo.http3Enabled = self.http3Enabled;
    zoneInfo.regionId = self.regionId;
    zoneInfo.domains = [self.domains copy];
    zoneInfo.old_domains = [self.old_domains copy];
    zoneInfo.allHosts = [self.allHosts copy];
    zoneInfo.detailInfo = [self.detailInfo copy];
    return zoneInfo;
}


@end

@interface InspurZonesInfo()
@property (nonatomic, assign) BOOL isTemporary;
@property (nonatomic, strong) NSArray<InspurZoneInfo *> *zonesInfo;
@end
@implementation InspurZonesInfo

- (instancetype)initWithZonesInfo:(NSArray<InspurZoneInfo *> *)zonesInfo{
    self = [super init];
    if (self) {
        _zonesInfo = zonesInfo;
    }
    return self;
}

+ (instancetype)infoWithDictionary:(NSDictionary *)dictionary {
    return [self infoWithDictionary:dictionary actionType:QNActionTypeNone];
}

+ (instancetype)infoWithDictionary:(NSDictionary *)dictionary actionType:(QNActionType)actionType {
    NSMutableArray *zonesInfo = [NSMutableArray array];
    
    NSArray *supportApis = [InspurApiType apisWithActionType:actionType];
    if (supportApis != nil && supportApis.count > 0) {
        NSMutableDictionary *universal = [dictionary[@"universal"] mutableCopy];
        if ([universal isKindOfClass:[NSDictionary class]]) {
            
            BOOL support = false;
            NSArray *apis = universal[@"support_apis"];
            if ([apis isKindOfClass:[NSArray class]]) {
                support = true;
                for (NSString *supportApi in supportApis) {
                    if (![apis containsObject:supportApi]) {
                        support = false;
                        break;
                    }
                }
            }
            
            // 同时满足所有 api
            if (support) {
                [universal setObject:@"universal" forKey:@"region"];
                InspurZoneInfo *zoneInfo = [InspurZoneInfo zoneInfoFromDictionary:universal];
                if (zoneInfo && [zoneInfo isValid]) {
                    [zonesInfo addObject:zoneInfo];
                }
            }
        }
    }
    
    NSArray *hosts = dictionary[@"hosts"];
    if ([hosts isKindOfClass:[NSArray class]]) {
        for (NSInteger i = 0; i < hosts.count; i++) {
            InspurZoneInfo *zoneInfo = [InspurZoneInfo zoneInfoFromDictionary:hosts[i]];
            if (zoneInfo && [zoneInfo isValid]) {
                [zonesInfo addObject:zoneInfo];
            }
        }
    }
    
    return [[[self class] alloc] initWithZonesInfo:zonesInfo];
}

- (void)toTemporary {
    _isTemporary = true;
}

- (BOOL)isValid {
    return [self.zonesInfo count] > 0 && [self.zonesInfo.firstObject isValid];
}

- (id)copyWithZone:(NSZone *)zone {
    NSMutableArray *zonesInfoArray = [NSMutableArray array];
    for (InspurZoneInfo *info in self.zonesInfo) {
        [zonesInfoArray addObject:[info copy]];
    }
    InspurZonesInfo *zonesInfo = [[InspurZonesInfo allocWithZone:zone] init];
    zonesInfo.zonesInfo = [zonesInfoArray copy];
    zonesInfo.isTemporary = self.isTemporary;
    return zonesInfo;
}

@end
