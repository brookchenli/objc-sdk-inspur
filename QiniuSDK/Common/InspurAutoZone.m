//
//  QNAutoZone.m
//  InspurOSSSDK
//
//  Created by Brook on 2020/4/16.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurDefine.h"
#import "InspurAutoZone.h"
#import "InspurConfig.h"
#import "InspurRequestTransaction.h"
#import "InspurZoneInfo.h"
#import "InspurUpToken.h"
#import "InspurResponseInfo.h"
#import "InspurFixedZone.h"
#import "InspurSingleFlight.h"
#import "InspurUploadRequestMetrics.h"


@interface InspurAutoZoneCache : NSObject
@property(nonatomic, strong)NSMutableDictionary *cache;
@end
@implementation InspurAutoZoneCache

+ (instancetype)share {
    static InspurAutoZoneCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[InspurAutoZoneCache alloc] init];
        [cache setupData];
    });
    return cache;
}

- (void)setupData{
    self.cache = [NSMutableDictionary dictionary];
}

- (void)cache:(InspurZonesInfo *)zonesInfo forKey:(NSString *)cacheKey{
    
    if (!cacheKey || [cacheKey isEqualToString:@""] || zonesInfo == nil) {
        return;
    }
    
    @synchronized (self) {
        self.cache[cacheKey] = zonesInfo;
    }
}

- (InspurZonesInfo *)cacheForKey:(NSString *)cacheKey{
    
    if (!cacheKey || [cacheKey isEqualToString:@""]) {
        return nil;
    }
    
    @synchronized (self) {
        return self.cache[cacheKey];
    }
}

- (InspurZonesInfo *)zonesInfoForKey:(NSString *)cacheKey{
    
    if (!cacheKey || [cacheKey isEqualToString:@""]) {
        return nil;
    }
    
    InspurZonesInfo *zonesInfo = nil;
    @synchronized (self) {
        zonesInfo = self.cache[cacheKey];
    }
    
    return zonesInfo;
}

- (void)clearCache {
    @synchronized (self) {
        for (NSString *key in self.cache.allKeys) {
            InspurZonesInfo *info = self.cache[key];
            [info toTemporary];
        }
    }
}

@end

@interface InspurUCQuerySingleFlightValue : NSObject

@property(nonatomic, strong)InspurResponseInfo *responseInfo;
@property(nonatomic, strong)NSDictionary *response;
@property(nonatomic, strong)InspurUploadRegionRequestMetrics *metrics;

@end
@implementation InspurUCQuerySingleFlightValue
@end

@interface InspurAutoZone()

@property(nonatomic, strong)NSArray *ucHosts;
@property(nonatomic, strong)NSMutableArray <InspurRequestTransaction *> *transactions;

@end
@implementation InspurAutoZone

+ (InspurSingleFlight *)UCQuerySingleFlight {
    static InspurSingleFlight *singleFlight = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleFlight = [[InspurSingleFlight alloc] init];
    });
    return singleFlight;
}

+ (instancetype)zoneWithUcHosts:(NSArray *)ucHosts {
    InspurAutoZone *zone = [[self alloc] init];
    zone.ucHosts = [ucHosts copy];
    return zone;
}

+ (void)clearCache {
    [[InspurAutoZoneCache share] clearCache];
}

- (instancetype)init{
    if (self = [super init]) {
        _transactions = [NSMutableArray array];
    }
    return self;
}

- (InspurZonesInfo *)getZonesInfoWithToken:(InspurUpToken * _Nullable)token
                            actionType:(QNActionType)actionType {
    
    if (token == nil) return nil;
    NSString *cacheKey = [NSString stringWithFormat:@"%@%@", token.index, [InspurApiType actionTypeString:actionType]] ;
    InspurZonesInfo *zonesInfo = [[InspurAutoZoneCache share] cacheForKey:cacheKey];
    zonesInfo = [zonesInfo copy];
    return zonesInfo;
}

- (void)preQuery:(InspurUpToken *)token actionType:(QNActionType)actionType on:(InspurPrequeryReturn)ret {

    if (token == nil || ![token isValid]) {
        ret(-1, [InspurResponseInfo responseInfoWithInvalidToken:@"invalid token"], nil);
        return;
    }
    
    InspurUploadRegionRequestMetrics *cacheMetrics = [InspurUploadRegionRequestMetrics emptyMetrics];
    [cacheMetrics start];
    
    NSString *cacheKey = [NSString stringWithFormat:@"%@%@", token.index, [InspurApiType actionTypeString:actionType]] ;
    InspurZonesInfo *zonesInfo = [[InspurAutoZoneCache share] zonesInfoForKey:cacheKey];
    
    // 临时的 zonesInfo 仅能使用一次
    if (zonesInfo != nil && zonesInfo.isValid && !zonesInfo.isTemporary) {
        [cacheMetrics end];
        ret(0, [InspurResponseInfo successResponse], cacheMetrics);
        return;
    }
    
    kInspurWeakSelf;
    InspurSingleFlight *singleFlight = [InspurAutoZone UCQuerySingleFlight];
    [singleFlight perform:token.index action:^(QNSingleFlightComplete  _Nonnull complete) {
        kInspurStrongSelf;
        InspurRequestTransaction *transaction = [self createUploadRequestTransaction:token];
        
        kInspurWeakSelf;
        kInspurWeakObj(transaction);
        [transaction queryUploadHosts:^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
            kInspurStrongSelf;
            kInspurStrongObj(transaction);
            
            InspurUCQuerySingleFlightValue *value = [[InspurUCQuerySingleFlightValue alloc] init];
            value.responseInfo = responseInfo;
            value.response = response;
            value.metrics = metrics;
            complete(value, nil);
            
            [self destroyUploadRequestTransaction:transaction];
        }];
        
    } complete:^(id  _Nullable value, NSError * _Nullable error) {
        InspurResponseInfo *responseInfo = [(InspurUCQuerySingleFlightValue *)value responseInfo];
        NSDictionary *response = [(InspurUCQuerySingleFlightValue *)value response];
        InspurUploadRegionRequestMetrics *metrics = [(InspurUCQuerySingleFlightValue *)value metrics];

        if (responseInfo && responseInfo.isOK) {
            InspurZonesInfo *zonesInfo = [InspurZonesInfo infoWithDictionary:response actionType:actionType];
            if ([zonesInfo isValid]) {
                [[InspurAutoZoneCache share] cache:zonesInfo forKey:cacheKey];
                ret(0, responseInfo, metrics);
            } else {
                ret(-1, responseInfo, metrics);
            }
        } else {
            if (responseInfo.isConnectionBroken) {
                ret(kInspurNetworkError, responseInfo, metrics);
            } else {
                InspurZonesInfo *zonesInfo = [[InspurFixedZone localsZoneInfo] getZonesInfoWithToken:token];
                if ([zonesInfo isValid]) {
                    [[InspurAutoZoneCache share] cache:zonesInfo forKey:cacheKey];
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
        hosts = @[kInspurPreQueryHost02, kInspurPreQueryHost00, kInspurPreQueryHost01];
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
