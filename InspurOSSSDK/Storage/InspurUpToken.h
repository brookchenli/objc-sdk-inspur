//
//  InspurUpToken.h
//  InspurOSSSDK
//
//  Created by Brook on 15/6/7.
//  Copyright (c) 2015年 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^InspurUpTokenSignatureResultHandler)(NSArray <NSString *> * _Nullable signaturedContents, NSError  * _Nullable error);
typedef void (^InspurUpTokenSignatureHandler)(NSArray <NSString *> * _Nullable contentsNeedSignature, InspurUpTokenSignatureResultHandler _Nullable result);


@interface InspurUpToken : NSObject

- (instancetype)initBucket:(NSString *)bucket
                  deadLine:(long)deadLine
                 accessKey:(NSString *)accessKey
                     domin:(NSString *)domin;

+ (instancetype)parse:(NSString *)token;

@property (assign, nonatomic, readonly) long deadline;
@property (copy  , nonatomic, readonly) NSString *access;
@property (copy  , nonatomic, readonly) NSString *bucket;
@property (copy  , nonatomic, readonly) NSString *token;
@property (copy  , nonatomic, readonly) NSString *domin;

@property (copy  , nonatomic) InspurUpTokenSignatureHandler signatureHandler;

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
