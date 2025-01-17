//
//  InspurPipeline.m
//  InspurOSSSDK
//
//  Created by Brook on 2017/7/25.
//  Copyright © 2017年 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "InspurSessionManager.h"

#import "InspurPipeline.h"

@implementation InspurPipelineConfig

- (instancetype)init {
    return [self initWithHost:@"https://pipeline.qiniu.com"];
}

- (instancetype)initWithHost:(NSString*)host {
    if (self = [super init]) {
        _host = host;
        _timeoutInterval = 10;
    }
    return self;
}

@end

@interface InspurPipeline ()

@property (nonatomic) InspurSessionManager *httpManager;
@property (nonatomic) InspurPipelineConfig* config;

+ (NSDateFormatter*)dateFormatter;

@end

static NSString* buildString(NSObject* obj) {
    NSString* v;
    if ([obj isKindOfClass:[NSNumber class]]) {
        NSNumber* num = (NSNumber*)obj;
        if (num == (void*)kCFBooleanFalse) {
            v = @"false";
        } else if (num == (void*)kCFBooleanTrue) {
            v = @"true";
        } else if (!strcmp(num.objCType, @encode(BOOL))) {
            if ([num intValue] == 0) {
                v = @"false";
            } else {
                v = @"true";
            }
        } else {
            v = num.stringValue;
        }
    } else if ([obj isKindOfClass:[NSString class]]) {
        v = (NSString*)obj;
        v = [v stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
        v = [v stringByReplacingOccurrencesOfString:@"\t" withString:@"\\t"];
    } else if ([obj isKindOfClass:[NSDictionary class]] || [obj isKindOfClass:[NSArray class]] || [obj isKindOfClass:[NSSet class]]) {
        v = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:obj options:kNilOptions error:nil] encoding:NSUTF8StringEncoding];
    } else if ([obj isKindOfClass:[NSDate class]]) {
        v = [[InspurPipeline dateFormatter] stringFromDate:(NSDate*)obj];
    } else {
        v = [obj description];
    }
    return v;
}

static void formatPoint(NSDictionary* event, NSMutableString* buffer) {
    [event enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSObject* obj, BOOL* stop) {
        if (obj == nil || [obj isEqual:[NSNull null]]) {
            return;
        }
        [buffer appendString:key];
        [buffer appendString:@"="];
        [buffer appendString:buildString(obj)];
        [buffer appendString:@"\t"];
    }];
    NSRange range = NSMakeRange(buffer.length - 1, 1);
    [buffer replaceCharactersInRange:range withString:@"\n"];
}

static NSMutableString* formatPoints(NSArray<NSDictionary*>* events) {
    NSMutableString* str = [NSMutableString new];
    [events enumerateObjectsUsingBlock:^(NSDictionary* _Nonnull obj, NSUInteger idx, BOOL* _Nonnull stop) {
        formatPoint(obj, str);
    }];
    return str;
}

@implementation InspurPipeline

- (instancetype)init:(InspurPipelineConfig*)config {
    if (self = [super init]) {
        if (config == nil) {
            config = [InspurPipelineConfig new];
        }
        _config = config;
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1090)
        _httpManager = [[InspurSessionManager alloc] initWithProxy:nil timeout:config.timeoutInterval urlConverter:nil];
#endif
    }
    return self;
}

- (void)pumpRepo:(NSString*)repo
           event:(NSDictionary*)data
           token:(NSString*)token
         handler:(InspurPipelineCompletionHandler)handler {
    NSMutableString* str = [NSMutableString new];
    formatPoint(data, str);
    [self pumpRepo:repo string:str token:token handler:handler];
}

- (void)pumpRepo:(NSString*)repo
          events:(NSArray<NSDictionary*>*)data
           token:(NSString*)token
         handler:(InspurPipelineCompletionHandler)handler {
    NSMutableString* str = formatPoints(data);
    [self pumpRepo:repo string:str token:token handler:handler];
}

- (NSString*)url:(NSString*)repo {
    return [NSString stringWithFormat:@"%@/v2/repos/%@/data", _config.host, repo];
}

- (void)pumpRepo:(NSString*)repo
          string:(NSString*)str
           token:(NSString*)token
         handler:(InspurPipelineCompletionHandler)handler {
    NSDictionary* headers = @{ @"Authorization" : token,
                               @"Content-Type" : @"text/plain" };
    [_httpManager post:[self url:repo] withData:[str dataUsingEncoding:NSUTF8StringEncoding] withParams:nil withHeaders:headers withIdentifier:nil withCompleteBlock:^(InspurResponseInfo *httpResponseInfo, NSDictionary *respBody) {
        handler(httpResponseInfo);
    } withProgressBlock:nil withCancelBlock:nil withAccess:nil];
}

+ (NSDateFormatter*)dateFormatter {
    static NSDateFormatter* formatter = nil;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        [formatter setLocale:[NSLocale currentLocale]];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSXXX"];
        [formatter setTimeZone:[NSTimeZone defaultTimeZone]];
    });

    return formatter;
}

@end
