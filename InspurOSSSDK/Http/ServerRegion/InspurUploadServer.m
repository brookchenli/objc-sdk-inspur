//
//  InspurUploadServer.m
//  AppTest
//
//  Created by Brook on 2020/4/23.
//  Copyright © 2020 com.inspur. All rights reserved.
//

#import "InspurUploadServer.h"

@interface InspurUploadServer()

@property(nonatomic,  copy)NSString *ip;
@property(nonatomic,  copy)NSString *host;
@property(nonatomic,  copy)NSString *source;
@property(nonatomic,strong)NSNumber *ipPrefetchedTime;

@end
@implementation InspurUploadServer
@synthesize httpVersion;

+ (instancetype)server:(NSString *)host
                    ip:(NSString *)ip
                source:(NSString *)source
      ipPrefetchedTime:(NSNumber *)ipPrefetchedTime{
    InspurUploadServer *server = [[InspurUploadServer alloc] init];
    server.ip = ip;
    server.host = host;
    server.source = source ?: @"none";
    server.httpVersion = kInspurHttpVersion2;
    server.ipPrefetchedTime = ipPrefetchedTime;
    return server;
}

- (NSString *)serverId {
    return [self.host copy];
}

@end
