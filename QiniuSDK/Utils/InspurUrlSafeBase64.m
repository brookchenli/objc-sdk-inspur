//
//  InspurOSSSDK
//
//  Created by Brook on 14-9-28.
//  Copyright (c) 2014年 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "InspurUrlSafeBase64.h"

#import "Inspur_GTM_Base64.h"

@implementation InspurUrlSafeBase64

+ (NSString *)encodeString:(NSString *)sourceString {
    NSData *data = [NSData dataWithBytes:[sourceString UTF8String] length:[sourceString lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
    return [self encodeData:data];
}

+ (NSString *)encodeData:(NSData *)data {
    return [Inspur_GTM_Base64 stringByWebSafeEncodingData:data padded:YES];
}

+ (NSData *)decodeString:(NSString *)data {
    return [Inspur_GTM_Base64 webSafeDecodeString:data];
}

@end
