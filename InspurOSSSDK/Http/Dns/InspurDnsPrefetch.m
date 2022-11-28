//
//  QNDnsPrefetch.m
//  QnDNS
//
//  Created by Brook on 2020/3/26.
//  Copyright © 2020 com.inspur. All rights reserved.
//


#import "InspurDnsPrefetch.h"
#import "InspurInetAddress.h"
#import "InspurDnsCacheInfo.h"
#import "InspurZoneInfo.h"

#import "InspurDefine.h"
#import "InspurConfig.h"
#import "InspurDnsCacheFile.h"
#import "InspurUtils.h"
#import "InspurAsyncRun.h"
#import "InspurFixedZone.h"
#import "InspurAutoZone.h"
#import <HappyDNS/HappyDNS.h>


//MARK: -- 缓存模型
@interface QNDnsNetworkAddress : NSObject<InspurIDnsNetworkAddress>

@property(nonatomic,   copy)NSString *hostValue;
@property(nonatomic,   copy)NSString *ipValue;
@property(nonatomic, strong)NSNumber *ttlValue;
@property(nonatomic,   copy)NSString *sourceValue;
@property(nonatomic, strong)NSNumber *timestampValue;

/// 构造方法 addressData为json String / Dictionary / Data / 遵循 QNIDnsNetworkAddress的实例
+ (instancetype)inetAddress:(id)addressInfo;

/// 是否有效，根据时间戳判断
- (BOOL)isValid;

/// 对象转json
- (NSString *)toJsonInfo;

/// 对象转字典
- (NSDictionary *)toDictionary;

@end
@implementation QNDnsNetworkAddress

+ (instancetype)inetAddress:(id)addressInfo{
    
    NSDictionary *addressDic = nil;
    if ([addressInfo isKindOfClass:[NSDictionary class]]) {
        addressDic = (NSDictionary *)addressInfo;
    } else if ([addressInfo isKindOfClass:[NSString class]]){
        NSData *data = [(NSString *)addressInfo dataUsingEncoding:NSUTF8StringEncoding];
        addressDic = [NSJSONSerialization JSONObjectWithData:data
                                                     options:NSJSONReadingMutableLeaves
                                                       error:nil];
    } else if ([addressInfo isKindOfClass:[NSData class]]) {
        addressDic = [NSJSONSerialization JSONObjectWithData:(NSData *)addressInfo
                                                     options:NSJSONReadingMutableLeaves
                                                       error:nil];
    } else if ([addressInfo conformsToProtocol:@protocol(InspurIDnsNetworkAddress)]){
        id <InspurIDnsNetworkAddress> address = (id <InspurIDnsNetworkAddress> )addressInfo;
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        if ([address respondsToSelector:@selector(hostValue)] && [address hostValue]) {
            dic[@"hostValue"] = [address hostValue];
        }
        if ([address respondsToSelector:@selector(ipValue)] && [address ipValue]) {
            dic[@"ipValue"] = [address ipValue];
        }
        if ([address respondsToSelector:@selector(ttlValue)] && [address ttlValue]) {
            dic[@"ttlValue"] = [address ttlValue];
        }
        if ([address respondsToSelector:@selector(sourceValue)] && [address sourceValue]) {
            dic[@"sourceValue"] = [address sourceValue];
        } else {
            dic[@"sourceValue"] = kInspurDnsSourceCustom;
        }
        if ([address respondsToSelector:@selector(timestampValue)] && [address timestampValue]) {
            dic[@"timestampValue"] = [address timestampValue];
        }
        addressDic = [dic copy];
    }
    
    if (addressDic) {
        QNDnsNetworkAddress *address = [[QNDnsNetworkAddress alloc] init];
        [address setValuesForKeysWithDictionary:addressDic];
        return address;
    } else {
        return nil;
    }
}

/// 过了 ttl 时间则需要刷新
- (BOOL)needRefresh{
    if (!self.timestampValue || !self.ipValue || self.ipValue.length == 0) {
        return NO;
    }
    NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
    return currentTimestamp > (self.timestampValue.doubleValue + self.ttlValue.doubleValue);
}

/// 只要在最大 ttl 时间内，即为有效
- (BOOL)isValid{
    if (!self.timestampValue || !self.ipValue || self.ipValue.length == 0) {
        return NO;
    }
    NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
    return currentTimestamp < (self.timestampValue.doubleValue + kInspurGlobalConfiguration.dnsCacheMaxTTL);
}

