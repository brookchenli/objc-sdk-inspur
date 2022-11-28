//
//  QNEtag.m
//  InspurOSSSDK
//
//  Created by Brook on 14/10/4.
//  Copyright (c) 2014年 Inspur. All rights reserved.
//

#include <CommonCrypto/CommonCrypto.h>

#import "InspurConfiguration.h"
#import "InspurEtag.h"
#import "InspurUrlSafeBase64.h"

@implementation InspurEtag
+ (NSString *)file:(NSString *)filePath
             error:(NSError **)error {
    @autoreleasepool {
        NSData *data = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:error];
        if (error && *error) {
            return 0;
        }
        return [InspurEtag data:data];
    }
}

+ (NSString *)data:(NSData *)data {
    if (data == nil || [data length] == 0) {
        return @"Fto5o-5ea0sNMlW_75VgGJCv2AcJ";
    }
    int len = (int)[data length];
    int count = (len + kQNBlockSize - 1) / kQNBlockSize;

    NSMutableData *retData = [NSMutableData dataWithLength:CC_SHA1_DIGEST_LENGTH + 1];
    UInt8 *ret = [retData mutableBytes];

    NSMutableData *blocksSha1 = nil;
    UInt8 *pblocksSha1 = ret + 1;
    if (count > 1) {
        blocksSha1 = [NSMutableData dataWithLength:CC_SHA1_DIGEST_LENGTH * count];
        pblocksSha1 = [blocksSha1 mutableBytes];
    }

    for (int i = 0; i < count; i++) {
        int offset = i * kQNBlockSize;
        int size = (len - offset) > kQNBlockSize ? kQNBlockSize : (len - offset);
        NSData *d = [data subdataWithRange:NSMakeRange(offset, (unsigned int)size)];
        CC_SHA1([d bytes], (CC_LONG)size, pblocksSha1 + i * CC_SHA1_DIGEST_LENGTH);
    }
    if (count == 1) {
        ret[0] = 0x16;
    } else {
        ret[0] = 0x96;
        CC_SHA1(pblocksSha1, (CC_LONG)CC_SHA1_DIGEST_LENGTH * count, ret + 1);
    }

    return [InspurUrlSafeBase64 encodeData:retData];
}

@end
