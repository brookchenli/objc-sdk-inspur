//
//  InspurFileRecorder.m
//  InspurOSSSDK
//
//  Created by Brook on 14/10/5.
//  Copyright (c) 2014年 Inspur. All rights reserved.
//

#import "InspurFileRecorder.h"
#import "InspurUrlSafeBase64.h"

@interface InspurFileRecorder ()

@property (copy, readonly) NSString *directory;
@property BOOL encode;

@end

@implementation InspurFileRecorder

- (NSString *)pathOfKey:(NSString *)key {
    return [InspurFileRecorder pathJoin:key path:_directory];
}

+ (NSString *)pathJoin:(NSString *)key
                  path:(NSString *)path {
    return [[NSString alloc] initWithFormat:@"%@/%@", path, key];
}

+ (instancetype)fileRecorderWithFolder:(NSString *)directory
                                 error:(NSError *__autoreleasing *)perror {
    return [InspurFileRecorder fileRecorderWithFolder:directory encodeKey:false error:perror];
}

+ (instancetype)fileRecorderWithFolder:(NSString *)directory
                             encodeKey:(BOOL)encode
                                 error:(NSError *__autoreleasing *)perror {
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error];
    if (error != nil) {
        if (perror) {
            *perror = error;
        }
        return nil;
    }

    return [[InspurFileRecorder alloc] initWithFolder:directory encodeKey:encode];
}

- (instancetype)initWithFolder:(NSString *)directory encodeKey:(BOOL)encode {
    if (self = [super init]) {
        _directory = directory;
        _encode = encode;
    }
    return self;
}

- (NSError *)set:(NSString *)key
            data:(NSData *)value {
    NSError *error;
    if (_encode) {
        key = [InspurUrlSafeBase64 encodeString:key];
    }
    [value writeToFile:[self pathOfKey:key] options:NSDataWritingAtomic error:&error];
    return error;
}

- (NSData *)get:(NSString *)key {
    if (_encode) {
        key = [InspurUrlSafeBase64 encodeString:key];
    }
    return [NSData dataWithContentsOfFile:[self pathOfKey:key]];
}

- (NSError *)del:(NSString *)key {
    NSError *error;
    if (_encode) {
        key = [InspurUrlSafeBase64 encodeString:key];
    }
    [[NSFileManager defaultManager] removeItemAtPath:[self pathOfKey:key] error:&error];
    return error;
}

- (NSString *)getFileName{
    return nil;
}

+ (void)removeKey:(NSString *)key
        directory:(NSString *)dir
        encodeKey:(BOOL)encode {
    if (encode) {
        key = [InspurUrlSafeBase64 encodeString:key];
    }
    NSError *error;
    NSString *path = [InspurFileRecorder pathJoin:key path:dir];
    [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    if (error) {
        NSLog(@"%s,%@", __func__, error);
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, dir: %@>", NSStringFromClass([self class]), self, _directory];
}

@end
