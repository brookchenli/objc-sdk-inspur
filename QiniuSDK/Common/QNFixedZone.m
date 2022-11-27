//
//  QNFixZone.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNFixedZone.h"
#import "QNZoneInfo.h"

@interface QNFixedZone ()

@property (nonatomic, strong) QNZonesInfo *zonesInfo;

@end

@implementation QNFixedZone

+ (instancetype)zone0 {
    static QNFixedZone *z0 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        z0 = [[QNFixedZone alloc] initWithUpDomainList:@[@"upload.qiniup.com", @"up.qiniup.com"]
                                             oldUpList:@[@"upload.qbox.me", @"up.qbox.me"]
                                              regionId:@"z0"];
    });
    return z0;
}

+ (instancetype)north3 {
    static QNFixedZone *north3 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        north3 = [[QNFixedZone alloc] initWithUpDomainList:@[@"inspurcloudoss.com"]
                                             oldUpList:@[@"inspurcloudoss.com"]
                                              regionId:@"oss.cn-north-3"];
    });
    return north3;
}

+ (instancetype)zoneCnEast2 {
    static QNFixedZone *zoneCnEast2 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        zoneCnEast2 = [[QNFixedZone alloc] initWithUpDomainList:@[@"upload-cn-east-2.qiniup.com", @"up-cn-east-2.qiniup.com"]
                                                      oldUpList:nil
                                                       regionId:@"cn-east-2"];
    });
    return zoneCnEast2;
}

+ (instancetype)zone1 {
    static QNFixedZone *z1 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        z1 = [[QNFixedZone alloc] initWithUpDomainList:@[@"upload-z1.qiniup.com", @"up-z1.qiniup.com"]
                                             oldUpList:@[@"upload-z1.qbox.me", @"up-z1.qbox.me"]
                                              regionId:@"z1"];
    });
    return z1;
}

+ (instancetype)zone2 {
    static QNFixedZone *z2 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        z2 = [[QNFixedZone alloc] initWithUpDomainList:@[@"upload-z2.qiniup.com", @"up-z2.qiniup.com"]
                                             oldUpList:@[@"upload-z2.qbox.me", @"up-z2.qbox.me"]
                                              regionId:@"z2"];
    });
    return z2;
}

+ (instancetype)zoneApNorthEast1 {
    static QNFixedZone *zoneNorthEast1 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        zoneNorthEast1 = [[QNFixedZone alloc] initWithUpDomainList:@[@"upload-ap-northeast-1.qiniup.com", @"up-ap-northeast-1.qiniup.com"]
                                                         oldUpList:nil
                                                          regionId:@"ap-northeast-1"];
    });
    return zoneNorthEast1;
}

+ (instancetype)zoneNa0 {
    static QNFixedZone *zNa0 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        zNa0 = [[QNFixedZone alloc] initWithUpDomainList:@[@"upload-na0.qiniup.com", @"up-na0.qiniup.com"]
                                               oldUpList:@[@"upload-na0.qbox.me", @"up-na0.qbox.me"]
                                                regionId:@"na0"];
    });
    return zNa0;
}

+ (instancetype)zoneAs0 {
    static QNFixedZone *zAs0 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        zAs0 = [[QNFixedZone alloc] initWithUpDomainList:@[@"upload-as0.qiniup.com", @"up-as0.qiniup.com"]
                                               oldUpList:@[@"upload-as0.qbox.me", @"up-as0.qbox.me"]
                                                regionId:@"as0"];;
    });
    return zAs0;
}

+ (QNFixedZone *)localsZoneInfo{

    NSArray *zones = @[[QNFixedZone zone0],
                       [QNFixedZone zone1],
                       [QNFixedZone zone2],
                       [QNFixedZone zoneCnEast2],
                       [QNFixedZone zoneNa0],
                       [QNFixedZone zoneApNorthEast1],
                       [QNFixedZone zoneAs0]];
    
    NSMutableArray <QNZoneInfo *> *zoneInfoArray = [NSMutableArray array];
    for (QNFixedZone *zone in zones) {
        if (zone.zonesInfo.zonesInfo) {
            [zoneInfoArray addObjectsFromArray:zone.zonesInfo.zonesInfo];
        }
    }
    
    QNFixedZone *fixedZone = [[QNFixedZone alloc] init];
    fixedZone.zonesInfo = [[QNZonesInfo alloc] initWithZonesInfo:[zoneInfoArray copy]];
    [fixedZone.zonesInfo toTemporary];
    return fixedZone;
}

+ (instancetype)createWithHost:(NSArray<NSString *> *)upList {
    return [[QNFixedZone alloc] initWithUpDomainList:upList oldUpList:nil regionId:nil];
}

- (QNZonesInfo *)createZonesInfo:(NSArray <NSString *> *)upDomains
                        regionId:(NSString *)regionId {
    return [self createZonesInfo:upDomains oldUpDomains:nil regionId:regionId];
}

- (QNZonesInfo *)createZonesInfo:(NSArray <NSString *> *)upDomains
                    oldUpDomains:(NSArray <NSString *> *)oldUpDomains
                        regionId:(NSString *)regionId {
    if (!upDomains && upDomains.count == 0) {
        return nil;
    }

    QNZoneInfo *zoneInfo = [QNZoneInfo zoneInfoWithMainHosts:upDomains oldHosts:oldUpDomains regionId:regionId];
    QNZonesInfo *zonesInfo = [[QNZonesInfo alloc] initWithZonesInfo:@[zoneInfo]];
    return zonesInfo;
}

- (instancetype)initWithUpDomainList:(NSArray<NSString *> *)upList {
    if (self = [super init]) {
        self.zonesInfo = [self createZonesInfo:upList regionId:nil];
    }
    return self;
}
- (instancetype)initWithUpDomainList:(NSArray<NSString *> *)upList
                            regionId:(NSString *)regionId {
    if (self = [super init]) {
        self.zonesInfo = [self createZonesInfo:upList regionId:regionId];
    }
    return self;
}
- (instancetype)initWithUpDomainList:(NSArray<NSString *> *)upList
                           oldUpList:(NSArray<NSString *> *)oldUpList
                            regionId:(NSString *)regionId {
    if (self = [super init]) {
        self.zonesInfo = [self createZonesInfo:upList oldUpDomains:oldUpList regionId:regionId];
    }
    return self;
}

- (QNZonesInfo *)getZonesInfoWithToken:(QNUpToken *)token actionType:(QNActionType)actionType {
    return self.zonesInfo;
}


@end
