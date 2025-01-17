//
//  NSData+MD5.m
//  InspurOSSSDK
//
//  Created by Brook on 2020/7/28.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "NSData+InspurMD5.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSData(InspurMD5)

- (NSString *)inspur_md5{
    
    CC_MD5_CTX md5;
    CC_MD5_Init(&md5);
    CC_MD5_Update(&md5, self.bytes, (CC_LONG)self.length);
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &md5);
    NSMutableString *result = [NSMutableString string];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [result appendFormat:@"%02X", digest[i]];
    }
    return result;
}

@end
