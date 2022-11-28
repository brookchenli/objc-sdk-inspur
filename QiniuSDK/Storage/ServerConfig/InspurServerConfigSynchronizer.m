//
//  QNServerConfigSynchronizer.m
//  QiniuSDK
//
//  Created by Brook on 2021/8/30.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurConfig.h"
#import "InspurUpToken.h"
#import "InspurZoneInfo.h"
#import "InspurResponseInfo.h"
#import "InspurRequestTransaction.h"
#import "InspurServerConfigSynchronizer.h"


static NSString *Token = nil;
static NSArray <NSString *> *Hosts = nil;
static InspurRequestTransaction *serverConfigTransaction = nil;
static InspurRequestTransaction *serverUserConfigTransaction = nil;

@implementation InspurServerConfigSynchronizer

//MARK: --- server config
+ (void)getServerConfigFromServer:(void(^)(InspurServerConfig *config))complete {
    if (complete == nil) {
        return;
    }
    
    InspurRequestTransaction *transaction = [self createServerConfigTransaction];
    if (transaction == nil) {
        complete(nil);
        return;
    }
    
    [transaction serverConfig:^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        if (responseInfo.isOK && response != nil) {
            complete([InspurServerConfig config:response]);
        } else {
            complete(nil);
        }
        [self destroyServerConfigRequestTransaction];
    }];
}

+ (InspurRequestTransaction *)createServerConfigTransaction {
    @synchronized (self) {
        if (serverConfigTransaction != nil) {
            return nil;
        }
        
        InspurUpToken *token = [InspurUpToken parse:Token];
        if (token == nil) {
            token = [InspurUpToken getInvalidToken];
        }
        
        NSArray *hosts = Hosts;
        if (hosts == nil) {
            hosts = @[kQNPreQueryHost00, kQNPreQueryHost01];
        }
        InspurRequestTransaction *transaction = [[InspurRequestTransaction alloc] initWithHosts:hosts
                                                                               regionId:QNZoneInfoEmptyRegionId
                                                                                  token:token];
        serverConfigTransaction = transaction;
        return transaction;
    }
}

+ (void)destroyServerConfigRequestTransaction {
    @synchronized (self) {
        serverConfigTransaction = nil;
    }
}

//MARK: --- server user config
+ (void)getServerUserConfigFromServer:(void(^)(InspurServerUserConfig *config))complete {
    if (complete == nil) {
        return;
    }
    
    InspurRequestTransaction *transaction = [self createServerUserConfigTransaction];
    if (transaction == nil) {
        complete(nil);
        return;
    }
    
    [transaction serverUserConfig:^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        if (responseInfo.isOK && response != nil) {
            complete([InspurServerUserConfig config:response]);
        } else {
            complete(nil);
        }
        [self destroyServerConfigRequestTransaction];
    }];
}

+ (InspurRequestTransaction *)createServerUserConfigTransaction {
    @synchronized (self) {
        if (serverConfigTransaction != nil) {
            return nil;
        }
        
        InspurUpToken *token = [InspurUpToken parse:Token];
        if (token == nil || !token.isValid) {
            return nil;
        }
        
        NSArray *hosts = Hosts;
        if (hosts == nil) {
            hosts = @[kQNPreQueryHost00, kQNPreQueryHost01];
        }
        InspurRequestTransaction *transaction = [[InspurRequestTransaction alloc] initWithHosts:hosts
                                                                               regionId:QNZoneInfoEmptyRegionId
                                                                                  token:token];
        serverUserConfigTransaction = transaction;
        return transaction;
    }
}

+ (void)destroyServerUserConfigRequestTransaction {
    @synchronized (self) {
        serverUserConfigTransaction = nil;
    }
}

+ (void)setToken:(NSString *)token {
    Token = token;
}

+ (NSString *)token {
    return Token;
}

+ (void)setHosts:(NSArray<NSString *> *)servers {
    Hosts = [servers copy];
}

+ (NSArray<NSString *> *)hosts {
    return Hosts;
}

@end
