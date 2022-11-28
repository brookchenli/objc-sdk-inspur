//
//  QNIUploadServer.m
//  InspurOSSSDK
//
//  Created by Brook on 2021/2/4.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurIUploadServer.h"

BOOL kQNIsHttp3(NSString * _Nullable httpVersion) {
    return [httpVersion isEqualToString:kQNHttpVersion3];
}

BOOL kQNIsHttp2(NSString * _Nullable httpVersion) {
    return [httpVersion isEqualToString:kQNHttpVersion2];
}
