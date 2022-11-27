//
//  QNUpToken.h
//  QiniuSDK
//
//  Created by bailong on 15/6/7.
//  Copyright (c) 2015年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^QNUpTokenSignatureResultHandler)(NSString *signture, NSError  * _Nullable error);
typedef void (^QNUpTokenSignatureHandler)(NSString *contentNeedSignature, QNUpTokenSignatureResultHandler result);


@interface QNUpToken : NSObject

- (instancetype)initBucket:(NSString *)bucket
                  deadLine:(long)deadLine
                 accessKey:(NSString *)accessKey;

+ (instancetype)parse:(NSString *)token;

@property (assign, nonatomic, readonly) long deadline;
@property (copy  , nonatomic, readonly) NSString *access;
@property (copy  , nonatomic, readonly) NSString *bucket;
@property (copy  , nonatomic, readonly) NSString *token;

@property (copy  , nonatomic) QNUpTokenSignatureHandler signatureHandler;

@property (readonly) BOOL isValid;
@property (readonly) BOOL hasReturnUrl;

+ (instancetype)getInvalidToken;

- (NSString *)index;

/// 是否在未来 duration 分钟内有效
- (BOOL)isValidForDuration:(long)duration;

/// 在是否在 date 之前有效
- (BOOL)isValidBeforeDate:(NSDate *)date;

- (NSString *)toString;

@end
