//
//  InspurCrc.m
//  InspurOSSSDK
//
//  Created by Brook on 14-9-29.
//  Copyright (c) 2014年 Inspur. All rights reserved.
//

#import <zlib.h>

#import "InspurConfiguration.h"
#import "InspurCrc32.h"

@implementation InspurCrc32

+ (UInt32)data:(NSData *)data {
    uLong crc = crc32(0L, Z_NULL, 0);

    crc = crc32(crc, [data bytes], (uInt)[data length]);
    return (UInt32)crc;
}

+ (UInt32)file:(NSString *)filePath
         error:(NSError **)error {
    @autoreleasepool {
        NSData *data = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:error];
        if (*error != nil) {
            return 0;
        }

        int len = (int)[data length];
        int count = (len + kInspurBlockSize - 1) / kInspurBlockSize;

        uLong crc = crc32(0L, Z_NULL, 0);
        for (int i = 0; i < count; i++) {
            int offset = i * kInspurBlockSize;
            int size = (len - offset) > kInspurBlockSize ? kInspurBlockSize : (len - offset);
            NSData *d = [data subdataWithRange:NSMakeRange(offset, (unsigned int)size)];
            crc = crc32(crc, [d bytes], (uInt)[d length]);
        }
        return (UInt32)crc;
    }
}

@end