- (NSString *)toJsonInfo{
    NSString *defaultString = @"{}";
    NSDictionary *infoDic = [self toDictionary];
    if (!infoDic) {
        return defaultString;
    }
    
    NSData *infoData = [NSJSONSerialization dataWithJSONObject:infoDic
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:nil];
    if (!infoData) {
        return defaultString;
    }
    
    NSString *infoStr = [[NSString alloc] initWithData:infoData encoding:NSUTF8StringEncoding];
    if (!infoStr) {
        return defaultString;
    } else {
        return infoStr;
    }
}

- (NSDictionary *)toDictionary{
    return [self dictionaryWithValuesForKeys:@[@"ipValue", @"hostValue", @"ttlValue", @"sourceValue", @"timestampValue"]];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key{}

@end


//MARK: -- HappyDNS 适配
@interface QNRecord(DNS)<InspurIDnsNetworkAddress>
@end
@implementation QNRecord(DNS)
- (NSString *)hostValue{
    return nil;
}
- (NSString *)ipValue{
    return self.value;
}
- (NSNumber *)ttlValue{
    return @(self.ttl);
}
- (NSNumber *)timestampValue{
    return @(self.timeStamp);
}
- (NSString *)sourceValue{
    if (self.source == QNRecordSourceSystem) {
        return kInspurDnsSourceSystem;
    } else if (self.source == QNRecordSourceDoh) {
        return [NSString stringWithFormat:@"%@<%@>", kInspurDnsSourceDoh, self.server];
    } else if (self.source == QNRecordSourceUdp) {
        return [NSString stringWithFormat:@"%@<%@>", kInspurDnsSourceUdp, self.server];
    } else if (self.source == QNRecordSourceDnspodEnterprise) {
        return kInspurDnsSourceDnspod;
    } else if (self.ipValue == nil || self.ipValue.length == 0) {
        return kInspurDnsSourceNone;
    } else {
        return kInspurDnsSourceCustom;
    }
}
@end

@interface InspurInternalDns : NSObject
@property(nonatomic, strong)id<InspurDnsDelegate> dns;
@property(nonatomic, strong)id<QNResolverDelegate> resolver;
@end
@implementation InspurInternalDns
+ (instancetype)dnsWithDns:(id<InspurDnsDelegate>)dns {
    InspurInternalDns *interDns = [[InspurInternalDns alloc] init];
    interDns.dns = dns;
    return interDns;
}
+ (instancetype)dnsWithResolver:(id<QNResolverDelegate>)resolver {
    InspurInternalDns *interDns = [[InspurInternalDns alloc] init];
    interDns.resolver = resolver;
    return interDns;
}
- (NSArray < id <InspurIDnsNetworkAddress> > *)query:(NSString *)host error:(NSError **)error {
    if (self.dns && [self.dns respondsToSelector:@selector(query:)]) {
        return [self.dns query:host];
    } else if (self.resolver) {
        NSArray <QNRecord *>* records = [self.resolver query:[[QNDomain alloc] init:host] networkInfo:nil error:error];
        return [self filterRecords:records];
    }
    return nil;
}
- (NSArray <QNRecord *>*)filterRecords:(NSArray <QNRecord *>*)records {
    NSMutableArray <QNRecord *> *newRecords = [NSMutableArray array];
    for (QNRecord *record in records) {
        if (record.type == kQNTypeA || record.type == kQNTypeAAAA) {
            [newRecords addObject:record];
        }
    }
    return [newRecords copy];
}
@end


//MARK: -- DNS Prefetcher
@interface InspurDnsPrefetch()

// dns 预解析超时，默认3s
@property(nonatomic, assign)int dnsPrefetchTimeout;

// 最近一次预取错误信息
@property(nonatomic,  copy)NSString *lastPrefetchedErrorMessage;
/// 是否正在预取，正在预取会直接取消新的预取操作请求
@property(atomic, assign)BOOL isPrefetching;
/// 获取AutoZone时的同步锁
@property(nonatomic, strong)dispatch_semaphore_t getAutoZoneSemaphore;
/// DNS信息本地缓存key
@property(nonatomic, strong)InspurDnsCacheInfo *dnsCacheInfo;
// 用户定制 dns
@property(nonatomic, strong)InspurInternalDns *customDns;
// 系统 dns
@property(nonatomic, strong)InspurInternalDns *systemDns;
/// prefetch hosts
@property(nonatomic, strong)NSMutableSet *prefetchHosts;
/// 缓存DNS解析结果
/// 线程安全：内部方法均是在同一线程执行，读写不必加锁，对外开放接口读操作 需要和内部写操作枷锁
@property(nonatomic, strong)NSMutableDictionary <NSString *, NSArray<QNDnsNetworkAddress *>*> *addressDictionary;
@property(nonatomic, strong)InspurDnsCacheFile *diskCache;

@end

@implementation InspurDnsPrefetch

+ (instancetype)shared{
    static InspurDnsPrefetch *prefetcher = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        prefetcher = [[InspurDnsPrefetch alloc] init];
    });
    return prefetcher;
}

