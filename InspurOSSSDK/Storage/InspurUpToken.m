//
//  InspurUpToken.m
//  InspurOSSSDK
//
//  Created by Brook on 15/6/7.
//  Copyright (c) 2015年 Inspur. All rights reserved.
//

#import "InspurUrlSafeBase64.h"
#import "InspurUpToken.h"

#define kInspurPolicyKeyScope @"scope"
#define kInspurPolicyKeyDeadline @"deadline"
#define kInspurPolicyKeyReturnUrl @"returnUrl"
@interface InspurUpToken ()

- (instancetype)init:(NSDictionary *)policy token:(NSString *)token;

@end

@implementation InspurUpToken

+ (instancetype)getInvalidToken {
    InspurUpToken *token = [[InspurUpToken alloc] init];
    token->_deadline = -1;
    return token;
}

- (instancetype)initBucket:(NSString *)bucket
                  deadLine:(long)deadLine
                 accessKey:(NSString *)accessKey
                     domin:(NSString *)domin{
    if (self = [super init]) {
        _token = [NSString stringWithFormat:@"%@:%@:%@", bucket, accessKey,@(deadLine)];
        _access = accessKey;
        _bucket = bucket;
        _deadline = deadLine;
        _domin = domin;
    }
    return self;
}

- (instancetype)init:(NSDictionary *)policy token:(NSString *)token {
    if (self = [super init]) {
        _token = token;
        _access = [self getAccess];
        _bucket = [self getBucket:policy];
        _deadline = [policy[kInspurPolicyKeyDeadline] longValue];
        _hasReturnUrl = (policy[kInspurPolicyKeyReturnUrl] != nil);
    }

    return self;
}

- (NSString *)getAccess {
    
    NSRange range = [_token rangeOfString:@":" options:NSCaseInsensitiveSearch];
    return [_token substringToIndex:range.location];
}

- (NSString *)getBucket:(NSDictionary *)info {

    NSString *scope = [info objectForKey:kInspurPolicyKeyScope];
    if (!scope || [scope isKindOfClass:[NSNull class]]) {
        return @"";
    }

    NSRange range = [scope rangeOfString:@":"];
    if (range.location == NSNotFound) {
        return scope;
    }
    return [scope substringToIndex:range.location];
}

+ (instancetype)parseInspur:(NSString *)token {
    if (token == nil) {
        return nil;
    }
    NSArray *array = [token componentsSeparatedByString:@":"];
    if (array == nil || array.count != 3) {
        return nil;
    }
    //bucket, accessKey,@(deadLine)
    NSString *bucket = array[0];
    NSString *accessKey = array[1];
    long deadLine = [array[2] longValue];
    return [[InspurUpToken alloc] initBucket:bucket deadLine:deadLine accessKey:accessKey domin:@""];
}


+ (instancetype)parse:(NSString *)token {
    if (token == nil) {
        return nil;
    }
    NSArray *array = [token componentsSeparatedByString:@":"];
    if (array == nil || array.count != 3) {
        return nil;
    }

    NSData *data = [InspurUrlSafeBase64 decodeString:array[2]];
    if (!data) {
        return nil;
    }
    
    NSError *tmp = nil;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&tmp];
    if (tmp != nil || dict[kInspurPolicyKeyScope] == nil || dict[kInspurPolicyKeyDeadline] == nil) {
        return nil;
    }
    return [[InspurUpToken alloc] init:dict token:token];
}

- (NSString *)index {
    return [NSString stringWithFormat:@"%@:%@", _access, _bucket];
}

- (BOOL)isValid {
    return _access && _access.length > 0 && _bucket && _bucket.length > 0;
}

- (BOOL)isValidForDuration:(long)duration {
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:duration];
    return [self isValidBeforeDate:date];
}

- (BOOL)isValidBeforeDate:(NSDate *)date {
    if (date == nil) {
        return NO;
    }
    return [date timeIntervalSince1970] < self.deadline;
}

- (NSString *)toString {
    return _token;
}



@end
