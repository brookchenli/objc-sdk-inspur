//
//  InspurUploadOption.m
//  InspurOSSSDK
//
//  Created by Brook on 14/10/4.
//  Copyright (c) 2014年 Inspur. All rights reserved.
//

#import "InspurUploadOption.h"
#import "InspurUploadManager.h"

static NSString *mime(NSString *mimeType) {
    if (mimeType == nil || [mimeType isEqualToString:@""]) {
        return @"application/octet-stream";
    }
    return mimeType;
}

@implementation InspurUploadOption

+ (NSDictionary *)filterParam:(NSDictionary *)params {
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    if (params == nil) {
        return ret;
    }

    [params enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        if ([key hasPrefix:@"x:"] && ![obj isEqualToString:@""]) {
            ret[key] = obj;
        } else {
            NSLog(@"参数%@设置无效，请检查参数格式", key);
        }
    }];

    return ret;
}

+ (NSDictionary *)filterMetaDataParam:(NSDictionary *)params {
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    if (params == nil) {
        return ret;
    }

    [params enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        if ([key hasPrefix:@"x-qn-meta-"] && ![obj isEqualToString:@""]) {
            ret[key] = obj;
        } else {
            NSLog(@"参数%@设置无效，请检查参数格式", key);
        }
    }];

    return ret;
}


- (instancetype)initWithProgressHandler:(InspurUpProgressHandler)progress {
    return [self initWithMime:nil progressHandler:progress params:nil checkCrc:NO cancellationSignal:nil];
}

- (instancetype)initWithByteProgressHandler:(InspurUpByteProgressHandler)progress {
    return [self initWithMime:nil byteProgressHandler:progress params:nil checkCrc:NO cancellationSignal:nil];
}

- (instancetype)initWithMime:(NSString *)mimeType
             progressHandler:(InspurUpProgressHandler)progress
                      params:(NSDictionary *)params
                    checkCrc:(BOOL)check
          cancellationSignal:(InspurUpCancellationSignal)cancel {
    return [self initWithMime:mimeType
              progressHandler:progress
                       params:params
               metaDataParams:nil
                     checkCrc:check
           cancellationSignal:cancel];
}

- (instancetype)initWithMime:(NSString *)mimeType
         byteProgressHandler:(InspurUpByteProgressHandler)progress
                      params:(NSDictionary *)params
                    checkCrc:(BOOL)check
          cancellationSignal:(InspurUpCancellationSignal)cancellation {
    return [self initWithMime:mimeType
          byteProgressHandler:progress
                       params:params
               metaDataParams:nil
                     checkCrc:check
           cancellationSignal:cancellation];
}

- (instancetype)initWithMime:(NSString *)mimeType
             progressHandler:(InspurUpProgressHandler)progress
                      params:(NSDictionary *)params
              metaDataParams:(NSDictionary *)metaDataParams
                    checkCrc:(BOOL)check
          cancellationSignal:(InspurUpCancellationSignal)cancellation{
    if (self = [super init]) {
        _mimeType = mime(mimeType);
        _progressHandler = progress != nil ? progress : ^(NSString *key, float percent) {};
        _params = [InspurUploadOption filterParam:params];
        _metaDataParam = [InspurUploadOption filterMetaDataParam:metaDataParams];
        _checkCrc = check;
        _cancellationSignal = cancellation != nil ? cancellation : ^BOOL() {
            return NO;
        };
    }

    return self;
}

- (instancetype)initWithMime:(NSString *)mimeType
         byteProgressHandler:(InspurUpByteProgressHandler)progress
                      params:(NSDictionary *)params
              metaDataParams:(NSDictionary *)metaDataParams
                    checkCrc:(BOOL)check
          cancellationSignal:(InspurUpCancellationSignal)cancellation {
    if (self = [super init]) {
        _mimeType = mime(mimeType);
        _byteProgressHandler = progress != nil ? progress : ^(NSString *key, long long uploadBytes, long long totalBytes) {};
        _params = [InspurUploadOption filterParam:params];
        _metaDataParam = [InspurUploadOption filterMetaDataParam:metaDataParams];
        _checkCrc = check;
        _cancellationSignal = cancellation != nil ? cancellation : ^BOOL() {
            return NO;
        };
    }

    return self;
}

+ (instancetype)defaultOptions {
    return [[InspurUploadOption alloc] initWithMime:nil byteProgressHandler:nil params:nil checkCrc:NO cancellationSignal:nil];
}

@end