- (instancetype)init{
    if (self = [super init]) {
        _isPrefetching = NO;
        _dnsPrefetchTimeout = 3;
    }
    return self;
}

//MARK: -- uploadManager初始化时，加载本地缓存到内存
/// 同步本地预取缓存 如果存在且满足使用返回false，反之为true
- (BOOL)recoverCache{
    id <InspurRecorderDelegate> recorder = nil;
    
    NSError *error;
    recorder = [InspurDnsCacheFile dnsCacheFile:kInspurGlobalConfiguration.dnsCacheDir
                                      error:&error];
    if (error) {
        return YES;
    }
    
    NSData *data = [recorder get:[QNIP local]];
    if (!data) {
        return YES;
    }
    
    InspurDnsCacheInfo *cacheInfo = [InspurDnsCacheInfo dnsCacheInfo:data];
    if (!cacheInfo) {
        return YES;
    }
    
    NSString *localIp = [QNIP local];

    if (!localIp || localIp.length == 0 || ![cacheInfo.localIp isEqualToString:localIp]) {
        return YES;
    }
    
    [self setDnsCacheInfo:cacheInfo];
    
    return [self recoverDnsCache:cacheInfo.info];
}
/// 本地缓存读取失败后，加载本地域名，预取DNS解析信息
- (void)localFetch{
    if ([self prepareToPreFetch] == NO) {
        return;
    }
    NSArray *hosts = [self getLocalPreHost];
    @synchronized (self) {
        [self.prefetchHosts addObjectsFromArray:hosts];
    }
    [self preFetchHosts:hosts];
    [self recorderDnsCache];
    [self endPreFetch];
}
//MARK: -- 检测并预取
/// 根据token检测Dns缓存信息时效，无效则预取。 完成预取操作返回YES，反之返回NO
- (void)checkAndPrefetchDnsIfNeed:(InspurZone *)currentZone token:(InspurUpToken *)token{
    if ([self prepareToPreFetch] == NO) {
        return;
    }
    NSArray *hosts = [self getCurrentZoneHosts:currentZone token:token];
    if (hosts == nil) {
        return;
    }
    
    @synchronized (self) {
        [self.prefetchHosts addObjectsFromArray:hosts];
    }
    [self preFetchHosts:hosts];
    [self recorderDnsCache];
    [self endPreFetch];
}
/// 检测已预取dns是否还有效，无效则重新预取
- (void)checkWhetherCachedDnsValid{
    if ([self prepareToPreFetch] == NO) {
        return;
    }
    NSArray *hosts = nil;
    @synchronized (self) {
        hosts = [self.prefetchHosts allObjects];
    }
    [self preFetchHosts:hosts];
    [self recorderDnsCache];
    [self endPreFetch];
}

//MARK: -- 读取缓存的DNS信息
/// 根据host从缓存中读取DNS信息
- (NSArray <id <InspurIDnsNetworkAddress> > *)getInetAddressByHost:(NSString *)host{

    if ([self isDnsOpen] == NO) {
        return nil;
    }
    
    [self clearDnsCacheIfNeeded];
    
    NSArray <QNDnsNetworkAddress *> *addressList = nil;
    @synchronized (self) {
        addressList = self.addressDictionary[host];
    }
    
    if (addressList && addressList.count > 0 && [addressList.firstObject isValid]) {
        return addressList;
    } else {
        return nil;
    }
}

- (void)invalidNetworkAddressOfHost:(NSString *)host {
    if (host == nil || host.length == 0) {
        return;
    }
    @synchronized (self) {
        [self.addressDictionary removeObjectForKey:host];
    }
}

- (void)clearDnsCache:(NSError *__autoreleasing  _Nullable *)error {
    [self clearDnsMemoryCache];
    [self clearDnsDiskCache:error];
}

