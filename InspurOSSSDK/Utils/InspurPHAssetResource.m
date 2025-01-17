//
//  InspurPHAssetResource.m
//  InspurOSSSDK
//
//  Created by   Brook on 16/2/14.
//  Copyright © 2016年 Inspur. All rights reserved.
//

#import "InspurPHAssetResource.h"
#import <Photos/Photos.h>
#import "InspurResponseInfo.h"

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000)

enum {
    kAMASSETMETADATA_PENDINGREADS = 1,
    kAMASSETMETADATA_ALLFINISHED = 0
};

@interface InspurPHAssetResource () {
    BOOL _hasGotInfo;
}

@property (nonatomic) PHAsset *phAsset;

@property (nonatomic) PHAssetResource *phAssetResource;

@property (nonatomic) int64_t fileSize;

@property (nonatomic) int64_t fileModifyTime;

@property (nonatomic, strong) NSData *assetData;

@property (nonatomic, strong) NSURL *assetURL;

@property (nonatomic, strong) NSLock *lock;

@end

@implementation InspurPHAssetResource
- (instancetype)init:(PHAssetResource *)phAssetResource
               error:(NSError *__autoreleasing *)error {
    if (self = [super init]) {
        PHAsset *phasset = [PHAsset fetchAssetsWithBurstIdentifier:self.phAssetResource.assetLocalIdentifier options:nil][0];
        NSDate *createTime = phasset.creationDate;
        int64_t t = 0;
        if (createTime != nil) {
            t = [createTime timeIntervalSince1970];
        }
        _fileModifyTime = t;
        _phAssetResource = phAssetResource;
        _lock = [[NSLock alloc] init];
        [self getInfo];
    }
    return self;
}

- (NSData *)read:(long long)offset
            size:(long)size
           error:(NSError **)error {
    
    NSData *data = nil;
    @try {
        [_lock lock];
        if (!self.assetData) {
            self.assetData = [self fetchDataFromAsset:self.phAssetResource error:error];
        }
        
        if (_assetData != nil && offset < _assetData.length) {
            NSUInteger realSize = MIN((NSUInteger)size, _assetData.length - (NSUInteger)offset);
            data = [_assetData subdataWithRange:NSMakeRange((NSUInteger)offset, realSize)];
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
}

- (NSString *)path {
    return self.assetURL.path;
}

- (int64_t)modifyTime {
    return _fileModifyTime;
}

- (int64_t)size {
    return _fileSize;
}

- (NSString *)fileType {
    return @"PHAssetResource";
}

- (void)getInfo {
    if (!_hasGotInfo) {
        _hasGotInfo = YES;
        NSConditionLock *assetReadLock = [[NSConditionLock alloc] initWithCondition:kAMASSETMETADATA_PENDINGREADS];

        NSString *fileName = [NSString stringWithFormat:@"tempAsset-%f-%d.mov", [[NSDate date] timeIntervalSince1970], arc4random()%100000];
        NSString *pathToWrite = [NSTemporaryDirectory() stringByAppendingString:fileName];
        NSURL *localpath = [NSURL fileURLWithPath:pathToWrite];
        PHAssetResourceRequestOptions *options = [PHAssetResourceRequestOptions new];
        options.networkAccessAllowed = YES;
        [[PHAssetResourceManager defaultManager] writeDataForAssetResource:self.phAssetResource toFile:localpath options:options completionHandler:^(NSError *_Nullable error) {
            if (error == nil) {
                AVURLAsset *urlAsset = [AVURLAsset URLAssetWithURL:localpath options:nil];
                NSNumber *fileSize = nil;
                [urlAsset.URL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:nil];
                self.fileSize = [fileSize unsignedLongLongValue];
                self.assetURL = urlAsset.URL;
                self.assetData = [NSData dataWithData:[NSData dataWithContentsOfURL:urlAsset.URL]];
            } else {
                NSLog(@"%@", error);
            }

            BOOL blHave = [[NSFileManager defaultManager] fileExistsAtPath:pathToWrite];
            if (!blHave) {
                return;
            } else {
                [[NSFileManager defaultManager] removeItemAtPath:pathToWrite error:nil];
            }
            [assetReadLock lock];
            [assetReadLock unlockWithCondition:kAMASSETMETADATA_ALLFINISHED];
        }];

        [assetReadLock lockWhenCondition:kAMASSETMETADATA_ALLFINISHED];
        [assetReadLock unlock];
        assetReadLock = nil;
    }
}

- (NSData *)fetchDataFromAsset:(PHAssetResource *)videoResource error:(NSError **)err {
    __block NSData *tmpData = [NSData data];
    __block NSError *innerError = *err;

    NSConditionLock *assetReadLock = [[NSConditionLock alloc] initWithCondition:kAMASSETMETADATA_PENDINGREADS];

    NSString *fileName = [NSString stringWithFormat:@"tempAsset-%f-%d.mov", [[NSDate date] timeIntervalSince1970], arc4random()%100000];
    NSString *pathToWrite = [NSTemporaryDirectory() stringByAppendingString:fileName];
    NSURL *localpath = [NSURL fileURLWithPath:pathToWrite];
    PHAssetResourceRequestOptions *options = [PHAssetResourceRequestOptions new];
    options.networkAccessAllowed = YES;
    [[PHAssetResourceManager defaultManager] writeDataForAssetResource:videoResource toFile:localpath options:options completionHandler:^(NSError *_Nullable error) {
        if (error == nil) {
            AVURLAsset *urlAsset = [AVURLAsset URLAssetWithURL:localpath options:nil];
            NSData *videoData = [NSData dataWithContentsOfURL:urlAsset.URL];
            tmpData = [NSData dataWithData:videoData];
        } else {
            innerError = error;
        }
        BOOL blHave = [[NSFileManager defaultManager] fileExistsAtPath:pathToWrite];
        if (!blHave) {
            return;
        } else {
            [[NSFileManager defaultManager] removeItemAtPath:pathToWrite error:nil];
        }
        [assetReadLock lock];
        [assetReadLock unlockWithCondition:kAMASSETMETADATA_ALLFINISHED];
    }];

    [assetReadLock lockWhenCondition:kAMASSETMETADATA_ALLFINISHED];
    [assetReadLock unlock];
    assetReadLock = nil;

    return tmpData;
}

@end

#endif
