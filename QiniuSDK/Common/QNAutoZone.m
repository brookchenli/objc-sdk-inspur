//
//  QNAutoZone.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNDefine.h"
#import "QNAutoZone.h"
#import "QNConfig.h"
#import "InspurRequestTransaction.h"
#import "QNZoneInfo.h"
#import "InspurUpToken.h"
#import "InspurResponseInfo.h"
#import "QNFixedZone.h"
#import "InspurSingleFlight.h"
#import "QNUploadRequestMetrics.h"


@interface QNAutoZoneCache : NSObject
@property(nonatomic, strong)NSMutableDictionary *cache;
@end
@implementation QNAutoZoneCache

+ (instancetype)share {
    static QNAutoZoneCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[QNAutoZoneCache alloc] init];
        [cache setupData];
    });
    return cache;
}

- (void)setupData{
    self.cache = [NSMutableDictionary dictionary];
}

- (void)cache:(QNZonesInfo *)zonesInfo forKey:(NSString *)cacheKey{
    
    if (!cacheKey || [cacheKey isEqualToString:@""] || zonesInfo == nil) {
        return;
    }
    
    @synchronized (self) {
        self.cache[cacheKey] = zonesInfo;
    }
}

- (QNZonesInfo *)cacheForKey:(NSString *)cacheKey{
    
    if (!cacheKey || [cacheKey isEqualToString:@""]) {
        return nil;
    }
    
    @synchronized (self) {
        return self.cache[cacheKey];
    }
}

- (QNZonesInfo *)zonesInfoForKey:(NSString *)cacheKey{
    
    if (!cacheKey || [cacheKey isEqualToString:@""]) {
        return nil;
    }
    
    QNZonesInfo *zonesInfo = nil;
    @synchronized (self) {
        zonesInfo = self.cache[cacheKey];
    }
    
    return zonesInfo;
}

- (void)clearCache {
    @synchronized (self) {
        for (NSString *key in self.cache.allKeys) {
            QNZonesInfo *info = self.cache[key];
            [info toTemporary];
        }
    }
}

@end

@interface QNUCQuerySingleFlightValue : NSObject

@property(nonatomic, strong)InspurResponseInfo *responseInfo;
@property(nonatomic, strong)NSDictionary *response;
@property(nonatomic, strong)QNUploadRegionRequestMetrics *metrics;

@end
@implementation QNUCQuerySingleFlightValue
@end

@interface QNAutoZone()

@property(nonatomic, strong)NSArray *ucHosts;
@property(nonatomic, strong)NSMutableArray <InspurRequestTransaction *> *transactions;

@end
@implementation QNAutoZone

+ (InspurSingleFlight *)UCQuerySingleFlight {
    static InspurSingleFlight *singleFlight = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleFlight = [[InspurSingleFlight alloc] init];
    });
    return singleFlight;
}

+ (instancetype)zoneWithUcHosts:(NSArray *)ucHosts {
    QNAutoZone *zone = [[self alloc] init];
    zone.ucHosts = [ucHosts copy];
    return zone;
}

+ (void)clearCache {
    [[QNAutoZoneCache share] clearCache];
}

- (instancetype)init{
    if (self = [super init]) {
        _transactions = [NSMutableArray array];
    }
    return self;
}

- (QNZonesInfo *)getZonesInfoWithToken:(InspurUpToken * _Nullable)token
                            actionType:(QNActionType)actionType {
    
    if (token == nil) return nil;
    NSString *cacheKey = [NSString stringWithFormat:@"%@%@", token.index, [InspurApiType actionTypeString:actionType]] ;
    QNZonesInfo *zonesInfo = [[QNAutoZoneCache share] cacheForKey:cacheKey];
    zonesInfo = [zonesInfo copy];
    return zonesInfo;
}