//MARK: --
//MARK: -- 根据dns预取
- (NSString *)prefetchHostBySafeDns:(NSString *)host error:(NSError * __autoreleasing *)error {
    if (host == nil) {
        return nil;
    }
    
    [self invalidNetworkAddressOfHost:host];
    
    NSError *err = nil;
    NSArray *nextFetchHosts = @[host];
    nextFetchHosts = [self preFetchHosts:nextFetchHosts dns:self.customDns error:&err];
    if (nextFetchHosts.count == 0) {
        return [self getInetAddressByHost:host].firstObject.sourceValue;
    }
    
    if (!kInspurGlobalConfiguration.dohEnable) {
        if (error != nil && err) {
            *error = err;
        }
        return nil;
    }
    
    QNDohResolver *dohResolver = [QNDohResolver resolverWithServers:kInspurGlobalConfiguration.dohIpv4Servers recordType:kQNTypeA timeout:kInspurGlobalConfiguration.dnsResolveTimeout];
    InspurInternalDns *doh = [InspurInternalDns dnsWithResolver:dohResolver];
    nextFetchHosts = [self preFetchHosts:nextFetchHosts dns:doh error:&err];
    if (nextFetchHosts.count == 0) {
        return [self getInetAddressByHost:host].firstObject.sourceValue;
    }
    if (error != nil && err) {
        *error = err;
    }
    
    if ([QNIP isIpV6FullySupported]) {
        QNDohResolver *dohResolver = [QNDohResolver resolverWithServers:kInspurGlobalConfiguration.dohIpv6Servers recordType:kQNTypeA timeout:kInspurGlobalConfiguration.dnsResolveTimeout];
        InspurInternalDns *doh = [InspurInternalDns dnsWithResolver:dohResolver];
        nextFetchHosts = [self preFetchHosts:nextFetchHosts dns:doh error:&err];
        if (error != nil && err) {
            *error = err;
        }
    }
    
    if (nextFetchHosts.count == 0) {
        return [self getInetAddressByHost:host].firstObject.sourceValue;
    } else {
        return nil;
    }
}

- (BOOL)prepareToPreFetch {
    if ([self isDnsOpen] == NO) {
        return NO;
    }
    
    self.lastPrefetchedErrorMessage = nil;
    
    if (self.isPrefetching == YES) {
        return NO;
    }
    
    [self clearDnsCacheIfNeeded];
    
    self.isPrefetching = YES;
    return YES;
}

- (void)endPreFetch{
    self.isPrefetching = NO;
}

- (void)preFetchHosts:(NSArray <NSString *> *)fetchHosts {
    NSError *err = nil;
    [self preFetchHosts:fetchHosts error:&err];
    self.lastPrefetchedErrorMessage = err.description;
}

- (void)preFetchHosts:(NSArray <NSString *> *)fetchHosts error:(NSError **)error {
    NSArray *nextFetchHosts = fetchHosts;
    
    // 定制
    nextFetchHosts = [self preFetchHosts:nextFetchHosts dns:self.customDns error:error];
    if (nextFetchHosts.count == 0) {
        return;
    }
    
    // 系统
    nextFetchHosts = [self preFetchHosts:nextFetchHosts dns:self.systemDns error:error];
    if (nextFetchHosts.count == 0) {
        return;
    }
    
    // doh
    if (kInspurGlobalConfiguration.dohEnable) {
        QNDohResolver *dohResolver = [QNDohResolver resolverWithServers:kInspurGlobalConfiguration.dohIpv4Servers recordType:kQNTypeA timeout:kInspurGlobalConfiguration.dnsResolveTimeout];
        InspurInternalDns *doh = [InspurInternalDns dnsWithResolver:dohResolver];
        nextFetchHosts = [self preFetchHosts:nextFetchHosts dns:doh error:error];
        if (nextFetchHosts.count == 0) {
            return;
        }
        
        if ([QNIP isIpV6FullySupported]) {
            QNDohResolver *dohResolver = [QNDohResolver resolverWithServers:kInspurGlobalConfiguration.dohIpv6Servers recordType:kQNTypeA timeout:kInspurGlobalConfiguration.dnsResolveTimeout];
            InspurInternalDns *doh = [InspurInternalDns dnsWithResolver:dohResolver];
            nextFetchHosts = [self preFetchHosts:nextFetchHosts dns:doh error:error];
            if (nextFetchHosts.count == 0) {
                return;
            }
        }
    }
    
    // udp
    if (kInspurGlobalConfiguration.udpDnsEnable) {
        QNDnsUdpResolver *udpDnsResolver = [QNDnsUdpResolver resolverWithServerIPs:kInspurGlobalConfiguration.udpDnsIpv4Servers recordType:kQNTypeA timeout:kInspurGlobalConfiguration.dnsResolveTimeout];
        InspurInternalDns *udpDns = [InspurInternalDns dnsWithResolver:udpDnsResolver];
        [self preFetchHosts:nextFetchHosts dns:udpDns error:error];
        
        if ([QNIP isIpV6FullySupported]) {
            QNDnsUdpResolver *udpDnsResolver = [QNDnsUdpResolver resolverWithServerIPs:kInspurGlobalConfiguration.udpDnsIpv6Servers recordType:kQNTypeA timeout:kInspurGlobalConfiguration.dnsResolveTimeout];
            InspurInternalDns *udpDns = [InspurInternalDns dnsWithResolver:udpDnsResolver];
            [self preFetchHosts:nextFetchHosts dns:udpDns error:error];
        }
    }
}

