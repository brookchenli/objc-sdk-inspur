//
//  InspurIUploadServer.h
//  InspurOSSSDK
//
//  Created by Brook on 2020/7/3.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import<Foundation/Foundation.h>

@protocol InspurUploadServer <NSObject>

@property(nonatomic,  copy, nullable, readonly)NSString *httpVersion;
@property(nonatomic,  copy, nullable, readonly)NSString *serverId;
@property(nonatomic,  copy, nullable, readonly)NSString *ip;
@property(nonatomic,  copy, nullable, readonly)NSString *host;
@property(nonatomic,  copy, nullable, readonly)NSString *source;
@property(nonatomic,strong, nullable, readonly)NSNumber *ipPrefetchedTime;

@end

#define kInspurHttpVersion1 @"http_version_1"
#define kInspurHttpVersion2 @"http_version_2"
#define kInspurHttpVersion3 @"http_version_3"

BOOL kInspurIsHttp3(NSString * _Nullable httpVersion);
BOOL kInspurIsHttp2(NSString * _Nullable httpVersion);