- (void)preQuery:(InspurUpToken *)token actionType:(QNActionType)actionType on:(QNPrequeryReturn)ret {

    if (token == nil || ![token isValid]) {
        ret(-1, [InspurResponseInfo responseInfoWithInvalidToken:@"invalid token"], nil);
        return;
    }
    
    QNUploadRegionRequestMetrics *cacheMetrics = [QNUploadRegionRequestMetrics emptyMetrics];
    [cacheMetrics start];
    
    NSString *cacheKey = [NSString stringWithFormat:@"%@%@", token.index, [InspurApiType actionTypeString:actionType]] ;
    QNZonesInfo *zonesInfo = [[QNAutoZoneCache share] zonesInfoForKey:cacheKey];
    
    // 临时的 zonesInfo 仅能使用一次
    if (zonesInfo != nil && zonesInfo.isValid && !zonesInfo.isTemporary) {
        [cacheMetrics end];
        ret(0, [InspurResponseInfo successResponse], cacheMetrics);
        return;
    }
    
    kQNWeakSelf;
    InspurSingleFlight *singleFlight = [QNAutoZone UCQuerySingleFlight];
    [singleFlight perform:token.index action:^(QNSingleFlightComplete  _Nonnull complete) {
        kQNStrongSelf;
        InspurRequestTransaction *transaction = [self createUploadRequestTransaction:token];
        
        kQNWeakSelf;
        kQNWeakObj(transaction);
        [transaction queryUploadHosts:^(InspurResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
            kQNStrongSelf;
            kQNStrongObj(transaction);
            
            QNUCQuerySingleFlightValue *value = [[QNUCQuerySingleFlightValue alloc] init];
            value.responseInfo = responseInfo;
            value.response = response;
            value.metrics = metrics;
            complete(value, nil);
            
            [self destroyUploadRequestTransaction:transaction];
        }];
        
    } complete:^(id  _Nullable value, NSError * _Nullable error) {
        InspurResponseInfo *responseInfo = [(QNUCQuerySingleFlightValue *)value responseInfo];
        NSDictionary *response = [(QNUCQuerySingleFlightValue *)value response];
        QNUploadRegionRequestMetrics *metrics = [(QNUCQuerySingleFlightValue *)value metrics];

        if (responseInfo && responseInfo.isOK) {
            QNZonesInfo *zonesInfo = [QNZonesInfo infoWithDictionary:response actionType:actionType];
            if ([zonesInfo isValid]) {
                [[QNAutoZoneCache share] cache:zonesInfo forKey:cacheKey];
                ret(0, responseInfo, metrics);
            } else {
                ret(-1, responseInfo, metrics);
            }
        } else {
            if (responseInfo.isConnectionBroken) {
                ret(kQNNetworkError, responseInfo, metrics);
            } else {
                QNZonesInfo *zonesInfo = [[QNFixedZone localsZoneInfo] getZonesInfoWithToken:token];
                if ([zonesInfo isValid]) {
                    [[QNAutoZoneCache share] cache:zonesInfo forKey:cacheKey];
                    ret(0, responseInfo, metrics);
                } else {
                    ret(-1, responseInfo, metrics);
                }
            }
        }
    }];
}

- (InspurRequestTransaction *)createUploadRequestTransaction:(InspurUpToken *)token{
    NSArray *hosts = nil;
    if (self.ucHosts && self.ucHosts.count > 0) {
        hosts = [self.ucHosts copy];
    } else {
        hosts = @[kQNPreQueryHost02, kQNPreQueryHost00, kQNPreQueryHost01];
    }
    InspurRequestTransaction *transaction = [[InspurRequestTransaction alloc] initWithHosts:hosts
                                                                           regionId:QNZoneInfoEmptyRegionId
                                                                              token:token];
    @synchronized (self) {
        [self.transactions addObject:transaction];
    }
    return transaction;
}

- (void)destroyUploadRequestTransaction:(InspurRequestTransaction *)transaction{
    if (transaction) {
        @synchronized (self) {
            [self.transactions removeObject:transaction];
        }
    }
}

@end