- (NSArray *)preFetchHosts:(NSArray <NSString *> *)preHosts dns:(InspurInternalDns *)dns error:(NSError **)error {

    if (!preHosts || preHosts.count == 0) {
        return nil;
    }
    
    if (!dns) {
        return [preHosts copy];
    }
    
    int dnsRepreHostNum = kInspurGlobalConfiguration.dnsRepreHostNum;
    NSMutableArray *failHosts = [NSMutableArray array];
    for (NSString *host in preHosts) {
        int rePreNum = 0;
        BOOL isSuccess = NO;
        
        while (rePreNum < dnsRepreHostNum) {
            if ([self preFetchHost:host dns:dns error:error]) {
                isSuccess = YES;
                break;
            }
            rePreNum += 1;
        }
        
        if (!isSuccess) {
            [failHosts addObject:host];
        }
    }
    return [failHosts copy];
}

- (BOOL)preFetchHost:(NSString *)preHost dns:(InspurInternalDns *)dns error:(NSError **)error {
    
    if (!preHost || preHost.length == 0) {
        return NO;
    }
    
    NSDictionary *addressDictionary = nil;
    @synchronized (self) {
        addressDictionary = [self.addressDictionary copy];
    }
    NSArray<QNDnsNetworkAddress *>* preAddressList = addressDictionary[preHost];
    if (preAddressList && ![preAddressList.firstObject needRefresh]) {
        return YES;
    }
    
    NSArray <id <InspurIDnsNetworkAddress> > * addressList = [dns query:preHost error:error];
    if (addressList && addressList.count > 0) {
        NSMutableArray *addressListP = [NSMutableArray array];
        for (id <InspurIDnsNetworkAddress>inetAddress in addressList) {
            QNDnsNetworkAddress *address = [QNDnsNetworkAddress inetAddress:inetAddress];
            if (address) {
                address.hostValue = preHost;
                if (!address.ttlValue) {
                    address.ttlValue = @(kQNDefaultDnsCacheTime);
                }
                if (!address.timestampValue) {
                    address.timestampValue = @([[NSDate date] timeIntervalSince1970]);
                }
                [addressListP addObject:address];
            }
        }
        addressListP = [addressListP copy];
        @synchronized (self) {
            self.addressDictionary[preHost] = addressListP;
        }
        return YES;
    } else {
        return NO;
    }
}

//MARK: -- 加载和存储缓存信息
- (BOOL)recoverDnsCache:(NSDictionary *)dataDic{
    if (dataDic == nil) {
        return NO;
    }
    
    NSMutableDictionary *records = [NSMutableDictionary dictionary];
    for (NSString *key in dataDic.allKeys) {
        NSArray *ips = dataDic[key];
        if ([ips isKindOfClass:[NSArray class]]) {
            
            NSMutableArray <QNDnsNetworkAddress *> * addressList = [NSMutableArray array];
            
            for (NSDictionary *ipInfo in ips) {
                if ([ipInfo isKindOfClass:[NSDictionary class]]) {
                    QNDnsNetworkAddress *address = [QNDnsNetworkAddress inetAddress:ipInfo];
                    if (address) {
                        [addressList addObject:address];
                    }
                }
            }
            
            if (addressList.count > 0) {
                records[key] = [addressList copy];
            }
        }
    }
    @synchronized (self) {
        [self.addressDictionary setValuesForKeysWithDictionary:records];
    }
    return NO;
}

