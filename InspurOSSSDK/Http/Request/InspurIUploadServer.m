//
//  InspurIUploadServer.m
//  InspurOSSSDK
//
//  Created by Brook on 2021/2/4.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurIUploadServer.h"

BOOL kInspurIsHttp3(NSString * _Nullable httpVersion) {
    return [httpVersion isEqualToString:kInspurHttpVersion3];
}

BOOL kInspurIsHttp2(NSString * _Nullable httpVersion) {
    return [httpVersion isEqualToString:kInspurHttpVersion2];
}
