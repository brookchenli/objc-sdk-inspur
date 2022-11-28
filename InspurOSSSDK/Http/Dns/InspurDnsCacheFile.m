//
//  InspurDnsCacheFile.m
//  InspurDNS
//
//  Created by Brook on 2020/3/26.
//  Copyright © 2020 com.inspur. All rights reserved.
//

#import "InspurDnsCacheFile.h"

@interface InspurDnsCacheFile()

@property(nonatomic,  copy)NSString *directory;

@end
@implementation InspurDnsCacheFile

+ (instancetype)dnsCacheFile:(NSString *)directory
                       error:(NSError **)error{
    NSError *err = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&err];
    if (err != nil) {
        if (error != nil) *error = err;
        return nil;
    }
    
    InspurDnsCacheFile *f = [[InspurDnsCacheFile alloc] init];
    f.directory = directory;
    return f;
}

- (NSError *)set:(NSString *)key data:(NSData *)value {
    @synchronized (self) {
        NSError *error;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *filePath = [self pathOfKey:key];
        if ([fileManager fileExistsAtPath:filePath]) {
            [fileManager removeItemAtPath:filePath error:&error];
        }
        [fileManager createFileAtPath:filePath contents:value attributes:nil];
        return error;
    }
}

- (NSData *)get:(NSString *)key {
    return [NSData dataWithContentsOfFile:[self pathOfKey:key]];
}

- (NSError *)del:(NSString *)key {
    @synchronized (self) {
        NSError *error = nil;
        NSString *path = [self pathOfKey:key];
        if (path) {
            NSFileManager *fileManager = [NSFileManager defaultManager];
            [fileManager removeItemAtPath:path error:&error];
        }
        return error;
    }
}

- (void)clearCache:(NSError *__autoreleasing  _Nullable *)error {
    @synchronized (self) {
        NSError *err;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        [fileManager removeItemAtPath:self.directory error:&err];
        if (err != nil) {
            if (error != nil) *error = err;
            return;
        }
        
        [fileManager createDirectoryAtPath:self.directory withIntermediateDirectories:YES attributes:nil error:&err];
        if (error != nil) {
            *error = err;
        }
    }
}

- (NSString *)getFileName{
    return @"dnsCache";
}

- (NSString *)pathOfKey:(NSString *)key {
    return [InspurDnsCacheFile pathJoin:key path:_directory];
}

+ (NSString *)pathJoin:(NSString *)key
                  path:(NSString *)path {
    return [[NSString alloc] initWithFormat:@"%@/%@", path, key];
}

@end