- (BOOL)recorderDnsCache{
    NSTimeInterval currentTime = [InspurUtils currentTimestamp];
    NSString *localIp = [QNIP local];
    
    if (localIp == nil || localIp.length == 0) {
        return NO;
    }

    NSError *error;
    id <InspurRecorderDelegate> recorder = [InspurDnsCacheFile dnsCacheFile:kInspurGlobalConfiguration.dnsCacheDir
                                                             error:&error];
    if (error) {
        return NO;
    }
    
    NSDictionary *addressDictionary = nil;
    @synchronized (self) {
        addressDictionary = [self.addressDictionary copy];
    }
    NSMutableDictionary *addressInfo = [NSMutableDictionary dictionary];
    for (NSString *key in addressDictionary.allKeys) {
       
        NSArray *addressModelList = addressDictionary[key];
        NSMutableArray * addressDicList = [NSMutableArray array];

        for (QNDnsNetworkAddress *ipInfo in addressModelList) {
            NSDictionary *addressDic = [ipInfo toDictionary];
            if (addressDic) {
                [addressDicList addObject:addressDic];
            }
        }
       
        if (addressDicList.count > 0) {
            addressInfo[key] = addressDicList;
        }
    }
   
    InspurDnsCacheInfo *cacheInfo = [InspurDnsCacheInfo dnsCacheInfo:[NSString stringWithFormat:@"%.0lf",currentTime]
                                                     localIp:localIp
                                                        info:addressInfo];
    
    NSData *cacheData = [cacheInfo jsonData];
    if (!cacheData) {
        return NO;
    }
    [self setDnsCacheInfo:cacheInfo];
    [recorder set:localIp data:cacheData];
    return true;
}

- (void)clearDnsCacheIfNeeded{
    NSString *localIp = [QNIP local];
    if (localIp == nil || (self.dnsCacheInfo && ![localIp isEqualToString:self.dnsCacheInfo.localIp])) {
        [self clearDnsMemoryCache];
    }
}

- (void)clearDnsMemoryCache {
    @synchronized (self) {
        [self.addressDictionary removeAllObjects];
    }
}

- (void)clearDnsDiskCache:(NSError **)error {
    [self.diskCache clearCache:error];
}


//MARK: -- 获取预取hosts
- (NSArray <NSString *> *)getLocalPreHost{
    NSMutableArray *localHosts = [NSMutableArray array];
    [localHosts addObject:kInspurUpLogHost];
    return [localHosts copy];
}

- (NSArray <NSString *> *)getCurrentZoneHosts:(InspurZone *)currentZone
                                        token:(InspurUpToken *)token{
    if (!currentZone || !token || !token.token) {
        return nil;
    }
    [currentZone preQuery:token on:^(int code, InspurResponseInfo *responseInfo, InspurUploadRegionRequestMetrics *metrics) {
        dispatch_semaphore_signal(self.semaphore);
    }];
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    
    InspurZonesInfo *autoZonesInfo = [currentZone getZonesInfoWithToken:token];
    NSMutableArray *autoHosts = [NSMutableArray array];
    NSArray *zoneInfoList = autoZonesInfo.zonesInfo;
    for (InspurZoneInfo *info in zoneInfoList) {
        if (info.allHosts) {
            [autoHosts addObjectsFromArray:info.allHosts];
        }
    }
    return [autoHosts copy];
}


//MARK: --
- (BOOL)isDnsOpen{
    return [kInspurGlobalConfiguration isDnsOpen];
}

- (InspurDnsCacheInfo *)dnsCacheInfo{
    if (_dnsCacheInfo == nil) {
        _dnsCacheInfo = [[InspurDnsCacheInfo alloc] init];
    }
    return _dnsCacheInfo;
}
- (NSMutableDictionary<NSString *,NSArray<QNDnsNetworkAddress *> *> *)addressDictionary{
    if (_addressDictionary == nil) {
        _addressDictionary = [NSMutableDictionary dictionary];
    }
    return _addressDictionary;
}

- (dispatch_semaphore_t)semaphore{
    if (_getAutoZoneSemaphore == NULL) {
        _getAutoZoneSemaphore = dispatch_semaphore_create(0);
    }
    return _getAutoZoneSemaphore;
}

