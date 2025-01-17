//
//  InspurFile.m
//  InspurOSSSDK
//
//  Created by Brook on 15/7/25.
//  Copyright (c) 2015年 Inspur. All rights reserved.
//

#import "InspurFile.h"
#import "InspurResponseInfo.h"

@interface InspurFile ()

@property (nonatomic, readonly) NSString *filepath;

@property (nonatomic) NSData *data;

@property (readonly) int64_t fileSize;

@property (readonly) int64_t fileModifyTime;

@property (nonatomic) NSFileHandle *file;

@property (nonatomic) NSLock *lock;

@end

@implementation InspurFile

- (instancetype)init:(NSString *)path
               error:(NSError *__autoreleasing *)error {
    if (self = [super init]) {
        _filepath = path;
        NSError *error2 = nil;
        NSDictionary *fileAttr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error2];
        if (error2 != nil) {
            if (error != nil) {
                *error = error2;
            }
            return self;
        }
        _fileSize = [fileAttr fileSize];
        NSDate *modifyTime = fileAttr[NSFileModificationDate];
        int64_t t = 0;
        if (modifyTime != nil) {
            t = [modifyTime timeIntervalSince1970];
        }
        _fileModifyTime = t;
        NSFileHandle *f = nil;
        NSData *d = nil;
        //[NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:&error] 不能用在大于 200M的文件上，改用filehandle
        // 参见 https://issues.apache.org/jira/browse/CB-5790
        if (_fileSize > 16 * 1024 * 1024) {
            f = [NSFileHandle fileHandleForReadingAtPath:path];
            if (f == nil) {
                if (error != nil) {
                    *error = [[NSError alloc] initWithDomain:path code:kInspurFileError userInfo:nil];
                }
                return self;
            }
        } else {
            d = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:&error2];
            if (error2 != nil) {
                if (error != nil) {
                    *error = error2;
                }
                return self;
            }
        }
        _file = f;
        _data = d;
        _lock = [[NSLock alloc] init];
    }

    return self;
}

- (NSData *)read:(long long)offset
            size:(long)size
           error:(NSError **)error {

    NSData *data = nil;
    @try {
        [_lock lock];
        if (_data != nil && offset < _data.length) {
            NSUInteger realSize = MIN((NSUInteger)size, _data.length - ((NSUInteger)offset));
            data = [_data subdataWithRange:NSMakeRange((NSUInteger)offset, realSize)];
        } else if (_file != nil && offset < _fileSize) {
            [_file seekToFileOffset:offset];
            data = [_file readDataOfLength:size];
        } else {
            data = [NSData data];
        }
    } @catch (NSException *exception) {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:kInspurFileError userInfo:@{NSLocalizedDescriptionKey : exception.reason}];
        NSLog(@"read file failed reason: %@ \n%@", exception.reason, exception.callStackSymbols);
    } @finally {
        [_lock unlock];
    }
    return data;
}

- (NSData *)readAllWithError:(NSError **)error {
    return [self read:0 size:(long)_fileSize error:error];
}

- (void)close {
    if (_file != nil) {
        [_file closeFile];
    }
}

- (NSString *)path {
    return _filepath;
}

- (int64_t)modifyTime {
    return _fileModifyTime;
}

- (int64_t)size {
    return _fileSize;
}

- (NSString *)fileType {
    return @"File";
}
@end
