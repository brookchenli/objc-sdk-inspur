//
//  QNALAssetFile.m
//  InspurOSSSDK
//
//  Created by Brook on 15/7/25.
//  Copyright (c) 2015年 Inspur. All rights reserved.
//

#import "InspurALAssetFile.h"

#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
#if !TARGET_OS_MACCATALYST
#import <AssetsLibrary/AssetsLibrary.h>
#import "InspurResponseInfo.h"

@interface InspurALAssetFile ()

@property (nonatomic) ALAsset *asset;

@property (readonly) int64_t fileSize;

@property (readonly) int64_t fileModifyTime;

@property (nonatomic, strong) NSLock *lock;

@end

@implementation InspurALAssetFile
- (instancetype)init:(ALAsset *)asset
               error:(NSError *__autoreleasing *)error {
    if (self = [super init]) {
        NSDate *createTime = [asset valueForProperty:ALAssetPropertyDate];
        int64_t t = 0;
        if (createTime != nil) {
            t = [createTime timeIntervalSince1970];
        }
        _fileModifyTime = t;
        _fileSize = asset.defaultRepresentation.size;
        _asset = asset;
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
        ALAssetRepresentation *rep = [self.asset defaultRepresentation];
        Byte *buffer = (Byte *)malloc(size);
        NSUInteger buffered = [rep getBytes:buffer fromOffset:offset length:size error:error];
        data = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
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
}

- (NSString *)path {
    ALAssetRepresentation *rep = [self.asset defaultRepresentation];
    return [rep url].path;
}

- (int64_t)modifyTime {
    return _fileModifyTime;
}

- (int64_t)size {
    return _fileSize;
}

- (NSString *)fileType {
    return @"ALAsset";
}
@end
#endif
#endif