- (InspurDnsCacheFile *)diskCache {
    if (!_diskCache) {
        NSError *error;
        InspurDnsCacheFile *cache = [InspurDnsCacheFile dnsCacheFile:kInspurGlobalConfiguration.dnsCacheDir error:&error];
        if (!error) {
            _diskCache = cache;
        }
    }
    return _diskCache;
}

- (InspurInternalDns *)customDns {
    if (_customDns == nil && kInspurGlobalConfiguration.dns) {
        _customDns = [InspurInternalDns dnsWithDns:kInspurGlobalConfiguration.dns];
    }
    return _customDns;
}

- (InspurInternalDns *)systemDns {
    if (_systemDns == nil) {
        _systemDns = [InspurInternalDns dnsWithResolver:[[QNResolver alloc] initWithAddress:nil timeout:self.dnsPrefetchTimeout]];
    }
    return _systemDns;
}

- (NSMutableSet *)prefetchHosts {
    if (!_prefetchHosts) {
        _prefetchHosts = [NSMutableSet set];
    }
    return _prefetchHosts;
}

@end


//MARK: -- DNS 事务
@implementation InspurTransactionManager(Dns)
#define kQNLoadLocalDnsTransactionName @"QNLoadLocalDnsTransaction"
#define kQNDnsCheckAndPrefetchTransactionName @"QNDnsCheckAndPrefetchTransactionName"

- (void)addDnsLocalLoadTransaction{
    
    if ([kInspurDnsPrefetch isDnsOpen] == NO) {
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        InspurTransaction *transaction = [InspurTransaction transaction:kQNLoadLocalDnsTransactionName after:0 action:^{
            
            [kInspurDnsPrefetch recoverCache];
            [kInspurDnsPrefetch localFetch];
        }];
        [[InspurTransactionManager shared] addTransaction:transaction];
        [self setDnsCheckWhetherCachedValidTransactionAction];
    });
}

- (BOOL)addDnsCheckAndPrefetchTransaction:(InspurZone *)currentZone token:(InspurUpToken *)token{
    if (!token) {
        return NO;
    }
    
    if ([kInspurDnsPrefetch isDnsOpen] == NO) {
        return NO;
    }
    
    BOOL ret = NO;
    @synchronized (kInspurDnsPrefetch) {
        
        InspurTransactionManager *transactionManager = [InspurTransactionManager shared];
        
        if (![transactionManager existTransactionsForName:token.token]) {
            InspurTransaction *transaction = [InspurTransaction transaction:token.token after:0 action:^{
               
                [kInspurDnsPrefetch checkAndPrefetchDnsIfNeed:currentZone token:token];
            }];
            [transactionManager addTransaction:transaction];
            
            ret = YES;
        }
    }
    return ret;
}

- (void)setDnsCheckWhetherCachedValidTransactionAction{

    if ([kInspurDnsPrefetch isDnsOpen] == NO) {
        return;
    }
    
    @synchronized (kInspurDnsPrefetch) {
        
        InspurTransactionManager *transactionManager = [InspurTransactionManager shared];
        InspurTransaction *transaction = [transactionManager transactionsForName:kQNDnsCheckAndPrefetchTransactionName].firstObject;
        
        if (!transaction) {
            
            InspurTransaction *transaction = [InspurTransaction timeTransaction:kQNDnsCheckAndPrefetchTransactionName
                                                                  after:10
                                                               interval:120
                                                                 action:^{
                [kInspurDnsPrefetch checkWhetherCachedDnsValid];
            }];
            [transactionManager addTransaction:transaction];
        } else {
            [transactionManager performTransaction:transaction];
        }
    }
}

@end

BOOL kInspurIsDnsSourceDoh(NSString * _Nullable source) {
    return [source containsString:kInspurDnsSourceDoh];
}

BOOL kInspurIsDnsSourceUdp(NSString * _Nullable source) {
    return [source containsString:kInspurDnsSourceUdp];
}

BOOL kInspurIsDnsSourceDnsPod(NSString * _Nullable source) {
    return [source containsString:kInspurDnsSourceDnspod];
}

BOOL kInspurIsDnsSourceSystem(NSString * _Nullable source) {
    return [source containsString:kInspurDnsSourceSystem];
}

BOOL kInspurIsDnsSourceCustom(NSString * _Nullable source) {
    return [source containsString:kInspurDnsSourceCustom];
}
