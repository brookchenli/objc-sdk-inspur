//
//  InspurDnsCacheKey.m
//  InspurDNS
//
//  Created by Brook on 2020/3/26.
//  Copyright © 2020 com.inspur. All rights reserved.
//

#import "InspurDnsCacheInfo.h"

@interface InspurDnsCacheInfo()
/// 缓存时间戳
@property(nonatomic,  copy)NSString *currentTime;
/// 缓存时本地IP
@property(nonatomic,  copy)NSString *localIp;
/// 缓存信息
@property(nonatomic,  copy)NSDictionary *info;
@end
@implementation InspurDnsCacheInfo

+ (instancetype)dnsCacheInfo:(NSData *)jsonData{
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableLeaves error:nil];
    if (!info || info.count == 0 ||
        (!info[@"currentTime"] && !info[@"localIp"] && !info[@"info"])) {
        return nil;
    }
    return [InspurDnsCacheInfo dnsCacheInfo:info[@"currentTime"]
                                localIp:info[@"localIp"]
                                   info:info[@"info"]];;
}

+ (instancetype)dnsCacheInfo:(NSString *)currentTime
                     localIp:(NSString *)localIp
                        info:(NSDictionary *)info{
    
    InspurDnsCacheInfo *cacheInfo = [[InspurDnsCacheInfo alloc] init];
    cacheInfo.currentTime = currentTime;
    cacheInfo.localIp = localIp;
    cacheInfo.info = info;
    return cacheInfo;
}

- (NSData *)jsonData{
    NSMutableDictionary *cacheInfo = [NSMutableDictionary dictionary];
    if (self.currentTime) {
        cacheInfo[@"currentTime"] = self.currentTime;
    }
    if (self.localIp) {
        cacheInfo[@"localIp"] = self.localIp;
    }
    if (self.info) {
        cacheInfo[@"info"] = self.info;
    }
    return [NSJSONSerialization dataWithJSONObject:cacheInfo options:NSJSONWritingPrettyPrinted error:nil];
}


@end
